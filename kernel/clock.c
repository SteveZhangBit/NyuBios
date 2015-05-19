#include "clock.h"
#include "global.h"
#include "proc.h"
#include "i8259.h"

static u32 _ticks;

u32 sys_get_ticks()
{
	return _ticks;
}

void clock_handler(int irq)
{
	_ticks++;		// 每次时钟中断，令ticks++，可用做计时
	_p_proc_ready->ticks--;

	if (_k_reenter != 0) {
		return ;
	}

	// 优先级高的未执行完前，不执行其他的程序
	// 比如优先级为3:2:1，则获得的CPU时间也是3:2:1
	if (_p_proc_ready->ticks > 0) {
		return ;
	}

	schedule();
}

// 当前HZ为100，即每10ms发生一次中断，所以最小的间隔为10ms
void milli_delay(u32 milli_sec)
{
	u32 t = get_ticks();
	while (((get_ticks() - t) * 1000 / HZ) < milli_sec) {}
}

void init_clock()
{
	// 初始化 8253 PIT，产生时钟中断的计数器，每10ms产生一个中断
	out_byte(TIMER_MODE, RATE_GENERATOR);
	out_byte(TIMER0, (u8)(TIMER_FREQ / HZ));
	out_byte(TIMER0, (u8)((TIMER_FREQ / HZ) >> 8));


	_ticks = 0;
	put_irq_handler(CLOCK_IRQ, clock_handler);
	enable_irq(CLOCK_IRQ);
}