org  0100h
jmp LABEL_START     ; Start

; 引入 FAT12 磁盘的头信息
%include "fat12hdr.inc"
%include "load.inc"
%include "pm.inc"

BaseOfStack     equ 0100h       ; 堆栈基地址（栈底，向低地址生长）

; GDT
;                                   段基址     段界限         属性
LABEL_GDT:              Descriptor  0,          0,          0; 空描述符
LABEL_DESC_FLAT_C:      Descriptor  0,          0FFFFFh,    DA_CR | DA_32 | DA_LIMIT_4K  ; 0~4G
LABEL_DESC_FLAT_RW:     Descriptor  0,          0FFFFFh,    DA_DRW | DA_32 | DA_LIMIT_4K ; 0~4G
LABEL_DESC_VIDEO:       Descriptor  0B8000h,    0FFFFh,     DA_DRW | DA_DPL3 ; 显存首地址

GDTLen      equ $ - LABEL_GDT
GDTPtr      dw  GDTLen - 1                          ; 段界限
            dd  BaseOfLoaderPhyAddr + LABEL_GDT     ; 基地址

; Selectors
SelectorFlatC       equ LABEL_DESC_FLAT_C - LABEL_GDT
SelectorFlatRW      equ LABEL_DESC_FLAT_RW - LABEL_GDT
SelectorVideo       equ LABEL_DESC_VIDEO - LABEL_GDT + SA_RPL3
;==============================================================================



LABEL_START:
    mov     ax, cs
    mov     ds, ax
    mov     es, ax
    mov     ss, ax
    mov     sp, BaseOfStack

    mov     dh, 0   ; print "Loading"
    call    DispStrRealMode

    ; 得到内存大小
    mov     ebx, 0          ; ebx = 后续值，开始时为0
    mov     di, _MemChkBuf  ; es:di -> 一个地址范围描述符结构（ARDS）
.MemChkLoop:
    mov     eax, 0E820h
    mov     ecx, 20         ; ecx = 地址范围结构描述符大小
    mov     edx, 0534D4150h ; edx = 'SMAP'
    int     15h
    jc      .MemChkFail
    add     di, 20
    inc          dword [_dwMCRNumber]    ; dwMCRNumber = ARDS 的个数
    cmp     ebx, 0
    jne     .MemChkLoop
    jmp     .MemChkOK
.MemChkFail:
    mov     dword [_dwMCRNumber], 0
.MemChkOK:

    xor     ah, ah  ; 软驱复位
    xor     dl, dl
    int     13h

    ; 在A盘的根目录下寻找KERNEL.BIN
    mov     word [SectorNo], SectorNoOfRootDirectory
LABEL_SEARCH_ROOT_DIR_BEGIN:
    cmp     word [wRootDirSize], 0
    jz      LABEL_NO_KERNEL          ; 判断是否已遍历完整个根目录
    dec     word [wRootDirSize]      ; 未读完，继续查找

    mov     ax, BaseOfKernelFile
    mov     es, ax                  ; es <- BaseOfKernelFile
    mov     bx, OffsetOfKernelFile      ; bx <- OffsetOfKernelFile, es:bx = BaseOfKernelFile:OffsetOfKernelFile
    mov     ax, [SectorNo]          ; 根目录中的某个Sector
    mov     cl, 1
    call    ReadSector

    mov     si, KernelFileName      ; ds:si -> "KERNEL  BIN"
    mov     di, OffsetOfKernelFile      ; es:di -> BaseOfKernelFile:OffsetOfKernelFile
    cld
    mov     dx, 10h
LABEL_SEARCH_KERNELBIN:
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
    jmp     LABEL_DIFFERENT         ; 发现不一样的，说明不是我们要找的KERNEL.BIN
LABEL_GO_ON:
    inc          di
    jmp     LABEL_CMP_FILENAME

LABEL_DIFFERENT:
    and     di, 0ffe0h              ; di &= e0h 指向本条目录开头
    add     di, 20h                 ; di += 20h 指向下一条目录
    mov     si, KernelFileName
    jmp     LABEL_SEARCH_KERNELBIN

LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
    add     word [SectorNo], 1
    jmp     LABEL_SEARCH_ROOT_DIR_BEGIN

LABEL_NO_KERNEL:
    mov     dh, 2       ; "No KERNEL"
    call    DispStrRealMode
    jmp     $           ; 没有KERNEL.BIN，死循环在这

