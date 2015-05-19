#include "type.h"
#include "const.h"
#include "protect.h"
#include "global.h"

/* 本文件内函数声明 */
static void init_idt_desc(u8 vector, u8 desc_type,
				int_handler handler, u8 privilege);
static void init_descriptor(DESCRIPTOR * p_desc, u32 base,
				u32 limit, u16 attribute);

// 中断处理函数申明，其实现在kernel.asm中
void divide_error();
void single_step_exception();
void nmi();
void breakpoint_exception();
void overflow();
void bounds_check();
void inval_opcode();
void copr_not_available();
void double_fault();
void copr_seg_overrun();
void inval_tss();
void segment_not_present();
void stack_exception();
void general_protection();
void page_fault();
void copr_error();

//   硬件中断处理函数
void hwint00();
void hwint01();
void hwint02();
void hwint03();
void hwint04();
void hwint05();
void hwint06();
void hwint07();
void hwint08();
void hwint09();
void hwint10();
void hwint11();
void hwint12();
void hwint13();
void hwint14();
void hwint15();

// 系统调用函数
void sys_call();


void init_prot()
{
	init_8259A();

	// 全部初始化成中断门(没有陷阱门)
	init_idt_desc(INT_VECTOR_DIVIDE,       DA_386IGate, divide_error, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_DEBUG,        DA_386IGate, single_step_exception, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_NMI,          DA_386IGate, nmi, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_BREAKPOINT,   DA_386IGate, breakpoint_exception, PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_OVERFLOW,     DA_386IGate, overflow, PRIVILEGE_USER);
	init_idt_desc(INT_VECTOR_BOUNDS,       DA_386IGate, bounds_check, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_INVAL_OP,     DA_386IGate, inval_opcode, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_NOT,   DA_386IGate, copr_not_available, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_DOUBLE_FAULT, DA_386IGate, double_fault, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_SEG,   DA_386IGate, copr_seg_overrun, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_INVAL_TSS,    DA_386IGate, inval_tss, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_SEG_NOT,      DA_386IGate, segment_not_present, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_STACK_FAULT,  DA_386IGate, stack_exception, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_PROTECTION,   DA_386IGate, general_protection, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_PAGE_FAULT,   DA_386IGate, page_fault, PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_COPROC_ERR,   DA_386IGate, copr_error, PRIVILEGE_KRNL);

	// 硬件中断初始化
	init_idt_desc(INT_VECTOR_IRQ0 + 0,	DA_386IGate,	hwint00,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 1,	DA_386IGate,	hwint01,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 2,	DA_386IGate,	hwint02,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 3,	DA_386IGate,	hwint03,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 4,	DA_386IGate,	hwint04,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 5,	DA_386IGate,	hwint05,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 6,	DA_386IGate,	hwint06,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ0 + 7,	DA_386IGate,	hwint07,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 0,	DA_386IGate,	hwint08,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 1,	DA_386IGate,	hwint09,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 2,	DA_386IGate,	hwint10,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 3,	DA_386IGate,	hwint11,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 4,	DA_386IGate,	hwint12,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 5,	DA_386IGate,	hwint13,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 6,	DA_386IGate,	hwint14,	PRIVILEGE_KRNL);
	init_idt_desc(INT_VECTOR_IRQ8 + 7,	DA_386IGate,	hwint15,	PRIVILEGE_KRNL);

	// 初始化系统调用函数中断
	init_idt_desc(INT_VECTOR_SYS_CALL,	DA_386IGate,	sys_call,	PRIVILEGE_USER);

	// 填充GDT中的TSS的描述符
	memset(&_tss, 0, sizeof(_tss));
	_tss.ss0 = SELECTOR_KERNEL_DS;
	init_descriptor(
		_gdt + INDEX_TSS,
		vir2phys(seg2phys(SELECTOR_KERNEL_DS), &_tss), 	// _tss在内存中的基地址
		sizeof(_tss) - 1,
		DA_386TSS);
	_tss.iobase = sizeof(_tss);	// 没有I/O许可位图

	// 填充GDT中进程的LDT描述符，多个进程，循环初始化
	int i;
	PROCESS *p_proc = _proc_table;
	u16 selector_ldt = INDEX_LDT_FIRST << 3;
	for (i = 0; i < NR_TASKS + NR_PROCS; i++) {
		init_descriptor(
			&_gdt[selector_ldt >> 3],
			vir2phys(seg2phys(SELECTOR_KERNEL_DS), _proc_table[i].ldts),
			LDT_SIZE * sizeof(DESCRIPTOR) - 1,
			DA_LDT);

		p_proc++;
		selector_ldt += 1 << 3;
	}
}

