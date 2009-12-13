/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id$
 * $URL$
 */

#ifndef GLOBALS_H
#define GLOBALS_H

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <assert.h>
#include <errno.h>
#include <wctype.h>

/* --- Emulation issues -------------------------------------------------- */

#if defined EMULATED_WCWIDTH
extern int wcwidth(int c);
#else
#include <wchar.h>
#endif

extern int main(int argc, const char* argv[]);

/* --- Configuration options --------------------------------------------- */

#define LUA_SRC_DIR PREFIX "/share/wordgrinder/"

/* --- Lua --------------------------------------------------------------- */

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

extern lua_State* L;

typedef struct
{
	const char* data;
	size_t size;
	const char* name;
} FileDescriptor;

extern const FileDescriptor script_table[];

extern void script_init(void);
extern void script_load(const char* filename);
extern void script_load_from_table(const FileDescriptor* table);
extern void script_run(const char* argv[]);

/* --- Screen management ------------------------------------------------- */

extern void screen_init(const char* argv[]);
extern void screen_deinit(void);

/* --- Word management --------------------------------------------------- */

extern void word_init(void);

/* --- Bitmask management ------------------------------------------------ */

extern void bit_init(void);

/* --- General utilities ------------------------------------------------- */

typedef int uni_t;

extern int getu8bytes(char c);
extern uni_t readu8(const char** ptr);
extern void writeu8(char** ptr, uni_t value);

extern void utils_init(void);

/* --- Display layer ----------------------------------------------------- */

enum
{
	DPY_BOLD = (1<<1),
	DPY_UNDERLINE = (1<<2),
	DPY_REVERSE = (1<<3),
	DPY_DIM = (1<<4)
};

extern void dpy_init(const char* argv[]);
extern void dpy_start(void);
extern void dpy_shutdown(void);

extern void dpy_setattr(int andmask, int ormask);
extern void dpy_writechar(int x, int y, uni_t c);
extern void dpy_setcursor(int x, int y);
extern void dpy_clearscreen(void);
extern void dpy_sync(void);
extern void dpy_cleararea(int x1, int y1, int x2, int y2);
extern void dpy_getscreensize(int* x, int* y);
extern uni_t dpy_getchar(int timeout);
extern const char* dpy_getkeyname(uni_t key);

#endif
