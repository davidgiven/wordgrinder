/* © 2010 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 *
 * $Id: dpy.c 159 2009-12-13 13:11:03Z dtrg $
 * $URL: https://wordgrinder.svn.sf.net/svnroot/wordgrinder/wordgrinder/src/c/arch/win32/console/dpy.c $
 */

#include "globals.h"
#include <string.h>
#include <windows.h>
#include "gdi.h"

static struct glyph* glyphs;
static int fontwidth = 0;
static int fontheight = 0;

struct fontinfo
{
	LOGFONT logfont;
	long long panose;
	HFONT font;
	GLYPHSET* glyphset;
	bool defaultfont : 1;
};

static int numfonts = 0;
static struct fontinfo* fontdata = NULL;

#define DEFAULT_PANOSE 0x2b66900000LL

static struct glyph* create_struct_glyph(void)
{
	return calloc(1, sizeof(struct glyph));
}

static void delete_struct_glyph(struct glyph* glyph)
{
	if (!glyph)
		return;

	if (glyph->bitmap)
		DeleteObject(glyph->bitmap);
	if (glyph->dc)
		DeleteDC(glyph->dc);
	free(glyph);
}

static int CALLBACK font_counter_cb(
		ENUMLOGFONTEX* fontex,
		NEWTEXTMETRICEX* metrics,
		DWORD type,
		LPARAM user)
{
	if (strcmp((char*)fontex->elfScript, "Western") == 0)
		numfonts++;
	return 1;
}

struct font_reader_cb_data
{
	int index;
	HDC dc;
	long long currentpanose;
};

static long long compare_panose(unsigned long long p1, unsigned long long p2)
{
	unsigned long long result = 0;

	for (int i=60; i >= 0; i--)
	{
		int d1 = (p1 >> i) & 0xf;
		int d2 = (p2 >> i) & 0xf;
		if ((d1 != 0) && (d1 != 1) && (d2 != 0) && (d2 != 1))
		{
			int d = d1 - d2;
			if (d < 0)
				d = -d;
			result |= d;
		}
		result <<= 4;
	}

	return result;
}

static long long decode_panose(PANOSE* panose)
{
	BYTE* panosebytes = (BYTE*) panose;
	long long number = 0;

	for (int i = 0; i < PANOSE_COUNT; i++)
		number = (number<<4) | panosebytes[i];

	return number;
}

static long long get_panose(HFONT font, HDC dc)
{
	SelectObject(dc, font);

	int result = GetOutlineTextMetrics(dc, 0, NULL);
	if (result)
	{
		char buffer[result];
		LPOUTLINETEXTMETRIC metrics = (void*) buffer;
		GetOutlineTextMetrics(dc, result, metrics);

		return decode_panose(&metrics->otmPanoseNumber);
	}
	else
		return DEFAULT_PANOSE;
}

static int CALLBACK font_reader_cb(
		ENUMLOGFONTEX* fontex,
		NEWTEXTMETRICEX* metrics,
		DWORD type,
		LPARAM user)
{
	struct font_reader_cb_data* data = (void*) user;

	if (strcmp((char*)fontex->elfScript, "Western") == 0)
	{
		struct fontinfo* fi = &fontdata[data->index];
		fi->logfont = fontex->elfLogFont;
		fi->logfont.lfWidth = 0;//fontwidth;
		fi->logfont.lfHeight = fontheight;
		fi->font = CreateFontIndirect(&fi->logfont);
		assert(fi->font);
		unsigned long long p = get_panose(fi->font, data->dc);
		fi->panose = compare_panose(p, data->currentpanose);

		SelectObject(data->dc, fi->font);
		int glyphsetsize = GetFontUnicodeRanges(data->dc, NULL);
		fi->glyphset = malloc(glyphsetsize);
		assert(fi->glyphset);
		GetFontUnicodeRanges(data->dc, fi->glyphset);

		fi->defaultfont = false;

		data->index++;
	}
	return 1;
}

static int font_sorter_cb(const void* p1, const void* p2)
{
	const struct fontinfo* f1 = p1;
	const struct fontinfo* f2 = p2;

	if (f1->defaultfont && !f2->defaultfont)
		return -1;
	if (!f1->defaultfont && f2->defaultfont)
		return 1;

	long long d = f1->panose - f2->panose;
	if (d == 0)
		return 0;
	if (d < 0)
		return -1;
	return 1;
}

