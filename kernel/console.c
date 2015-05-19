#include "tty.h"
#include "global.h"

static CONSOLE _console_table[NR_CONSOLES];
static int _nr_current_console;

static void set_cursor(unsigned int pos);
static void set_video_start_addr(u32 addr);
static void flush(CONSOLE* p_con);

void init_screen(TTY* p_tty)
{
	int nr_tty = p_tty - _tty_table;
	p_tty->p_console = _console_table + nr_tty;

	int v_mem_size = V_MEM_SIZE >> 1;	/* 显存总大小 (in WORD) */

	int con_v_mem_size = v_mem_size / NR_CONSOLES;

	p_tty->p_console->original_addr      = nr_tty * con_v_mem_size;
	p_tty->p_console->v_mem_limit        = con_v_mem_size;
	p_tty->p_console->current_start_addr = p_tty->p_console->original_addr;

	/* 默认光标位置在最开始处 */
	p_tty->p_console->cursor = p_tty->p_console->original_addr;

	if (nr_tty == 0) {
		/* 第一个控制台沿用原来的光标位置 */
		p_tty->p_console->cursor = _disp_pos / 2;
		_disp_pos = 0;
	}
	else {
		out_char(p_tty->p_console, nr_tty + '0');
		out_char(p_tty->p_console, '#');
	}

	set_cursor(p_tty->p_console->cursor);
}


int is_current_console(CONSOLE* p_con)
{
	return (p_con == &_console_table[_nr_current_console]);
}

void out_char(CONSOLE *p_con, char ch)
{
	u8* p_vmem = (u8*)(V_MEM_BASE + p_con->cursor * 2);

	switch (ch) {
	case '\n':
		if (p_con->cursor < p_con->original_addr +
		    	p_con->v_mem_limit - SCREEN_WIDTH) {
			p_con->cursor = p_con->original_addr + SCREEN_WIDTH *
				((p_con->cursor - p_con->original_addr) / SCREEN_WIDTH + 1);
		}
		break;

	case '\b':
		if (p_con->cursor > p_con->original_addr) {
			p_con->cursor--;
			*(p_vmem-2) = ' ';
			*(p_vmem-1) = DEFAULT_CHAR_COLOR;
		}
		break;

	default:
		if (p_con->cursor < p_con->original_addr + p_con->v_mem_limit - 1) {
			*p_vmem++ = ch;
			*p_vmem++ = DEFAULT_CHAR_COLOR;
			p_con->cursor++;
		}
		break;
	}

	while (p_con->cursor >= p_con->current_start_addr + SCREEN_SIZE) {
		scroll_screen(p_con, SCR_DN);
	}

	flush(p_con);
}

void select_console(int nr_console)	/* 0 ~ (NR_CONSOLES - 1) */
{
	if ((nr_console < 0) || (nr_console >= NR_CONSOLES)) {
		return;
	}

	_nr_current_console = nr_console;

	set_cursor(_console_table[nr_console].cursor);
	set_video_start_addr(_console_table[nr_console].current_start_addr);
}

void scroll_screen(CONSOLE* p_con, int direction)
{
	if (direction == SCR_UP) {
		if (p_con->current_start_addr > p_con->original_addr) {
			p_con->current_start_addr -= SCREEN_WIDTH;
		}
	}
	else if (direction == SCR_DN) {
		if (p_con->current_start_addr + SCREEN_SIZE <
			p_con->original_addr + p_con->v_mem_limit) {
			p_con->current_start_addr += SCREEN_WIDTH;
		}
	}

	set_video_start_addr(p_con->current_start_addr);
	set_cursor(p_con->cursor);
}

static void flush(CONSOLE* p_con)
{
	set_cursor(p_con->cursor);
	set_video_start_addr(p_con->current_start_addr);
}

static void set_cursor(unsigned int pos)
{
	asm("cli");
	out_byte(CRTC_ADDR_REG, CURSOR_H);
	out_byte(CRTC_DATA_REG, (pos >> 8) & 0xFF);
	out_byte(CRTC_ADDR_REG, CURSOR_L);
	out_byte(CRTC_DATA_REG, pos & 0xFF);
	asm("sti");
}

static void set_video_start_addr(u32 addr)
{
	asm("cli");
	out_byte(CRTC_ADDR_REG, START_ADDR_H);
	out_byte(CRTC_DATA_REG, (addr >> 8) & 0xFF);
	out_byte(CRTC_ADDR_REG, START_ADDR_L);
	out_byte(CRTC_DATA_REG, addr & 0xFF);
	asm("sti");
}


