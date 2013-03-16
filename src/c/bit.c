/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"

static int bitand_cb(lua_State* L)
{
	int a = luaL_checkint(L, 1);
	int b = luaL_checkint(L, 2);
	
	lua_pushnumber(L, a & b);
	return 1;
}
		
static int bitor_cb(lua_State* L)
{
	int a = luaL_checkint(L, 1);
	int b = luaL_checkint(L, 2);
	
	lua_pushnumber(L, a | b);
	return 1;
}

static int bitxor_cb(lua_State* L)
{
	int a = luaL_checkint(L, 1);
	int b = luaL_checkint(L, 2);
	
	lua_pushnumber(L, a ^ b);
	return 1;
}
		
static int bit_cb(lua_State* L)
{
	int a = luaL_checkint(L, 1);
	int b = luaL_checkint(L, 2);
	
	lua_pushboolean(L, a & b);
	return 1;
}
		
void bit_init(void)
{
	const static luaL_Reg funcs[] =
	{
		{ "bitand",                    bitand_cb },
		{ "bitor",                     bitor_cb },
		{ "bitxor",                    bitxor_cb },
		{ "bit",                       bit_cb },
		{ NULL,                        NULL }
	};
	
	lua_getglobal(L, "wg");
	luaL_setfuncs(L, funcs, 0);
}
