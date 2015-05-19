#ifndef _GLOBAL_H_
#define _GLOBAL_H_

#include "type.h"
#include "protect.h"
#include "const.h"
#include "proc.h"
#include "tty.h"

// EXTERN is defined as extern except in global.c
#ifdef	GLOBAL_VARIABLES_HERE
#undef	EXTERN
#define	EXTERN
#endif

extern int _disp_pos;	// 屏幕输出位置
extern u8 _gdt_ptr[6];	// GDTR的值
extern DESCRIPTOR _gdt[GDT_SIZE];	// GDT表
extern u8 _idt_ptr[6];	// IDTR的值
extern GATE _idt[IDT_SIZE];	// IDT表

extern u32 _k_reenter;	// 先简单定义一个变量-1表示无中断重入，0为中断嵌套

extern TSS _tss;
extern PROCESS *_p_proc_ready;	// 指向一个已经就绪的进程

// 系统调用相关
extern system_call _sys_call_table[NR_SYS_CALL];		// 系统调用函数表


#endif