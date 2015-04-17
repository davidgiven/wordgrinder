/* © 2015 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <curses.h>
#include <wctype.h>
#include <sys/time.h>
#include <time.h>
#include <X11/Xlib.h>
#include <Xft/Xft.h>
#include <ctype.h>
#include "utils/uthash.h"

#define KEY_TIMEOUT (KEY_MAX + 1)

#define VKM_SHIFT     0x02000000
#define VKM_CTRL      0x04000000
#define VKM_CTRLASCII 0x08000000
#define VKM__MASK     0x0e000000
#define VK_RESIZE     0x10000000
#define VK_TIMEOUT    0x20000000
#define VK_REDRAW     0x30000000

struct glyph
{
	unsigned c : 24;
	unsigned attr : 8; 
};

enum
{
	BLACK = 0,
	DIM,
	NORMAL,
	BRIGHT,

	NUM_COLOURS
};

enum
{
	REGULAR = 0,
	ITALIC = (1<<0),
	BOLD = (1<<1),
};

static Display* display;
static Window window;
static XComposeStatus compose;
static XftFont* fonts[4];
static XftDraw* draw;
static int fontwidth, fontheight, fontascent;

static int screenwidth, screenheight;
static int cursorx, cursory;
static struct glyph* frontbuffer = NULL;
static int defaultattr = 0;

static XftColor colours[NUM_COLOURS];

static uni_t queued[4];
static int numqueued = 0;

static void redraw(void);

static uni_t dequeue(void)
{
	uni_t c = queued[0];
	queued[0] = queued[1];
	queued[1] = queued[2];
	queued[2] = queued[3];
	numqueued--;
	return c;
}

void push_key(uni_t c)
{
	if (numqueued >= (sizeof(queued)/sizeof(*queued)))
		return;

	queued[numqueued] = c;
	numqueued++;
}


void dpy_init(const char* argv[])
{
}

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
	lua_getglobal(L, "X11_FONT_BOLD");
	const char* bold = lua_tostring(L, -1);
	if (!bold)
		bold = ":bold";

	lua_getglobal(L, "X11_FONT_ITALIC");
	const char* italic = lua_tostring(L, -1);
	if (!italic)
		italic = ":italic";

	lua_getglobal(L, "X11_FONT_BASENAME");
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
}

static XftColor load_colour(const char* name, const char* fallback)
{
	lua_getglobal(L, "X11_BLACK");
	const char* value = lua_tostring(L, -1);
	if (!value)
		value = fallback;

	XftColor colour;
	if (!XftColorAllocName(display,
			DefaultVisual(display, DefaultScreen(display)),
			DefaultColormap(display, DefaultScreen(display)),
			value, &colour))
	{
		fprintf(stderr, "Error: can't parse colour '%s'.\n", value);
		exit(1);
	}

	return colour;
}

void dpy_start(void)
{
	display = XOpenDisplay(NULL);
	if (!display)
	{
		fprintf(stderr, "Error: can't open display. Is DISPLAY set?\n");
		exit(1);
	}

	window = XCreateSimpleWindow(display, RootWindow(display, 0),
					  0, 0, 800, 600, 0, 0, BlackPixel(display, 0));
	XSelectInput(display, window,
		StructureNotifyMask | ExposureMask | KeyPressMask);
	XMapWindow(display, window);

	load_fonts();
	colours[BLACK]  = load_colour("X11_BLACK",  "#000000");
	colours[DIM]    = load_colour("X11_DIM",    "#555555");
	colours[NORMAL] = load_colour("X11_NORMAL", "#888888");
	colours[BRIGHT] = load_colour("X11_BRIGHT", "#ffffff");

	{
		XGlyphInfo xgi;
		XftFont* font = fonts[BOLD|ITALIC];
		XftTextExtents8(display, font, (FcChar8*) "M", 1, &xgi);
		fontwidth = xgi.xOff;
		fontheight = font->height + 1;
		fontascent = font->ascent;
	}

	
	draw = XftDrawCreate(display, window,
		DefaultVisual(display, DefaultScreen(display)),
		DefaultColormap(display, DefaultScreen(display)));

	screenwidth = screenheight = -1;
	cursorx = cursory = 0;
}

void dpy_shutdown(void)
{
}

void dpy_clearscreen(void)
{
	dpy_cleararea(0, 0, screenwidth-1, screenheight-1);
}

void dpy_getscreensize(int* x, int* y)
{
	*x = screenwidth;
	*y = screenheight;
}

void dpy_sync(void)
{
	redraw();
}

void dpy_setcursor(int x, int y)
{
	cursorx = x;
	cursory = y;
}

void dpy_setattr(int andmask, int ormask)
{
	defaultattr &= andmask;
	defaultattr |= ormask;
}

void dpy_writechar(int x, int y, uni_t c)
{
	if (!frontbuffer
			|| (x < 0) || (y < 0) || (x >= screenwidth) || (y >= screenheight))
		return;

	struct glyph* g = &frontbuffer[x + y*screenwidth];
	g->c = c;
	g->attr = defaultattr;
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	for (int y=y1; y<=y2; y++)
	{
		struct glyph* p = &frontbuffer[y * screenwidth];
		for (int x=x1; x<=x2; x++)
		{
			struct glyph* g = &p[x];
			g->c = ' ';
			g->attr = defaultattr;
		}
	}
}

static void render_glyph(struct glyph* g, int x, int y)
{
	FcChar32 c = g->c;
	XftColor* fg;
	XftColor* bg;

	if (g->attr & DPY_BRIGHT)
		fg = &colours[BRIGHT];
	else if (g->attr & DPY_DIM)
		fg = &colours[DIM];
	else
		fg = &colours[NORMAL];

	if (g->attr & DPY_REVERSE)
	{
		bg = fg;
		fg = &colours[BLACK];
	}
	else
		bg = &colours[BLACK];

	int style = REGULAR;
	if (g->attr & DPY_BOLD)
		style |= BOLD;
	if (g->attr & DPY_ITALIC)
		style |= ITALIC;

	XftDrawRect(draw, bg,
		x*fontwidth, y*fontheight,
		fontwidth, fontheight);
	if (c)
		XftDrawString32(draw, fg, fonts[style],
			x*fontwidth, fontascent + y*fontheight, &c, 1);
}

static void redraw(void)
{
	for (int y = 0; y<screenheight; y++)
	{
		struct glyph* p = &frontbuffer[y * screenwidth];
		for (int x = 0; x<screenwidth; x++)
			render_glyph(&p[x], x, y);
	}
}

uni_t dpy_getchar(int timeout)
{
	while (numqueued == 0)
	{
		XEvent e;
		XNextEvent(display, &e);

		switch (e.type)
		{
			case MapNotify:
				break;

			case Expose:
				redraw();
				break;

			case ConfigureNotify:
			{
				XConfigureEvent* xce = &e.xconfigure;
				int w = xce->width / fontwidth;
				int h = xce->height / fontheight;

				if ((w != screenwidth) || (h != screenheight))
				{
					screenwidth = w;
					screenheight = h;

					if (frontbuffer)
						free(frontbuffer);
					frontbuffer = calloc(screenwidth * screenheight, sizeof(struct glyph));
					push_key(-VK_RESIZE);
				}

				break;
			}

			case MappingNotify:
				XRefreshKeyboardMapping(&e.xmapping);
				break;

			case KeyPress:
			{
				XKeyEvent* xke = &e.xkey;
				KeySym keysym;
				char buffer[32];
				int charcount = XLookupString(xke, buffer, sizeof(buffer)-1,
					&keysym, &compose);
				buffer[charcount] = '\0';

				const char* p = buffer;
				uni_t c = readu8(&p);

				int mods = 0;
				if (xke->state & ShiftMask)
					mods |= VKM_SHIFT;
				if (xke->state & ControlMask)
					mods |= VKM_CTRL;

				if ((keysym & 0xffffff00) == 0xff00)
				{
					/* Special function key. */
					if (!IsModifierKey(keysym))
						push_key(-(keysym | mods));
				}
				else if (c < 32)
				{
					/* Ctrl + letter key */
					push_key(-(VKM_CTRLASCII | c | mods));
				}
				else
				{
					if (xke->state & Mod1Mask)
						push_key(-XK_Escape);
					push_key(c);
				}
				break;
			}
		}
	}

	return dequeue();
}

