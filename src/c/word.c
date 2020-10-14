/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <ctype.h>

/* A 'word' is a string with embedded text style codes.
 *
 * The data consists of standard UTF-8 sequences interspaced with
 * control codes. A word is always considered to start with
 * all style turned off.
 *
 * Control codes consist of combinations of the first four DPY_
 * constants, with STYLE_MARKER set to prevent nil characters.
 */

enum
{
	STYLE_MARKER = (1<<4), /* always set */
	STYLE_ALL = 15
};

#define OVERHEAD (3*2 + 1)

static bool iscontrolbyte(int c)
{
	return (c >= 0) && (c <= 31);
}

/* Parse a styled word. */

static int parseword_cb(lua_State* L)
{
	size_t size;
	const char* s = luaL_checklstring(L, 1, &size);
	const char* send = s + size;
	int dstyle = forceinteger(L, 2);
	/* pos 3 contains the callback function */

	int oldattr = 0;
	int attr = 0;
	const char* w = s;
	const char* wend = NULL;
	bool flush = false;

	for (;;)
	{
		if (flush)
		{
			if (w != wend)
			{
				lua_pushvalue(L, 3);
				lua_pushnumber(L, oldattr | dstyle);
				lua_pushlstring(L, w, wend - w);
				lua_call(L, 2, 0);
			}
			w = s;
			oldattr = attr;
			flush = false;
		}

		if (s == send)
		{
			if (w == s)
				break;

			flush = true;
		}
		else
		{
			uni_t c = readu8(&s);

			if (iswcntrl(c))
			{
				oldattr = attr;
				attr = c & STYLE_ALL;
				flush = true;
				wend = s - 1;
			}
			else
				wend = s;
		}
	}

	return 0;
}

/* Draw a styled word at a particular location. */

static int writestyled_cb(lua_State* L)
{
	int x = forceinteger(L, 1);
	int y = forceinteger(L, 2);
	size_t size;
	const char* s = luaL_checklstring(L, 3, &size);
	const char* send = s + size;
	int oattr = forceinteger(L, 4);
	const char* revon = s + forceinteger(L, 5) - 1;
	const char* revoff = s + forceinteger(L, 6) - 1;
	int sor = forceinteger(L, 7);

	int attr = sor;
	int mark = 0;

	dpy_setattr(0, sor);
	bool first = true;
	while (s < send)
	{
		if (s == revon)
		{
			mark = DPY_REVERSE;
			dpy_setattr(0, attr | mark);
		}
		if (s == revoff)
		{
			mark = 0;
			dpy_setattr(0, attr | mark);
		}

		uni_t c = readu8(&s);

		if (iswcntrl(c))
		{
			c &= STYLE_ALL;
			attr = c | sor;
			dpy_setattr(0, attr | mark);
		}
		else
		{
			if (first && (oattr & (DPY_REVERSE|DPY_UNDERLINE))
				&& ((attr | mark) == oattr))
				dpy_writechar(x-1, y, 160); /* non-breaking space */

			dpy_writechar(x, y, c);
			x += emu_wcwidth(c);
			first = false;
		}
	}
	dpy_setattr(0, 0);

	lua_pushnumber(L, attr | mark);
	return 1;
}

/* Returns the raw text of a word, with no styling. */

static int getwordtext_cb(lua_State* L)
{
	size_t bytes;
	const char* src = luaL_checklstring(L, 1, &bytes);
	char dest[bytes+1];
	char* p = dest;

	for (;;)
	{
		uni_t c = readu8(&src);
		if (c == '\0')
			break;

		if (!iswcntrl(c))
			writeu8(&p, c);
	}

	lua_pushlstring(L, dest, p - dest);
	return 1;
}

/* Advances an offset pointer to the next thing in the string. */

