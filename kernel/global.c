/* 定义全局变量，这个文件中的变量不加extern前缀
** 而其他文件都会有extern前缀，表示外部的变量
*/

#define GLOBAL_VARIABLES_HERE

#include "global.h"
#include "clock.h"

int _disp_pos;	// 屏幕输出位置
u8 _gdt_ptr[6];	// GDTR的值
DESCRIPTOR _gdt[GDT_SIZE];	// GDT表
u8 _idt_ptr[6];	// IDTR的值
GATE _idt[IDT_SIZE];	// IDT表

u32 _k_reenter;	// 先简单定义一个变量-1表示无中断重入，0为中断嵌套

TSS _tss;
PROCESS *_p_proc_ready;	// 指向一个已经就绪的进程

// 系统调用函数表
system_call _sys_call_table[NR_SYS_CALL] = {
	sys_get_ticks, sys_write
};
