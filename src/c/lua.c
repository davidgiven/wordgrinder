/* © 2007 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
 */

#include "globals.h"

lua_State* L;

static int report(lua_State* L, int status)
{
	if (status && !lua_isnil(L, -1))
	{
		const char* msg = lua_tostring(L, -1);
		if (!msg)
			msg = "(error object is not a string)";
		screen_deinit();
		fprintf(stderr, "Lua error: %s\n", msg);
		lua_pop(L, 1);
		
		exit(1);
	}
	
	return status;
}

static int traceback (lua_State *L)
{
	lua_getfield(L, LUA_GLOBALSINDEX, "debug");
	if (!lua_istable(L, -1))
	{
		lua_pop(L, 1);
		return 1;
	}
	
	lua_getfield(L, -1, "traceback");
	if (!lua_isfunction(L, -1))
	{
		lua_pop(L, 2);
		return 1;
	}
	
	lua_pushvalue(L, 1);  /* pass error message */
	lua_pushinteger(L, 2);  /* skip this function and traceback */
	lua_call(L, 2, 1);  /* call debug.traceback */
	return 1;
}

static int docall(lua_State* L, int narg, int clear)
{
	int base = lua_gettop(L) - narg;
	lua_pushcfunction(L, traceback);
	lua_insert(L, base);
	
	int status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
	
	lua_remove(L, base);
	
	if (status != 0)
		lua_gc(L, LUA_GCCOLLECT, 0);
	return status;
}
	
void script_deinit(void)
{
	lua_close(L);
}

void script_init(void)
{
	L = lua_open();
	luaL_openlibs(L);
	
	atexit(script_deinit);
}

void script_load(const char* filename, const char* argv[])
{
	int status = luaL_loadfile(L, filename);
	
	/* Set some global variables. */
	
	lua_pushstring(L, LUA_SRC_DIR);
	lua_setglobal(L, "LUA_SRC_DIR");
	
	lua_pushstring(L, VERSION);
	lua_setglobal(L, "VERSION");
	
	lua_pushnumber(L, FILEFORMAT);
	lua_setglobal(L, "FILEFORMAT");
	
	lua_pushboolean(L,
#ifndef NDEBUG
			1
#else
			0
#endif
		);
	lua_setglobal(L, "DEBUG");
	
	/* Push the arguments onto the stack. */
	
	int argc = 0;
	for (;;)
	{
		const char* s = *argv++;
		if (!s)
			break;
		lua_pushstring(L, s);
		argc++;
	}
	
	/* Call the main program. */
	
	status = status || docall(L, argc, 1);
	(void) report(L, status);
}
