#ifndef GUI_H
#define GUI_H

#include "globals.h"

#ifdef __WXMAC__
#include "OpenGL/glu.h"
#include "OpenGL/gl.h"
#else
#include <GL/glu.h>
#include <GL/gl.h>
#endif

enum
{
	REGULAR   = 0,
	ITALIC    = (1<<0),
	BOLD      = (1<<1),
};

extern int fontWidth;
extern int fontHeight;

extern void loadFonts();
extern void flushFontCache();
extern void printChar(uni_t c, uint8_t attrs, float x, float y);

extern int get_ivar(const char* name);
extern const char* get_svar(const char* name);

#endif

// vim: sw=4 ts=4 et

