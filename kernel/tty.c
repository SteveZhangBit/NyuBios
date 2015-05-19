#include "const.h"
#include "keyboard.h"
#include "tty.h"

#define TTY_FIRST		(_tty_table)
#define TTY_END			(_tty_table + NR_CONSOLES)

static void init_tty(TTY *p_tty);
static void tty_do_read(TTY* p_tty);
static void tty_do_write(TTY* p_tty);
static void put_key(TTY* p_tty, u32 key);

void task_tty()
{
	TTY *p_tty;

	init_keyboard();

	for (p_tty = TTY_FIRST; p_tty < TTY_END; p_tty++) {
		init_tty(p_tty);
	}
	select_console(0);
	while (1) {
		for (p_tty = TTY_FIRST; p_tty < TTY_END; p_tty++) {
			tty_do_read(p_tty);
			tty_do_write(p_tty);
		}
	}
}

void in_process(TTY *p_tty, u32 key)
{
	char output[2] = {0};

	if (!(key & FLAG_EXT)) {
		put_key(p_tty, key);
	}
	else {
		int raw_code = key & MASK_RAW;
		switch(raw_code) {
		case UP:
			if ((key & FLAG_SHIFT_L) || (key & FLAG_SHIFT_R)) {
				scroll_screen(p_tty->p_console, SCR_UP);
			}
			break;

		case DOWN:
			if ((key & FLAG_SHIFT_L) || (key & FLAG_SHIFT_R)) {
				scroll_screen(p_tty->p_console, SCR_DN);
			}
			break;

		case ENTER:
			put_key(p_tty, '\n');
			break;

		case BACKSPACE:
			put_key(p_tty, '\b');
			break;

		case F1:
		case F2:
		case F3:
		case F4:
		case F5:
		case F6:
		case F7:
		case F8:
		case F9:
		case F10:
		case F11:
		case F12:
			/* Alt + F1~F12 */
			if ((key & FLAG_CTRL_L) || (key & FLAG_CTRL_R)) {
				select_console(raw_code - F1);
			}
			break;

		default:
			break;
		}
	}
}

void tty_write(TTY* p_tty, char* buf, int len)
{
	char* p = buf;
	int i = len;

	while (i) {
		out_char(p_tty->p_console, *p++);
		i--;
	}
}

int sys_write(char* buf, int len, PROCESS* p_proc)
{
	tty_write(&_tty_table[p_proc->nr_tty], buf, len);
	return 0;
}


static void init_tty(TTY* p_tty)
{
	p_tty->inbuf_count = 0;
	p_tty->p_inbuf_head = p_tty->p_inbuf_tail = p_tty->in_buf;

	init_screen(p_tty);
}

static void put_key(TTY* p_tty, u32 key)
{
	if (p_tty->inbuf_count < TTY_IN_BYTES) {
		*(p_tty->p_inbuf_head) = key;
		p_tty->p_inbuf_head++;
		if (p_tty->p_inbuf_head == p_tty->in_buf + TTY_IN_BYTES) {
			p_tty->p_inbuf_head = p_tty->in_buf;
		}
		p_tty->inbuf_count++;
	}
}

static void tty_do_read(TTY *p_tty)
{
	if (is_current_console(p_tty->p_console)) {
		keyboard_read(p_tty);
	}
}

static void tty_do_write(TTY* p_tty)
{
	if (p_tty->inbuf_count) {
		char ch = *(p_tty->p_inbuf_tail);
		p_tty->p_inbuf_tail++;
		if (p_tty->p_inbuf_tail == p_tty->in_buf + TTY_IN_BYTES) {
			p_tty->p_inbuf_tail = p_tty->in_buf;
		}
		p_tty->inbuf_count--;

		out_char(p_tty->p_console, ch);
	}
}
