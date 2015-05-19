#ifndef _CLOCK_H_
#define _CLOCK_H_

#include "type.h"

// 8253/8254 PIT (Programmable Interval Timer)
#define TIMER0			0x40
#define TIMER_MODE		0x43
#define RATE_GENERATOR 	0x34	// 00-11-010-0
#define TIMER_FREQ		1193182L
#define HZ				1000

u32 sys_get_ticks();
void clock_handler(int irq);
// 当前HZ为100，即每10ms发生一次中断，所以最小的间隔为10ms
void milli_delay(u32 milli_sec);
void init_clock();

#endif