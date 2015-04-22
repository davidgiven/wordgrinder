/* © 2013 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <zlib.h>
#include "unzip.h"
#include "zip.h"

static const int STACKSIZE = 64;

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

	luaL_checkstack(L, STACKSIZE, "out of memory");
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

		if (outputchunks == (STACKSIZE-1))
		{
			/* Stack full! Concatenate what we've got, to empty the stack, and
			 * keep going. This will only happen on very large input files. */
			lua_concat(L, outputchunks);
			outputchunks = 1;
		}
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

	luaL_checkstack(L, STACKSIZE, "out of memory");
	do
	{
		zs.avail_out = sizeof(outputbuffer);
		zs.next_out = outputbuffer;

		i = deflate(&zs, Z_FINISH);

		int have = sizeof(outputbuffer) - zs.avail_out;
		lua_pushlstring(L, (char*) outputbuffer, have);
		outputchunks++;

		if (outputchunks == (STACKSIZE-1))
		{
			/* Stack full! Concatenate what we've got, to empty the stack, and
			 * keep going. This will only happen on very large input files. */
			lua_concat(L, outputchunks);
			outputchunks = 1;
		}
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

static int writezip_cb(lua_State* L)
{
	const char* zipname = luaL_checkstring(L, 1);
	luaL_checktype(L, 2, LUA_TTABLE);
	int result = 0;

	zipFile zf = zipOpen(zipname, APPEND_STATUS_CREATE);
	if (zf)
	{
		result = 1;

		lua_pushnil(L);
		while (lua_next(L, 2) != 0)
		{
			const char* key = lua_tostring(L, -2);
			size_t valuelen;
			const char* value = lua_tolstring(L, -1, &valuelen);

			int i = zipOpenNewFileInZip(zf, key, NULL,
					NULL, 0,
					NULL, 0,
					NULL,
					Z_DEFLATED,
					Z_DEFAULT_COMPRESSION);
			if (i != ZIP_OK)
			{
				result = 0;
				break;
			}

			i = zipWriteInFileInZip(zf, value, valuelen);
			if (i != ZIP_OK)
			{
				result = 0;
				break;
			}

			i = zipCloseFileInZip(zf);
			if (i != ZIP_OK)
			{
				result = 0;
				break;
			}

			lua_pop(L, 1); /* leave key on stack */
		}

		zipClose(zf, NULL);
	}

	if (!result)
		return 0;
	lua_pushboolean(L, true);
	return 1;
}

void zip_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "compress",                  compress_cb },
		{ "decompress",                decompress_cb },
		{ "readfromzip",               readfromzip_cb },
		{ "writezip",                  writezip_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);
}
