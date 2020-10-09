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

#if defined A_ITALIC
static bool has_italics = false;
#endif

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

	#if defined A_ITALIC
		has_italics = !!tigetstr("sitm");
	#endif
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

void dpy_setcursor(int x, int y, bool shown)
{
	move(y, x);
}

void dpy_setattr(int andmask, int ormask)
{
	static int attr = 0;
	attr &= andmask;
	attr |= ormask;

	int cattr = 0;
	if (attr & DPY_ITALIC)
	{
		#if defined A_ITALIC
			if (has_italics)
				cattr |= A_ITALIC;
			else
				cattr |= A_BOLD;
		#else
			cattr |= A_BOLD;
		#endif
	}
	if (attr & (DPY_BOLD|DPY_BRIGHT))
		cattr |= A_BOLD;
	if (attr & DPY_DIM)
		cattr |= A_DIM;
	if (attr & DPY_UNDERLINE)
		cattr |= A_UNDERLINE;
	if (attr & DPY_REVERSE)
		cattr |= A_REVERSE;

	attrset(cattr);
}

void dpy_writechar(int x, int y, uni_t c)
{
	char buffer[8];
	char* p = buffer;
	writeu8(&p, c);
	*p = '\0';

	mvaddstr(y, x, buffer);
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	char cc = ' ';

	for (int y = y1; y <= y2; y++)
		for (int x = x1; x <= x2; x++)
			mvaddnstr(y, x, &cc, 1);
}

uni_t dpy_getchar(double timeout)
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

			int delay = ((u_int64_t) (timeout*1000)) + nowms - thenms;
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

static const char* ncurses_prefix_to_name(const char* s)
{
	if (strcmp(s, "KDC") == 0)  return "DELETE";
	if (strcmp(s, "kDN") == 0)  return "DOWN";
	if (strcmp(s, "kEND") == 0) return "END";
	if (strcmp(s, "kHOM") == 0) return "HOME";
	if (strcmp(s, "kIC") == 0)  return "INSERT";
	if (strcmp(s, "kLFT") == 0) return "LEFT";
	if (strcmp(s, "kNXT") == 0) return "PGDN";
	if (strcmp(s, "kPRV") == 0) return "PGUP";
	if (strcmp(s, "kRIT") == 0) return "RIGHT";
	if (strcmp(s, "kUP") == 0)  return "UP";

	return s;
}

static const char* ncurses_suffix_to_name(int suffix)
{
	switch (suffix)
	{
		case 3: return "A";
		case 4: return "SA";
		case 5: return "^";
		case 6: return "S^";
		case 7: return "A^";
	}

	return NULL;
}

const char* dpy_getkeyname(uni_t k)
{
	k = -k;

	switch (k)
	{
		case 127: /* Some misconfigured terminals produce this */
		case KEY_BACKSPACE:
			return "KEY_BACKSPACE";

		case KEY_TIMEOUT: return "KEY_TIMEOUT";
		case KEY_DOWN: return "KEY_DOWN";
		case KEY_UP: return "KEY_UP";
		case KEY_LEFT: return "KEY_LEFT";
		case KEY_RIGHT: return "KEY_RIGHT";
		case KEY_HOME: return "KEY_HOME";
		case KEY_END: return "KEY_END";
		case KEY_DC: return "KEY_DELETE";
		case KEY_IC: return "KEY_INSERT";
		case KEY_NPAGE: return "KEY_PGDN";
		case KEY_PPAGE: return "KEY_PGUP";
		case KEY_STAB: return "KEY_STAB";
		case KEY_CTAB: return "KEY_^TAB";
		case KEY_CATAB: return "KEY_^ATAB";
		case KEY_ENTER: return "KEY_RETURN";
		case KEY_SIC: return "KEY_SINSERT";
		case KEY_SDC: return "KEY_SDELETE";
		case KEY_SHOME: return "KEY_SHOME";
		case KEY_SEND: return "KEY_SEND";
		case KEY_SR: return "KEY_SUP";
		case KEY_SF: return "KEY_SDOWN";
		case KEY_SLEFT: return "KEY_SLEFT";
		case KEY_SRIGHT: return "KEY_SRIGHT";
		case KEY_MOUSE: return "KEY_MOUSE";
		case KEY_RESIZE: return "KEY_RESIZE";
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

	const char* name = keyname(k);
	if (name)
	{
		char buf[strlen(name)+1];
		strcpy(buf, name);

		int prefix = strcspn(buf, "0123456789");
		int suffix = buf[prefix] - '0';
		buf[prefix] = '\0';

		if ((suffix >= 0) && (suffix <= 9))
		{
			const char* ps = ncurses_prefix_to_name(buf);
			const char* ss = ncurses_suffix_to_name(suffix);
			if (ss)
			{
				sprintf(buffer, "KEY_%s%s", ss, ps);
				return buffer;
			}
		}
	}

	sprintf(buffer, "KEY_UNKNOWN_%d (%s)", k, name ? name : "???");
	return buffer;
}