LABEL_FILENAME_FOUND:
    mov     ax, RootDirSectors
    and     di, 0FFF0h          ; di -> 当前目录的开始

    push    eax
    mov     eax, [es:di + 01Ch]
    mov     dword [dwKernelSize], eax     ;保存 KERNEL.BIN 文件大小
    pop     eax

    add     di, 01Ah            ; di -> 首sector
    mov     cx, word [es:di]
    push    cx
    add     cx, ax
    add     cx, DeltaSectorNo   ; cl <- KERNEL.BIN的起始扇区号
    mov     ax, BaseOfKernelFile
    mov     es, ax              ; es <- BaseOfKernelFile
    mov     bx, OffsetOfKernelFile
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
    call    KillMotor

    mov     dh, 1           ; "Ready"
    call    DispStrRealMode

    ; KERNEL.BIN 已经装入内存，准备跳入保护模式
    ; 加载GDTR
    lgdt    [GDTPtr]

    ; 关中断
    cli

    ; 打开A20地址线
    in      al, 92h
    or      al, 00000010b
    out     92h, al

    ; 准备切换到保护模式，设置cr0的PE位
    mov     eax, cr0
    or      eax, 1
    mov     cr0, eax

    ; 进入保护模式
    jmp     dword SelectorFlatC:(BaseOfLoaderPhyAddr + LABEL_PM_START)

;==============================================================================
; 变量
;==============================================================================
wRootDirSize    dw RootDirSectors   ; 根目录占用的扇区数，在循环中递减
SectorNo        dw 0    ; 要读取的扇区号
isOdd           db 0    ; 奇数还是偶数
dwKernelSize    dd 0    ; KERNEL.BIN 文件大小

;==============================================================================
; 字符串
;==============================================================================
KernelFileName  db "KERNEL  BIN", 0     ; KERNEL.BIN文件名
MessageLength   equ 9
LoadMessage     db "Loading  "
Message1        db "Ready.   "
Message2        db "No KERNEL"

;==============================================================================
; 函数名：DispStrRealMode
; 作用：
;   显示一个字符串，dh中为字符串序号，方便起见，字符串长度相同
DispStrRealMode:
    mov     ax, MessageLength  ; 计算字符串的偏移量
    mul     dh
    add     ax, LoadMessage

    mov     bp, ax          ; ES:BP = 串地址
    mov     ax, ds
    mov     es, ax

    mov     cx, MessageLength  ; cx = 串长度
    mov     ax, 01301h         ; ah = 13,  al = 01h
    mov     bx, 0007h          ; 页号为0(bh = 0) 黑底白字(bl = 07h)
    mov     dl, 0
    add     dh, 3
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

    mov     ax, BaseOfKernelFile
    sub     ax, 0100h           ; 在 BaseOfKernelFile 后面留出 4K 空间用于存放 FAT
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
    mov     bx, 0               ; es:bx = (BaseOfKernelFile - 100):00
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

;==============================================================================
; 函数名：KillMotor
; 作用：
;   关闭软驱马达
KillMotor:
    push    dx
    mov     dx, 03F2h
    mov     al, 0
    out     dx, al
    pop     dx
    ret

;==============================================================================
[SECTION .s32]
ALIGN 32
[BITS 32]

LABEL_PM_START:
    mov     ax, SelectorVideo
    mov     gs, ax

    mov     ax, SelectorFlatRW
    mov     ds, ax
    mov     es, ax
    mov     fs, ax
    mov     ss, ax
    mov     esp, TopOfStack

    push    szMemChkTitle
    call    DispStr
    add     esp, 4

    call    DispMemInfo
    call    SetupPaging

    call    InitKernel

    ; 正式进入内核
    jmp     SelectorFlatC:KernelEntryPointPhyAddr


; ------------------------------------------------------------------------
; 显示 AL 中的数字
; ------------------------------------------------------------------------
DispAL:
    push    ecx
    push    edx
    push    edi

    mov     edi, [dwDispPos]

    mov     ah, 07h
    mov     dl, al
    shr     al, 4
    mov     ecx, 2
.begin:
    and     al, 01111b
    cmp     al, 9
    ja      .1
    add     al, '0'
    jmp     .2
.1:
    sub     al, 0Ah
    add     al, 'A'
.2:
    mov     [gs:edi], ax
    add     edi, 2

    mov     al, dl
    loop    .begin
    ;add    edi, 2

    mov     [dwDispPos], edi

    pop     edi
    pop     edx
    pop     ecx

    ret
; DispAL 结束-------------------------------------------------------------


; ------------------------------------------------------------------------
; 显示一个整形数
; ------------------------------------------------------------------------
DispInt:
    mov     eax, [esp + 4]
    shr     eax, 24
    call    DispAL

    mov     eax, [esp + 4]
    shr     eax, 16
    call    DispAL

    mov     eax, [esp + 4]
    shr     eax, 8
    call    DispAL

    mov     eax, [esp + 4]
    call    DispAL

    mov     ah, 07h         ; 0000b: 黑底    0111b: 灰字
    mov     al, 'h'
    push    edi
    mov     edi, [dwDispPos]
    mov     [gs:edi], ax
    add     edi, 4
    mov     [dwDispPos], edi
    pop     edi

    ret
