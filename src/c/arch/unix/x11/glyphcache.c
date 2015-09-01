/* © 2015 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include "x11.h"

enum
{
	REGULAR = 0,
	ITALIC = (1<<0),
	BOLD = (1<<1),
};

static struct glyph* glyphs;
static XftFont* fonts[4];

static struct glyph* create_struct_glyph(void)
{
	return calloc(1, sizeof(struct glyph));
}

#if 0
static void delete_struct_glyph(struct glyph* glyph)
{
	if (!glyph)
		return;

	if (glyph->pixmap)
		XFreePixmap(display, glyph->pixmap);
	free(glyph);
}
#endif

static void check_font(XftFont* font, const char* name)
{
	if (!font)
	{
		fprintf(stderr, "Error: font variant '%s' could not be loaded\n", name);
		exit(1);
	}
}

static void load_fonts(void)
{
	lua_getglobal(L, "X11_BOLD_MODIFIER");
	const char* bold = lua_tostring(L, -1);
	if (!bold)
		bold = ":bold";

	lua_getglobal(L, "X11_ITALIC_MODIFIER");
	const char* italic = lua_tostring(L, -1);
	if (!italic)
		italic = ":italic";

	lua_getglobal(L, "X11_FONT");
	const char* normalfont = lua_tostring(L, -1);
	if (!normalfont)
		normalfont = "monospace";
	char buffer[strlen(normalfont) + strlen(bold) + strlen(italic)];

	fonts[REGULAR] = XftFontOpenName(display, DefaultScreen(display), normalfont);
	check_font(fonts[REGULAR], normalfont);

	sprintf(buffer, "%s%s", normalfont, bold);
	fonts[BOLD] = XftFontOpenName(display, DefaultScreen(display), buffer);
	check_font(fonts[BOLD], buffer);

	sprintf(buffer, "%s%s", normalfont, italic);
	fonts[ITALIC] = XftFontOpenName(display, DefaultScreen(display), buffer);
	check_font(fonts[ITALIC], buffer);

	sprintf(buffer, "%s%s%s", normalfont, bold, italic);
	fonts[BOLD|ITALIC] = XftFontOpenName(display, DefaultScreen(display), buffer);
	check_font(fonts[BOLD|ITALIC], buffer);

	{
		XGlyphInfo xgi;
		XftFont* font = fonts[BOLD|ITALIC];
		XftTextExtents8(display, font, (FcChar8*) "M", 1, &xgi);
		fontwidth = xgi.xOff;
		fontheight = font->height + 1;
		fontascent = font->ascent;
	}

}

void glyphcache_init(void)
{
	load_fonts();
}

static struct glyph* create_glyph(unsigned int id)
{
	FcChar32 c = id >> 8;
	int attrs = id & 0xff;

	struct glyph* glyph = create_struct_glyph();
	glyph->id = id;

	int wcw = emu_wcwidth(c);
	if (wcw < 1)
		wcw = 1;

	glyph->width = fontwidth * wcw;
	glyph->pixmap = XCreatePixmap(display, window,
		glyph->width, fontheight,
		DefaultDepth(display, DefaultScreen(display)));

	XftDraw* draw = XftDrawCreate(display, glyph->pixmap,
		DefaultVisual(display, DefaultScreen(display)),
		DefaultColormap(display, DefaultScreen(display)));

	XftColor* fg;
	XftColor* bg;

	if (attrs & DPY_BRIGHT)
		fg = &colours[COLOUR_BRIGHT];
	else if (attrs & DPY_DIM)
		fg = &colours[COLOUR_DIM];
	else
		fg = &colours[COLOUR_NORMAL];

	if (attrs & DPY_REVERSE)
	{
		bg = fg;
		fg = &colours[COLOUR_BLACK];
	}
	else
		bg = &colours[COLOUR_BLACK];

	int style = REGULAR;
	if (attrs & DPY_BOLD)
		style |= BOLD;
	if (attrs & DPY_ITALIC)
		style |= ITALIC;

	int w = (glyph->width+1) & ~1;
	int w2 = w/2;
	int h = (fontheight+1) & ~1;
	int h2 = h/2;

	XftDrawRect(draw, bg, 0, 0, w, h);

	switch (c)
	{
		case 32:
		case 160: /* Non-breaking space */
			break;

		case 0x2500: /* ─ */
		case 0x2501: /* ━ */
			XftDrawRect(draw, fg, 0, h2, w, 1);
			break;

		case 0x2502: /* │ */
		case 0x2503: /* ┃ */
			XftDrawRect(draw, fg, w2, 0, 1, h);
			break;

		case 0x250c: /* ┌ */
		case 0x250d: /* ┍ */
		case 0x250e: /* ┎ */
		case 0x250f: /* ┏ */
			XftDrawRect(draw, fg, w2, h2, 1, h2);
			XftDrawRect(draw, fg, w2, h2, w2, 1);
			break;

		case 0x2510: /* ┐ */
		case 0x2511: /* ┑ */
		case 0x2512: /* ┒ */
		case 0x2513: /* ┓ */
			XftDrawRect(draw, fg, w2, h2, 1, h2);
			XftDrawRect(draw, fg, 0, h2, w2, 1);
			break;

		case 0x2514: /* └ */
		case 0x2515: /* ┕ */
		case 0x2516: /* ┖ */
		case 0x2517: /* ┗ */
			XftDrawRect(draw, fg, w2, 0, 1, h2);
			XftDrawRect(draw, fg, w2, h2, w2, 1);
			break;

		case 0x2518: /* ┘ */
		case 0x2519: /* ┙ */
		case 0x251a: /* ┚ */
		case 0x251b: /* ┛ */
			XftDrawRect(draw, fg, w2, 0, 1, h2);
			XftDrawRect(draw, fg, 0, h2, w2+1, 1);
			break;

		case 0x2551: /* ║ */
			XftDrawRect(draw, fg, w2-1, 0, 1, h);
			XftDrawRect(draw, fg, w2+1, 0, 1, h);
			break;

		case 0x2594: /* ▔ */
			XftDrawRect(draw, fg, 0, 2, w, 1);
			break;
	
		default:
			XftDrawString32(draw, fg, fonts[style], 0, fontascent, &c, 1);
			break;
	}

	if (attrs & DPY_UNDERLINE)
		XftDrawRect(draw, fg, 0, fontascent + 2, fontwidth, 1);
	
	XftDrawDestroy(draw);
	return glyph;
}

struct glyph* glyphcache_getglyph(unsigned int id)
{
	struct glyph* glyph;

	/* 0 is special, and means don't draw. */

	if (id == 0)
		return NULL;

	/* Attempt to find the glyph in the cache. */

    HASH_FIND_INT(glyphs, &id, glyph);
    if (!glyph)
	{
		glyph = create_glyph(id);
		if (glyph)
			HASH_ADD_INT(glyphs, id, glyph);
    }

    return glyph;
}

