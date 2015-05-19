#ifndef _KLIB_H_
#define _KLIB_H_

#include "type.h"

void out_byte(u16 port, u8 value);
u8 in_byte(u16 port);
void disp_str(char * info);
void disp_color_str(char * info, int color);
void enabel_irq(int irq);
void disabel_irq(int irq);

char* itoa(char *str, int num);
void disp_int(int i);

#endif