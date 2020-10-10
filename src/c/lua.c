/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#if LUA_VERSION_NUM == 501
#include "lua-bitop.h"
#endif

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
	lua_pushglobaltable(L);
	lua_getfield(L, -1, "debug");
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
	L = luaL_newstate();
	luaL_openlibs(L);

#if LUA_VERSION_NUM == 501
	luaopen_bit(L);
#endif

	atexit(script_deinit);

	/* Set some global variables. */

	lua_pushstring(L, VERSION);
	lua_setglobal(L, "VERSION");

	lua_pushnumber(L, FILEFORMAT);
	lua_setglobal(L, "FILEFORMAT");

	lua_pushstring(L, ARCH);
	lua_setglobal(L, "ARCH");

	lua_newtable(L);
	lua_setglobal(L, "wg");

	lua_pushboolean(L,
#ifndef NDEBUG
			1
#else
			0
#endif
		);
	lua_setglobal(L, "DEBUG");
}

void script_load(const char* filename)
{
	int status = luaL_loadfile(L, filename);
	status = status || docall(L, 0, 1);
	(void) report(L, status);
}

void script_load_from_table(const FileDescriptor* table)
{
	while (table->data)
	{
		int status = luaL_loadbuffer(L, table->data, table->size,
				table->name);
		status = status || docall(L, 0, 1);
		if (status)
		{
			(void) report(L, status);
			break;
		}

		table++;
	}
}

void script_run(const char* argv[])
{
	lua_getglobal(L, "Main");

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

	int status = docall(L, argc, 1);
	(void) report(L, status);
}

/* Lua fallback functions, used for compatibility with 5.1 */

#if LUA_VERSION_NUM==501
void luaL_setfuncs(lua_State *L, const luaL_Reg *l, int nup)
{
	luaL_checkstack(L, nup+1, "too many upvalues");
	for (; l->name != NULL; l++)
	{  /* fill the table with given functions */
		int i;
		lua_pushstring(L, l->name);

		for (i = 0; i < nup; i++)  /* copy upvalues to the top */
			lua_pushvalue(L, -(nup+1));

		lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
		lua_settable(L, -(nup + 3));
	}
	lua_pop(L, nup);  /* remove upvalues */
}
#endif
