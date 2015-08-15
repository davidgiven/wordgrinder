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
	HFONT fontb;
	HFONT fonti;
	HFONT fontbi;
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
	struct fontinfo* fi = &fontdata[data->index];
	fi->logfont = fontex->elfLogFont;
	fi->logfont.lfWidth = 0;//fontwidth;
	fi->logfont.lfHeight = fontheight;

	fi->logfont.lfItalic = FALSE;
	fi->logfont.lfWeight = FW_NORMAL;
	fi->font = CreateFontIndirect(&fi->logfont);

	fi->logfont.lfItalic = TRUE;
	fi->logfont.lfWeight = FW_NORMAL;
	fi->fonti = CreateFontIndirect(&fi->logfont);

	fi->logfont.lfItalic = FALSE;
	fi->logfont.lfWeight = FW_BOLD;
	fi->fontb = CreateFontIndirect(&fi->logfont);

	fi->logfont.lfItalic = TRUE;
	fi->logfont.lfWeight = FW_BOLD;
	fi->fontbi = CreateFontIndirect(&fi->logfont);

	unsigned long long p = get_panose(fi->font, data->dc);
	fi->panose = compare_panose(p, data->currentpanose);

	SelectObject(data->dc, fi->font);
	int glyphsetsize = GetFontUnicodeRanges(data->dc, NULL);
	fi->glyphset = malloc(glyphsetsize);
	assert(fi->glyphset);
	GetFontUnicodeRanges(data->dc, fi->glyphset);

	fi->defaultfont = false;

	data->index++;
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
	int state = SaveDC(dc);
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

	RestoreDC(dc, state);
}

