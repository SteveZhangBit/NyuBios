#include "type.h"
#include "protect.h"
#include "global.h"


PUBLIC void cstart()
{
	disp_str("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"
		 "-----\"cstart\" begins-----\n");
	// 将LOADER中的GDT复制到新的GDT中
	memcpy(
		&_gdt,							// 新的GDT
		(void*)(*(u32*)(&_gdt_ptr[2])),	// 旧的GDT基址
		*((u16*)(&_gdt_ptr[0])) + 1		// 旧的GDT界限
		);

	u16 *p_gdt_limit = (u16*)(&_gdt_ptr[0]);
	u32 *p_gdt_base  = (u32*)(&_gdt_ptr[2]);
	*p_gdt_limit     = GDT_SIZE * sizeof(DESCRIPTOR) - 1;
	*p_gdt_base      = (u32)&_gdt;

	u16 *p_idt_limit = (u16*)(&_idt_ptr[0]);
	u32 *p_idt_base  = (u32*)(&_idt_ptr[2]);
	*p_idt_limit     = IDT_SIZE * sizeof(GATE) - 1;
	*p_idt_base      = (u32)&_idt;

	// 初始化中断向量表
	init_prot();

	disp_str("-----\"cstart\" ends-----\n");
}