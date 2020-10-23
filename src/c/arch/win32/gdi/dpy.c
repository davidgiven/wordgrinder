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
#include <ctype.h>
#include "gdi.h"

#define CTRL_PRESSED (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED)

#define DEFAULT_CHAR (' ' << 8)

enum {
	MENUITEM_SETFONT,
	MENUITEM_FULLSCREEN,
	MENUITEM_SETBGCOL,
	MENUITEM_SETDIMCOL,
	MENUITEM_SETNORMALCOL,
	MENUITEM_SETBRIGHTCOL,
};

#define REGISTRY_PATH "Software\\Cowlark Technologies\\WordGrinder"

HWND window = INVALID_HANDLE_VALUE;
static LOGFONT fontlf;
static unsigned int* frontbuffer = NULL;
static unsigned int* backbuffer = NULL;
static int screenwidth = 0;
static int screenheight = 0;
static int defaultattr = 0;

static int cursorx = 0;
static int cursory = 0;
static bool cursorshown = true;

static bool isfullscreen = false;
static bool window_geometry_valid = false;
static RECT window_geometry;
static bool window_created = false;

static int shadowwidth;
static int shadowheight;
static HBITMAP shadow = NULL;
static WINDOWPLACEMENT nonFullScreenSize = { sizeof(WINDOWPLACEMENT) };

static void resize_shadow(int width, int height);
static void resize_buffer(bool force);
static void fullscreen_cb(void);
static void switch_to_full_screen(void);
static void switch_to_windowed(void);
static void create_window(void);

static COLORREF custom_colours[16];

COLORREF colourmap[COLOUR__NUM];

static HKEY make_key(const char* keystring)
{
	HKEY key;

	int e = RegCreateKeyEx(HKEY_CURRENT_USER, keystring,
			0, NULL, REG_OPTION_NON_VOLATILE,
			KEY_ALL_ACCESS, NULL, &key,
			NULL);
	if (e == ERROR_SUCCESS)
		return key;
	return NULL;
}

static void read_default_font(void)
{
	HKEY key = make_key(REGISTRY_PATH);
	DWORD size = sizeof(fontlf);
	DWORD e = RegQueryValueEx(key, "DefaultFont",
			NULL, NULL,
			(LPBYTE) &fontlf, &size);
	RegCloseKey(key);

	if (e != ERROR_SUCCESS)
	{
		HFONT defaultfont = (HFONT) GetStockObject(SYSTEM_FIXED_FONT);
		GetObject(defaultfont, sizeof(fontlf), &fontlf);
	}
}

static void write_default_font(void)
{
	HKEY key = make_key(REGISTRY_PATH);
	RegSetValueEx(key, "DefaultFont", 0,
			REG_BINARY,
			(LPBYTE) &fontlf, sizeof(fontlf));
	RegCloseKey(key);
}

static void read_colourmap(void)
{
	HKEY key = make_key(REGISTRY_PATH);
	DWORD size = sizeof(colourmap);
	DWORD e = RegQueryValueEx(key, "Colours",
			NULL, NULL,
			(LPBYTE) colourmap, &size);
	RegCloseKey(key);

	if (e != ERROR_SUCCESS)
	{
		colourmap[COLOUR_BLACK]  = 0x000000;
		colourmap[COLOUR_DIM]    = 0x555555;
		colourmap[COLOUR_NORMAL] = 0x888888;
		colourmap[COLOUR_BRIGHT] = 0xffffff;
	}
}

static void write_colourmap(void)
{
	HKEY key = make_key(REGISTRY_PATH);
	RegSetValueEx(key, "Colours", 0,
			REG_BINARY,
			(LPBYTE) colourmap, sizeof(colourmap));
	RegCloseKey(key);
}

static void read_window_geometry(void)
{
	HKEY key = make_key(REGISTRY_PATH);
	DWORD size = sizeof(window_geometry);
	DWORD e = RegQueryValueEx(key, "WindowGeometry",
			NULL, NULL,
			(LPBYTE) &window_geometry, &size);
	RegCloseKey(key);

	if (e != ERROR_SUCCESS)
		window_geometry_valid = false;
	else
		window_geometry_valid = true;
}

static void write_window_geometry(void)
{
	HKEY key = make_key(REGISTRY_PATH);

	if (window_geometry_valid)
		RegSetValueEx(key, "WindowGeometry", 0,
			REG_BINARY,
			(LPBYTE) &window_geometry, sizeof(window_geometry));
	else
		RegDeleteKey(key, "WindowGeometry");

	RegCloseKey(key);
}

