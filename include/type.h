
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            type.h
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#ifndef	_TYPE_H_
#define	_TYPE_H_

typedef unsigned int		u32;
typedef unsigned short		u16;
typedef unsigned char		u8;
typedef char*				va_list;

typedef void (*int_handler)();	// 中断处理函数的函数指针类型
typedef void (*task_f)();		// 任务其实地址函数指针
typedef void (*irq_handler)(int irq);	// 中断处理程序函数指针
typedef void* system_call;		// 适用于任何函数

#endif /* _TYPE_H_ */
