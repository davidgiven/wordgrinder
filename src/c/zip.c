/* © 2013 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <zlib.h>
#include "unzip.h"

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
	int i = deflateInit(&zs, 1);
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

static int readfromzip_cb(lua_State* L)
{
	const char* zipname = luaL_checkstring(L, 1);
	const char* subname = luaL_checkstring(L, 2);
	int result = 0;

	unzFile zf = unzOpen(zipname);
	if (zf)
	{
		int i = unzLocateFile(zf, subname, 0);
		if (i == UNZ_OK)
		{
			unz_file_info fi;
			unzGetCurrentFileInfo(zf, &fi,
				NULL, 0, NULL, 0, NULL, 0);

			char* buffer = malloc(fi.uncompressed_size);
			if (buffer)
			{
				unzOpenCurrentFile(zf);
				i = unzReadCurrentFile(zf, buffer, fi.uncompressed_size);
				if (i == fi.uncompressed_size)
				{
					lua_pushlstring(L, buffer, fi.uncompressed_size);
					result = 1;
				}
				free(buffer);
			}
		}

		unzClose(zf);
	}

	return result;
}

void zip_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "compress",                  compress_cb },
		{ "decompress",                decompress_cb },
		{ "readfromzip",               readfromzip_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);
}
