/* © 2010 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id: dpy.c 159 2009-12-13 13:11:03Z dtrg $
 * $URL: https://wordgrinder.svn.sf.net/svnroot/wordgrinder/wordgrinder/src/c/arch/win32/console/dpy.c $
 */

#ifndef GDI_H
#define GDI_H

#include "uthash.h"

#define VKM_SHIFT      0x100
#define VKM_CTRL       0x200
#define VKM_CTRLASCII  0x400
#define VK_RESIZE     0x1000
#define VK_TIMEOUT    0x1001
#define VK_REDRAW     0x1002

#define TIMEOUT_TIMER_ID 1

struct glyph
{
	unsigned int id;
	HDC dc;
	HBITMAP bitmap;
	int width;
	int xoffset, yoffset;
	int realwidth, realheight;
	UT_hash_handle hh;
};

extern void glyphcache_init(HDC dc, LOGFONT* defaultfont);
extern void glyphcache_deinit(void);
extern void glyphcache_getfontsize(int* w, int* h);

extern void glyphcache_flush(void);
extern struct glyph* glyphcache_getglyph(unsigned int id, HDC dc);

extern void dpy_queuekey(uni_t key);
extern void dpy_flushkeys(void);

extern HWND window;

#endif
