/* © 2021 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"

/* Lua 5.4 actually has built-in bit operators. Unfortunately we can't use them in our code
 * because the Lua 5.1-5.3 parsers error out if they see them! So we provide our own bit
 * library instead. If we ever manage to switch to requiring Lua 5.4, we can get rid of
 * this. */

static int band(lua_State* L)
{
	lua_Integer a = luaL_checkinteger(L, 1);
	lua_Integer b = luaL_checkinteger(L, 2);
	lua_pushinteger(L, a & b);
	return 1;
}

static int bor(lua_State* L)
{
	lua_Integer a = luaL_checkinteger(L, 1);
	lua_Integer b = luaL_checkinteger(L, 2);
	lua_pushinteger(L, a | b);
	return 1;
}

static int bxor(lua_State* L)
{
	lua_Integer a = luaL_checkinteger(L, 1);
	lua_Integer b = luaL_checkinteger(L, 2);
	lua_pushinteger(L, a ^ b);
	return 1;
}

static int btest(lua_State* L)
{
	lua_Integer a = luaL_checkinteger(L, 1);
	lua_Integer b = luaL_checkinteger(L, 2);
	lua_pushboolean(L, a & b);
	return 1;
}

void bit32_init(lua_State* L)
{
	const static luaL_Reg funcs[] =
	{
		{ "band",   band },
		{ "bor",    bor },
		{ "bxor",   bxor },
		{ "btest",  btest },
		{ NULL,     NULL }
	};

    lua_newtable(L);
    luaL_setfuncs(L, funcs, 0);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "bit32");
}

