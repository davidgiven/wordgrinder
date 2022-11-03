#ifndef GUI_H
#define GUI_H

#include "globals.h"

#ifdef __APPLE__
#include "OpenGL/gl.h"
#else
#include <GL/gl.h>
#endif

enum
{
	REGULAR   = 0,
	ITALIC    = (1<<0),
	BOLD      = (1<<1),
};

typedef struct
{
    GLfloat f[3];
}
colour_t;

extern colour_t colours[16];
extern int fontWidth;
extern int fontHeight;

extern void loadFonts();
extern void unloadFonts();
extern void flushFontCache();
extern void printChar(uni_t c, uint8_t attrs, int fg, int bg, float x, float y);

extern int get_ivar(const char* name);
extern const char* get_svar(const char* name);

#endif

// vim: sw=4 ts=4 et

