#include "const.h"
#include "keymap.h"
#include "i8259.h"

static KB_INPUT kb_in;		// 缓冲区

static int	code_with_E0;
static int	shift_l;			/* l shift state */
static int	shift_r;			/* r shift state */
static int	alt_l;			/* l alt state	 */
static int	alt_r;			/* r left state	 */
static int	ctrl_l;			/* l ctrl state	 */
static int	ctrl_r;			/* l ctrl state	 */
static int	caps_lock;		/* Caps Lock	 */
static int	num_lock;		/* Num Lock	 */
static int	scroll_lock;	/* Scroll Lock	 */
static int	column;

static u8 get_byte_from_buf();
static void set_leds();
static void kb_wait();
static void kb_ack();

void keyboard_handler(int irq)
{
	u8 scan_code = in_byte(KB_DATA);		// 读键盘缓冲，若缓冲区不为空，8042将不再接受扫描码

	if (kb_in.count < KB_IN_BYTES) {
		*(kb_in.p_head) = scan_code;
		kb_in.p_head++;
		if (kb_in.p_head == kb_in.buf + KB_IN_BYTES) {
			kb_in.p_head = kb_in.buf;
		}
		kb_in.count++;
	}
}

void init_keyboard()
{
	kb_in.count = 0;
	kb_in.p_head = kb_in.p_tail = kb_in.buf;

	shift_l	= shift_r = FALSE;
	alt_l	= alt_r   = FALSE;
	ctrl_l	= ctrl_r  = FALSE;

	caps_lock = FALSE;
	num_lock = TRUE;
	scroll_lock = FALSE;

	set_leds();

	put_irq_handler(KEYBOARD_IRQ, keyboard_handler);
	enable_irq(KEYBOARD_IRQ);
}

