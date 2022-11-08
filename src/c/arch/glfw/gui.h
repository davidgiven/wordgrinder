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
    REGULAR = 0,
    ITALIC = (1 << 0),
    BOLD = (1 << 1),
};

typedef struct
{
    uni_t c;
    uint8_t attr;
    colour_t fg;
    colour_t bg;
} cell_t;

extern int fontWidth;
extern int fontHeight;

extern void loadFonts();
extern void unloadFonts();
extern void flushFontCache();
extern void printChar(const cell_t* cell, float x, float y);

extern int get_ivar(const char* name);
extern const char* get_svar(const char* name);

#endif

// vim: sw=4 ts=4 et
