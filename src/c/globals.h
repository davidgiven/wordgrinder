/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#ifndef GLOBALS_H
#define GLOBALS_H

#if !defined WIN32
#if !defined _XOPEN_SOURCE
#define _XOPEN_SOURCE
#endif

#if !defined _XOPEN_SOURCE_EXTENDED
#define _XOPEN_SOURCE_EXTENDED
#endif

#if !defined _GNU_SOURCE
#define _GNU_SOURCE
#endif
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <errno.h>
#include <wctype.h>
#include <string>

/* --- Platform detection ------------------------------------------------ */

#if defined(__APPLE__) && defined(__MACH__)
#define OSX
#endif

/* --- Emulation issues -------------------------------------------------- */

typedef int uni_t;

#if defined EMULATED_WCWIDTH
extern int emu_wcwidth(uni_t c);
#else
#include <wchar.h>
#define emu_wcwidth(c) wcwidth(c)
#endif

extern int main(int argc, char* argv[]);

/* --- Lua --------------------------------------------------------------- */

#include "lua.h"
#include "lauxlib.h"

#if defined WINSHIM
#include "winshim.h"
#endif

extern lua_State* L;

typedef struct
{
    const char* name;
    int value;
} luaL_Constant;

extern void luaL_setconstants(
    lua_State* L, const luaL_Constant* array, int len);

typedef struct
{
    std::string data;
    const char* name;
} FileDescriptor;

extern void script_init(void);
extern void script_load(const char* filename);
extern void script_load_from_table(const FileDescriptor* table);
extern void script_run(const char* argv[]);

#if !defined LUA_VERSION_NUM || LUA_VERSION_NUM == 501
extern void luaL_setfuncs(lua_State* L, const luaL_Reg* l, int nup);
#define lua_pushglobaltable(L) lua_pushvalue(L, LUA_GLOBALSINDEX)
#endif

extern void bit32_init(lua_State* L);

#define forceinteger(L, offset) (int)lua_tonumber(L, offset)
#define forcedouble(L, offset) (double)lua_tonumber(L, offset)

/* --- Screen management ------------------------------------------------- */

extern void screen_init(const char* argv[]);
extern void screen_deinit(void);
extern void dpy_writeunichar(int x, int y, uni_t c);
extern void decode_mouse_event(uni_t key, int* x, int* y, bool* p);
extern uni_t encode_mouse_event(int x, int y, bool p);

/* --- Word management --------------------------------------------------- */

extern void word_init(void);

/* --- Zipfile management ------------------------------------------------ */

extern void zip_init(void);

/* --- CommonMark -------------------------------------------------------- */

extern void cmark_init(void);

/* --- General utilities ------------------------------------------------- */

extern int getu8bytes(char c);
extern uni_t readu8(const char** ptr);
extern void writeu8(char** ptr, uni_t value);

extern void utils_init(void);
extern void filesystem_init(void);
extern void clipboard_init(void);

#define STRINGIFY1(x) #x
#define STRINGIFY(x) STRINGIFY1(x)

/* --- Display layer ----------------------------------------------------- */

enum
{
    /* These four are also style control codes. */
    DPY_ITALIC = (1 << 0),
    DPY_UNDERLINE = (1 << 1),
    DPY_REVERSE = (1 << 2),
    DPY_BOLD = (1 << 3),

    /* These cannot appear in text. */
    DPY_BRIGHT = (1 << 4),
    DPY_DIM = (1 << 5),
};

enum
{
    /* uni_t special values for representing mouse events. */

    KEYM_MOUSE = 0x7f << 24,
    KEY_MOUSEDOWN = 1 << 24,
    KEY_MOUSEUP = 2 << 24,
    KEY_SCROLLUP = 3 << 24,
    KEY_SCROLLDOWN = 4 << 24,
    KEY_MENU = 5 << 24,
    KEY_RESIZE = 6 << 24,
    KEY_TIMEOUT = 7 << 24,
    KEY_QUIT = 8 << 24,
};

typedef struct
{
    float r, g, b;
} colour_t;

extern void dpy_init(const char* argv[]);
extern void dpy_start(void);
extern void dpy_shutdown(void);

extern void dpy_setattr(int andmask, int ormask);
extern void dpy_setcolour(const colour_t* fg, const colour_t* bg);
extern void dpy_writechar(int x, int y, uni_t c);
extern void dpy_setcursor(int x, int y, bool shown);
extern void dpy_clearscreen(void);
extern void dpy_sync(void);
extern void dpy_cleararea(int x1, int y1, int x2, int y2);
extern void dpy_getscreensize(int* x, int* y);
extern uni_t dpy_getchar(double timeout);
extern const char* dpy_getkeyname(uni_t key);

extern bool enable_unicode;

#endif