static void unicode_key(uni_t key, unsigned flags)
{
	if ((key >= 1) && (key <= 31))
	{
		dpy_queuekey(-(VKM_CTRLASCII | key));
		return;
	}

	if ((key == ' ') && (GetKeyState(VK_CONTROL) & 0x8000))
	{
		dpy_queuekey(-(VKM_CTRLASCII | 0));
		return;
	}

	dpy_queuekey(key);
}

static bool special_key(int vk, unsigned flags)
{
	if (GetKeyState(VK_LMENU) & 0x8000)
	{
		if (vk == VK_RETURN)
		{
			fullscreen_cb();
			return true;
		}
		else if ((vk == ' ') || isdigit(vk) || isupper(vk))
		{
			dpy_queuekey(-27);
			dpy_queuekey(vk);
			return true;
		}
	}

	switch (vk)
	{
		case VK_DOWN:
		case VK_UP:
		case VK_LEFT:
		case VK_RIGHT:
		case VK_HOME:
		case VK_END:
		case VK_BACK:
		case VK_DELETE:
		case VK_INSERT:
		case VK_NEXT:
		case VK_PRIOR:
		case VK_TAB:
		case VK_RETURN:
		case VK_ESCAPE:
		case VK_F1:
		case VK_F2:
		case VK_F3:
		case VK_F4:
		case VK_F5:
		case VK_F6:
		case VK_F7:
		case VK_F8:
		case VK_F9:
		case VK_F10:
		case VK_F11:
		case VK_F12:
			if (GetKeyState(VK_CONTROL) & 0x8000)
				vk |= VKM_CTRL;
			if (GetKeyState(VK_SHIFT) & 0x8000)
				vk |= VKM_SHIFT;

			dpy_queuekey(-vk);
			return true;
	}

	return false;
}

static void paint_cb(HWND window, PAINTSTRUCT* ps, HDC wdc)
{
	int textwidth, textheight;
	glyphcache_getfontsize(&textwidth, &textheight);

	if (!shadow)
		return;

	HDC dc = CreateCompatibleDC(wdc);
	SelectObject(dc, shadow);

	int x1 = ps->rcPaint.left / textwidth;
	x1 -= 1; /* because of overlapping characters */
	if (x1 < 0)
		x1 = 0;

	HBRUSH blackbrush = CreateSolidBrush(colourmap[COLOUR_BLACK]);
	HPEN dimpen = CreatePen(PS_SOLID, 0, colourmap[COLOUR_DIM]);
	HPEN normalpen = CreatePen(PS_SOLID, 0, colourmap[COLOUR_NORMAL]);
	HPEN brightpen = CreatePen(PS_SOLID, 0, colourmap[COLOUR_BRIGHT]);

	int y1 = ps->rcPaint.top/textheight;
	int x2 = ps->rcPaint.right/textwidth;
	x2 += 1; /* because of overlapping characters */
	if (x2 >= screenwidth)
	{
		RECT r = {screenwidth*textwidth, 0, ps->rcPaint.right, ps->rcPaint.bottom};
		FillRect(dc, &r, blackbrush);
		x2 = screenwidth;
	}

	int y2 = ps->rcPaint.bottom / textheight;
	if (y2 >= screenheight)
	{
		RECT r = {0, screenheight*textheight, ps->rcPaint.right, ps->rcPaint.bottom};
		FillRect(dc, &r, blackbrush);
		y2 = screenheight-1;
	}


	for (int y = y1; y <= y2; y++)
	{
		int sy = y * textheight;

		/* Clear this line (or at least the part of it we're drawing). */

		RECT r = {ps->rcPaint.left, sy, ps->rcPaint.right, sy+textheight};
		FillRect(dc, &r, blackbrush);

		/* Draw the actual text. */

		for (int x = x1; x < x2; x++)
		{
			int seq = y*screenwidth + x;
			int sx = x * textwidth;

			unsigned int id = frontbuffer[seq];
			struct glyph* glyph = glyphcache_getglyph(id, dc);
			if (glyph)
			{
				BitBlt(dc, sx+glyph->xoffset, sy+glyph->yoffset,
					glyph->realwidth, glyph->realheight,
					glyph->dc, 0, 0, SRCCOPY);

				if (id & DPY_UNDERLINE)
				{
					if (id & DPY_BRIGHT)
						SelectObject(dc, brightpen);
					else if (id & DPY_DIM)
						SelectObject(dc, dimpen);
					else
						SelectObject(dc, normalpen);

					MoveToEx(dc, sx, sy+textheight-1, NULL);
					LineTo(dc, sx+glyph->width, sy+textheight-1);
				}
			}
		}

		/* Now go through and invert any characters which are in reverse. */

		for (int x = x1; x < x2; x++)
		{
			int seq = y*screenwidth + x;
			int sx = x * textwidth;

			unsigned int id = frontbuffer[seq];
			if (id & DPY_REVERSE)
			{
				int w;
				struct glyph* glyph = glyphcache_getglyph(id, dc);
				if (glyph)
					w = glyph->width;
				else
					w = textwidth;

				BitBlt(dc, sx, sy, w, textheight, NULL, 0, 0, DSTINVERT);
			}
		}
	}

	/* Draw the cursor caret. */

	if (cursorshown)
	{
		int x = cursorx*textwidth;
		int y = cursory*textheight;

		SelectObject(dc, brightpen);
		MoveToEx(dc, x, y, NULL);
		LineTo(dc, x, y+textheight);
		SetPixelV(dc, x-1, y-1, 0xffffff);
		SetPixelV(dc, x+1, y-1, 0xffffff);
		SetPixelV(dc, x-1, y+textheight, 0xffffff);
		SetPixelV(dc, x+1, y+textheight, 0xffffff);
	}


	DeleteObject(brightpen);
	DeleteObject(normalpen);
	DeleteObject(dimpen);
	DeleteObject(blackbrush);

	BitBlt(wdc,
		ps->rcPaint.left, ps->rcPaint.top,
		ps->rcPaint.right - ps->rcPaint.left,
		ps->rcPaint.bottom - ps->rcPaint.top,
		dc,
		ps->rcPaint.left, ps->rcPaint.top,
		SRCCOPY);

	DeleteDC(dc);
}

