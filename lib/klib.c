#include "klib.h"

// 将整数转化为16进制字符串
char* itoa(char *str, int num)
{
	char *p = str;
	char ch;
	int i;

	// 开头的0x
	*p++ = '0'; *p++ = 'x';

	if (num == 0) {
		*p++ = '0';
	} else {
		for (i = 28; i >= 0; i -= 4) {
			ch = (num >> i) & 0x0F;
			if (ch == 0)
				continue;

			if (ch < 10) {
				ch += '0';
			} else {
				ch = ch - 10 + 'A';
			}
			*p++ = ch;
		}
	}

	*p = 0;
	return str;
}

void disp_int(int i)
{
	char output[16];
	itoa(output, i);
	disp_str(output);
}