void glyphcache_deinit(void)
{
	glyphcache_flush();

	if (fontdata)
	{
		for (int i = 0; i < numfonts; i++)
		{
			DeleteObject(fontdata[i].font);
			DeleteObject(fontdata[i].fonti);
			DeleteObject(fontdata[i].fontb);
			DeleteObject(fontdata[i].fontbi);
			free(fontdata[i].glyphset);
		}
		numfonts = 0;
		free(fontdata);
		fontdata = NULL;
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

static HFONT select_font_with_glyph(HDC dc, uni_t unicode, int attrs)
{
	for (int fi = 0; fi < numfonts; fi++)
	{
		GLYPHSET* gs = fontdata[fi].glyphset;
		for (int i = 0; i < gs->cRanges; i++)
		{
			WCRANGE* range = &gs->ranges[i];
			int delta = unicode - range->wcLow;
			if ((delta >= 0) && (delta < range->cGlyphs))
			{
				bool bold = attrs & DPY_BOLD;
				bool italic = attrs & DPY_ITALIC;
				if (!bold && !italic)
					return fontdata[fi].font;
				else if (bold && !italic)
					return fontdata[fi].fontb;
				else if (bold && italic)
					return fontdata[fi].fontbi;
				else if (!bold && italic)
					return fontdata[fi].fonti;
			}
		}
	}

	return INVALID_HANDLE_VALUE;
}

static void draw_unicode(HDC dc, WCHAR* wstring, int slen, int w, int h,
		int xo, unsigned int attrs)
{
	int fg;

	if (attrs & DPY_DIM)
		fg = colourmap[COLOUR_DIM];
	else if (attrs & DPY_BRIGHT)
		fg = colourmap[COLOUR_BRIGHT];
	else
		fg = colourmap[COLOUR_NORMAL];

	SetBkColor(dc, colourmap[COLOUR_BLACK]);
	SetTextColor(dc, fg);

	HPEN pen = CreatePen(PS_SOLID, 0, fg);
	SelectObject(dc, pen);

	if (wstring)
	{
		/* If there's text, draw it. */

		switch (*wstring)
		{
			case 32:
			case 160: /* Non-breaking space */
				break;

			case 0x2500: /* ─ */
			case 0x2501: /* ━ */
				MoveToEx(dc, 0, h/2, NULL);
				LineTo(dc, w, h/2);
				break;

			case 0x2502: /* │ */
			case 0x2503: /* ┃ */
				MoveToEx(dc, w/2, 0, NULL);
				LineTo(dc, w/2, h);
				break;

			case 0x250c: /* ┌ */
			case 0x250d: /* ┍ */
			case 0x250e: /* ┎ */
			case 0x250f: /* ┏ */
				MoveToEx(dc, w/2, h, NULL);
				LineTo(dc, w/2, h/2);
				LineTo(dc, w, h/2);
				break;

			case 0x2510: /* ┐ */
			case 0x2511: /* ┑ */
			case 0x2512: /* ┒ */
			case 0x2513: /* ┓ */
				MoveToEx(dc, w/2, h, NULL);
				LineTo(dc, w/2, h/2);
				LineTo(dc, -1, h/2);
				break;

			case 0x2514: /* └ */
			case 0x2515: /* ┕ */
			case 0x2516: /* ┖ */
			case 0x2517: /* ┗ */
				MoveToEx(dc, w/2, 0, NULL);
				LineTo(dc, w/2, h/2);
				LineTo(dc, w, h/2);
				break;

			case 0x2518: /* ┘ */
			case 0x2519: /* ┙ */
			case 0x251a: /* ┚ */
			case 0x251b: /* ┛ */
				MoveToEx(dc, w/2, 0, NULL);
				LineTo(dc, w/2, h/2);
				LineTo(dc, -1, h/2);
				break;

			case 0x2551: /* ║ */
				MoveToEx(dc, w/2-1, 0, NULL);
				LineTo(dc, w/2-1, h);
				MoveToEx(dc, w/2+1, 0, NULL);
				LineTo(dc, w/2+1, h);
				break;

			case 0x2594: /* ▔ */
				MoveToEx(dc, 0, 0, NULL);
				LineTo(dc, w, 0);
				break;

			default:
				TextOutW(dc, xo, 0, wstring, slen);
				break;
		}
	}
	else
	{
		/* No text, so draw a placeholder. */

		MoveToEx(dc, xo, 0, NULL);
		LineTo(dc, xo+w-1, 0);
		LineTo(dc, xo+w-1, h-1);
		LineTo(dc, xo, h-1);
		LineTo(dc, xo, 0);
		LineTo(dc, xo+w-1, h);
		MoveToEx(dc, xo, h-1, NULL);
		LineTo(dc, xo+w-1, 0);
	}

	DeleteObject(pen);
}

static struct glyph* create_glyph(unsigned int id, HDC dc)
{
	int state = SaveDC(dc);

	struct glyph* glyph = create_struct_glyph();
	if (!glyph)
		goto error;
	glyph->id = id;

	int x, xo, w, h;

	/* Look for a font containing this glyph. */

	uni_t unicode = id >> 8;
	unsigned int attrs = id & 0xff;

	/* Force bright if in reverse text; this makes reverse much easier
	 * to read. */

	if (attrs & DPY_REVERSE)
		attrs |= DPY_BRIGHT;

	attrs &= DPY_ITALIC | DPY_BOLD | DPY_DIM | DPY_BRIGHT;
	HFONT font = select_font_with_glyph(dc, unicode, attrs);

	/* Determine the size of the bitmap needed. */

	WCHAR wstringarray[2];
	int slen = 0;
	WCHAR* wstring;
	if (font != INVALID_HANDLE_VALUE)
	{
		/* There is a font for this glyph; calculate its size. */

		SelectObject(dc, font);

		unicode_to_utf16(unicode, wstringarray, &slen);
		wstring = wstringarray;

		switch (unicode)
		{
			/* These are box drawing glyphs, and are handled specially. */

			case 0x2500: /* ─ */
			case 0x2501: /* ━ */
			case 0x2502: /* │ */
			case 0x2503: /* ┃ */
			case 0x250c: /* ┌ */
			case 0x250d: /* ┍ */
			case 0x250e: /* ┎ */
			case 0x250f: /* ┏ */
			case 0x2510: /* ┐ */
			case 0x2511: /* ┑ */
			case 0x2512: /* ┒ */
			case 0x2513: /* ┓ */
			case 0x2514: /* └ */
			case 0x2515: /* ┕ */
			case 0x2516: /* ┖ */
			case 0x2517: /* ┗ */
			case 0x2518: /* ┘ */
			case 0x2519: /* ┙ */
			case 0x251a: /* ┚ */
			case 0x251b: /* ┛ */
			case 0x2551: /* ║ */
			case 0x2594: /* ▔ */
				w = fontwidth;
				h = fontheight;
				x = 0;
				xo = 0;
				break;

			default: /* This is an ordinary glyph. */
			{
				SIZE size;
				GetTextExtentPoint32W(dc, wstring, slen, &size);
				w = size.cx;
				h = size.cy;

				/* Adjust size to cope with font glyphs that are bigger than a
				 * character cell (italic or bold bitmap, or TrueType). */

				ABC abc;
				if (GetCharABCWidths(dc, unicode, unicode, &abc))
				{
					/* If this function succeeds, then this is a TrueType font,
					 * so we use the ABC mechanism to calculate the overhang. */

					if (abc.abcB > w)
						w = abc.abcB;
					if (abc.abcA < 0)
					{
						xo = -abc.abcA;
						w += xo;
						x = abc.abcA;
					}
					else
					{
						xo = 0;
						x = 0;
					}
					if (abc.abcC < 0)
						w += -abc.abcC;
				}
				else
				{
					/* GetCharABCWidths() failed, therefore this is a bitmap
					 * font, and we need to use GetTextMetrics() to calculate the
					 * overhang. */

					TEXTMETRIC tm;
					GetTextMetrics(dc, &tm);
					w += tm.tmOverhang;
					x = -tm.tmOverhang/2;
					xo = 0;
				}
			}
		}
	}
	else
	{
		/* There isn't a font for this glyph. Use a placeholder. */
		w = emu_wcwidth(unicode) * fontwidth;
		h = fontheight;
		x = 0;
		xo = 0;
		wstring = NULL;
	}

	/* Attempt to create the bitmap. */

	glyph->dc = CreateCompatibleDC(dc);
	if (!glyph->dc)
		goto error;
	glyph->bitmap = CreateCompatibleBitmap(dc, w, h);
	if (!glyph->bitmap)
		goto error;
	SelectObject(glyph->dc, glyph->bitmap);
	if (font != INVALID_HANDLE_VALUE)
		SelectObject(glyph->dc, font);

	/* Initialise the glyph structure and draw it. */

	glyph->width = emu_wcwidth(unicode) * fontwidth;
	glyph->realwidth = w;
	glyph->realheight = h;
	glyph->xoffset = x;
	glyph->yoffset = 0;
	draw_unicode(glyph->dc, wstring, slen, w, h, xo, attrs);

exit:
	RestoreDC(dc, state);
	return glyph;

error:
	delete_struct_glyph(glyph);
	glyph = NULL;
	goto exit;
}

struct glyph* glyphcache_getglyph(unsigned int id, HDC dc)
{
	struct glyph* glyph;

	/* 0 is special, and means don't draw. */

	if (id == 0)
		return NULL;

	/* Attempt to find the glyph in the cache. */

    HASH_FIND_INT(glyphs, &id, glyph);
    if (!glyph)
	{
		glyph = create_glyph(id, dc);
		if (glyph)
			HASH_ADD_INT(glyphs, id, glyph);
    }

    return glyph;
}
