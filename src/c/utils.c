/* © 2008 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
 */

#include "globals.h"
#include <iconv.h>

static const uint32_t offsets[6] = {
    0x00000000UL, 0x00003080UL, 0x000E2080UL,
    0x03C82080UL, 0xFA082080UL, 0x82082080UL
};

static const char trailing_bytes[256] = {
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

wint_t readu8(const char** srcp)
{
	const char* src = *srcp;
	int nb = trailing_bytes[*(unsigned char*)src];

	wint_t ch = 0;
	switch (nb) {
	    /* these fall through deliberately */
		case 3: ch += (unsigned char)*src++; ch <<= 6;
		case 2: ch += (unsigned char)*src++; ch <<= 6;
		case 1: ch += (unsigned char)*src++; ch <<= 6;
		case 0: ch += (unsigned char)*src++;
	}
	
	ch -= offsets[nb];
	*srcp = src;
	return ch;
}

void writeu8(char** destp, wint_t ch)
{
	char* dest = *destp;
	
    if (ch < 0x80)
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
    else
    {
        *dest++ = (ch>>18) | 0xF0;
        *dest++ = ((ch>>12) & 0x3F) | 0x80;
        *dest++ = ((ch>>6) & 0x3F) | 0x80;
        *dest++ = (ch & 0x3F) | 0x80;
    }
    
    *destp = dest;
}

static int readu8_cb(lua_State* L)
{
	const char* s = luaL_checkstring(L, 1);
	int offset = lua_tointeger(L, 2);
	wint_t c;
	
	if (offset > 0)
		offset--;
	s = s + offset;
	c = readu8(&s);
	
	lua_pushnumber(L, c);
	return 1;
}

static int writeu8_cb(lua_State* L)
{
	wint_t c = luaL_checkinteger(L, 1);
	static char buffer[8];
	char* s = buffer;
	
	writeu8(&s, c);
	*s = '\0';
	lua_pushstring(L, buffer);
	return 1;
}

static iconv_t transcoder = NULL;

static int setencodings_cb(lua_State* L)
{
	const char* from_encoding = luaL_checkstring(L, 1);
	const char* to_encoding = luaL_checkstring(L, 2);
	
	if (transcoder)
	{
		iconv_close(transcoder);
		transcoder = NULL;
	}
	
	transcoder = iconv_open(to_encoding, from_encoding);
	return 0;
}

static int transcode_cb(lua_State* L)
{
	size_t inputbuffersize;
	const char* inputbuffer = luaL_checklstring(L, 1, &inputbuffersize);

	size_t outputbuffersize = inputbuffersize*2 + 32;
	char outputbuffer[outputbuffersize]; /* should fit everything */
	
	char* in = (char*) inputbuffer;
	size_t inleft = inputbuffersize;
	char* out = outputbuffer;
	size_t outleft = outputbuffersize;
	
	while (inleft > 0)
	{
		size_t e = iconv(transcoder, &in, &inleft, &out, &outleft);
		if (e == -1)
		{
			assert(errno != E2BIG);
			if ((errno == EILSEQ) || (errno == EINVAL))
			{
				*out++ = '?';
				outleft--;
				in++;
			}
		}
	}
	
	lua_pushlstring(L, outputbuffer, out - outputbuffer);
	return 1;
}

void utils_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "readu8",                    readu8_cb },
		{ "writeu8",                   writeu8_cb },
		{ "setencodings",              setencodings_cb },
		{ "transcode",                 transcode_cb },
		{ NULL,                        NULL }
	};
	
	luaL_register(L, "wg", funcs);
}
