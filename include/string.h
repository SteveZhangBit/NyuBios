#ifndef _STRING_H_
#define _STRING_H_

#include "type.h"
// 串操作的函数申明

void* memcpy(void *p_dst, void *p_src, int size);
void memset(void *p_dst, u8 val, int size);
char* strcpy(char *p_dst, const char *p_src);
int strlen(const char *p_str);

#endif