#include "lauxlib.h"
#include "Luau/Compiler.h"

static Luau::CompileOptions copts()
{
    Luau::CompileOptions result = {};
    result.optimizationLevel = 2;
    result.debugLevel = 1;
    result.coverageLevel = 0;
    return result;
}

static Luau::ParseOptions popts()
{
    Luau::ParseOptions result = {};
    result.allowDeclarationSyntax = true;
    return result;
}

int luaL_loadstring(lua_State* L, const char* str)
{
    lua_setsafeenv(L, LUA_ENVIRONINDEX, false);

    std::string bytecode = Luau::compile(std::string(str), copts(), popts());
    if (luau_load(L, "(anonymous)", bytecode.data(), bytecode.size(), 0) == 0)
        return 0;

    lua_pushnil(L);
    lua_insert(L, -2); /* put before error message */
    return LUA_ERRRUN;
}

int luaL_dostring(lua_State* L, const char* str)
{
    int status = luaL_loadstring(L, str);
    if (status == 0)
        return lua_pcall(L, 0, LUA_MULTRET, 0);
    return status;
}