void glyphcache_init(HDC dc, LOGFONT* defaultfont)
{
	HFONT defaultfonthandle = CreateFontIndirect(defaultfont);
	SelectObject(dc, defaultfonthandle);

	{
		fontwidth = defaultfont->lfWidth;
		fontheight = defaultfont->lfHeight;

		/* Only bitmap fonts (I think) have genuine sizes in the
		 * LOGFONT structure. For other fonts, we need to query
		 * the metrics. */

		if ((fontwidth <= 0) || (fontheight <= 0))
		{
			TEXTMETRIC tm;
			GetTextMetrics(dc, &tm);
			fontheight = tm.tmHeight;

			GetCharWidth32(dc, 'M', 'M', &fontwidth);
		}

		assert(fontwidth > 0);
		assert(fontheight > 0);
	}

	/* Count the number of available fonts. */

	{
		LOGFONT logfont;
		logfont.lfCharSet = DEFAULT_CHARSET;
		logfont.lfFaceName[0] = 0;
		logfont.lfPitchAndFamily = 0;
		numfonts = 0;
		EnumFontFamiliesEx(dc, &logfont, (FONTENUMPROCA) font_counter_cb, 0, 0);
	}

	/* Allocate space for them, and then read them in. */

	{
		fontdata = calloc(numfonts, sizeof(struct fontinfo));
		LOGFONT logfont;

		logfont.lfCharSet = DEFAULT_CHARSET;
		logfont.lfFaceName[0] = 0;
		logfont.lfPitchAndFamily = 0;

		struct font_reader_cb_data data;
		data.index = 0;
		data.dc = dc;
		data.currentpanose = get_panose(defaultfonthandle, dc);
		EnumFontFamiliesEx(dc, &logfont, (FONTENUMPROCA) font_reader_cb, (LPARAM) &data, 0);
	}

	/* Check for the default font, mark it so that it always appears
	 * at the top of the list (regardless of Panose data), and sort
	 * the fonts. */

	{
		for (int i = 0; i < numfonts; i++)
		{
			if (strcmp(defaultfont->lfFaceName,
				fontdata[i].logfont.lfFaceName) == 0)
			{
				fontdata[i].defaultfont = true;
			}
		}

		qsort(fontdata, numfonts, sizeof(*fontdata), font_sorter_cb);
	}

	glyphs = NULL;
	DeleteObject(defaultfonthandle);
}

void glyphcache_deinit(void)
{
	glyphcache_flush();

	for (int i = 0; i < numfonts; i++)
	{
		DeleteObject(fontdata[i].font);
		free(fontdata[i].glyphset);
	}
}

void glyphcache_getfontsize(int* w, int* h)
{
	*w = fontwidth;
	*h = fontheight;
}

void glyphcache_flush(void)
{
	while (glyphs)
	{
		struct glyph* glyph = glyphs;
		HASH_DEL(glyphs, glyph);
		delete_struct_glyph(glyph);
	}

	fontwidth = 0;
	fontheight = 0;
}

static void unicode_to_utf16(uni_t unicode, WCHAR* string, int* slen)
{
	if (unicode < 0x00010000)
	{
		*string = unicode;
		*slen = 1;
		return;
	}

	unicode -= 0x00010000;
	string[0] = ((unicode >> 10) & 0x3ff) | 0xd800;
	string[1] = ((unicode >>  0) & 0x3ff) | 0xdc00;
	*slen = 2;
}

static void select_font_with_glyph(HDC dc, uni_t unicode)
{
	for (int i = 0; i < numfonts; i++)
	{
		SelectObject(dc, fontdata[i].font);

		GLYPHSET* gs = fontdata[i].glyphset;
		for (int i = 0; i < gs->cRanges; i++)
		{
			WCRANGE* range = &gs->ranges[i];
			int delta = unicode - range->wcLow;
			if ((delta >= 0) && (delta < range->cGlyphs))
				return;
		}
	}

	SelectObject(dc, fontdata[0].font);
}

static void draw_glyph(HDC dc, unsigned int id, int w, int h)
{
	RECT size = {0, 0, w, h};
	unsigned int attrs = id & 0xf;
	bool reverse = attrs & DPY_REVERSE;
	int bg = 0x000000;
	int fg;

	if (attrs & DPY_REVERSE)
	{
		fg = 0x000000;
		bg = 0xffffff;
	}
	else
	{
		if (attrs & DPY_DIM)
			fg = 0x606060;
		else if (attrs & DPY_BOLD)
			fg = 0xffffff;
		else
			fg = 0x808080;
	}

	FillRect(dc, &size, GetStockObject(reverse ? WHITE_BRUSH : BLACK_BRUSH));
	SetBkColor(dc, bg);
	SetTextColor(dc, fg);

	uni_t unicode = id >> 4;
	select_font_with_glyph(dc, unicode);

	WCHAR wstring[2];
	int slen;
	unicode_to_utf16(unicode, wstring, &slen);
	TextOutW(dc, 0, 0, wstring, slen);

	if (attrs & DPY_UNDERLINE)
	{
		HPEN pen = CreatePen(PS_SOLID, 0, fg);
		SelectObject(dc, pen);
		MoveToEx(dc, 0, h-1, NULL);
		LineTo(dc, w, h-1);
		DeleteObject(pen);
	}
}

struct glyph* glyphcache_getglyph(unsigned int id, HDC dc)
{
	struct glyph* glyph;

	/* Attempt to find the glyph in the cache. */

    HASH_FIND_INT(glyphs, &id, glyph);
    if (!glyph)
    {
		/* Need to create a new glyph. */

		glyph = create_struct_glyph();
		if (!glyph)
			goto error;
		glyph->id = id;

		/* Attempt to create the bitmap. */

		glyph->dc = CreateCompatibleDC(dc);
		if (!glyph->dc)
			goto error;
		glyph->width = emu_wcwidth(id >> 4) * fontwidth;
		glyph->bitmap = CreateCompatibleBitmap(dc, glyph->width, fontheight);
		if (!glyph->bitmap)
			goto error;
		SelectObject(glyph->dc, glyph->bitmap);

		/* Now draw the glyph. */

		draw_glyph(glyph->dc, glyph->id, glyph->width, fontheight);

		/* Add the glyph to the cache. */

		HASH_ADD_INT(glyphs, id, glyph);
    }

    return glyph;

error:
	delete_struct_glyph(glyph);
	return NULL;
}
