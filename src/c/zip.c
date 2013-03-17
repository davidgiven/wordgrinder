/* © 2013 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <zlib.h>

static int decompress_cb(lua_State* L)
{
	size_t srcsize;
	const char* srcbuffer = luaL_checklstring(L, 1, &srcsize);

	int outputchunks = 0;
	uint8_t outputbuffer[64*1024];

	z_stream zs = {0};
	int i = inflateInit(&zs);
	if (i != Z_OK)
		return 0;

	zs.avail_in = srcsize;
	zs.next_in = (uint8_t*) srcbuffer;

	do
	{
		zs.avail_out = sizeof(outputbuffer);
		zs.next_out = outputbuffer;

		i = inflate(&zs, Z_NO_FLUSH);
		switch (i)
		{
			case Z_NEED_DICT:
			case Z_DATA_ERROR:
			case Z_MEM_ERROR:
				(void)inflateEnd(&zs);
				return 0;
		}

		int have = sizeof(outputbuffer) - zs.avail_out;
		lua_pushlstring(L, (char*) outputbuffer, have);
		outputchunks++;
	}
	while (i != Z_STREAM_END);

	(void)inflateEnd(&zs);

	lua_concat(L, outputchunks);
	return 1;
}

static int compress_cb(lua_State* L)
{
	size_t srcsize;
	const char* srcbuffer = luaL_checklstring(L, 1, &srcsize);

	int outputchunks = 0;
	uint8_t outputbuffer[64*1024];

	z_stream zs = {0};
	int i = deflateInit(&zs, Z_DEFAULT_COMPRESSION);
	if (i != Z_OK)
		return 0;

	zs.avail_in = srcsize;
	zs.next_in = (uint8_t*) srcbuffer;

	do
	{
		zs.avail_out = sizeof(outputbuffer);
		zs.next_out = outputbuffer;

		i = deflate(&zs, Z_FINISH);

		int have = sizeof(outputbuffer) - zs.avail_out;
		lua_pushlstring(L, (char*) outputbuffer, have);
		outputchunks++;
	}
	while (i != Z_STREAM_END);

	(void)deflateEnd(&zs);

	lua_concat(L, outputchunks);
	return 1;
}

void zip_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "compress",                  compress_cb },
		{ "decompress",                decompress_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);
}
