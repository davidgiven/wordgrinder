/* © 2021 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <SDL2/SDL.h>

#define VKM_SHIFT      0x100
#define VKM_CTRL       0x200
#define VKM_CTRLASCII  0x400
#define SDLK_RESIZE     0x1000
#define SDLK_TIMEOUT    0x1001

#define CTRL_PRESSED (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED)

static int screenwidth;
static int screenheight;

void dpy_init(const char* argv[])
{
}

void dpy_start(void)
{
}

void dpy_shutdown(void)
{
}

void dpy_clearscreen(void)
{
}

void dpy_getscreensize(int* x, int* y)
{
	*x = screenwidth;
	*y = screenheight;
}

void dpy_sync(void)
{
}

void dpy_setcursor(int x, int y, bool shown)
{
}

void dpy_setattr(int andmask, int ormask)
{
}

void dpy_writechar(int x, int y, uni_t c)
{
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
}

uni_t dpy_getchar(double timeout)
{
	return 0;
}

const char* dpy_getkeyname(uni_t k)
{
	switch (-k)
	{
		case SDLK_RESIZE:      return "KEY_RESIZE";
		case SDLK_TIMEOUT:     return "KEY_TIMEOUT";
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
		case SDLK_DOWN:        template = "DOWN"; break;
		case SDLK_UP:          template = "UP"; break;
		case SDLK_LEFT:        template = "LEFT"; break;
		case SDLK_RIGHT:       template = "RIGHT"; break;
		case SDLK_HOME:        template = "HOME"; break;
		case SDLK_END:         template = "END"; break;
		case SDLK_BACKSPACE:   template = "BACKSPACE"; break;
		case SDLK_DELETE:      template = "DELETE"; break;
		case SDLK_INSERT:      template = "INSERT"; break;
		case SDLK_PAGEUP:      template = "PGDN"; break;
		case SDLK_PAGEDOWN:    template = "PGUP"; break;
		case SDLK_TAB:         template = "TAB"; break;
		case SDLK_RETURN:      template = "RETURN"; break;
		case SDLK_ESCAPE:      template = "ESCAPE"; break;
	}

	if (template)
	{
		sprintf(buffer, "KEY_%s%s%s",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "C" : "",
				template);
		return buffer;
	}

	if ((key >= SDLK_F1) && (key <= (SDLK_F24)))
	{
		sprintf(buffer, "KEY_%s%sF%d",
				(mods & VKM_SHIFT) ? "S" : "",
				(mods & VKM_CTRL) ? "C" : "",
				key - SDLK_F1 + 1);
		return buffer;
	}

	sprintf(buffer, "KEY_UNKNOWN_%d", -k);
	return buffer;
}
