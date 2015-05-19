; 系统调用

_NR_get_ticks       equ 0       ; 要与global.c中的sys_call_table中的元素对应
_NR_write			equ 1
INT_VECTOR_SYS_CALL equ 0x90    ; 系统调用中断号

global get_ticks
global write

bits 32
[SECTION .text]

get_ticks:
    mov     eax, _NR_get_ticks
    int     INT_VECTOR_SYS_CALL
    ret

write:
	mov		eax, _NR_write
	mov		ebx, [esp + 4]
	mov		ecx, [esp + 8]
	int 	INT_VECTOR_SYS_CALL
	ret