// 初始化386中断门
static void init_idt_desc(u8 vector, u8 desc_type, int_handler handler, u8 privilege)
{
	GATE* p_gate        = &_idt[vector];		// 中断向量描述符表中找到中断描述符
	u32	base            = (u32)handler;			// 中断处理函数的函数指针，即函数的入口地址
	p_gate->offset_low  = base & 0xFFFF;
	p_gate->selector    = SELECTOR_KERNEL_CS;
	p_gate->dcount      = 0;
	p_gate->attr        = desc_type | (privilege << 5);
	p_gate->offset_high = (base >> 16) & 0xFFFF;
}

// 初始化段描述符
static void init_descriptor(DESCRIPTOR *p_desc, u32 base, u32 limit, u16 attribute)
{
	p_desc->limit_low        = limit & 0x0FFFF;
	p_desc->base_low         = base & 0x0FFFF;
	p_desc->base_mid         = (base >> 16) & 0x0FF;
	p_desc->attr1            = attribute & 0xFF;
	p_desc->limit_high_attr2 = ((limit>>16) & 0x0F) | (attribute>>8) & 0xF0;
	p_desc->base_high        = (base >> 24) & 0x0FF;
}


// 由段名求绝对地址
u32 seg2phys(u16 seg)
{
	DESCRIPTOR *p_dest = &_gdt[seg >> 3];
	return (p_dest->base_high<<24 | p_dest->base_mid<<16 | p_dest->base_low);
}



// 中断处理函数
// CPU处理中断时，会依次将EFLAGS, CS, EIP压入栈，如果有错误码，错误码也入栈
void exception_handler(int vec_no, int err_code, int eip, int cs, int eflags)
{
	int i;
	int text_color = 0x74; /* 灰底红字 */

	char * err_msg[] = {
		"#DE Divide Error",
		"#DB RESERVED",
		"--  NMI Interrupt",
		"#BP Breakpoint",
		"#OF Overflow",
		"#BR BOUND Range Exceeded",
		"#UD Invalid Opcode (Undefined Opcode)",
		"#NM Device Not Available (No Math Coprocessor)",
		"#DF Double Fault",
		"    Coprocessor Segment Overrun (reserved)",
		"#TS Invalid TSS",
		"#NP Segment Not Present",
		"#SS Stack-Segment Fault",
		"#GP General Protection",
		"#PF Page Fault",
		"--  (Intel reserved. Do not use.)",
		"#MF x87 FPU Floating-Point Error (Math Fault)",
		"#AC Alignment Check",
		"#MC Machine Check",
		"#XF SIMD Floating-Point Exception"
	};

	/* 通过打印空格的方式清空屏幕的前五行，并把 _disp_pos 清零 */
	_disp_pos = 0;
	for(i = 0; i < 80 * 5; i++) {
		disp_str(" ");
	}
	_disp_pos = 0;

	disp_color_str("Exception! --> ", text_color);
	disp_color_str(err_msg[vec_no], text_color);
	disp_color_str("\n\n", text_color);
	disp_color_str("EFLAGS:", text_color);
	disp_int(eflags);
	disp_color_str("CS:", text_color);
	disp_int(cs);
	disp_color_str("EIP:", text_color);
	disp_int(eip);

	if(err_code != 0xFFFFFFFF) {
		disp_color_str("Error code:", text_color);
		disp_int(err_code);
	}
}