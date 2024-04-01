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
#include <fmt/format.h>

#ifdef WIN32
#include <windows.h>
#include <rpc.h>
#endif

static int pusherrno(lua_State* L)
{
    lua_pushnil(L);
    lua_pushstring(L, strerror(errno));
    lua_pushinteger(L, errno);
    return 3;
}

#ifdef WIN32
static std::string createUuid()
{
    UUID uuid;
    UuidCreate(&uuid);

    unsigned char* s;
    UuidToStringA(&uuid, &s);
    std::string ss((char*)s);
    RpcStringFreeA(&s);

    return ss;
}
#endif

static int chdir_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);

    std::error_code ec;
    std::filesystem::current_path(filename, ec);
    if (ec)
        return pusherrno(L);

    lua_pushboolean(L, true);
    return 1;
}

static int mkdir_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);

    std::error_code ec;
    std::filesystem::create_directory(filename, ec);
    if (ec)
        return pusherrno(L);

    lua_pushboolean(L, true);
    return 1;
}

static int mkdirs_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);

    std::error_code ec;
    std::filesystem::create_directories(filename, ec);
    if (ec)
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

    int index = 1;
    auto addItem = [&](std::string filename)
    {
        lua_pushinteger(L, index);
        lua_pushstring(L, filename.c_str());
        lua_settable(L, -3);
        index++;
    };

    addItem(".");
    addItem("..");
    for (auto const& de : std::filesystem::directory_iterator(filename))
        addItem(de.path().filename().string());

    return 1;
}

static int stat_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);

    std::error_code ec;
    auto status = std::filesystem::status(filename);
    if (ec)
        return pusherrno(L);

    switch (status.type())
    {
        case std::filesystem::file_type::not_found:
            lua_pushnil(L);
            lua_pushstring(L, strerror(errno));
            lua_pushinteger(L, errno);
            return 3;

        case std::filesystem::file_type::directory:
            lua_newtable(L);

            lua_pushstring(L, "size");
            lua_pushinteger(L, 0);
            lua_settable(L, -3);

            lua_pushstring(L, "mode");
            lua_pushstring(L, "directory");
            lua_settable(L, -3);
            return 1;

        default:
            lua_newtable(L);

            lua_pushstring(L, "size");
            lua_pushinteger(L, std::filesystem::file_size(filename));
            lua_settable(L, -3);

            lua_pushstring(L, "mode");
            lua_pushstring(L, "file");
            lua_settable(L, -3);
            return 1;
    }
}

static int access_cb(lua_State* L)
{
    const char* filename = luaL_checklstring(L, 1, NULL);
    int mode = forceinteger(L, 2);

#if defined WIN32
    wchar_t widepath[strlen(filename) + 1];
    MultiByteToWideChar(
        CP_UTF8, 0, filename, -1, widepath, strlen(filename) + 1);

    if (_waccess(widepath, mode) != 0)
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
    std::string path = std::filesystem::temp_directory_path().string();
    fmt::print(stderr, "temp directory={}\n", path);

#ifdef WIN32
    path = path + "/" + createUuid();
    if (std::filesystem::create_directory(path))
    {
        lua_pushstring(L, path.c_str());
        return 1;
    }
    else
        return pusherrno(L);
#else
    path += "/XXXXXX";
    if (mkdtemp(&path[0]))
    {
        lua_pushstring(L, path.c_str());
        return 1;
    }
    else
        return pusherrno(L);
#endif
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
        {"mkdirs",    mkdirs_cb    },
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

// vim: sw=4 ts=4 et
