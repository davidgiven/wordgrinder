#include "gui.h"

int getIvar(const char* name)
{
    lua_getglobal(L, "GlobalSettings");
    lua_getfield(L, -1, "gui");
	lua_getfield(L, -1, name);
    return luaL_checkinteger(L, -1);
}

std::string getSvar(const char* name)
{
    lua_getglobal(L, "GlobalSettings");
    lua_getfield(L, -1, "gui");
	lua_getfield(L, -1, name);
	return lua_tostring(L, -1);
}


