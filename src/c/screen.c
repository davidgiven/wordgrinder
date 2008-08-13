/* © 2008 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
 */

#include "globals.h"
#include <string.h>
#include <curses.h>
#include <wchar.h>
#include <wctype.h>

static bool running = false;
static int cursorx = 0;
static int cursory = 0;

void screen_deinit(void)
{
	if (running)
	{
		endwin();
		running = false;
	}
}

static int initscreen_cb(lua_State* L)
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

	running = true;
	atexit(screen_deinit);
	return 0;
}

static int clearscreen_cb(lua_State* L)
{
	erase();
	return 0;
}

static int sync_cb(lua_State* L)
{
	move(cursory, cursorx);
	refresh();
	return 0;
}

static int setbold_cb(lua_State* L)
{
	attron(A_BOLD);
	return 0;
}

static int setunderline_cb(lua_State* L)
{
	attron(A_UNDERLINE);
	return 0;
}

static int setreverse_cb(lua_State* L)
{
	wbkgdset(stdscr, A_REVERSE | ' ');
	attron(A_REVERSE);
	return 0;
}

static int setdim_cb(lua_State* L)
{
	attron(A_DIM);
	return 0;
}

static int setnormal_cb(lua_State* L)
{
	wbkgdset(stdscr, ' ');
	attrset(A_NORMAL);
	return 0;
}

static int write_cb(lua_State* L)
{
	int x = luaL_checkint(L, 1);
	int y = luaL_checkint(L, 2);
	size_t size;
	const char* s = luaL_checklstring(L, 3, &size);
	const char* send = s + size;

	while (s < send)
	{
		wchar_t c = readu8(&s);

		mvaddnwstr(y, x, &c, 1);
		if (!iswcntrl(c))
			x += wcwidth(c);
	}

	return 0;
}

static int cleartoeol_cb(lua_State* L)
{
	clrtoeol();
	return 0;
}

static int goto_cb(lua_State* L)
{
	cursorx = luaL_checkint(L, 1);
	cursory = luaL_checkint(L, 2);
	return 0;
}

static int getscreensize_cb(lua_State* L)
{
	int x, y;
	getmaxyx(stdscr, y, x);
	lua_pushnumber(L, x);
	lua_pushnumber(L, y);
	return 2;
}

static int getstringwidth_cb(lua_State* L)
{
	size_t size;
	const char* s = luaL_checklstring(L, 1, &size);
	const char* send = s + size;

	int width = 0;
	while (s < send)
	{
		wchar_t c = readu8(&s);
		if (!iswcntrl(c))
			width += wcwidth(c);
	}

	lua_pushnumber(L, width);
	return 1;
}

static int getboundedstring_cb(lua_State* L)
{
	size_t size;
	const char* start = luaL_checklstring(L, 1, &size);
	const char* send = start + size;
	int width = luaL_checkinteger(L, 2);

	const char* s = start;
	while (s < send)
	{
		const char* p = s;
		wchar_t c = readu8(&s);
		if (!iswcntrl(c))
		{
			width -= wcwidth(c);
			if (width < 0)
			{
				send = p;
				break;
			}
		}
	}

	lua_pushlstring(L, start, send - start);
	return 1;
}

static int getbytesofcharacter_cb(lua_State* L)
{
	int c = luaL_checkinteger(L, 1);

	lua_pushnumber(L, getu8bytes(c));
	return 1;
}

