#ifndef GUI_H
#define GUI_H

extern "C"
{
#include "globals.h"
}

#include <stdio.h>
#include <stdlib.h>
#include <wx/wx.h>
#include <wx/glcanvas.h>
#include <memory>
#include <functional>
#include <deque>
#include "stb_truetype.h"

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

extern void loadFonts();
extern void flushFontCache();
extern void getFontSize(int& width, int& height);
extern void printChar(uni_t c, uint8_t attrs, float x, float y);

extern int getIvar(const char* name);
extern std::string getSvar(const char* name);

extern void runOnUiThread(std::function<void()> callback);

template <typename R>
static inline R runOnUiThread(std::function<R()> callback)
{
    R retvar;
    runOnUiThread(
        [&]()
        {
            retvar = callback();
        });
    return retvar;
}

#endif

