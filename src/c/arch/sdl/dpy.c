/* © 2021 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <SDL2/SDL.h>
#include "SDL_FontCache.h"

#define VKM_SHIFT       0x10000
#define VKM_CTRL        0x20000
#define VKM_CTRLASCII   0x40000
#define VK_RESIZE     0x80000
#define VK_TIMEOUT    0x80001

static SDL_Window* window;
static SDL_Renderer* renderer;
static int cursorx = 0;
static int cursory = 0;
static bool cursor_shown = false;
static int charwidth;
static int charheight;
static int screenwidth;
static int screenheight;
static uint8_t defaultattr = 0;

static const int font_size = 14;

struct cell_s
{
    uni_t c;
    uint8_t attr;
};

static struct cell_s* screen = NULL;

enum
{
	REGULAR = 0,
	ITALIC = (1<<0),
	BOLD = (1<<1),
};

static FC_Font* fonts[4];

static const SDL_Color background_colour = {0x00, 0x00, 0x00, 0xff};
static const SDL_Color dim_colour        = {0x55, 0x55, 0x55, 0xff};
static const SDL_Color normal_colour     = {0xaa, 0xaa, 0xaa, 0xff};
static const SDL_Color bright_colour     = {0xff, 0xff, 0x00, 0xff};

static void fatal(const char* s, ...)
{
    va_list ap;
    va_start(ap, s);
    fprintf(stderr, "error: ");
    vfprintf(stderr, s, ap);
    fprintf(stderr, "\n");
    va_end(ap);
    exit(1);
}

static void sput(int x, int y, unsigned int id)
{
	if (!screen)
        return;
	if ((x < 0) || (x >= screenwidth))
		return;
	if ((y < 0) || (y >= screenheight))
		return;

    struct cell_s* p = &screen[y*screenwidth + x];
    p->c = id;
    p->attr = defaultattr;
}

static void change_screen_size(void)
{
    int w, h;
    SDL_GetWindowSize(window, &w, &h);
    screenwidth = w / charwidth;
    screenheight = h / charheight;

    free(screen);
    screen = calloc(screenwidth * screenheight, sizeof(struct cell_s));
}

static FC_Font* load_font(const char* filename)
{
    FC_Font* font = FC_CreateFont();  
    if (!FC_LoadFont(font, renderer, filename, font_size, normal_colour, TTF_STYLE_NORMAL))
        fatal("could not load font %s: %s", filename, SDL_GetError());
    return font;
}

void dpy_init(const char* argv[])
{
    if (SDL_Init(SDL_INIT_VIDEO) < 0)
        fatal("could not initialize sdl2: %s", SDL_GetError());

    window = SDL_CreateWindow(
            "WordGrinder",
            SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED,
            640, 480,
            SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE
    );
    if (!window)
        fatal("could not create window: %s", SDL_GetError());
    SDL_StartTextInput();

    renderer = SDL_CreateRenderer(window, -1,
            SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer)
        fatal("could not create renderer: %s", SDL_GetError());
    
    fonts[REGULAR] = load_font("/usr/share/fonts/truetype/fantasque-sans/Normal/TTF/FantasqueSansMono-Regular.ttf");
    fonts[ITALIC] = load_font("/usr/share/fonts/truetype/fantasque-sans/Normal/TTF/FantasqueSansMono-Italic.ttf");
    fonts[BOLD] = load_font("/usr/share/fonts/truetype/fantasque-sans/Normal/TTF/FantasqueSansMono-Bold.ttf");
    fonts[BOLD|ITALIC] = load_font("/usr/share/fonts/truetype/fantasque-sans/Normal/TTF/FantasqueSansMono-BoldItalic.ttf");
    charwidth = FC_GetWidth(fonts[REGULAR], "m");
    charheight = FC_GetLineHeight(fonts[REGULAR]);
    
    change_screen_size();
}

void dpy_start(void)
{
}

void dpy_shutdown(void)
{
    SDL_DestroyWindow(window);
    SDL_Quit();
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
    SDL_SetRenderDrawColor(renderer, background_colour.r, background_colour.g, background_colour.b, 0xff);
    SDL_RenderClear(renderer);

    for (int y = 0; y < screenheight; y++)
    {
        struct cell_s* cp = &screen[y*screenwidth];
        for (int x = 0; x < screenwidth; x++)
        {
            char buffer[8];
            char* p = &buffer[0];
            writeu8(&p, cp->c);
            *p = '\0';

            SDL_Rect r =
            {
                .x = x*charwidth,
                .y = y*charheight,
                .w = charwidth,
                .h = charheight
            };

            SDL_Color fg;
            int attr = cp->attr;
            if (attr & DPY_BRIGHT)
                fg = bright_colour;
            else if (attr & DPY_DIM)
                fg = dim_colour;
            else
                fg = normal_colour;

            if (attr & DPY_REVERSE)
            {
                SDL_SetRenderDrawColor(renderer, fg.r, fg.g, fg.b, 0xff);
                SDL_RenderFillRect(renderer, &r);
                fg = background_colour;
            }

            int style = REGULAR;
            if (attr & DPY_BOLD)
                style |= BOLD;
            if (attr & DPY_ITALIC)
                style |= ITALIC;

            FC_DrawColor(fonts[style], renderer, r.x, r.y, fg, buffer);

            cp++;
        }
    }

    SDL_RenderPresent(renderer);
    SDL_UpdateWindowSurface(window);
}

void dpy_setcursor(int x, int y, bool shown)
{
    cursorx = x;
    cursory = y;
    cursor_shown = shown;
}

void dpy_setattr(int andmask, int ormask)
{
	defaultattr &= andmask;
	defaultattr |= ormask;
}

void dpy_writechar(int x, int y, uni_t c)
{
    sput(x, y, c);
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
    for (int y = y1; y <= y2; y++)
    {
        struct cell_s* p = &screen[y*screenwidth + x1];
        for (int x = x1; x <= x2; x++)
        {
            p->c = 0;
            p->attr = 0;
            p++;
        }
    }
}

uni_t dpy_getchar(double timeout)
{
    SDL_Event e;
    int expiry_ms = SDL_GetTicks() + timeout*1000.0;
    if (timeout == -1)
        expiry_ms = INT_MAX;
    for (;;)
    {
        int now_ms = SDL_GetTicks();
        if (now_ms >= expiry_ms)
            return 0;
        if (SDL_WaitEventTimeout(&e, expiry_ms - now_ms))
        {
            switch (e.type)
            {
                case SDL_QUIT:
                    break;

                case SDL_WINDOWEVENT:
                    switch (e.window.event)
                    {
                        case SDL_WINDOWEVENT_SIZE_CHANGED:
                            change_screen_size();
                            return -VK_RESIZE;
                    }
                    break;
                    
                case SDL_TEXTINPUT:
		        {
                    const char* p = &e.text.text[0];
                    uni_t key = readu8(&p);
                    if (!key)
                        break;

                    return key;
                }

                case SDL_KEYDOWN:
                {
                    uni_t key = e.key.keysym.sym;
                    if ((key >= 0x20) && (key < 0x80))
                    {
                        if (e.key.keysym.mod & KMOD_CTRL)
                        {
                            key = toupper(key);
                            if (key == ' ')
                            {
                                key = -(VKM_CTRLASCII | 0);
                                goto check_shift;
                            }
                            if ((key >= 'A') && (key <= 'Z'))
                            {
                                key = (key & 0x1f) | VKM_CTRLASCII;
                                goto check_shift;
                            }
                        }
                        break;
                    }
                    
                    if (e.key.keysym.mod & KMOD_CTRL)
                        key |= VKM_CTRL;
                check_shift:
                    if (e.key.keysym.mod & KMOD_SHIFT)
                        key |= VKM_SHIFT;
                    key = -key;
                    return key;
                }
            }
        }
    }

    return VK_TIMEOUT;
}

const char* dpy_getkeyname(uni_t k)
{
    switch (-k)
    {
        case VK_RESIZE:      return "KEY_RESIZE";
        case VK_TIMEOUT:     return "KEY_TIMEOUT";
    }

    int mods = -k;
    int key = (-k & 0xfff0ffff);
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
        case SDLK_PAGEUP:      template = "PGUP"; break;
        case SDLK_PAGEDOWN:    template = "PGDN"; break;
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

// vim: sw=4 ts=4 et

