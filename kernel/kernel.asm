; ----------------------------------------------------------------------
; 编译连接方法:
; $ rm -f kernel.bin
; $ nasm -f elf -o kernel.o kernel.asm
; $ nasm -f elf -o string.o string.asm
; $ nasm -f elf -o klib.o klib.asm
; $ gcc -c -o start.o start.c
; $ ld -s -Ttext 0x30400 -o kernel.bin kernel.o string.o start.o klib.o
; $ rm -f kernel.o string.o start.o
; $
; ----------------------------------------------------------------------

%include "sconst.inc"

; 导入函数
extern cstart
extern exception_handler
extern spurious_irq
extern kernel_main

; 导入全局变量
extern _gdt_ptr
extern _idt_ptr
extern _disp_pos
extern _p_proc_ready
extern _tss
extern _k_reenter
extern _irq_table
extern _sys_call_table

[SECTION .bss]
StackSpace      resb 2 * 1024
StackTop:       ; 栈底

[SECTION .text] ; 代码

global _start   ; 导出 _start

global restart  ; 完成从ring0到ring1的跳转
global sys_call

; 异常中断
global divide_error
global single_step_exception
global nmi
global breakpoint_exception
global overflow
global bounds_check
global inval_opcode
global copr_not_available
global double_fault
global copr_seg_overrun
global inval_tss
global segment_not_present
global stack_exception
global general_protection
global page_fault
global copr_error

;      8259硬件终端
global hwint00
global hwint01
global hwint02
global hwint03
global hwint04
global hwint05
global hwint06
global hwint07
global hwint08
global hwint09
global hwint10
global hwint11
global hwint12
global hwint13
global hwint14
global hwint15


_start:
    ; 此时内存看上去是这样的（更详细的内存情况在 LOADER.ASM 中有说明）：
    ;              ┃                                    ┃
    ;              ┃                 ...                ┃
    ;              ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■Page  Tables■■■■■■┃
    ;              ┃■■■■■(大小由LOADER决定)■■■■┃ PageTblBase
    ;    00201000h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■Page Directory Table■■■■┃ PageDirBase = 2M
    ;    00200000h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃□□□□ Hardware  Reserved □□□□┃ B8000h ← gs
    ;       9FC00h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■LOADER.BIN■■■■■■┃ somewhere in LOADER ← esp
    ;       90000h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■KERNEL.BIN■■■■■■┃
    ;       80000h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃■■■■■■■■KERNEL■■■■■■■┃ 30400h ← KERNEL 入口 (KernelEntryPointPhyAddr)
    ;       30000h ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┋                 ...                ┋
    ;              ┋                                    ┋
    ;           0h ┗━━━━━━━━━━━━━━━━━━┛ ← cs, ds, es, fs, ss
    ;
    ;
    ; GDT 以及相应的描述符是这样的：
    ;
    ;                     Descriptors               Selectors
    ;              ┏━━━━━━━━━━━━━━━━━━┓
    ;              ┃         Dummy Descriptor           ┃
    ;              ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃         DESC_FLAT_C    (0～4G)     ┃   8h = cs
    ;              ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃         DESC_FLAT_RW   (0～4G)     ┃  10h = ds, es, fs, ss
    ;              ┣━━━━━━━━━━━━━━━━━━┫
    ;              ┃         DESC_VIDEO                 ┃  1Bh = gs
    ;              ┗━━━━━━━━━━━━━━━━━━┛
    ;
    ; 注意! 在使用 C 代码的时候一定要保证 ds, es, ss 这几个段寄存器的值是一样的
    ; 因为编译器有可能编译出使用它们的代码, 而编译器默认它们是一样的. 比如串拷贝操作会用到 ds 和 es.
    ;
    ;

    ; 把 esp 从 LOADER 移到 KERNEL
    mov     esp, StackTop

    mov     dword [_disp_pos], 0

    sgdt    [_gdt_ptr]      ; cstart() 中用到，保存旧的GDTR的值
    call    cstart         ; 函数改变了_gdt_ptr的值，为新的GDTR的值
    lgdt    [_gdt_ptr]      ; 使用新的GDTR

    lidt    [_idt_ptr]

    jmp     SELECTOR_KERNEL_CS:csinit
csinit:
    ; 装载tr
    xor     eax, eax
    mov     ax, SELECTOR_TSS
    ltr     ax
    jmp     kernel_main

; 中断和异常 —— 硬件中断
;------------------------------------------------------------------------------
%macro hwint_master 1
    ; 保存原寄存器值，call将把下一条指令（mov）地址压栈，刚好对应regs中retaddr的位置。
    call    save
    in      al, INT_M_CTLMASK   ; 不允许同类型中断在发生
    or      al, (1 << %1)
    out     INT_M_CTLMASK, al
    mov     al, EOI
    out     INT_M_CTL, al
    sti     ; 允许中断嵌套，CPU相应中断时会自动关中断
    push    %1
    call    [_irq_table + 4 * %1] ; 调用中断处理函数
    pop     ecx
    cli
    in      al, INT_M_CTLMASK    ; 恢复中断
    and     al, ~(1 << %1)
    out     INT_M_CTLMASK, al
    ret                       ; 重入时跳到.restart_reenter，通常情况跳到.restart，返回地址已压入栈
%endmacro

ALIGN   16
hwint00:                ; Interrupt routine for irq 0 (the clock).
    hwint_master 0

ALIGN   16
hwint01:                ; Interrupt routine for irq 1 (keyboard)
    hwint_master 1

ALIGN   16
hwint02:                ; Interrupt routine for irq 2 (cascade!)
    hwint_master 2

ALIGN   16
hwint03:                ; Interrupt routine for irq 3 (second serial)
    hwint_master 3

