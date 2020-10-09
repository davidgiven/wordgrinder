/* © 2015 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <wctype.h>
#include <sys/time.h>
#include <time.h>
#include <ctype.h>
#include <poll.h>
#include "x11.h"

#define VKM_SHIFT     0x02000000
#define VKM_CTRL      0x04000000
#define VKM_CTRLASCII 0x08000000
#define VKM__MASK     0x0e000000
#define VK_RESIZE     0x10000000
#define VK_TIMEOUT    0x20000000
#define VK_REDRAW     0x30000000

struct gg
{
	unsigned c : 24;
	unsigned attr : 8;
};

enum
{
	REGULAR = 0,
	ITALIC = (1<<0),
	BOLD = (1<<1),
};

Display* display;
Window window;
XftColor colours[NUM_COLOURS];
int fontwidth, fontheight, fontascent;

static XIC xic;
static XIM xim;
static XftDraw* draw;
static GC gc;

static int screenwidth, screenheight;
static int cursorx, cursory;
static bool cursorshown;
static unsigned int* frontbuffer = NULL;
static unsigned int* backbuffer = NULL;
static int defaultattr = 0;

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

static void sput(unsigned int* screen, int x, int y, unsigned int id)
{
	if (!screen)
		return;
	if ((x < 0) || (x >= screenwidth))
		return;
	if ((y < 0) || (y >= screenheight))
		return;

	screen[y*screenwidth + x] = id;
}

void dpy_init(const char* argv[])
{
}

static XftColor load_colour(const char* name, const char* fallback)
{
	lua_getglobal(L, name);
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
	XStoreName(display, window, "WordGrinder " VERSION);
	XSetClassHint(display, window,
		&((XClassHint) { "WordGrinder", "WordGrinder" }));
	XSelectInput(display, window,
		StructureNotifyMask | ExposureMask | KeyPressMask | KeymapStateMask);
	XMapWindow(display, window);

	glyphcache_init();

	colours[COLOUR_BLACK]  = load_colour("X11_BLACK_COLOUR",  "#000000");
	colours[COLOUR_DIM]    = load_colour("X11_DIM_COLOUR",    "#555555");
	colours[COLOUR_NORMAL] = load_colour("X11_NORMAL_COLOUR", "#888888");
	colours[COLOUR_BRIGHT] = load_colour("X11_BRIGHT_COLOUR", "#ffffff");

	draw = XftDrawCreate(display, window,
		DefaultVisual(display, DefaultScreen(display)),
		DefaultColormap(display, DefaultScreen(display)));

	xim = XOpenIM(display, NULL, NULL, NULL);
	if (xim)
		xic = XCreateIC(xim, XNInputStyle,
			XIMPreeditNothing | XIMStatusNothing, XNClientWindow, window, NULL);
	if (!xim || !xic)
	{
		fprintf(stderr, "Error: couldn't set up input methods\n");
		exit(1);
	}
	XSetICFocus(xic);

	{
		XGCValues gcv =
		{
			.graphics_exposures = false
		};

		gc = XCreateGC(display, window, GCGraphicsExposures, &gcv);
	}

	screenwidth = screenheight = 0;
	cursorx = cursory = 0;
	cursorshown = true;
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
	if (!frontbuffer)
		frontbuffer = calloc(screenwidth * screenheight, sizeof(unsigned int));
	redraw();
}

void dpy_setcursor(int x, int y, bool shown)
{
	if (frontbuffer)
	{
		for (int xx=(cursorx-1); xx<=(cursorx+1); xx++)
			for (int yy=(cursory-1); yy<=(cursory+1); yy++)
				sput(frontbuffer, xx, yy, 0);
	}

	cursorx = x;
	cursory = y;
	cursorshown = shown;
}

void dpy_setattr(int andmask, int ormask)
{
	defaultattr &= andmask;
	defaultattr |= ormask;
}

void dpy_writechar(int x, int y, uni_t c)
{
	unsigned int id = glyphcache_id(c, defaultattr);
	sput(backbuffer, x, y, id);
	if (emu_wcwidth(c) == 2)
		sput(backbuffer, x+1, y, 0);
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	for (int y=y1; y<=y2; y++)
		for (int x=x1; x<=x2; x++)
			sput(backbuffer, x, y, glyphcache_id(' ' , defaultattr));
}

static void render_glyph(unsigned int id, int x, int y)
{
	struct glyph* glyph = glyphcache_getglyph(id);
	if (glyph && glyph->pixmap)
		XCopyArea(display, glyph->pixmap, window, gc,
			0, 0, glyph->width, fontheight,
			x*fontwidth, y*fontheight);
}

static void redraw(void)
{
	if (!frontbuffer || !backbuffer)
		return;

	for (int y = 0; y<screenheight; y++)
	{
		unsigned int* frontp = &frontbuffer[y * screenwidth];
		unsigned int* backp = &backbuffer[y * screenwidth];
		for (int x = 0; x<screenwidth; x++)
		{
			if (frontp[x] != backp[x])
			{
				frontp[x] = backp[x];
				render_glyph(frontp[x], x, y);
			}
		}
	}

	/* Draw a caret where the cursor should be. */

	if (cursorshown) {
		int x = cursorx*fontwidth - 1;
		if (x < 0)
			x = 0;
		int y = cursory*fontheight;
		int h = fontheight;
		XftColor* c = &colours[COLOUR_BRIGHT];

		XftDrawRect(draw, c, x,   y,   1, h);
		XftDrawRect(draw, c, x-1, y-1, 1, 1);
		XftDrawRect(draw, c, x+1, y-1, 1, 1);
		XftDrawRect(draw, c, x-1, y+h, 1, 1);
		XftDrawRect(draw, c, x+1, y+h, 1, 1);
	}
}

uni_t dpy_getchar(double timeout)
{
	while (numqueued == 0)
	{
		/* If a timeout was asked for, wait that long for an event. */

		if ((timeout != -1) && !XPending(display))
		{
			struct pollfd pfd =
			{
				.fd = ConnectionNumber(display),
				.events = POLLIN,
				.revents = 0
			};

			poll(&pfd, 1, timeout*1000);
			if (!pfd.revents)
				return -VK_TIMEOUT;
		}

		XEvent e;
		XNextEvent(display, &e);

		if (XFilterEvent(&e, window))
			continue;

		switch (e.type)
		{
			case MapNotify:
				break;

			case Expose:
			{
				/* Mark some of the screen as needing redrawing. */

				if (frontbuffer)
				{
					for (int y=0; y<screenheight; y++)
					{
						unsigned int* p = &frontbuffer[y * screenwidth];
						for (int x=0; x<screenwidth; x++)
							p[x] = 0;
					}
				}
				redraw();
				break;
			}

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
					frontbuffer = NULL;
					if (backbuffer)
						free(backbuffer);
					backbuffer = calloc(screenwidth * screenheight, sizeof(unsigned int));
					push_key(-VK_RESIZE);
				}

				break;
			}

			case MappingNotify:
			case KeymapNotify:
				XRefreshKeyboardMapping(&e.xmapping);
				break;

			case KeyPress:
			{
				XKeyPressedEvent* xke = &e.xkey;
				KeySym keysym;
				char buffer[32];
				Status status = 0;
                int charcount = Xutf8LookupString(xic, xke,
					buffer, sizeof(buffer)-1, &keysym, &status);

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
				else
				{
					const char* p = buffer;

					while ((p-buffer) < charcount)
					{
						uni_t c = readu8(&p);

						if (c < 32)
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
					}
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

