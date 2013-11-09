/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <curses.h>
#include <wctype.h>
#include <sys/time.h>
#include <time.h>

#define KEY_TIMEOUT (KEY_MAX + 1)

void dpy_init(const char* argv[])
{
}

void dpy_start(void)
{
	initscr();
	raw();
	noecho();
	meta(NULL, TRUE);
	nonl();
	idlok(stdscr, TRUE);
	idcok(stdscr, TRUE);
	scrollok(stdscr, FALSE);
	intrflush(stdscr, FALSE);
	//notimeout(stdscr, TRUE);
	keypad(stdscr, TRUE);
}

void dpy_shutdown(void)
{
	endwin();
}

void dpy_clearscreen(void)
{
	erase();
}

void dpy_getscreensize(int* x, int* y)
{
	getmaxyx(stdscr, *y, *x);
}

void dpy_sync(void)
{
	refresh();
}

void dpy_setcursor(int x, int y)
{
	move(y, x);
}

void dpy_setattr(int andmask, int ormask)
{
	static int attr = 0;
	attr &= andmask;
	attr |= ormask;

	int cattr = 0;
	if (attr & (DPY_ITALIC|DPY_BOLD))
		cattr |= A_BOLD;
	if (attr & DPY_UNDERLINE)
		cattr |= A_UNDERLINE;
	if (attr & DPY_REVERSE)
		cattr |= A_REVERSE;
	if (attr & DPY_DIM)
		cattr |= A_DIM;

	attrset(cattr);
}

void dpy_writechar(int x, int y, uni_t c)
{
	wchar_t cc = c;

	mvaddnwstr(y, x, &cc, 1);
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	wchar_t cc = ' ';

	for (int y = y1; y <= y2; y++)
		for (int x = x1; x <= x2; x++)
			mvaddnwstr(y, x, &cc, 1);
}

uni_t dpy_getchar(int timeout)
{
	struct timeval then;
	gettimeofday(&then, NULL);
	u_int64_t thenms = (then.tv_usec/1000) + ((u_int64_t) then.tv_sec*1000);

	for (;;)
	{

		if (timeout != -1)
		{
			struct timeval now;
			gettimeofday(&now, NULL);
			u_int64_t nowms = (now.tv_usec/1000) + ((u_int64_t) now.tv_sec*1000);

			int delay = ((u_int64_t) timeout*1000) + nowms - thenms;
			if (delay <= 0)
				return -KEY_TIMEOUT;

			timeout(delay);
		}
		else
			timeout(-1);

		wint_t c;
		int r = get_wch(&c);

		if (r == ERR) /* timeout */
			return -KEY_TIMEOUT;

		if ((r == KEY_CODE_YES) || !iswprint(c)) /* function key */
			return -c;

		if (emu_wcwidth(c) > 0)
			return c;
	}
}

const char* dpy_getkeyname(uni_t k)
{
	k = -k;

	switch (k)
	{
		case KEY_TIMEOUT: return "KEY_TIMEOUT";
		case KEY_DOWN: return "KEY_DOWN";
		case KEY_UP: return "KEY_UP";
		case KEY_LEFT: return "KEY_LEFT";
		case KEY_RIGHT: return "KEY_RIGHT";
		case KEY_HOME: return "KEY_HOME";
		case KEY_END: return "KEY_END";
		case KEY_BACKSPACE: return "KEY_BACKSPACE";
		case KEY_DC: return "KEY_DELETE";
		case KEY_IC: return "KEY_INSERT";
		case KEY_NPAGE: return "KEY_PGDN";
		case KEY_PPAGE: return "KEY_PGUP";
		case KEY_STAB: return "KEY_STAB";
		case KEY_CTAB: return "KEY_CTAB";
		case KEY_CATAB: return "KEY_CATAB";
		case KEY_ENTER: return "KEY_RETURN";
		case KEY_SIC: return "KEY_SINSERT";
		case KEY_SDC: return "KEY_SDELETE";
		case KEY_SHOME: return "KEY_SHOME";
		case KEY_SEND: return "KEY_SEND";
		case KEY_SLEFT: return "KEY_SLEFT";
		case KEY_SRIGHT: return "KEY_SRIGHT";
		case KEY_MOUSE: return "KEY_MOUSE";
		case KEY_RESIZE: return "KEY_RESIZE";
		case KEY_EVENT: return "KEY_EVENT";
		case 13: return "KEY_RETURN";
		case 27: return "KEY_ESCAPE";
	}

	static char buffer[32];
	if (k < 32)
	{
		sprintf(buffer, "KEY_^%c", k+'A'-1);
		return buffer;
	}

	if ((k >= KEY_F0) && (k < (KEY_F0+64)))
	{
		sprintf(buffer, "KEY_F%d", k - KEY_F0);
		return buffer;
	}

	sprintf(buffer, "KEY_UNKNOWN_%d", k);
	return buffer;
}
