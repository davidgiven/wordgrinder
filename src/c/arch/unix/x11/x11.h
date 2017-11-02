/* © 2015 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#ifndef X11_H
#define X11_H

#include <X11/Xlib.h>
#include <Xft/Xft.h>
#include "uthash.h"

#define MAX(x, y) (((x) > (y)) ? (x) : (y))
#define MIN(x, y) (((x) < (y)) ? (x) : (y))

#define VKM_SHIFT     0x02000000
#define VKM_CTRL      0x04000000
#define VKM_CTRLASCII 0x08000000
#define VKM__MASK     0x0e000000
#define VK_RESIZE     0x10000000
#define VK_TIMEOUT    0x20000000
#define VK_REDRAW     0x30000000

enum
{
	COLOUR_BLACK = 0,
	COLOUR_DIM,
	COLOUR_NORMAL,
	COLOUR_BRIGHT,

	NUM_COLOURS
};


struct glyph
{
	unsigned int id;              /* id of this glyph */
	Pixmap pixmap;                /* glyph storage */
	int width;                    /* width of this cell */
	UT_hash_handle hh;
};

#define glyphcache_id(c, a) ((c<<8) | a)

extern void glyphcache_init(void);
extern void glyphcache_deinit(void);
extern void glyphcache_getfontsize(int* w, int* h);

extern void glyphcache_flush(void);
extern struct glyph* glyphcache_getglyph(unsigned int id);

extern Display* display;
extern Window window;
extern XftColor colours[NUM_COLOURS];
extern int fontwidth, fontheight, fontascent;

#endif

