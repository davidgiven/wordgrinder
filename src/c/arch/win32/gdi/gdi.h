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

struct glyph
{
	unsigned int id;
	HDC dc;
	HBITMAP bitmap;
	int width;
	UT_hash_handle hh;
};

extern void glyphcache_init(HDC dc, LOGFONT* defaultfont);
extern void glyphcache_deinit(void);
extern void glyphcache_getfontsize(int* w, int* h);

extern void glyphcache_flush(void);
extern struct glyph* glyphcache_getglyph(unsigned int id, HDC dc);

#endif
