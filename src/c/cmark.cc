/* © 2022 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <vector>
#include <cmark.h>

static int cmark_parse_cb(lua_State* L)
{
    size_t len;
    const char* data = lua_tolstring(L, 1, &len);

    cmark_node* document = cmark_parse_document(data, len, CMARK_OPT_DEFAULT);
    lua_pushlightuserdata(L, document);
    luaL_getmetatable(L, "cmark.document");
    lua_setmetatable(L, -2);
    return 1;
}

static int cmark_document_gc_cb(lua_State* L)
{
    cmark_node* document = (cmark_node*)lua_touserdata(L, 1);
    cmark_node_free(document);
    return 0;
}

static int cmark_iterate_cb(lua_State* L)
{
    cmark_node* document = (cmark_node*)lua_touserdata(L, 1);
    cmark_iter* iter = cmark_iter_new(document);
    lua_pushlightuserdata(L, iter);
    luaL_getmetatable(L, "cmark.iterator");
    lua_setmetatable(L, -2);
    return 1;
}

static int cmark_next_cb(lua_State* L)
{
    cmark_iter* iter = (cmark_iter*)lua_touserdata(L, 1);

    cmark_event_type event = cmark_iter_next(iter);
    cmark_node* node = cmark_iter_get_node(iter);

    lua_pushinteger(L, event);
    lua_pushinteger(L, cmark_node_get_type(node));
    lua_pushlightuserdata(L, node);
    luaL_getmetatable(L, "cmark.node");
    lua_setmetatable(L, -2);
    lua_pushstring(L, cmark_node_get_literal(node));
    return 4;
}

static int cmark_iterator_gc_cb(lua_State* L)
{
    cmark_iter* document = (cmark_iter*)lua_touserdata(L, 1);
    cmark_iter_free(document);
    return 0;
}

static int cmark_getheading_cb(lua_State* L)
{
    cmark_node* node = (cmark_node*)lua_touserdata(L, 1);
    int heading = cmark_node_get_heading_level(node);
    lua_pushinteger(L, heading);
    return 1;
}

static int cmark_getlist_cb(lua_State* L)
{
    cmark_node* node = (cmark_node*)lua_touserdata(L, 1);
    int list = cmark_node_get_list_type(node);
    lua_pushinteger(L, list);
    return 1;
}

void cmark_init()
{
    luaL_newmetatable(L, "cmark.document");
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, cmark_document_gc_cb);
    lua_settable(L, -3);

    luaL_newmetatable(L, "cmark.node");

    luaL_newmetatable(L, "cmark.iterator");
    lua_pushstring(L, "__gc");
    lua_pushcfunction(L, cmark_iterator_gc_cb);
    lua_settable(L, -3);

    const static luaL_Reg funcs[] = {
        {"CMarkParse",   cmark_parse_cb  },
        {"CMarkIterate", cmark_iterate_cb},
        {"CMarkNext",    cmark_next_cb   },
        {"CMarkGetHeading", cmark_getheading_cb },
        {"CMarkGetList", cmark_getlist_cb },
        {NULL,           NULL            }
    };

#define CONST(n) \
    {            \
        #n, n    \
    }

    const static luaL_Constant consts[] = {
        CONST(CMARK_EVENT_NONE),
        CONST(CMARK_EVENT_DONE),
        CONST(CMARK_EVENT_ENTER),
        CONST(CMARK_EVENT_EXIT),

        CONST(CMARK_NO_LIST),
        CONST(CMARK_BULLET_LIST),
        CONST(CMARK_ORDERED_LIST),

        CONST(CMARK_NODE_DOCUMENT),
        CONST(CMARK_NODE_BLOCK_QUOTE),
        CONST(CMARK_NODE_LIST),
        CONST(CMARK_NODE_ITEM),
        CONST(CMARK_NODE_CODE_BLOCK),
        CONST(CMARK_NODE_HTML_BLOCK),
        CONST(CMARK_NODE_CUSTOM_BLOCK),
        CONST(CMARK_NODE_PARAGRAPH),
        CONST(CMARK_NODE_HEADING),
        CONST(CMARK_NODE_THEMATIC_BREAK),
        CONST(CMARK_NODE_TEXT),
        CONST(CMARK_NODE_SOFTBREAK),
        CONST(CMARK_NODE_LINEBREAK),
        CONST(CMARK_NODE_CODE),
        CONST(CMARK_NODE_HTML_INLINE),
        CONST(CMARK_NODE_CUSTOM_INLINE),
        CONST(CMARK_NODE_EMPH),
        CONST(CMARK_NODE_STRONG),
        CONST(CMARK_NODE_LINK),
        CONST(CMARK_NODE_IMAGE),
    };

    lua_getglobal(L, "_G");
    luaL_setconstants(L, consts, sizeof(consts) / sizeof(*consts));
    luaL_register(L, nullptr, funcs);
}

// vim: ts=4 sw=4 et