; DispInt 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 显示一个字符串
; ------------------------------------------------------------------------
DispStr:
    push    ebp
    mov     ebp, esp
    push    ebx
    push    esi
    push    edi

    mov     esi, [ebp + 8]  ; pszInfo
    mov     edi, [dwDispPos]
    mov     ah, 07h
.1:
    lodsb
    test    al, al
    jz      .2
    cmp     al, 0Ah ; 是回车吗?
    jnz     .3
    push    eax
    mov     eax, edi
    mov     bl, 160
    div     bl
    and     eax, 0FFh
    inc     eax
    mov     bl, 160
    mul     bl
    mov     edi, eax
    pop     eax
    jmp     .1
.3:
    mov     [gs:edi], ax
    add     edi, 2
    jmp     .1

.2:
    mov     [dwDispPos], edi

    pop     edi
    pop     esi
    pop     ebx
    pop     ebp
    ret
; DispStr 结束------------------------------------------------------------

; ------------------------------------------------------------------------
; 换行
; ------------------------------------------------------------------------
DispReturn:
    push    szReturn
    call    DispStr         ;printf("\n");
    add     esp, 4

    ret
; DispReturn 结束---------------------------------------------------------


; ------------------------------------------------------------------------
; 内存拷贝，仿 memcpy
; ------------------------------------------------------------------------
; void* MemCpy(void* es:pDest, void* ds:pSrc, int iSize);
; ------------------------------------------------------------------------
MemCpy:
    push    ebp
    mov     ebp, esp

    push    esi
    push    edi
    push    ecx

    mov     edi, [ebp + 8]  ; Destination
    mov     esi, [ebp + 12] ; Source
    mov     ecx, [ebp + 16] ; Counter
.1:
    cmp     ecx, 0      ; 判断计数器
    jz      .2      ; 计数器为零时跳出

    mov     al, [ds:esi]        ; ┓
    inc     esi         ; ┃
                    ; ┣ 逐字节移动
    mov     byte [es:edi], al   ; ┃
    inc     edi         ; ┛

    dec     ecx     ; 计数器减一
    jmp     .1      ; 循环
.2:
    mov     eax, [ebp + 8]  ; 返回值

    pop     ecx
    pop     edi
    pop     esi
    mov     esp, ebp
    pop     ebp

    ret         ; 函数结束，返回
; MemCpy 结束-------------------------------------------------------------

;------------------------------------------------------------------------------
DispMemInfo:    ; 显示内存信息
    push    esi
    push    edi
    push    ecx

    mov     esi, MemChkBuf
    mov     ecx, [dwMCRNumber]      ; for (int i = 0; i < [MCRNumber]; i++)
.0:                             ; {
    mov     edx, 5                  ;   for (int j = 0; j < 5; j++) // 遍历结构中5个成员
    mov     edi, ARDStruct          ;   {
.1:
    push    dword [esi]
    call    DispInt                ;       DispInt(MemChkBuf[j * 4]); // 显示一个成员
    pop     eax
    stosd                       ;       ARDStruct[j * 4] = MemChkBuf[j * 4];
    add     esi, 4
    dec     edx
    cmp     edx, 0
    jnz     .1                      ;   }
    call    DispReturn             ;   printf("\n");
    cmp     dword [dwType], 1       ;   if (Type == AddressRangeMemory)
    jne     .2                      ;   {
    mov     eax, [dwBaseAddrLow]
    add     eax, [dwLengthLow]
    cmp     eax, [dwMemSize]        ;       if (BaseAddrLow + LengthLow > MemSize)
    jb      .2
    mov     [dwMemSize], eax        ;           MemSize = BaseAddrLow + LengthLow;
.2:                             ;   }
    loop    .0                     ; }

    call    DispReturn             ; printf("\n");
    push    szRAMSize
    call    DispStr                ; printf("RAM size: ");
    add     esp, 4

    push    dword [dwMemSize]
    call    DispInt                ; DispInt(MemSize);
    add     esp, 4

    pop     ecx
    pop     edi
    pop     esi
    ret

;------------------------------------------------------------------------------
SetupPaging:    ; 启动分页机制
    ; 根据内存大小计算应该初始化多少PDE以及多少页表
    xor     edx, edx
    mov     eax, [dwMemSize]
    mov     ebx, 400000h        ; 400000h = 4M = 4096 * 1024，一个页表对应的内存大小
    div     ebx
    mov     ecx, eax            ; ecx为页表数，即PDE的个数
    test    edx, edx
    jz      .no_remainder
    inc     ecx                 ; 余数不为0，则补充一个页表
