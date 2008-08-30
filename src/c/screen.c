/* © 2008 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
 */

#include "globals.h"
#include <string.h>

static bool running = false;
static int cursorx = 0;
static int cursory = 0;

void screen_deinit(void)
{
	if (running)
	{
		dpy_shutdown();
		running = false;
	}
}

static int initscreen_cb(lua_State* L)
{
	dpy_start();

	running = true;
	atexit(screen_deinit);
	return 0;
}

static int clearscreen_cb(lua_State* L)
{
	dpy_clearscreen();
	return 0;
}

static int sync_cb(lua_State* L)
{
	dpy_setcursor(cursorx, cursory);
	dpy_sync();
	return 0;
}

static int setbold_cb(lua_State* L)
{
	dpy_setattr(-1, DPY_BOLD);
	return 0;
}

static int setunderline_cb(lua_State* L)
{
	dpy_setattr(-1, DPY_UNDERLINE);
	return 0;
}

static int setreverse_cb(lua_State* L)
{
	dpy_setattr(-1, DPY_REVERSE);
	return 0;
}

static int setdim_cb(lua_State* L)
{
	dpy_setattr(-1, DPY_DIM);
	return 0;
}

static int setnormal_cb(lua_State* L)
{
	dpy_setattr(0, 0);
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

		dpy_writechar(x, y, c);
		if (!iswcntrl(c))
			x += wcwidth(c);
	}

	return 0;
}

static int cleararea_cb(lua_State* L)
{
	int x1 = luaL_checkint(L, 1);
	int y1 = luaL_checkint(L, 2);
	int x2 = luaL_checkint(L, 3);
	int y2 = luaL_checkint(L, 4);
	dpy_cleararea(x1, y1, x2, y2);
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
	dpy_getscreensize(&x, &y);
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

static int getchar_cb(lua_State* L)
{
	int t = -1;
	if (!lua_isnone(L, 1))
		t = luaL_checkinteger(L, 1);

	dpy_setcursor(cursorx, cursory);
	dpy_sync();

	for (;;)
	{
		uni_t c = dpy_getchar(t);
		if (c <= 0)
		{
			const char* s = dpy_getkeyname(c);
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

void screen_init(const char* argv[])
{
	dpy_init(argv);

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
		{ "cleararea",                 cleararea_cb },
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
