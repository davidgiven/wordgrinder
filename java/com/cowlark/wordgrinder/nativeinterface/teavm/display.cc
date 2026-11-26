#include "globals.h"
#include "display.h"
#include <cstring>
#include <cstdlib>

void wg_dpy_init(const char* const* argv)
{
    // The backend only reads the argument pointers.
    dpy_init(const_cast<const char**>(argv));
}

void wg_dpy_setcolour(float fr, float fg, float fb, float br, float bg, float bb)
{
    colour_t foreground{fr, fg, fb};
    colour_t background{br, bg, bb};
    dpy_setcolour(&foreground, &background);
}

void wg_dpy_getscreensize(int32_t* size)
{
    int width, height;
    dpy_getscreensize(&width, &height);
    size[0] = width;
    size[1] = height;
}

char* wg_dpy_getkeyname(int32_t key)
{
    std::string name = dpy_getkeyname(key);
    char* result = static_cast<char*>(std::malloc(name.size() + 1));
    if (result)
        std::memcpy(result, name.c_str(), name.size() + 1);
    return result;
}

/* Keep process-exit cleanup within the native backend's lifetime. */
static bool displayRunning = false;
static bool exitHandlerRegistered = false;

void wg_dpy_start(void)
{
    dpy_start();
    displayRunning = true;
    if (!exitHandlerRegistered)
    {
        atexit(wg_dpy_shutdown);
        exitHandlerRegistered = true;
    }
}

void wg_dpy_shutdown(void)
{
    if (displayRunning)
    {
        dpy_shutdown();
        displayRunning = false;
    }
}

void wg_dpy_setattr(int32_t andmask, int32_t ormask)
{
    dpy_setattr(andmask, ormask);
}

void wg_dpy_writechar(int32_t x, int32_t y, int32_t c)
{
    dpy_writechar(x, y, c);
}

void wg_dpy_setcursor(int32_t x, int32_t y, bool shown)
{
    dpy_setcursor(x, y, shown);
}

void wg_dpy_clearscreen(void)
{
    dpy_clearscreen();
}

void wg_dpy_sync(void)
{
    dpy_sync();
}

void wg_dpy_cleararea(int32_t x1, int32_t y1, int32_t x2, int32_t y2)
{
    dpy_cleararea(x1, y1, x2, y2);
}

int32_t wg_dpy_getchar(double timeout)
{
    return dpy_getchar(timeout);
}


// Preserve the native screen layer's locale-dependent character handling.
#if !defined(_WIN32) && !defined(__APPLE__)
#include <langinfo.h>
#endif

int32_t wg_screen_width(int32_t character) { return emu_wcwidth(character); }
bool wg_screen_control(int32_t character) { return iswcntrl(character); }
bool wg_screen_default_unicode(void)
{
#if defined(_WIN32) || defined(__APPLE__)
    return true;
#else
    return strcmp(nl_langinfo(CODESET), "UTF-8") == 0;
#endif
}