static int nextcharinword_cb(lua_State* L)
{
	const char* src = luaL_checkstring(L, 1);
	int offset = forceinteger(L, 2) - 1;
	const char* p = src + offset;

	/* At the end of the string? */

	if (*p == '\0')
	{
	atend:
		lua_pushnil(L);
		return 1;
	}

	/* Skip any control codes. */

	while (*p && iscontrolbyte(*p))
		p++;

	if (*p == '\0')
		goto atend;

	/* Skip exactly one UTF-8 code point. */

	(void) readu8(&p);

	lua_pushnumber(L, 1 + p - src);
	return 1;
}

/* Backs up to the previous thing in a string. */

static int prevcharinword_cb(lua_State* L)
{
	const char* src = luaL_checkstring(L, 1);
	int offset = forceinteger(L, 2) - 1;
	const char* p = src + offset;

	/* Back up over any control codes; give up if we find ourselves at
	 * the beginning of the string. */

	do
	{
		if (p == src)
		{
			lua_pushnil(L);
			return 1;
		}

		p--;
	}
	while (iscontrolbyte(*p));

	/* We now know that there is a character, and it's definitively not a
	 * control code. Skip any UTF-8 trailing bytes. */

	while ((p != src) && (getu8bytes(*p) == 0))
		p--;

	/* Back up over any additional control codes. */

	while (p != src)
	{
		if (iscontrolbyte(*(p-1)))
			p--;
		else
			break;
	}

	lua_pushnumber(L, 1 + p - src);
	return 1;
}

/* Copies one character (or control code) from the source to the destination
 * string.
 */

static bool copy(char** dest, int* dstate, const char** src, int* sstate, int stateor, int stateand)
{
	const char* oldsrc = *src;
	int c = readu8(src);

	if (c == '\0')
		return false;

	if (iswcntrl(c))
	{
		*sstate = c & STYLE_ALL;
		return true;
	}

	/* If we got here, we've just read a printable character. */

	if (dest)
	{
		int estate = (*sstate & stateand) | stateor;
		if (*dstate != estate)
		{
			/* We need to emit a style change byte; we do this, then we
			 * back up over the printable character we just read, so we
			 * can read it again next time.
			 */
			writeu8(dest, estate | STYLE_MARKER);
			*dstate = estate;

			*src = oldsrc;
			return true;
		}

		writeu8(dest, c);
	}
	return true;
}

/* Inserts a word into another word, at a particular offset. */

static int insertintoword_cb(lua_State* L)
{
	size_t srcbytes;
	const char* src = luaL_checklstring(L, 1, &srcbytes);
	const char* s = src;
	size_t insbytes;
	const char* ins = luaL_checklstring(L, 2, &insbytes);
	int offset = forceinteger(L, 3) - 1;
	int newstate = forceinteger(L, 4);

	char dest[srcbytes + insbytes + OVERHEAD];
	char* p = dest;

	int sstate = 0;
	int dstate = 0;
	int insstart = -1;
	int insend = -1;
	bool copied = 0;

	do
	{
		/* If we reach the right point in the source string, copy in the
		 * destination string. */

		if (!copied && ((s - src) >= offset))
		{
			insstart = p - dest;

			while (copy(&p, &dstate, &ins, &newstate, 0, STYLE_ALL))
				;

			insend = p - dest;
			copied = 1;
		}
	}
	while (copy(&p, &dstate, &s, &sstate, 0, STYLE_ALL));

	/* Return both the new string, and the offset to the end of the inserted
	 * section, and the offset to the *start* of the inserted section (because
	 * it might have changed). */

	lua_pushlstring(L, dest, p - dest);

	if (insend != -1)
		lua_pushnumber(L, 1 + insend);
	else
		lua_pushnil(L);

	if (insstart != -1)
		lua_pushnumber(L, 1 + insstart);
	else
		lua_pushnil(L);
	return 3;
}

/* Deletes all characters between certain offsets in a word. */

