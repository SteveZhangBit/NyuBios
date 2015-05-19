
org  07c00h         ; Boot 状态, Bios 将把 Boot Sector 加载到 0:7C00 处并开始执行

;==============================================================================
BaseOfStack     equ 07C00h

%include "load.inc"
;==============================================================================

jmp short LABEL_START        ; Start to boot.
nop                          ; 这个 nop 不可少

; 引入 FAT12 磁盘的头信息
%include "fat12hdr.inc"

LABEL_START:
    mov     ax, cs
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, BaseOfStack

    ; 清屏
    mov     ax, 0600h
    mov     bx, 0700h   ; 黑底白字
    mov     cx, 0       ; 左上角：（0，0）
    mov     dx, 0184Fh  ; 右下角：（80，50）
    int     10h

    mov     dh, 0   ; print Booting
    call    DispStr

    xor     ah, ah  ; 软驱复位
    xor     dl, dl
    int     13h

    ; 在A盘的根目录下寻找LOADER.BIN
    mov     word [SectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_ROOT_DIR_BEGIN:
    cmp     word [RootDirSize], 0
    jz      LABEL_NO_LOADER          ; 判断是否已遍历完整个根目录
    dec     word [RootDirSize]      ; 未读完，继续查找

    mov     ax, BaseOfLoader
    mov     es, ax                  ; es <- BaseOfLoader
    mov     bx, OffsetOfLoader      ; bx <- OffsetOfLoader, es:bx = BaseOfLoader:OffsetOfLoader
    mov     ax, [SectorNo]          ; 根目录中的某个Sector
    mov     cl, 1
    call    ReadSector

    mov     si, LoaderFileName      ; ds:si -> "LOADER  BIN"
    mov     di, OffsetOfLoader      ; es:di -> BaseOfLoader:OffsetOfLoader
    cld
    mov     dx, 10h
LABEL_SEARCH_LOADERBIN:
    cmp     dx, 0
    jz      LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR ; 读完一个sector，跳到下一个
    dec     dx
    mov     cx, 11
LABEL_CMP_FILENAME:
    cmp     cx, 0
    jz      LABEL_FILENAME_FOUND     ; 如果比较了11个字符都相等，表示找到
    dec     cx
    lodsb                       ; ds:si -> al
    cmp     al, byte [es:di]
    jz      LABEL_GO_ON
    jmp     LABEL_DIFFERENT         ; 发现不一样的，说明不是我们要找的LOADER.BIN
LABEL_GO_ON:
    inc     di
    jmp     LABEL_CMP_FILENAME

LABEL_DIFFERENT:
    and     di, 0ffe0h              ; di &= e0h 指向本条目录开头
    add     di, 20h                 ; di += 20h 指向下一条目录
    mov     si, LoaderFileName
    jmp     LABEL_SEARCH_LOADERBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
    add     word [SectorNo], 1
    jmp     LABEL_SEARCH_ROOT_DIR_BEGIN

LABEL_NO_LOADER:
    mov     dh, 2       ; "No LOADER"
    call    DispStr
%ifdef _BOOT_DEBUG_
    mov     ax, 4C00h
    int     21h
%else
    jmp $           ; 没有Loader，死循环在这
%endif

LABEL_FILENAME_FOUND:
    mov     ax, RootDirSectors
    and     di, 0ffe0h          ; di -> 当前目录的开始
    add     di, 01ah            ; di -> 首sector
    mov     cx, word [es:di]
    push    cx
    add     cx, ax
    add     cx, DeltaSectorNo   ; cl <- LOADER.BIN的起始扇区号
    mov     ax, BaseOfLoader
    mov     es, ax              ; es <- BaseOfLoader
    mov     bx, OffsetOfLoader
    mov     ax, cx

LABEL_GO_ON_LOADING_FILE:
    ; 每读一个扇区，就在Booting后面打一个点
    push    ax
    push    bx
    mov     ah, 0Eh
    mov     al, '.'
    mov     bl, 0Fh
    int     10h
    pop     bx
    pop     ax

    mov     cl, 1
    call    ReadSector
    pop     ax              ; 取出此Sector在FAT中的序号
    call    GetFATEntry
    cmp     ax, 0FFFh
    jz      LABEL_FILE_LOADED
    push    ax             ; 保存Sector在FAT中序号
    mov     dx, RootDirSectors
    add     ax, dx
    add     ax, DeltaSectorNo
    add     bx, [BPB_BytsPerSec]
    jmp     LABEL_GO_ON_LOADING_FILE

LABEL_FILE_LOADED:
    mov     dh, 1           ; "Ready"
    call    DispStr

    ; 正式跳转到以加载到内存中的LOADER.BIN开始出，开始执行LOADER.BIN
    jmp     BaseOfLoader:OffsetOfLoader

;==============================================================================
; 变量
;==============================================================================
RootDirSize     dw RootDirSectors   ; 根目录占用的扇区数，在循环中递减
SectorNo        dw 0    ; 要读取的扇区号
isOdd           db 0    ; 奇数还是偶数

;==============================================================================
; 字符串
;==============================================================================
LoaderFileName  db "LOADER  BIN", 0     ; LOADER.BIN文件名
MessageLength   equ 9
BootMessage     db "Booting  "
Message1        db "Ready.   "
Message2        db "No LOADER"

;==============================================================================
; 函数名：DispStr
; 作用：
;   显示一个字符串，dh中为字符串序号，方便起见，字符串长度相同
DispStr:
    mov     ax, MessageLength  ; 计算字符串的偏移量
    mul     dh
    add     ax, BootMessage

    mov     bp, ax          ; ES:BP = 串地址
    mov     ax, ds
    mov     es, ax

    mov     cx, MessageLength  ; cx = 串长度
    mov     ax, 01301h         ; ah = 13,  al = 01h
    mov     bx, 0007h          ; 页号为0(bh = 0) 黑底白字(bl = 07h)
    mov     dl, 0
    int     10h                ; int 10h

    ret

;==============================================================================
; 函数名：ReadSector
; 作用：
;     从第ax个sectort开始，将cl个sector读入到es:bx中
ReadSector:
    ; -----------------------------------------------------------------------
    ; 怎样由扇区号求扇区在磁盘中的位置 (扇区号 -> 柱面号, 起始扇区, 磁头号)
    ; -----------------------------------------------------------------------
    ; 设扇区号为 x
    ;                           ┌ 柱面号 = y >> 1
    ;       x           ┌ 商 y ┤
    ; -------------- => ┤      └ 磁头号 = y & 1
    ;  每磁道扇区数     │
    ;                   └ 余 z => 起始扇区号 = z + 1
    push    bp
    mov     bp, sp
    sub     esp, 2          ; 辟出两个字节的堆栈区域保存要读的扇区数: byte [bp-2]

    mov     byte [bp - 2], cl
    push    bx
    mov     bl, [BPB_SecPerTrk]     ; 每磁道扇区数，用作除数
    div     bl                      ; 商y在al中，余数z在ah中
    inc     ah                      ; z++
    mov     cl, ah                  ; cl <- 起始扇区号
    mov     dh, al                  ; dh <- y
    shr     al, 1                   ; y >> 1 (其实是 y/BPB_NumHeads, 这里BPB_NumHeads=2)
    mov     ch, al                  ; ch <- 柱面号
    and     dh, 1                   ; dh & 1 = 磁头号
    pop     bx                      ; 恢复bx
    ; 至此, "柱面号, 起始扇区, 磁头号" 全部得到
    mov     dl, [BS_DrvNum]         ; 驱动器号 (0 表示 A 盘)

.Reading:
    mov     ah, 2
    mov     al, byte [bp - 2]       ; 读al个扇区
    int     13h
    jc      .Reading                 ; 如果读取错误 CF 会被置为 1, 这时就不停地读, 直到正确为止

    add     esp, 2                  ; 恢复栈中的信息，返回函数
    pop     bp

    ret

;==============================================================================
; 函数名：GetFATEntry
; 作用：
;   找到序号为 ax 的 Sector 在 FAT 中的条目, 结果放在 ax 中
;   需要注意的是, 中间需要读 FAT 的扇区到 es:bx 处, 所以函数一开始保存了 es 和 bx
GetFATEntry:
    push    es
    push    bx
    push    ax

    mov     ax, BaseOfLoader
    sub     ax, 0100h           ; 在 BaseOfLoader 后面留出 4K 空间用于存放 FAT
    mov     es, ax
    pop     ax

    mov     byte [isOdd], 0
    mov     bx, 3
    mul     bx                  ; ax * 3
    mov     bx, 2
    div     bx                  ; ax / 2 ==> ax <- 商, dx <- 余数
    cmp     dx, 0
    jz      LABEL_EVEN
    mov     byte [isOdd], 1
LABEL_EVEN:     ; 偶数
    ; 现在 ax 中是 FATEntry 在 FAT 中的偏移量,下面来
    ; 计算 FATEntry 在哪个扇区中(FAT占用不止一个扇区)
    xor     dx, dx
    mov     bx, [BPB_BytsPerSec]
    div     bx                  ; dx:ax / BPB_BytsPerSec
                            ; ax <- 商 (FATEntry 所在的扇区相对于 FAT 的扇区号)
                            ; dx <- 余数 (FATEntry 在扇区内的偏移)
    push    dx
    mov     bx, 0               ; es:bx = (BaseOfLoader - 100):00
    add     ax, SectorNoOfFAT1  ; 此句之后的 ax 就是 FATEntry 所在的扇区号
    mov     cl, 2
    call    ReadSector         ; 读取 FATEntry 所在的扇区, 一次读两个, 避免在边界
                            ; 发生错误, 因为一个 FATEntry 可能跨越两个扇区
    pop     dx
    add     bx, dx
    mov     ax, [es:bx]
    cmp     byte [isOdd], 1
    jnz     LABEL_EVEN_2
    shr     ax, 4
LABEL_EVEN_2:
    and     ax, 0FFFh

LABEL_GET_FAT_ENTRY_OK:
    pop     bx
    pop     es
    ret

;==================================================================================================
times   510-($-$$)  db  0   ; 填充剩下的空间，使生成的二进制代码恰好为512字节
dw  0xaa55                  ; 结束标志
