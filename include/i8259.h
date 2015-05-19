#ifndef _I8259_H_
#define _I8259_H_

#include "type.h"

/* 8259A interrupt controller ports. */
#define INT_M_CTL     0x20 /* I/O port for interrupt controller       <Master> */
#define INT_M_CTLMASK 0x21 /* setting bits in this port disables ints <Master> */
#define INT_S_CTL     0xA0 /* I/O port for second interrupt controller<Slave>  */
#define INT_S_CTLMASK 0xA1 /* setting bits in this port disables ints <Slave>  */

/* Hardware interrupts */
#define	NR_IRQ			16	/* Number of IRQs */
#define	CLOCK_IRQ		0
#define	KEYBOARD_IRQ	1
#define	CASCADE_IRQ		2	/* cascade enable for 2nd AT controller */
#define	ETHER_IRQ		3	/* default ethernet interrupt vector */
#define	SECONDARY_IRQ	3	/* RS232 interrupt vector for port 2 */
#define	RS232_IRQ		4	/* RS232 interrupt vector for port 1 */
#define	XT_WINI_IRQ		5	/* xt winchester */
#define	FLOPPY_IRQ		6	/* floppy disk */
#define	PRINTER_IRQ		7
#define	AT_WINI_IRQ		14	/* at winchester */

void init_8259A();
void spurious_irq(int irq);
void put_irq_handler(int irq, irq_handler handler);

extern irq_handler _irq_table[NR_IRQ];


#endif