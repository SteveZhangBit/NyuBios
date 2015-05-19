
/*++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            const.h
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++*/

#ifndef	_CONST_H_
#define	_CONST_H_

/* EXTERN is defined as extern except in global.c */
#define EXTERN extern

/* 函数类型 */
#define	PUBLIC		/* PUBLIC is the opposite of PRIVATE */
#define	PRIVATE	static	/* PRIVATE x limits the scope of x */

/* Boolean */
#define	TRUE	1
#define	FALSE	0

// 系统调用
#define NR_SYS_CALL		2

/* VGA */
#define	CRTC_ADDR_REG	0x3D4	/* CRT Controller Registers - Addr Register */
#define	CRTC_DATA_REG	0x3D5	/* CRT Controller Registers - Data Register */
#define	START_ADDR_H	0xC	/* reg index of video mem start addr (MSB) */
#define	START_ADDR_L	0xD	/* reg index of video mem start addr (LSB) */
#define	CURSOR_H		0xE	/* reg index of cursor position (MSB) */
#define	CURSOR_L		0xF	/* reg index of cursor position (LSB) */
#define	V_MEM_BASE		0xB8000	/* base of color video memory */
#define	V_MEM_SIZE		0x8000	/* 32K: B8000H -> BFFFFH */



#endif /* _CONST_H_ */
