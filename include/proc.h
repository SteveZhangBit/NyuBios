#ifndef _PROCEDURE_H_
#define _PROCEDURE_H_

#include "const.h"
#include "protect.h"
#include "type.h"

typedef struct s_stackframe {
	u32 gs;		/* \                                    */
	u32 fs;		/* |                                    */
	u32 es;		/* |                                    */
	u32 ds;		/* |                                    */
	u32 edi;		/* |                                    */
	u32 esi;		/* | pushed by save()                   */
	u32 ebp;		/* |                                    */
	u32 kernel_esp;	/* <- 'popad' will ignore it            */
	u32 ebx;		/* |                                    */
	u32 edx;		/* |                                    */
	u32 ecx;		/* |                                    */
	u32 eax;		/* /                                    */
	u32 retaddr;	/* return addr for kernel.asm::save()   */
	u32 eip;		/* \                                    */
	u32 cs;		/* |                                    */
	u32 eflags;		/* | pushed by CPU during interrupt     */
	u32 esp;		/* |                                    */
	u32 ss;		/* /                                    */
} STACK_FRAME;

typedef struct s_proc {
	STACK_FRAME regs;          /* process registers saved in stack frame */

	u16 ldt_sel;               /* gdt selector giving ldt base and limit */
	DESCRIPTOR ldts[LDT_SIZE]; /* local descriptors for code and data */

	int ticks;
	int priority;				// remainted ticks

	u32 pid;                   /* process id passed in from MM */
	char p_name[16];           /* name of the process */

	int nr_tty;
} PROCESS;

typedef struct s_task {
	task_f initial_eip;		// 任务代码开始处，函数指针
	int stacksize;
	char name[32];
} TASK;


/* Max Number of tasks running*/
#define NR_TASKS	1
#define NR_PROCS	3

#define STACK_SIZE_TTY		0x8000
/* stacks of tasks */
#define STACK_SIZE_TESTA	0x8000
#define STACK_SIZE_TESTB	0x8000
#define STACK_SIZE_TESTC	0x8000

#define STACK_SIZE_TOTAL	(STACK_SIZE_TTY + STACK_SIZE_TESTA + STACK_SIZE_TESTB + STACK_SIZE_TESTC)

extern TASK _task_table[NR_TASKS];		// 任务表
extern TASK _user_proc_table[NR_PROCS];

extern PROCESS _proc_table[NR_TASKS + NR_PROCS]; 		// 进程表
extern u8 _task_stack[STACK_SIZE_TOTAL];				// 进程栈

void schedule();
void init_proc_table();


#endif