/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <sys/time.h>

static const uint8_t masks[6] = {
	0xff, 0x1f, 0x0f, 0x07, 0x03, 0x01
};

static const signed char trailing_bytes[256] = {
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 0
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 1
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 2
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 3
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 4
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 5
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 6
     0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  // 7
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // 8
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // 9
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // A
    -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,  // B
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // C
     1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,  // D
     2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,  // E
     3, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5,  // F
};

int getu8bytes(char c)
{
	return trailing_bytes[(unsigned char) c] + 1;
}

uni_t readu8(const char** srcp)
{
	const char* src = *srcp;

	int nb = trailing_bytes[*(unsigned char*)src];
	if (nb == -1)
	{
		/* Invalid character! */
		(*srcp)++;
		return 0xfffd;
	}

	uni_t ch = (unsigned char)*src++ & masks[nb];
	switch (nb) {
	    /* these fall through deliberately */
		case 5: if (!*src) break; ch <<= 6; ch += (unsigned char)*src++ & 0x3f; 
		case 4: if (!*src) break; ch <<= 6; ch += (unsigned char)*src++ & 0x3f;
		case 3: if (!*src) break; ch <<= 6; ch += (unsigned char)*src++ & 0x3f;
		case 2: if (!*src) break; ch <<= 6; ch += (unsigned char)*src++ & 0x3f;
		case 1: if (!*src) break; ch <<= 6; ch += (unsigned char)*src++ & 0x3f;
		case 0: break;
	}

	*srcp = src;
	return ch;
}

void writeu8(char** destp, uni_t ch)
{
	char* dest = *destp;

	if (ch < 0)
		assert(false);
    else if (ch < 0x80)
    {
        *dest++ = (char)ch;
    }
    else if (ch < 0x800)
    {
        *dest++ = (ch>>6) | 0xC0;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x10000)
    {
        *dest++ = (ch>>12) | 0xE0;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    else if (ch < 0x200000)
    {
        *dest++ = (ch>>18) | 0xF0;
        *dest++ = ((ch>>12) & 0x3F) | 0x80;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
	else if (ch < 0x4000000)
	{
        *dest++ = (ch>>24) | 0xF8;
        *dest++ = ((ch>>18) & 0x3F) | 0x80;
        *dest++ = ((ch>>12) & 0x3F) | 0x80;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
	}
	else if (ch <= 0x7fffffff)
	{
        *dest++ = (ch>>30) | 0xFC;
        *dest++ = ((ch>>24) & 0x3F) | 0x80;
        *dest++ = ((ch>>18) & 0x3F) | 0x80;
        *dest++ = ((ch>>12) & 0x3F) | 0x80;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
	}

    *destp = dest;
}

static int readu8_cb(lua_State* L)
{
	const char* s = luaL_checkstring(L, 1);
	int offset = forceinteger(L, 2);
	uni_t c;

	if (offset > 0)
		offset--;
	const char* p = s + offset;
	c = readu8(&p);

	lua_pushnumber(L, c);
	lua_pushinteger(L, (p - s)+1);
	return 2;
}

static int writeu8_cb(lua_State* L)
{
	uni_t c = forceinteger(L, 1);
	static char buffer[8];
	char* s = buffer;

	writeu8(&s, c);
	lua_pushlstring(L, buffer, s-buffer);
	return 1;
}

static int transcode_cb(lua_State* L)
{
	size_t inputbuffersize;
	const char* inputbuffer = luaL_checklstring(L, 1, &inputbuffersize);

	size_t outputbuffersize = inputbuffersize*2 + 32;
	char* outputbuffer = malloc(outputbuffersize); /* should fit everything */

	const char* in = (char*) inputbuffer;
	const char* inend = inputbuffer + inputbuffersize;

	char* out = outputbuffer;
	//char* outend = outputbuffer + outputbuffersize - 4;

	while (in < inend)
	{
		int c = readu8(&in);
		writeu8(&out, c);
	}

	lua_pushlstring(L, outputbuffer, out - outputbuffer);
	free(outputbuffer);
	return 1;
}

static int time_cb(lua_State* L)
{
	struct timeval tv;
	gettimeofday(&tv, NULL);

	double t = (double)tv.tv_sec +
			(double)tv.tv_usec / 1000000.0;
	lua_pushnumber(L, t);

	return 1;
}

static int escape_cb(lua_State* L)
{
	size_t inputbuffersize;
	const char* inputbuffer = luaL_checklstring(L, 1, &inputbuffersize);

	const size_t outputbuffersize = inputbuffersize*2; /* big enough to fit */
	char* const outputbuffer = malloc(outputbuffersize);

	const char* in = (char*) inputbuffer;
	const char* inend = inputbuffer + inputbuffersize;

	char* out = outputbuffer;

	while (in < inend)
	{
		int c = readu8(&in);
		switch (c)
		{
			case '\n':
				writeu8(&out, '\\');
				writeu8(&out, 'n');
				break;

			case '\r':
				writeu8(&out, '\\');
				writeu8(&out, 'r');
				break;

			case '"':
			case '\\':
				writeu8(&out, '\\');
				/* fall through */
			default:
				writeu8(&out, c);
		}
	}

	lua_pushlstring(L, outputbuffer, out - outputbuffer);
	free(outputbuffer);

	return 1;
}

static int unescape_cb(lua_State* L)
{
	size_t inputbuffersize;
	const char* inputbuffer = luaL_checklstring(L, 1, &inputbuffersize);

	const size_t outputbuffersize = inputbuffersize; /* big enough to fit */
	char* const outputbuffer = malloc(outputbuffersize);

	const char* in = (char*) inputbuffer;
	const char* inend = inputbuffer + inputbuffersize;

	char* out = outputbuffer;

	while (in < inend)
	{
		int c = readu8(&in);
		switch (c)
		{
			case '\\':
				c = readu8(&in);
				switch (c)
				{
					case 'n':
						writeu8(&out, '\n');
						break;

					case 'r':
						writeu8(&out, '\r');
						break;

					default:
						writeu8(&out, c);
				}
				break;

			default:
				writeu8(&out, c);
		}
	}

	lua_pushlstring(L, outputbuffer, out - outputbuffer);
	free(outputbuffer);

	return 1;
}

void utils_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "readu8",                    readu8_cb },
		{ "writeu8",                   writeu8_cb },
		{ "transcode",                 transcode_cb },
		{ "time",                      time_cb },
		{ "escape",                    escape_cb },
		{ "unescape",                  unescape_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);
}
