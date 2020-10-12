/* © 2020 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <sys/time.h>
#include <sys/stat.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>

static int pusherrno(lua_State* L)
{
	lua_pushnil(L);
	lua_pushstring(L, strerror(errno));
	lua_pushinteger(L, errno);
	return 3;
}

static int chdir_cb(lua_State* L)
{
	const char* filename = luaL_checklstring(L, 1, NULL);

	#if defined WIN32
		if (_wchdir(utf8_to_wide(L, filename)) != 0)
	#else
		if (chdir(filename) != 0)
	#endif
			return pusherrno(L);

	lua_pushboolean(L, true);
	return 1;
}

static int mkdir_cb(lua_State* L)
{
	const char* filename = luaL_checklstring(L, 1, NULL);

	#if defined WIN32
		if (_wmkdir(utf8_to_wide(L, filename)) != 0)
	#else
		if (mkdir(filename, 0755) != 0)
	#endif
			return pusherrno(L);

	lua_pushboolean(L, true);
	return 1;
}

static int getcwd_cb(lua_State* L)
{
	char* buf = getcwd(NULL, 0);
	if (!buf)
		return pusherrno(L);

	lua_pushstring(L, buf);
	free(buf);
	return 1;
}

static int readdir_cb(lua_State* L)
{
	const char* filename = luaL_checklstring(L, 1, NULL);

	lua_newtable(L);

	#if defined WIN32
		wchar_t* wide = utf8_to_wide(L, filename);
		_WDIR* dp = _wopendir(wide);
		lua_pop(L, 1);
		if (!dp)
			return pusherrno(L);

		int index = 1;
		for (;;)
		{
			struct _wdirent* de = _wreaddir(dp);
			if (!de)
				break;

			lua_pushinteger(L, index);
			lua_pushwstring(L, de->d_name);
			lua_settable(L, -3);
			index++;
		}

		_wclosedir(dp);
	#else
		DIR* dp = opendir(filename);
		if (!dp)
			return pusherrno(L);

		int index = 1;
		for (;;)
		{
			struct dirent* de = readdir(dp);
			if (!de)
				break;

			lua_pushinteger(L, index);
			lua_pushstring(L, de->d_name);
			lua_settable(L, -3);
			index++;
		}

		closedir(dp);
	#endif
	return 1;
}

static int stat_cb(lua_State* L)
{
	const char* filename = luaL_checklstring(L, 1, NULL);

	#if defined WIN32
		struct _stat st;
		if (_wstat(utf8_to_wide(L, filename), &st) != 0)
			return pusherrno(L);
	#else
		struct stat st;
		if (stat(filename, &st) != 0)
			return pusherrno(L);
	#endif

	lua_newtable(L);
	
	lua_pushstring(L, "size");
	lua_pushinteger(L, st.st_size);
	lua_settable(L, -3);

	lua_pushstring(L, "mode");
	lua_pushstring(L, S_ISDIR(st.st_mode) ? "directory" : "file");
	lua_settable(L, -3);

	return 1;
}

static int access_cb(lua_State* L)
{
	const char* filename = luaL_checklstring(L, 1, NULL);
	int mode = forceinteger(L, 2);

	#if defined WIN32
		if (_waccess(utf8_to_wide(L, filename), mode) != 0)
			return pusherrno(L);
	#else
		if (access(filename, mode) != 0)
			return pusherrno(L);
	#endif

	lua_pushboolean(L, true);
	return 1;
}

void filesystem_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "chdir",                     chdir_cb },
		{ "mkdir",                     mkdir_cb },
		{ "getcwd",                    getcwd_cb },
		{ "readdir",                   readdir_cb },
		{ "stat",                      stat_cb },
		{ "access",                    access_cb },
		{ NULL,                        NULL }
	};

	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);

	lua_pushinteger(L, ENOENT);
	lua_setfield(L, -2, "ENOENT");

	lua_pushinteger(L, EEXIST);
	lua_setfield(L, -2, "EEXIST");

	lua_pushinteger(L, EACCES);
	lua_setfield(L, -2, "EACCES");

	lua_pushinteger(L, EISDIR);
	lua_setfield(L, -2, "EISDIR");

	lua_pushinteger(L, W_OK);
	lua_setfield(L, -2, "W_OK");
}