.no_remainder:
    push    ecx

    ; 为简化处理, 所有线性地址对应相等的物理地址. 并且不考虑内存空洞.

    ; 首先初始化页目录
    mov     ax, SelectorFlatRW
    mov     es, ax
    mov     edi, PageDirBase    ; 此段首地址为PageDirBase
    xor     eax, eax
    mov     eax, PageTblBase | PG_P | PG_USU | PG_RWW
.1:
    stosd
    add     eax, 4096
    loop    .1

    ; 初始化所有页表
    pop     eax                 ; 页表个数
    mov     ebx, 1024           ; 每个页表1024个PTE
    mul     ebx
    mov     ecx, eax            ; PTE个数 ＝ 页表个数 ＊ 1024
    mov     edi, PageTblBase    ; 此段首地址为PageTblBase
    xor     eax, eax
    mov     eax, PG_P | PG_USU | PG_RWW
.2:
    stosd
    add     eax, 4096           ; 每页4k
    loop    .2

    ; 设置寄存器，开启分页
    mov     eax, PageDirBase
    mov     cr3, eax
    mov     eax, cr0
    or      eax, 80000000h
    mov     cr0, eax
    jmp     short .3
.3:
    nop

    ret

;------------------------------------------------------------------------------
; InitKernel 将KERNEL.BIN的内容经过整理对齐后放到新的位置
; 遍历每一个Program Header，根据Program Header中的信息来确定把什么放进内存，放到哪，放多少
InitKernel:
    xor     esi, esi
    mov     cx, word [BaseOfKernelFilePhyAddr + 2Ch]    ; ecx <- ELFHeader.e_phum
    movzx   ecx, cx
    mov     esi, [BaseOfKernelFilePhyAddr + 1Ch]        ; esi <- ELFHeader.e_phoff
    add     esi, BaseOfKernelFilePhyAddr                ; esi 等于ProgramHeader的地址
.Begin:
    mov     eax, [esi + 0]
    cmp     eax, 0
    jz      .NoAction
    push    dword [esi + 010h]             ; size
    mov     eax, [esi + 04h]
    add     eax, BaseOfKernelFilePhyAddr    ; ProgramHeader.vaddr
    push    eax
    push    dword [esi + 08h]              ; ProgramHeader.p_filesz
    call    MemCpy
    add     esp, 12
.NoAction:
    add     esi, 020h                       ; esi += ELFHeader.e_phentsize
    dec     ecx
    jnz     .Begin

    ret

;==============================================================================
[SECTION .data1]
ALIGN 32

LABEL_DATA:         ; 实模式下使用这些符号
_szMemChkTitle      db "BaseAddrL BaseAddrH LengthLow LengthHigh   Type", 0Ah, 0
_szRAMSize          db "RAM size: ", 0
_szReturn           db 0Ah, 0

; 变量
_dwMCRNumber    dd 0    ; Memory Check Result
_dwDispPos      dd (80 * 6 + 0) * 2 ; 屏幕第 6 行, 第 0 列
_dwMemSize      dd 0
_ARDStruct:             ; Address Range Descriptor Structure
    _dwBaseAddrLow      dd  0
    _dwBaseAddrHigh     dd  0
    _dwLengthLow        dd  0
    _dwLengthHigh       dd  0
    _dwType             dd  0
_MemChkBuf  times 256   db  0

; 保护模式下使用这些符号
szMemChkTitle   equ BaseOfLoaderPhyAddr + _szMemChkTitle
szRAMSize       equ BaseOfLoaderPhyAddr + _szRAMSize
szReturn        equ BaseOfLoaderPhyAddr + _szReturn
dwDispPos       equ BaseOfLoaderPhyAddr + _dwDispPos
dwMemSize       equ BaseOfLoaderPhyAddr + _dwMemSize
dwMCRNumber     equ BaseOfLoaderPhyAddr + _dwMCRNumber
ARDStruct       equ BaseOfLoaderPhyAddr + _ARDStruct
    dwBaseAddrLow   equ BaseOfLoaderPhyAddr + _dwBaseAddrLow
    dwBaseAddrHigh  equ BaseOfLoaderPhyAddr + _dwBaseAddrHigh
    dwLengthLow     equ BaseOfLoaderPhyAddr + _dwLengthLow
    dwLengthHigh    equ BaseOfLoaderPhyAddr + _dwLengthHigh
    dwType          equ BaseOfLoaderPhyAddr + _dwType
MemChkBuf       equ BaseOfLoaderPhyAddr + _MemChkBuf

; 堆栈就在数据段的末尾
StackSpace  times 1024  db  0
TopOfStack  equ BaseOfLoaderPhyAddr + $ ; 栈顶
; End of SECTION .data1