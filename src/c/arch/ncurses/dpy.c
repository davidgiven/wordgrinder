/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <curses.h>
#include <wctype.h>
#include <sys/time.h>
#include <time.h>
#include "stb_ds.h"

#define KEY_TIMEOUT (KEY_MAX + 1)
#define FIRST_COLOUR_ID 1
#define FIRST_PAIR_ID 1

#if defined WA_ITALIC
static bool use_italics = false;
#endif

static bool use_colours = false;
static int currentAttr = 0;
static short currentPair = 0;

typedef struct
{
    uint8_t fg;
    uint8_t bg;
} pair_t;

static colour_t* colours = NULL;
static pair_t* colourPairs = NULL;

void dpy_init(const char* argv[]) {}

void dpy_start(void)
{
    arrfree(colours);
    arrfree(colourPairs);

    initscr();

    use_colours = has_colors() && can_change_color();
    if (use_colours)
        start_color();

    raw();
    noecho();
    meta(NULL, TRUE);
    nonl();
    idlok(stdscr, TRUE);
    idcok(stdscr, TRUE);
    scrollok(stdscr, FALSE);
    intrflush(stdscr, FALSE);
    // notimeout(stdscr, TRUE);
    keypad(stdscr, TRUE);
    mousemask(ALL_MOUSE_EVENTS|REPORT_MOUSE_POSITION, NULL);
    mouseinterval(0);

#if defined A_ITALIC
    use_italics = !!tigetstr("sitm");
#endif
}

void dpy_shutdown(void)
{
    endwin();
}

void dpy_clearscreen(void)
{
    int w, h;
    getmaxyx(stdscr, h, w);
    dpy_cleararea(0, 0, w - 1, h - 1);
}

void dpy_getscreensize(int* x, int* y)
{
    getmaxyx(stdscr, *y, *x);
}

void dpy_getmouse(uni_t key, int* x, int* y, bool* p)
{
    x = y = 0;
    p = false;
}

void dpy_sync(void)
{
    refresh();
}

void dpy_setcursor(int x, int y, bool shown)
{
    move(y, x);
}

static void update_attrs()
{
    attr_t cattr = 0;
    if (currentAttr & DPY_ITALIC)
    {
#if defined WA_ITALIC
        if (use_italics)
            cattr |= WA_ITALIC;
        else
            cattr |= WA_BOLD;
#else
        cattr |= WA_BOLD;
#endif
    }
    if (currentAttr & DPY_BOLD)
        cattr |= WA_BOLD;
    if (!use_colours && (currentAttr & DPY_BRIGHT))
        cattr |= WA_BOLD;
    if (!use_colours && (currentAttr & DPY_DIM))
        cattr |= WA_DIM;
    if (currentAttr & DPY_UNDERLINE)
        cattr |= WA_UNDERLINE;
    if (currentAttr & DPY_REVERSE)
        cattr |= WA_REVERSE;

    if (use_colours)
        attr_set(cattr, currentPair, NULL);
    else
        attr_set(cattr, 0, NULL);
}

void dpy_setattr(int andmask, int ormask)
{
    currentAttr &= andmask;
    currentAttr |= ormask;

    update_attrs();
}

static int lookup_colour(const colour_t* colour)
{
    for (int i = 0; i < arrlen(colours); i++)
    {
        if ((colours[i].r == colour->r) && (colours[i].g == colour->g) &&
            (colours[i].b == colour->b))
            return i + FIRST_COLOUR_ID;
    }

    int id = arrlen(colours) + FIRST_COLOUR_ID;
    arrpush(colours, *colour);
    init_color(id, colour->r * 1000.0, colour->g * 1000.0, colour->b * 1000.0);
    return id;
}

void dpy_setcolour(const colour_t* fg, const colour_t* bg)
{
    if (!use_colours)
        return;

    int fgc = lookup_colour(fg);
    int bgc = lookup_colour(bg);

    for (int i = 0; i < arrlen(colourPairs); i++)
    {
        pair_t* p = &colourPairs[i];
        if ((p->fg == fgc) && (p->bg == bgc))
        {
            currentPair = FIRST_PAIR_ID + i;
            update_attrs();
            return;
        }
    }

    currentPair = arrlen(colourPairs) + FIRST_PAIR_ID;
    pair_t pair = {fgc, bgc};
    arrpush(colourPairs, pair);

    init_pair(currentPair, fgc, bgc);
    update_attrs();
}

void dpy_writechar(int x, int y, uni_t c)
{
    char buffer[8];
    char* p = buffer;
    writeu8(&p, c);
    *p = '\0';

    mvaddstr(y, x, buffer);
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
    char cc = ' ';

    for (int y = y1; y <= y2; y++)
        for (int x = x1; x <= x2; x++)
            mvaddnstr(y, x, &cc, 1);
}

static int handle_mouse(void)
{
    static int mx = -1;
    static int my = -1;
    static bool p = false;

    MEVENT event;
    getmouse(&event);
    switch (event.bstate)
    {
        case REPORT_MOUSE_POSITION:
            mx = event.x;
            my = event.y;
			if (!p)
				return 0;
            break;

        case BUTTON1_PRESSED:
            mx = event.x;
            my = event.y;
            p = true;
            break;

        case BUTTON1_RELEASED:
            mx = event.x;
            my = event.y;
            p = false;
            break;
    }

    return encode_mouse_event(mx, my, p);
}