static void setfont_cb(void)
{
	CHOOSEFONT cf;
	memset(&cf, 0, sizeof(cf));
	cf.lStructSize = sizeof(cf);
	cf.hwndOwner = window;
	cf.lpLogFont = &fontlf;
	cf.Flags = CF_INITTOLOGFONTSTRUCT | CF_FIXEDPITCHONLY | CF_SCREENFONTS;
	cf.nFontType = SCREEN_FONTTYPE;

	if (ChooseFont(&cf))
	{
		write_default_font();

		HDC dc = GetDC(window);
		glyphcache_deinit();
		glyphcache_init(dc, &fontlf);
		ReleaseDC(window, dc);

		resize_buffer(false);
	}
}

static void setcolour_cb(int c)
{
	CHOOSECOLOR cc = {sizeof(cc)};
	cc.hwndOwner = window;
	cc.Flags = CC_ANYCOLOR | CC_RGBINIT;
	cc.rgbResult = colourmap[c];
	cc.lpCustColors = custom_colours;

	if (ChooseColor(&cc))
	{
		colourmap[c] = cc.rgbResult;
		write_colourmap();

		glyphcache_flush();
		resize_buffer(true);
	}
}

static void fullscreen_cb(void)
{
	if (!isfullscreen)
	{
		window_geometry_valid = true;
		GetWindowRect(window, &window_geometry);
		write_window_geometry();
	}

	isfullscreen = !isfullscreen;
	if (isfullscreen)
		switch_to_full_screen();
	else
		switch_to_windowed();

	resize_buffer(false);
}

static void create_cb(void)
{
	/* Initialise the glyph cache. */

	read_colourmap();
	read_default_font();

	HDC dc = GetDC(window);
	glyphcache_init(dc, &fontlf);
	ReleaseDC(window, dc);
}

static void sizing_cb(int type, RECT* r)
{
	int w = r->right - r->left;
	if (w < 100)
		w = 100;
	int h = r->bottom - r->top;
	if (h < 100)
		h = 100;

	switch (type)
	{
		case WMSZ_LEFT:
		case WMSZ_TOPLEFT:
		case WMSZ_BOTTOMLEFT:
			r->left = r->right - w;
			break;

		case WMSZ_RIGHT:
		case WMSZ_TOPRIGHT:
		case WMSZ_BOTTOMRIGHT:
			r->right = r->left + w;
			break;
	}

	switch (type)
	{
		case WMSZ_TOP:
		case WMSZ_TOPLEFT:
		case WMSZ_TOPRIGHT:
			r->top = r->bottom - h;
			break;

		case WMSZ_BOTTOM:
		case WMSZ_BOTTOMLEFT:
		case WMSZ_BOTTOMRIGHT:
			r->bottom = r->top + h;
			break;
	}
}

