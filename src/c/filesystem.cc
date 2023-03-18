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
#include <string>
#include <filesystem>

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

static int remove_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);
    if (remove(filename) != 0)
        return pusherrno(L);

    lua_pushboolean(L, true);
    return 1;
}

static int rename_cb(lua_State* L)
{
    const char* oldfilename = luaL_checklstring(L, 1, NULL);
    const char* newfilename = luaL_checklstring(L, 2, NULL);
    if (rename(oldfilename, newfilename) != 0)
        return pusherrno(L);

    lua_pushboolean(L, true);
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

static int getenv_cb(lua_State* L)
{
    const char* varname = luaL_checklstring(L, 1, NULL);
    const char* result = getenv(varname);

    if (result)
        lua_pushstring(L, result);
    else
        lua_pushnil(L);
    return 1;
}

static int printerr_cb(lua_State* L)
{
    int count = lua_gettop(L);
    for (int i = 1; i <= count; i++)
    {
        const char* message = luaL_checklstring(L, i, nullptr);
        fprintf(stderr, "%s", message);
    }
    return 0;
}

static int printout_cb(lua_State* L)
{
    int count = lua_gettop(L);
    for (int i = 1; i <= count; i++)
    {
        const char* message = luaL_checklstring(L, i, nullptr);
        fprintf(stdout, "%s", message);
    }
    return 0;
}

static int mkdtemp_cb(lua_State* L)
{
    std::string path = std::filesystem::temp_directory_path();
    path += "/XXXXXX";
    if (mkdtemp(&path[0]))
    {
        lua_pushstring(L, path.c_str());
        return 1;
    }
    else
        return pusherrno(L);
}

static int readfile_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, nullptr);

    FILE* fp = fopen(filename, "rb");
    if (!fp)
        goto error;

    luaL_Buffer buffer;
    luaL_buffinit(L, &buffer);

    for (;;)
    {
        char b[LUA_BUFFERSIZE];
        size_t i = fread(b, 1, LUA_BUFFERSIZE, fp);
        if (i == 0)
            break;
        if (i < 0)
            goto error;

        luaL_addlstring(&buffer, b, i, -1);
    }

    fclose(fp);
    luaL_pushresult(&buffer);
    return 1;

error:
    pusherrno(L);
    if (fp)
        fclose(fp);
    return 3;
}

static int writefile_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, nullptr);
    size_t len;
    const char* data = luaL_checklstring(L, 2, &len);

    FILE* fp = fopen(filename, "wb");
    if (!fp)
        goto error;

    while (len != 0)
    {
        size_t i = fwrite(data, 1, len, fp);
        if (i < 0)
            goto error;

        len -= i;
        data += i;
    }
    fclose(fp);
    return 0;

error:
    pusherrno(L);
    if (fp)
        fclose(fp);
    return 3;
}

void filesystem_init(void)
{
    const static luaL_Reg funcs[] = {
        {"access",    access_cb   },
        {"chdir",     chdir_cb    },
        {"getcwd",    getcwd_cb   },
        {"getenv",    getenv_cb   },
        {"mkdir",     mkdir_cb    },
        {"mkdtemp",   mkdtemp_cb  },
        {"printerr",  printerr_cb },
        {"printout",  printout_cb },
        {"readdir",   readdir_cb  },
        {"readfile",  readfile_cb },
        {"remove",    remove_cb   },
        {"rename",    rename_cb   },
        {"stat",      stat_cb     },
        {"writefile", writefile_cb},
        {NULL,        NULL        }
    };

    const static luaL_Constant consts[] = {
        {"ENOENT", ENOENT},
        {"EEXIST", EEXIST},
        {"EACCES", EACCES},
        {"EISDIR", EISDIR},
    };

    lua_getglobal(L, "wg");
    luaL_register(L, NULL, funcs);
    luaL_setconstants(L, consts, sizeof(consts) / sizeof(*consts));
}