ALIGN   16
hwint04:                ; Interrupt routine for irq 4 (first serial)
    hwint_master 4

ALIGN   16
hwint05:                ; Interrupt routine for irq 5 (XT winchester)
    hwint_master 5

ALIGN   16
hwint06:                ; Interrupt routine for irq 6 (floppy)
    hwint_master 6

ALIGN   16
hwint07:                ; Interrupt routine for irq 7 (printer)
    hwint_master 7
;------------------------------------------------------------------------------

%macro hwint_slave 1
    push    %1
    call    spurious_irq
    add     esp, 4
    hlt
%endmacro

ALIGN   16
hwint08:                ; Interrupt routine for irq 8 (realtime clock).
    hwint_slave 8

ALIGN   16
hwint09:                ; Interrupt routine for irq 9 (irq 2 redirected)
    hwint_slave 9

ALIGN   16
hwint10:                ; Interrupt routine for irq 10
    hwint_slave 10

ALIGN   16
hwint11:                ; Interrupt routine for irq 11
    hwint_slave 11

ALIGN   16
hwint12:                ; Interrupt routine for irq 12
    hwint_slave 12

ALIGN   16
hwint13:                ; Interrupt routine for irq 13 (FPU exception)
    hwint_slave 13

ALIGN   16
hwint14:                ; Interrupt routine for irq 14 (AT winchester)
    hwint_slave 14

ALIGN   16
hwint15:                ; Interrupt routine for irq 15
    hwint_slave 15


;------------------------------------------------------------------------------
; 中断和异常 -- 异常，有的异常有错误码，有的没有
; 为了统一，没有错误码的先压入0xFFFFFFFF，再压入向量号
divide_error:
    push    0xFFFFFFFF  ; no err code
    push    0       ; vector_no = 0
    jmp     exception
single_step_exception:
    push    0xFFFFFFFF  ; no err code
    push    1       ; vector_no = 1
    jmp     exception
nmi:
    push    0xFFFFFFFF  ; no err code
    push    2       ; vector_no = 2
    jmp     exception
breakpoint_exception:
    push    0xFFFFFFFF  ; no err code
    push    3       ; vector_no = 3
    jmp     exception
overflow:
    push    0xFFFFFFFF  ; no err code
    push    4       ; vector_no = 4
    jmp     exception
bounds_check:
    push    0xFFFFFFFF  ; no err code
    push    5       ; vector_no = 5
    jmp     exception
inval_opcode:
    push    0xFFFFFFFF  ; no err code
    push    6       ; vector_no = 6
    jmp     exception
copr_not_available:
    push    0xFFFFFFFF  ; no err code
    push    7       ; vector_no = 7
    jmp     exception
double_fault:
    push    8       ; vector_no = 8
    jmp     exception
copr_seg_overrun:
    push    0xFFFFFFFF  ; no err code
    push    9       ; vector_no = 9
    jmp     exception
inval_tss:
    push    10      ; vector_no = A
    jmp     exception
segment_not_present:
    push    11      ; vector_no = B
    jmp     exception
stack_exception:
    push    12      ; vector_no = C
    jmp     exception
general_protection:
    push    13      ; vector_no = D
    jmp     exception
page_fault:
    push    14      ; vector_no = E
    jmp     exception
copr_error:
    push    0xFFFFFFFF  ; no err code
    push    16      ; vector_no = 10h
    jmp     exception

exception:
    call    exception_handler
    add     esp, 4 * 2    ; 让栈顶指向 EIP，堆栈中从顶向下依次是：EIP、CS、EFLAGS
    hlt

save:
    pushad                  ; 保存原寄存器值
    push    ds
    push    es
    push    fs
    push    gs
    mov     dx, ss
    mov     ds, dx
    mov     es, dx

    mov     esi, esp         ; esp当前在进程块的起始处

    inc     dword [_k_reenter]
    cmp     dword [_k_reenter], 0
    jne     .1                   ; 发生中断重入，跳过切换到内核栈，因为已经处在内核栈
    mov     esp, StackTop        ; 切换到内核栈，后面的操作都使用内核栈，不会破环进程块
    push    restart
    jmp     [esi + RETADR - P_STACKBASE]   ; 回到中断处理中call的下一条指令
.1:                     ; 发生中断重入
    push    restart_reenter
    jmp     [esi + RETADR - P_STACKBASE]
;==============================================================================
restart:
    mov     esp, [_p_proc_ready]            ; 离开内核栈，切换回进程块起始处
    lldt    [esp + P_LDT_SEL]              ; 加载下一个即将运行任务的LDT
    lea     eax, [esp + P_STACKTOP]        ; 将PROCESS结构中第一个成员（regs）的末地址赋给TSS中的ring0
    mov     dword [_tss + TSS3_S_SP0], eax  ; 的esp，下一次中断发生时进程的ss, esp, eflags, cs, eip
                                        ; 依次被压栈，放到regs的最后面（由于栈向低地址生长）
restart_reenter:        ; 如果重入，则会跳到这里
    dec     dword [_k_reenter]
    pop     gs
    pop     fs
    pop     es
    pop     ds
    popad
    add     esp, 4

    iretd       ; 从ring0进入ring1，寄存器值变为regs中定义的值

sys_call:
    call    save
    push    dword [_p_proc_ready]
    sti

    push    ecx
    push    ebx
    call    [_sys_call_table + eax * 4]          ; eax中存放的是系统调用函数的序号
    add     esp, 4 * 3

    mov     [esi + EAXREG - P_STACKBASE], eax   ; 将系统调用的函数返回值放在eax中，以便调用者使用
    cli
    ret