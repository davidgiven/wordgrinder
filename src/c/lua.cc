/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <fstream>
#include <string>
#include "Luau/Compiler.h"

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

static int traceback(lua_State* L)
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

    lua_pushvalue(L, 1);   /* pass error message */
    lua_pushinteger(L, 2); /* skip this function and traceback */
    lua_call(L, 2, 1);     /* call debug.traceback */
    return 1;
}

static int docall(lua_State* L, int narg, int clear)
{
    int base = lua_gettop(L) - narg;
    lua_pushcclosurek(L, traceback, "traceback", 0, nullptr);
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

static int loadstring_cb(lua_State* L)
{
    size_t len;
    const char* s = luaL_checklstring(L, 1, &len);
    const char* name = luaL_optlstring(L, 2, nullptr, nullptr);

    lua_setsafeenv(L, LUA_ENVIRONINDEX, false);
    if (luaL_loadstring(L, s, name) == 0)
        return 1;

    lua_pushnil(L);
    lua_insert(L, -2); /* put before error message */
    return 2;
}

static int exit_cb(lua_State* L)
{
    int e = forceinteger(L, 1);
    exit(e);
}

void script_init(void)
{
    L = luaL_newstate();
    luaL_openlibs(L);

    atexit(script_deinit);

    /* Set some global variables. */

    lua_pushstring(L, STRINGIFY(VERSION));
    lua_setglobal(L, "VERSION");

    lua_pushnumber(L, FILEFORMAT);
    lua_setglobal(L, "FILEFORMAT");

    lua_pushstring(L, STRINGIFY(ARCH));
    lua_setglobal(L, "ARCH");

    lua_pushstring(L, STRINGIFY(FRONTEND));
    lua_setglobal(L, "FRONTEND");

    lua_pushstring(L, STRINGIFY(DEFAULT_DICTIONARY_PATH));
    lua_setglobal(L, "DEFAULT_DICTIONARY_PATH");

    lua_pushcclosurek(L, loadstring_cb, "loadstring", 0, nullptr);
    lua_setglobal(L, "loadstring");

    lua_newtable(L);
    lua_setglobal(L, "wg");

    luaL_register(L,
        "wg",
        (const luaL_Reg[]){
            {"exit", exit_cb},
            {}
    });

    lua_pushboolean(L,
#ifndef NDEBUG
        1
#else
        0
#endif
    );
    lua_setglobal(L, "DEBUG");
}

void script_load_from_table(const FileDescriptor* table)
{
    while (table->name)
    {
        int status = luaL_dostring(L, table->data.c_str(), table->name);
        if (status)
        {
            (void)report(L, status);
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
    (void)report(L, status);
}

#if 0
/* Lua fallback functions, used for compatibility with 5.1 */

void luaL_setfuncs(lua_State* L, const luaL_Reg* l, int nup)
{
    luaL_checkstack(L, nup + 1, "too many upvalues");
    for (; l->name != NULL; l++)
    { /* fill the table with given functions */
        int i;
        lua_pushstring(L, l->name);

        for (i = 0; i < nup; i++) /* copy upvalues to the top */
            lua_pushvalue(L, -(nup + 1));

        lua_pushcfunction(L, l->func, nup); /* closure with those upvalues */
        lua_settable(L, -(nup + 3));
    }
    lua_pop(L, nup); /* remove upvalues */
}
#endif

extern void luaL_setconstants(lua_State* L, const luaL_Constant* array, int len)
{
    while (len--)
    {
        lua_pushnumber(L, array->value);
        lua_setfield(L, -2, array->name);
        array++;
    }
}