static int deletefromword_cb(lua_State* L)
{
	size_t srcbytes;
	const char* src = luaL_checklstring(L, 1, &srcbytes);
	const char* offset1 = src + forceinteger(L, 2) - 1;
	const char* offset2 = src + forceinteger(L, 3) - 1;

	char dest[srcbytes];
	char* p = dest;

	int sstate = 0;
	int dstate = 0;

	do
	{
		/* If we reach the right point in the source string, skip characters
		 * until we reach the end offset. */

		if (src == offset1)
		{
			while (src < offset2)
			{
				if (!copy(NULL, &dstate, &src, &sstate, 0, STYLE_ALL))
					goto finished;
			}
		}
	}
	while (copy(&p, &dstate, &src, &sstate, 0, STYLE_ALL));
finished:

	lua_pushlstring(L, dest, p - dest);
	return 1;
}

/* Turns on or off a style to a particular range of a word. */

static int applystyletoword_cb(lua_State* L)
{
	size_t srcbytes;
	const char* src = luaL_checklstring(L, 1, &srcbytes);
	int targetsor = forceinteger(L, 2);
	int targetsand = forceinteger(L, 3);
	const char* offset1 = src + forceinteger(L, 4) - 1;
	const char* offset2 = src + forceinteger(L, 5) - 1;
	const char* csoffset = src + forceinteger(L, 6) - 1;

	/* Adding a style will add at most two extra bytes to the string
	 * (on, and then off again). Probably less. */
	char dest[srcbytes+2];
	char* p = dest;
	char* cdoffset = dest;

	int sand = STYLE_ALL;
	int sor = 0;

	int sstate = 0;
	int dstate = 0;

	do
	{
		/* If we reach the right point in the source string, set the mask to
		 * apply the desired style. Also, turn it off again afterwards. */

		if (src == offset1)
		{
			sand = targetsand;
			sor = targetsor;
		}

		if (src == offset2)
		{
			sand = STYLE_ALL;
			sor = 0;
		}

		/* If we reach csoffset in the src, remember where we were in the dest
		 * so we can move the cursor correctly. */

		if (src == csoffset)
			cdoffset = p;
	}
	while (copy(&p, &dstate, &src, &sstate, sor, sand));

	lua_pushlstring(L, dest, p - dest);
	lua_pushnumber(L, 1 + cdoffset - dest);
	return 2;
}

/* Fetch the style at a particular offset into a word. */

static int getstylefromword_cb(lua_State* L)
{
	size_t srcbytes;
	const char* src = luaL_checklstring(L, 1, &srcbytes);
	const char* offset = src + forceinteger(L, 2) - 1;

	int state = 0;
	while (src < offset)
	{
		int c = readu8(&src);
		if (c == '\0')
			break;

		if (iswcntrl(c))
			state = c & STYLE_ALL;
	}

	lua_pushnumber(L, state);
	return 1;
}

/* Create a raw style byte. */

static int createstylebyte_cb(lua_State* L)
{
	int style = forceinteger(L, 1);
	char buffer = style | STYLE_MARKER;
	lua_pushlstring(L, &buffer, 1);
	return 1;
}

void word_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "parseword",                 parseword_cb },
		{ "writestyled",               writestyled_cb },
		{ "getwordtext",               getwordtext_cb },
		{ "nextcharinword",            nextcharinword_cb },
		{ "prevcharinword",            prevcharinword_cb },
		{ "insertintoword",            insertintoword_cb },
		{ "deletefromword",            deletefromword_cb },
		{ "applystyletoword",          applystyletoword_cb },
		{ "getstylefromword",          getstylefromword_cb },
		{ "createstylebyte",           createstylebyte_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);

	lua_pushnumber(L, DPY_ITALIC);
	lua_setfield(L, -2, "ITALIC");

	lua_pushnumber(L, DPY_UNDERLINE);
	lua_setfield(L, -2, "UNDERLINE");

	lua_pushnumber(L, DPY_REVERSE);
	lua_setfield(L, -2, "REVERSE");

	lua_pushnumber(L, DPY_BOLD);
	lua_setfield(L, -2, "BOLD");

	lua_pushnumber(L, DPY_BRIGHT);
	lua_setfield(L, -2, "BRIGHT");

	lua_pushnumber(L, DPY_DIM);
	lua_setfield(L, -2, "DIM");
}
