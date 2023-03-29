#pragma once

#include "lua.h"
#include "lualib.h"

#define LUA_VERSION_NUM 510
#define lua_pushglobaltable(L) lua_pushvalue(L, LUA_GLOBALSINDEX)

#undef lua_pushcfunction
#define lua_pushcfunction(L, fn) lua_pushcclosurek(L, fn, NULL, 0, NULL)

#undef lua_pushcclosure
#define lua_pushcclosure(L, fn, nup) lua_pushcclosurek(L, fn, NULL, nup, NULL)

#define lua_rawlen lua_objlen

extern int luaL_loadstring(lua_State* L, const char* str);
extern int luaL_dostring(lua_State* L, const char* str);
