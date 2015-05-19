#include "proc.h"
#include "global.h"

void TestA();
void TestB();
void TestC();

TASK _task_table[NR_TASKS] = {
	{task_tty, STACK_SIZE_TTY, "tty"}
};		// 任务表
TASK _user__proc_table[NR_PROCS] = {
	{TestA, STACK_SIZE_TESTA, "TestA"},
	{TestB, STACK_SIZE_TESTB, "TestB"},
	{TestC, STACK_SIZE_TESTC, "TestC"}
};
PROCESS _proc_table[NR_TASKS + NR_PROCS]; 		// 进程表
u8 _task_stack[STACK_SIZE_TOTAL];				// 进程栈

void schedule()
{
	PROCESS *p;
	int greatest_ticks = 0;

	while (!greatest_ticks) {
		// 选择优先级最高的运行
		for (p = _proc_table; p < _proc_table + NR_TASKS + NR_PROCS; p++) {
			if (p->ticks > greatest_ticks) {
				greatest_ticks = p->ticks;
				_p_proc_ready = p;
			}
		}
		// 所有进程的ticks都为0，则恢复其原有ticks，进行下一个运行周期
		if (!greatest_ticks) {
			for (p = _proc_table; p < _proc_table + NR_TASKS + NR_PROCS; p++) {
				p->ticks = p->priority;
			}

		}
	}
}

void init_proc_table()
{
	TASK *p_task     = _task_table;	// 指向第一个任务
	PROCESS *p_proc  = _proc_table;	// 指向第一个进程
	u8 *p__task_stack = _task_stack + STACK_SIZE_TOTAL;	// 指向所有任务栈总和的最后
	u16 selector_ldt = SELECTOR_LDT_FIRST;	// LDT描述符在GDT中的索引

	u8 privilege;
	u8 rpl;
	int eflags;

	int i;
	for (i = 0; i < NR_TASKS + NR_PROCS; i++) {
		if (i < NR_TASKS) {
			p_task    = _task_table + i;
			privilege = PRIVILEGE_TASK;
			rpl       = RPL_TASK;
			eflags    = 0x1202;
		}
		else {
			p_task    = _user__proc_table + (i - NR_TASKS);
			privilege = PRIVILEGE_USER;
			rpl       = RPL_USER;
			eflags    = 0x202;
		}

		strcpy(p_proc->p_name, p_task->name);
		p_proc->pid = i;

		p_proc->ldt_sel = selector_ldt;	// LDT在GDT中的描述符的选择子

		// 初始化LDT，使用于kernel同样的代码段和数据段，只是改变了DPL
		memcpy(&p_proc->ldts[0], &_gdt[SELECTOR_KERNEL_CS >> 3], sizeof(DESCRIPTOR));
		p_proc->ldts[0].attr1 = DA_C | privilege << 5;	// change the DPL
		memcpy(&p_proc->ldts[1], &_gdt[SELECTOR_KERNEL_DS >> 3], sizeof(DESCRIPTOR));
		p_proc->ldts[1].attr1 = DA_DRW | privilege << 5;	// change the DPL

		// 设置寄存器值，保护模式下段寄存器的值为GDT或LDT的选择子
		// cs指向LDT中的第0个描述符，即代码段
		// 其余均指向LDT中的第1个描述符，数据段
		// 注意选择子的后三位
		p_proc->regs.cs	= (0 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.ds	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.es	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.fs	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.ss	= (8 & SA_RPL_MASK & SA_TI_MASK) | SA_TIL | rpl;
		p_proc->regs.gs	= (SELECTOR_KERNEL_GS & SA_RPL_MASK) | rpl;

		p_proc->regs.eip= (u32)p_task->initial_eip;
		p_proc->regs.esp= (u32)p__task_stack;	// 栈从高地址向低地址生长
		p_proc->regs.eflags = eflags;	// IF=1, IOPL=1, bit 2 is always 1.

		p_proc->nr_tty = 0;

		// next task
		p__task_stack -= p_task->stacksize;	// 栈向低地址生长
		p_proc++;
		p_task++;
		selector_ldt += 1 << 3;		// 选择子指向下一个索引处
	}

	// 为进程设置优先级
	_proc_table[0].ticks = _proc_table[0].priority = 15;
	_proc_table[1].ticks = _proc_table[1].priority = 5;
	_proc_table[2].ticks = _proc_table[2].priority = 3;
	_proc_table[3].ticks = _proc_table[3].priority = 3;

	_proc_table[1].nr_tty = 0;
	_proc_table[2].nr_tty = 1;
	_proc_table[3].nr_tty = 1;
}