uni_t dpy_getchar(double timeout)
{
    struct timeval then;
    gettimeofday(&then, NULL);
    uint64_t thenms = (then.tv_usec / 1000) + ((uint64_t)then.tv_sec * 1000);

    for (;;)
    {

        if (timeout != -1)
        {
            struct timeval now;
            gettimeofday(&now, NULL);
            uint64_t nowms =
                (now.tv_usec / 1000) + ((uint64_t)now.tv_sec * 1000);

            int delay = ((uint64_t)(timeout * 1000)) + nowms - thenms;
            if (delay <= 0)
                return -KEY_TIMEOUT;

            timeout(delay);
        }
        else
            timeout(-1);

        wint_t c;
        int r = get_wch(&c);

        if (r == ERR) /* timeout */
            return -KEY_TIMEOUT;

        if (c == KEY_MOUSE)
            return -handle_mouse();

        if ((r == KEY_CODE_YES) || !iswprint(c)) /* function key */
            return -c;

        if (emu_wcwidth(c) > 0)
            return c;
    }
}

static const char* ncurses_prefix_to_name(const char* s)
{
    if (strcmp(s, "KDC") == 0)
        return "DELETE";
    if (strcmp(s, "kDN") == 0)
        return "DOWN";
    if (strcmp(s, "kEND") == 0)
        return "END";
    if (strcmp(s, "kHOM") == 0)
        return "HOME";
    if (strcmp(s, "kIC") == 0)
        return "INSERT";
    if (strcmp(s, "kLFT") == 0)
        return "LEFT";
    if (strcmp(s, "kNXT") == 0)
        return "PGDN";
    if (strcmp(s, "kPRV") == 0)
        return "PGUP";
    if (strcmp(s, "kRIT") == 0)
        return "RIGHT";
    if (strcmp(s, "kUP") == 0)
        return "UP";

    return s;
}

static const char* ncurses_suffix_to_name(int suffix)
{
    switch (suffix)
    {
        case 3:
            return "A";
        case 4:
            return "SA";
        case 5:
            return "^";
        case 6:
            return "S^";
        case 7:
            return "A^";
    }

    return NULL;
}

const char* dpy_getkeyname(uni_t k)
{
    k = -k;

    switch (k)
    {
        case 127: /* Some misconfigured terminals produce this */
        case KEY_BACKSPACE:
            return "KEY_BACKSPACE";

        case KEY_TIMEOUT:
            return "KEY_TIMEOUT";
        case KEY_DOWN:
            return "KEY_DOWN";
        case KEY_UP:
            return "KEY_UP";
        case KEY_LEFT:
            return "KEY_LEFT";
        case KEY_RIGHT:
            return "KEY_RIGHT";
        case KEY_HOME:
            return "KEY_HOME";
        case KEY_END:
            return "KEY_END";
        case KEY_DC:
            return "KEY_DELETE";
        case KEY_IC:
            return "KEY_INSERT";
        case KEY_NPAGE:
            return "KEY_PGDN";
        case KEY_PPAGE:
            return "KEY_PGUP";
        case KEY_STAB:
            return "KEY_STAB";
        case KEY_CTAB:
            return "KEY_^TAB";
        case KEY_CATAB:
            return "KEY_^ATAB";
        case KEY_ENTER:
            return "KEY_RETURN";
        case KEY_SIC:
            return "KEY_SINSERT";
        case KEY_SDC:
            return "KEY_SDELETE";
        case KEY_SHOME:
            return "KEY_SHOME";
        case KEY_SEND:
            return "KEY_SEND";
        case KEY_SR:
            return "KEY_SUP";
        case KEY_SF:
            return "KEY_SDOWN";
        case KEY_SLEFT:
            return "KEY_SLEFT";
        case KEY_SRIGHT:
            return "KEY_SRIGHT";
        case KEY_MOUSE:
            return "KEY_MOUSE";
        case KEY_RESIZE:
            return "KEY_RESIZE";
        case 13:
            return "KEY_RETURN";
        case 27:
            return "KEY_ESCAPE";
    }

    static char buffer[32];
    if (k < 32)
    {
        sprintf(buffer, "KEY_^%c", k + 'A' - 1);
        return buffer;
    }

    if ((k >= KEY_F0) && (k < (KEY_F0 + 64)))
    {
        sprintf(buffer, "KEY_F%d", k - KEY_F0);
        return buffer;
    }

    const char* name = keyname(k);
    if (name)
    {
        char buf[strlen(name) + 1];
        strcpy(buf, name);

        int prefix = strcspn(buf, "0123456789");
        int suffix = buf[prefix] - '0';
        buf[prefix] = '\0';

        if ((suffix >= 0) && (suffix <= 9))
        {
            const char* ps = ncurses_prefix_to_name(buf);
            const char* ss = ncurses_suffix_to_name(suffix);
            if (ss)
            {
                sprintf(buffer, "KEY_%s%s", ss, ps);
                return buffer;
            }
        }
    }

    sprintf(buffer, "KEY_UNKNOWN_%d (%s)", k, name ? name : "???");
    return buffer;
}
