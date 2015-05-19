#ifndef _IO_H_
#define _IO_H_

#include "type.h"

int printf(const char *fmt, ...);
int vsprintf(char *buf, const char *fmt, va_list args);

#endif