void keyboard_read(TTY *p_tty)
{
	u8 scan_code;
	int make;		// TRUE: make; FALSE: break;

	// 用一个整型来表示一个键。比如，如果 Home 被按下，
	// 则 key 值将为定义在 keyboard.h 中的 'HOME'。
	u32 key = 0;
	u32 *keyrow;	// 指向 keymap 中的某一行

	if (kb_in.count > 0) {
		code_with_E0 = FALSE;
		scan_code = get_byte_from_buf();

		// 解析程序，PUASE键是由0xE1开始的
		if (scan_code == 0xE1) {
			int i;
			u8 pause_brk_scode[] = {0xE1, 0x1D, 0x45, 0xE1, 0x9D, 0xC5};
			int is_pause_break = TRUE;
			for (i = 1; i < 6; i++) {
				if (get_byte_from_buf() != pause_brk_scode[i]) {
					is_pause_break = FALSE;
					break;
				}
			}
			if (is_pause_break) {
				key = PAUSEBREAK;
			}
		}
		else if (scan_code == 0xE0) {
			scan_code = get_byte_from_buf();

			/* PrintScreen 被按下 */
			if (scan_code == 0x2A) {
				if (get_byte_from_buf() == 0xE0) {
					if (get_byte_from_buf() == 0x37) {
						key = PRINTSCREEN;
						make = TRUE;
					}
				}
			}
			/* PrintScreen 被释放 */
			if (scan_code == 0xB7) {
				if (get_byte_from_buf() == 0xE0) {
					if (get_byte_from_buf() == 0xAA) {
						key = PRINTSCREEN;
						make = FALSE;
					}
				}
			}
			/* 不是PrintScreen, 此时scan_code为0xE0紧跟的那个值. */
			if (key == 0) {
				code_with_E0 = TRUE;
			}
		}

		if ((key != PAUSEBREAK) && (key != PRINTSCREEN)) {
			// 判断是make code 还是 break code
			// break code 是 make code 与 0x80 或出来的结果，所以FLAG_BREAK＝0x80
			make = (scan_code & FLAG_BREAK ? FALSE : TRUE);

			/* 先定位到 keymap 中的行 */
			keyrow = &keymap[(scan_code & 0x7F) * MAP_COLS];

			column = 0;

			int caps = shift_l || shift_r;
			if (caps_lock) {
				if (keyrow[0] >= 'a' && keyrow[0] <= 'z') {
					caps = !caps;
				}
			}
			if (caps) {
				column = 1;
			}
			if (code_with_E0) {
				column = 2;
				code_with_E0 = FALSE;
			}

			key = keyrow[column];

			switch(key) {
			case SHIFT_L:
				shift_l = make;
				break;
			case SHIFT_R:
				shift_r = make;
				break;
			case CTRL_L:
				ctrl_l = make;
				break;
			case CTRL_R:
				ctrl_r = make;
				break;
			case ALT_L:
				alt_l = make;
				break;
			case ALT_R:
				alt_r = make;
				break;
			case CAPS_LOCK:
				if (make) {
					caps_lock = !caps_lock;
					set_leds();
				}
				break;
			case NUM_LOCK:
				if (make) {
					num_lock    = !num_lock;
					set_leds();
				}
				break;
			case SCROLL_LOCK:
				if (make) {
					scroll_lock = !scroll_lock;
					set_leds();
				}
				break;

			default:
				break;
			}

			if (make) { /* 忽略 Break Code */
				int pad = 0;

				/* 首先处理小键盘 */
				if ((key >= PAD_SLASH) && (key <= PAD_9)) {
					pad = 1;
					switch(key) {
					case PAD_SLASH:
						key = '/';
						break;
					case PAD_STAR:
						key = '*';
						break;
					case PAD_MINUS:
						key = '-';
						break;
					case PAD_PLUS:
						key = '+';
						break;
					case PAD_ENTER:
						key = ENTER;
						break;
					default:
						if (num_lock &&
						    (key >= PAD_0) &&
						    (key <= PAD_9)) {
							key = key - PAD_0 + '0';
						}
						else if (num_lock &&
							 (key == PAD_DOT)) {
							key = '.';
						}
						else{
							switch(key) {
							case PAD_HOME:
								key = HOME;
								break;
							case PAD_END:
								key = END;
								break;
							case PAD_PAGEUP:
								key = PAGEUP;
								break;
							case PAD_PAGEDOWN:
								key = PAGEDOWN;
								break;
							case PAD_INS:
								key = INSERT;
								break;
							case PAD_UP:
								key = UP;
								break;
							case PAD_DOWN:
								key = DOWN;
								break;
							case PAD_LEFT:
								key = LEFT;
								break;
							case PAD_RIGHT:
								key = RIGHT;
								break;
							case PAD_DOT:
								key = DELETE;
								break;
							default:
								break;
							}
						}
						break;
					}
				}

				key |= shift_l	? FLAG_SHIFT_L	: 0;
				key |= shift_r	? FLAG_SHIFT_R	: 0;
				key |= ctrl_l	? FLAG_CTRL_L	: 0;
				key |= ctrl_r	? FLAG_CTRL_R	: 0;
				key |= alt_l	? FLAG_ALT_L	: 0;
				key |= alt_r	? FLAG_ALT_R	: 0;
				key |= pad 		? FLAG_PAD		: 0;

				in_process(p_tty, key);
			}

		}
	}
}

static u8 get_byte_from_buf()
{
	u8 scan_code;

	while (kb_in.count <= 0) {}

	// 嵌套汇编，关中断
	asm("cli");

	scan_code = *(kb_in.p_tail);
	kb_in.p_tail++;
	if (kb_in.p_tail == kb_in.buf + KB_IN_BYTES) {
		kb_in.p_tail = kb_in.buf;
	}
	kb_in.count--;

	// enable interupt
	asm("sti");

	return scan_code;
}

static void kb_wait()	/* 等待 8042 的输入缓冲区空 */
{
	u8 kb_stat;

	do {
		kb_stat = in_byte(KB_CMD);
	} while (kb_stat & 0x02);
}

static void kb_ack()
{
	u8 kb_read;

	do {
		kb_read = in_byte(KB_DATA);
	} while (kb_read =! KB_ACK);
}

static void set_leds()
{
	u8 leds = (caps_lock << 2) | (num_lock << 1) | scroll_lock;

	kb_wait();
	out_byte(KB_DATA, LED_CODE);
	kb_ack();

	kb_wait();
	out_byte(KB_DATA, leds);
	kb_ack();
}