static LRESULT CALLBACK window_cb(HWND window, UINT message,
		WPARAM wparam, LPARAM lparam)
{
	dpy_flushkeys();

	switch (message)
	{
		case WM_CLOSE:
			return 0;

		case WM_EXITSIZEMOVE:
			if (!isfullscreen)
			{
				window_geometry_valid = true;
				GetWindowRect(window, &window_geometry);
				write_window_geometry();
			}
			break;

		case WM_SIZE:
			if (!window_created)
			{
				create_cb();
				window_created = true;
			}
			resize_shadow(lparam & 0xffff, lparam >> 16);
			resize_buffer(false);
			break;

		case WM_SIZING:
			sizing_cb(wparam, (RECT*) lparam);
			goto delegate;

		case WM_ERASEBKGND:
		    return 1;

		case WM_PAINT:
		{
			PAINTSTRUCT ps;
			BeginPaint(window, &ps);

			paint_cb(window, &ps, ps.hdc);

			EndPaint(window, &ps);
			break;
		}

		case WM_PRINTCLIENT:
		{
			PAINTSTRUCT ps;
			ps.hdc = (HDC) wparam;
			GetClientRect(window, &ps.rcPaint);
			paint_cb(window, &ps, ps.hdc);
			break;
		}

		case WM_CHAR:
		{
			unicode_key(wparam, lparam);
			break;
		}

		case WM_KEYDOWN:
		case WM_SYSKEYDOWN:
		{
			if (special_key(wparam, lparam))
				return 1;
			break;
		}

		case WM_SYSCOMMAND:
		{
			switch (wparam)
			{
				case MENUITEM_SETFONT:
					setfont_cb();
					break;

				case MENUITEM_SETBGCOL:
					setcolour_cb(COLOUR_BLACK);
					break;
				case MENUITEM_SETDIMCOL:
					setcolour_cb(COLOUR_DIM);
					break;
				case MENUITEM_SETNORMALCOL:
					setcolour_cb(COLOUR_NORMAL);
					break;
				case MENUITEM_SETBRIGHTCOL:
					setcolour_cb(COLOUR_BRIGHT);
					break;

				case MENUITEM_FULLSCREEN:
					fullscreen_cb();
					break;
			}

			goto delegate;
		}

		case WM_TIMER:
		{
			if (wparam == TIMEOUT_TIMER_ID)
			{
				dpy_queuekey(-VK_TIMEOUT);
				break;
			}
			goto delegate;
		}

		delegate:
		default:
			return DefWindowProcW(window, message, wparam, lparam);
	}

	return 0;
}

void dpy_init(const char* argv[])
{
	SystemParametersInfo(SPI_SETFONTSMOOTHING,
			 TRUE, 0,
			 SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);
	SystemParametersInfo(SPI_SETFONTSMOOTHINGTYPE,
			 0, (PVOID)FE_FONTSMOOTHINGCLEARTYPE,
			 SPIF_UPDATEINIFILE | SPIF_SENDCHANGE);

	read_window_geometry();
}

static void resize_shadow(int width, int height)
{
	if (shadow && (shadowwidth == width) && (shadowheight == height))
		return;
	if (shadow)
		DeleteObject(shadow);

	HDC dc = GetDC(window);

	shadow = CreateCompatibleBitmap(dc, width, height);
	shadowwidth = width;
	shadowheight = height;

	ReleaseDC(window, dc);
}

static void resize_buffer(bool force)
{
	RECT rect;
	int e = GetClientRect(window, &rect);
	if (!e)
		SystemParametersInfo(SPI_GETWORKAREA, sizeof(RECT), &rect, 0);

	int textwidth, textheight;
	glyphcache_getfontsize(&textwidth, &textheight);

	int w = rect.right / textwidth;
	int h = rect.bottom / textheight;

	if (force || (w != screenwidth) || (h != screenheight))
	{
		glyphcache_flush();

		/* Wipe the character storage. */

		screenwidth = w;
		screenheight = h;

		frontbuffer = realloc(frontbuffer, sizeof(unsigned int) * w * h);
		backbuffer = realloc(backbuffer, sizeof(unsigned int) * w * h);

		for (int p = 0; p < (w * h); p++)
		{
			frontbuffer[p] = 0;
			backbuffer[p] = DEFAULT_CHAR;
		}

		/* Tell the main app that the screen has changed size; it'll
		 * redraw the character storage. */

		dpy_queuekey(-VK_RESIZE);
	}

	/* The front end will redraw the content area, if necessary, but it
	 * doesn't know anything about the screen borders. We need to force
	 * them to be redrawn as well. */

	RECT r;
	r = rect;
	r.left = w * textwidth;
	InvalidateRect(window, &r, 0);

	r = rect;
	r.top = h * textheight;
	InvalidateRect(window, &r, 0);
}

