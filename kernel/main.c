#include "proc.h"
#include "protect.h"
#include "global.h"

int kernel_main()
{
	disp_str("-----\"kernel_main\" begins-----\n");

	init_proc_table();

	// 中断重入设置
	_k_reenter = 0;

	// 初始化中断
	init_clock();

	// 启动第一个进程
	_p_proc_ready = _proc_table;
	restart();

	while (1) {}
}

// 我们假设的进程A，将不断输出A及循环次数
void TestA()
{
	while (1) {
		printf("<Ticks: %x>A", get_ticks());
		milli_delay(2000);
	}
}

void TestB()
{
	while (1) {
		// disp_str("B");
		milli_delay(2000);
	}
}

void TestC()
{
	while (1) {
		// disp_str("C");
		milli_delay(3000);
	}
}