static const char* getkeyname(int k)
{
	switch (k)
	{
		case KEY_DOWN: return "KEY_DOWN";
		case KEY_UP: return "KEY_UP";
		case KEY_LEFT: return "KEY_LEFT";
		case KEY_RIGHT: return "KEY_RIGHT";
		case KEY_HOME: return "KEY_HOME";
		case KEY_BACKSPACE: return "KEY_BACKSPACE";
		case KEY_F0: return "KEY_F0";
		case KEY_DL: return "KEY_DL";
		case KEY_IL: return "KEY_IL";
		case KEY_DC: return "KEY_DC";
		case KEY_IC: return "KEY_IC";
		case KEY_EIC: return "KEY_EIC";
		case KEY_CLEAR: return "KEY_CLEAR";
		case KEY_EOS: return "KEY_EOS";
		case KEY_EOL: return "KEY_EOL";
		case KEY_SF: return "KEY_SF";
		case KEY_SR: return "KEY_SR";
		case KEY_NPAGE: return "KEY_NPAGE";
		case KEY_PPAGE: return "KEY_PPAGE";
		case KEY_STAB: return "KEY_STAB";
		case KEY_CTAB: return "KEY_CTAB";
		case KEY_CATAB: return "KEY_CATAB";
		case KEY_ENTER: return "KEY_ENTER";
		case KEY_PRINT: return "KEY_PRINT";
		case KEY_LL: return "KEY_LL";
		case KEY_A1: return "KEY_A1";
		case KEY_A3: return "KEY_A3";
		case KEY_B2: return "KEY_B2";
		case KEY_C1: return "KEY_C1";
		case KEY_C3: return "KEY_C3";
		case KEY_BTAB: return "KEY_BTAB";
		case KEY_BEG: return "KEY_BEG";
		case KEY_CANCEL: return "KEY_CANCEL";
		case KEY_CLOSE: return "KEY_CLOSE";
		case KEY_COMMAND: return "KEY_COMMAND";
		case KEY_COPY: return "KEY_COPY";
		case KEY_CREATE: return "KEY_CREATE";
		case KEY_END: return "KEY_END";
		case KEY_EXIT: return "KEY_EXIT";
		case KEY_FIND: return "KEY_FIND";
		case KEY_HELP: return "KEY_HELP";
		case KEY_MARK: return "KEY_MARK";
		case KEY_MESSAGE: return "KEY_MESSAGE";
		case KEY_MOVE: return "KEY_MOVE";
		case KEY_NEXT: return "KEY_NEXT";
		case KEY_OPEN: return "KEY_OPEN";
		case KEY_OPTIONS: return "KEY_OPTIONS";
		case KEY_PREVIOUS: return "KEY_PREVIOUS";
		case KEY_REDO: return "KEY_REDO";
		case KEY_REFERENCE: return "KEY_REFERENCE";
		case KEY_REFRESH: return "KEY_REFRESH";
		case KEY_REPLACE: return "KEY_REPLACE";
		case KEY_RESTART: return "KEY_RESTART";
		case KEY_RESUME: return "KEY_RESUME";
		case KEY_SAVE: return "KEY_SAVE";
		case KEY_SBEG: return "KEY_SBEG";
		case KEY_SCANCEL: return "KEY_SCANCEL";
		case KEY_SCOMMAND: return "KEY_SCOMMAND";
		case KEY_SCOPY: return "KEY_SCOPY";
		case KEY_SCREATE: return "KEY_SCREATE";
		case KEY_SDC: return "KEY_SDC";
		case KEY_SDL: return "KEY_SDL";
		case KEY_SELECT: return "KEY_SELECT";
		case KEY_SEND: return "KEY_SEND";
		case KEY_SEOL: return "KEY_SEOL";
		case KEY_SEXIT: return "KEY_SEXIT";
		case KEY_SFIND: return "KEY_SFIND";
		case KEY_SHELP: return "KEY_SHELP";
		case KEY_SHOME: return "KEY_SHOME";
		case KEY_SIC: return "KEY_SIC";
		case KEY_SLEFT: return "KEY_SLEFT";
		case KEY_SMESSAGE: return "KEY_SMESSAGE";
		case KEY_SMOVE: return "KEY_SMOVE";
		case KEY_SNEXT: return "KEY_SNEXT";
		case KEY_SOPTIONS: return "KEY_SOPTIONS";
		case KEY_SPREVIOUS: return "KEY_SPREVIOUS";
		case KEY_SPRINT: return "KEY_SPRINT";
		case KEY_SREDO: return "KEY_SREDO";
		case KEY_SREPLACE: return "KEY_SREPLACE";
		case KEY_SRIGHT: return "KEY_SRIGHT";
		case KEY_SRSUME: return "KEY_SRSUME";
		case KEY_SSAVE: return "KEY_SSAVE";
		case KEY_SSUSPEND: return "KEY_SSUSPEND";
		case KEY_SUNDO: return "KEY_SUNDO";
		case KEY_SUSPEND: return "KEY_SUSPEND";
		case KEY_UNDO: return "KEY_UNDO";
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

static int getchar_cb(lua_State* L)
{
	int t = 0;
	if (!lua_isnone(L, 1))
		t = luaL_checkinteger(L, 1);

	move(cursory, cursorx);
	refresh();

	for (;;)
	{
		if (t)
			timeout(t*1000);
		else
			timeout(-1);

		wint_t c;
		int r = get_wch(&c);

		if (r == ERR) /* timeout */
		{
			lua_pushnil(L);
			break;
		}

		if ((r == KEY_CODE_YES) || !iswprint(c)) /* function key */
		{
			const char* s = getkeyname(c);
			if (s)
			{
				lua_pushstring(L, s);
				break;
			}
		}

		if (wcwidth(c) > 0)
		{
			static char buffer[8];
			char* p = buffer;

			writeu8(&p, c);
			*p = '\0';

			lua_pushstring(L, buffer);
			break;
		}
	}

	return 1;
}

void screen_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "initscreen",                initscreen_cb },
		{ "clearscreen",               clearscreen_cb },
		{ "sync",                      sync_cb },
		{ "setbold",                   setbold_cb },
		{ "setunderline",              setunderline_cb },
		{ "setreverse",                setreverse_cb },
		{ "setdim",                    setdim_cb },
		{ "setnormal",                 setnormal_cb },
		{ "write",                     write_cb },
		{ "cleartoeol",                cleartoeol_cb },
		{ "goto",                      goto_cb },
		{ "getscreensize",             getscreensize_cb },
		{ "getstringwidth",            getstringwidth_cb },
		{ "getboundedstring",          getboundedstring_cb },
		{ "getbytesofcharacter",       getbytesofcharacter_cb },
		{ "getchar",                   getchar_cb },
		{ NULL,                        NULL }
	};

	luaL_register(L, "wg", funcs);
}