/* Actually invalidates a 3x3 square around the character, to deal with
 * overdraw. */
static void invalidate_character_at(int x, int y)
{
	int textwidth, textheight;
	glyphcache_getfontsize(&textwidth, &textheight);

	RECT r;
	r.left = cursorx * textwidth - 1;
	r.top = cursory * textheight - 1;
	r.right = r.left + textwidth + 2;
	r.bottom = r.top + textheight + 2;
	InvalidateRect(window, &r, 0);
}

static void insert_item_on_menu(const char* msg, int id, HMENU menu)
{
	MENUITEMINFO mii = {sizeof(mii)};
	mii.fMask = MIIM_FTYPE | MIIM_STRING | MIIM_ID;
	mii.fType = MFT_STRING;
	mii.dwTypeData = (char*) msg;
	mii.cch = strlen(msg);
	mii.wID = id;

	int count = GetMenuItemCount(menu);
	InsertMenuItem(menu, count+1, TRUE, &mii);
}

static void create_window(void)
{
	if (window)
		DestroyWindow(window);

	/* Create the window. */

	window = CreateWindowW(
		L"WordGrinder",                 /* Class Name */
		L"WordGrinder",                 /* Title */
		WS_OVERLAPPEDWINDOW,            /* Style */
		CW_USEDEFAULT, CW_USEDEFAULT,   /* Position */
		CW_USEDEFAULT, CW_USEDEFAULT,   /* Size */
		NULL,                           /* Parent */
		NULL,                           /* No menu */
		GetModuleHandle(NULL),          /* Instance */
		0);                             /* No special parameters */

	if (window_geometry_valid)
		SetWindowPos(window, HWND_TOP,
			window_geometry.left,
			window_geometry.top,
			window_geometry.right - window_geometry.left,
			window_geometry.bottom - window_geometry.top,
			SWP_NOZORDER);

	/* Add the window menu commands and disable the close button. */

	{
		HMENU menu = GetSystemMenu(window, FALSE);

		MENUITEMINFO mii;
		mii.cbSize = sizeof(mii);

		mii.fMask = MIIM_FTYPE;
		mii.fType = MFT_SEPARATOR;
		int count = GetMenuItemCount(menu);
		InsertMenuItem(menu, count+1, TRUE, &mii);

		insert_item_on_menu("Select display fon&t...",
			MENUITEM_SETFONT, menu);

		insert_item_on_menu("Select &background colour...",
			MENUITEM_SETBGCOL, menu);
		insert_item_on_menu("Select &dim colour...",
			MENUITEM_SETDIMCOL, menu);
		insert_item_on_menu("Select &normal colour...",
			MENUITEM_SETNORMALCOL, menu);
		insert_item_on_menu("Select b&right colour...",
			MENUITEM_SETBRIGHTCOL, menu);

		insert_item_on_menu("&Fullscreen mode\tAlt+Enter",
			MENUITEM_FULLSCREEN, menu);

		EnableMenuItem(menu, SC_CLOSE,
			MF_BYCOMMAND | MF_DISABLED | MF_GRAYED);
	}

	ShowWindow(window, SW_SHOWDEFAULT);
}

