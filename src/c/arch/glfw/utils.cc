#include "globals.h"
#include "gui.h"

int get_ivar(const char* name)
{
	lua_checkstack(L, 10);
    lua_getglobal(L, "GlobalSettings");
    lua_getfield(L, -1, "gui");
    lua_getfield(L, -1, name);
    return luaL_checkinteger(L, -1);
}

const char* get_svar(const char* name)
{
	lua_checkstack(L, 10);
    lua_getglobal(L, "GlobalSettings");
    lua_getfield(L, -1, "gui");
    lua_getfield(L, -1, name);
    return lua_tostring(L, -1);
}