const char* dpy_getkeyname(uni_t k)
{
	static char buffer[32];

	switch (-k)
	{
		case VK_RESIZE:      return "KEY_RESIZE";
		case VK_TIMEOUT:     return "KEY_TIMEOUT";
		case VK_REDRAW:      return "KEY_REDRAW";
	}

	int key = -k & ~VKM__MASK;
	int mods = -k & VKM__MASK;

	if (mods & VKM_CTRLASCII)
	{
		sprintf(buffer, "KEY_%s^%c",
				(mods & VKM_SHIFT) ? "S" : "",
				key + 64);
		return buffer;
	}

	const char* template = NULL;
	switch (key)
	{
		case XK_KP_Down:
		case XK_Down:        template = "DOWN"; break;
		case XK_KP_Up:
		case XK_Up:          template = "UP"; break;
		case XK_KP_Left:
		case XK_Left:        template = "LEFT"; break;
		case XK_KP_Right:
		case XK_Right:       template = "RIGHT"; break;
		case XK_KP_Home:
		case XK_Home:        template = "HOME"; break;
		case XK_KP_End:
		case XK_End:         template = "END"; break;
		case XK_KP_Delete:
		case XK_Delete:      template = "DELETE"; break;
		case XK_KP_Insert:
		case XK_Insert:      template = "INSERT"; break;
		case XK_KP_Page_Down:
		case XK_Page_Down:   template = "PGDN"; break;
		case XK_KP_Page_Up:
		case XK_Page_Up:     template = "PGUP"; break;
		case XK_KP_Enter:
		case XK_Return:      template = "RETURN"; break;
		case XK_Tab:         template = "TAB"; break;
		case XK_Escape:      template = "ESCAPE"; break;
		case XK_BackSpace:   template = "BACKSPACE"; break;
	}
	
	if (template)
	{
		sprintf(buffer, "KEY_%s%s%s",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "^" : "",
				template);
		return buffer;
	}

	if ((key >= XK_F1) && (key <= XK_F35))
	{
		sprintf(buffer, "KEY_%s%sF%d",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "^" : "",
				key - XK_F1 + 1);
		return buffer;
	}

	sprintf(buffer, "KEY_UNKNOWN_%d", -k);
	return buffer;
}

