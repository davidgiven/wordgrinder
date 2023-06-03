/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <vector>
#include "clip.h"

static clip::format wordgrinderFormat;

static int clipboard_clear_cb(lua_State* L)
{
    clip::clear();
    return 0;
}

static void getdata(lua_State* L, clip::lock& l, clip::format format)
{
    if (l.is_convertible(format))
    {
        size_t len = l.get_data_length(format);

        std::vector<char> buf(len);
        l.get_data(format, &buf[0], len);
        if (buf.back() == 0)
            len--;
        lua_pushlstring(L, &buf[0], len);
    }
    else
        lua_pushnil(L);
}

static int clipboard_get_cb(lua_State* L)
{
    clip::lock l;

    getdata(L, l, clip::text_format());
    getdata(L, l, wordgrinderFormat);

    return 2;
}

static void setdata(lua_State* L, clip::lock& l, int index, clip::format format)
{
    size_t len;
    const char* ptr = lua_tolstring(L, index, &len);

    if (ptr)
        l.set_data(format, ptr, len);
}

static int clipboard_set_cb(lua_State* L)
{
    clip::lock l;

    l.clear();
    setdata(L, l, 1, clip::text_format());
    setdata(L, l, 2, wordgrinderFormat);

    return 0;
}

void clipboard_init()
{
    wordgrinderFormat = clip::register_format("com.cowlark.wordgrinder.wgtext");

    const static luaL_Reg funcs[] = {
        {"clipboard_clear", clipboard_clear_cb},
        {"clipboard_get",   clipboard_get_cb  },
        {"clipboard_set",   clipboard_set_cb  },
        {NULL,              NULL              }
    };

    luaL_register(L, "wg", funcs);
}

// vim: ts=4 sw=4 et
