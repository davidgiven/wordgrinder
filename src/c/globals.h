/* © 2008 David Given.
 * WordGrinder is licensed under the BSD open source license. See the COPYING
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

/* --- Configuration options --------------------------------------------- */

#define LUA_SRC_DIR PREFIX "/share/wordgrinder/"

/* --- Lua --------------------------------------------------------------- */

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

extern lua_State* L;

extern void script_init(void);
extern void script_load(const char* filename, const char* argv[]);

/* --- Screen management ------------------------------------------------- */

extern void screen_init(void);
extern void screen_deinit(void);

/* --- Word management --------------------------------------------------- */

extern void word_init(void);

/* --- Bitmask management ------------------------------------------------ */

extern void bit_init(void);

/* --- General utilities ------------------------------------------------- */

extern int getu8bytes(char c);
extern wint_t readu8(const char** ptr);
extern void writeu8(char** ptr, wint_t value);

extern void utils_init(void);

#endif