static void switch_to_full_screen(void)
{
	HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);

	MONITORINFO mi;
	mi.cbSize = sizeof(mi);
	GetMonitorInfo(monitor, &mi);

	GetWindowPlacement(window, &nonFullScreenSize);

	uint32_t style = GetWindowLong(window, GWL_STYLE);
	SetWindowLong(window, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
	SetWindowPos(window, HWND_TOP,
		mi.rcMonitor.left,              /* x */
		mi.rcMonitor.top,               /* y */
		mi.rcMonitor.right - mi.rcMonitor.left, /* width */
		mi.rcMonitor.bottom - mi.rcMonitor.top, /* height */
		SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
}

static void switch_to_windowed(void)
{
	uint32_t style = GetWindowLong(window, GWL_STYLE);
	SetWindowLong(window, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
	SetWindowPlacement(window, &nonFullScreenSize);
	SetWindowPos(window, NULL, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
}

void dpy_start(void)
{
	/* Register our window class. */

	{
		WNDCLASSW wc;
		wc.style = CS_OWNDC;
		wc.lpfnWndProc = window_cb;
		wc.cbClsExtra = 0;
		wc.cbWndExtra = 0;
		wc.hInstance = GetModuleHandle(NULL);
		wc.hIcon = LoadIcon(wc.hInstance, MAKEINTRESOURCE(101));
		wc.hCursor = LoadCursor(NULL, IDC_ARROW);
		wc.hbrBackground = NULL;
		wc.lpszMenuName = NULL;
		wc.lpszClassName = L"WordGrinder";

		if (!RegisterClassW(&wc))
		{
			fprintf(stderr, "Unable to register window class.\n");
			exit(-1);
		}
	}

	create_window();
}

void dpy_shutdown(void)
{
	free(frontbuffer);
	free(backbuffer);
	glyphcache_deinit();
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
	int textwidth, textheight;
	glyphcache_getfontsize(&textwidth, &textheight);

	for (int y=0; y<screenheight; y++)
	{
		unsigned int* front = frontbuffer + y*screenwidth;
		unsigned int* back = backbuffer + y*screenwidth;
		if (memcmp(front, back, screenwidth * sizeof(*backbuffer)) != 0)
		{
			memcpy(front, back, screenwidth * sizeof(*backbuffer));

			int sy = y*textheight;
			RECT r = {0, sy, screenwidth*textwidth, sy+textheight};
			InvalidateRect(window, &r, 0);
		}
	}

	invalidate_character_at(cursorx, cursory);
	UpdateWindow(window);
}

void dpy_setcursor(int x, int y, bool shown)
{
	invalidate_character_at(cursorx, cursory);
	invalidate_character_at(x, y);

	cursorx = x;
	cursory = y;
	cursorshown = shown;

	UpdateWindow(window);
}

void dpy_setattr(int andmask, int ormask)
{
	defaultattr &= andmask;
	defaultattr |= ormask;
}

void dpy_writechar(int x, int y, uni_t c)
{
	if ((x < 0) || (y < 0) || (x >= screenwidth) || (y >= screenheight))
		return;

	backbuffer[y*screenwidth + x] = (c<<8) | defaultattr;
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
	for (int y = y1; y <= y2; y++)
		for (int x = x1; x <= x2; x++)
			dpy_writechar(x, y, (' '<<8) | defaultattr);
}

const char* dpy_getkeyname(uni_t k)
{
	switch (-k)
	{
		case VK_RESIZE:      return "KEY_RESIZE";
		case VK_TIMEOUT:     return "KEY_TIMEOUT";
		case VK_REDRAW:      return "KEY_REDRAW";
	}

	int mods = -k;
	int key = (-k & 0xFF);
	static char buffer[32];

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
		case VK_NUMLOCK:     return NULL;

		case VK_DOWN:        template = "DOWN"; break;
		case VK_UP:          template = "UP"; break;
		case VK_LEFT:        template = "LEFT"; break;
		case VK_RIGHT:       template = "RIGHT"; break;
		case VK_HOME:        template = "HOME"; break;
		case VK_END:         template = "END"; break;
		case VK_BACK:        template = "BACKSPACE"; break;
		case VK_DELETE:      template = "DELETE"; break;
		case VK_INSERT:      template = "INSERT"; break;
		case VK_NEXT:        template = "PGDN"; break;
		case VK_PRIOR:       template = "PGUP"; break;
		case VK_TAB:         template = "TAB"; break;
		case VK_RETURN:      template = "RETURN"; break;
		case VK_ESCAPE:      template = "ESCAPE"; break;
	}

	if (template)
	{
		sprintf(buffer, "KEY_%s%s%s",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "^" : "",
				template);
		return buffer;
	}

	if ((key >= VK_F1) && (key <= (VK_F24)))
	{
		sprintf(buffer, "KEY_%s%sF%d",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "^" : "",
				key - VK_F1 + 1);
		return buffer;
	}

	sprintf(buffer, "KEY_UNKNOWN_%d", -k);
	return buffer;
}
