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

static Display* display;
static Window window;
static XComposeStatus compose;
static int widthPixels, heightPixels;
static XftFont* font;
static XftDraw* draw;
static int fontWidth, fontHeight, fontAscent;

static int widthChars, heightChars;
static int cursorx, cursory;
static struct glyph* frontbuffer = NULL;
static int defaultattr = 0;

static XftColor colours[NUM_COLOURS];
static const XRenderColor rawcolours[NUM_COLOURS] =
{
	{ 0x0000, 0x0000, 0x0000, 0xffff },
	{ 0x5555, 0x5555, 0x5555, 0xffff },
	{ 0x8888, 0x8888, 0x8888, 0xffff },
	{ 0xffff, 0xffff, 0xffff, 0xffff },
};

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

void dpy_start(void)
{
	display = XOpenDisplay(NULL);
	if (!display)
	{
		fprintf(stderr, "Error: Can't open display. Is DISPLAY set?\n");
		exit(1);
	}

	window = XCreateSimpleWindow(display, RootWindow(display, 0),
					  0, 0, 800, 600, 0, 0, BlackPixel(display, 0));
	XSelectInput(display, window,
		StructureNotifyMask | ExposureMask | KeyPressMask);
	XMapWindow(display, window);

	font = XftFontOpenName(display, DefaultScreen(display), "mono-13");
	if (!font)
	{
		fprintf(stderr, "Error: font not found\n");
		exit(1);
	}

	{
		XGlyphInfo xgi;
		XftTextExtents8(display, font, (FcChar8*) "M", 1, &xgi);
		fontWidth = xgi.width + 1;
		fontHeight = font->height;
		fontAscent = font->ascent;
	}

	for (int i=0; i<NUM_COLOURS; i++)
	{
		XftColorAllocValue(display,
			DefaultVisual(display, DefaultScreen(display)),
			DefaultColormap(display, DefaultScreen(display)),
			&rawcolours[i], &colours[i]);
	}

	draw = XftDrawCreate(display, window,
		DefaultVisual(display, DefaultScreen(display)),
		DefaultColormap(display, DefaultScreen(display)));

	widthPixels = heightPixels = -1;
	widthChars = heightChars = -1;
	cursorx = cursory = 0;
}

void dpy_shutdown(void)
{
}

void dpy_clearscreen(void)
{
	dpy_cleararea(0, 0, widthChars-1, heightChars-1);
}

void dpy_getscreensize(int* x, int* y)
{
	*x = widthChars;
	*y = heightChars;
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
			|| (x < 0) || (y < 0) || (x >= widthChars) || (y >= heightChars))
		return;

	struct glyph* g = &frontbuffer[x + y*widthChars];
	g->c = c;
	g->attr = defaultattr;
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	for (int y=y1; y<=y2; y++)
	{
		struct glyph* p = &frontbuffer[y * widthChars];
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

	XftDrawRect(draw, bg,
		x*fontWidth, y*fontHeight,
		fontWidth, fontHeight);
	if (c)
		XftDrawString32(draw, fg, font,
			x*fontWidth, fontAscent + y*fontHeight, &c, 1);
}

static void redraw(void)
{
	for (int y = 0; y<heightChars; y++)
	{
		struct glyph* p = &frontbuffer[y * widthChars];
		for (int x = 0; x<widthChars; x++)
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

				if ((xce->width != widthPixels) || (xce->height != heightPixels))
				{
					widthPixels = xce->width;
					heightPixels = xce->height;

					int w = widthPixels / fontWidth;
					int h = heightPixels / fontHeight;
					if ((w != widthChars) || (h != heightChars))
					{
						widthChars = w;
						heightChars = h;

						if (frontbuffer)
							free(frontbuffer);
						frontbuffer = calloc(widthChars * heightChars, sizeof(struct glyph));
						push_key(-VK_RESIZE);
					}
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

