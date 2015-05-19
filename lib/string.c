#include "string.h"

void* memcpy(void *p_dst, void *p_src, int size)
{
	u8 *s = (u8*)p_src;
	u8 *d = (u8*)p_dst;
	int i;

	for (i = 0; i < size; i++) {
		*d++ = *s++;
	}

	return p_dst;
}

void memset(void *p_dst, u8 val, int size)
{
	u8 *d = (u8*)p_dst;
	int i;

	for (i = 0; i < size; i++) {
		*d++ = val;
	}
}

char* strcpy(char *p_dst, const char *p_src)
{
	char *p = p_dst;

	while (*p_src) {
		*p++ = *p_src++;
	}

	return p_dst;
}

int strlen(const char *p_str)
{
	int i = 0;

	while (*p_str++) {
		i++;
	}

	return i;
}