/* C interface to the C++ display backend, for TeaVM-generated code. */
#ifndef WORDGRINDER_DISPLAY_H
#define WORDGRINDER_DISPLAY_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void wg_dpy_init(const char* const* argv);
void wg_dpy_setcolour(float fr, float fg, float fb, float br, float bg, float bb);
void wg_dpy_getscreensize(int32_t* size);
/* Returns a malloc-allocated string; the caller must free it. */
char* wg_dpy_getkeyname(int32_t key);
void wg_dpy_start(void);
void wg_dpy_shutdown(void);
void wg_dpy_setattr(int32_t andmask, int32_t ormask);
void wg_dpy_writechar(int32_t x, int32_t y, int32_t c);
void wg_dpy_setcursor(int32_t x, int32_t y, bool shown);
void wg_dpy_clearscreen(void);
void wg_dpy_sync(void);
void wg_dpy_cleararea(int32_t x1, int32_t y1, int32_t x2, int32_t y2);
int32_t wg_dpy_getchar(double timeout);

int32_t wg_screen_width(int32_t character);
bool wg_screen_control(int32_t character);
bool wg_screen_default_unicode(void);

#ifdef __cplusplus
}
#endif

#endif
