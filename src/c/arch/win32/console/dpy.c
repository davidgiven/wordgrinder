/* © 2008 David Given.
 * WordGrinder is licensed under the MIT open source license. See the COPYING
 * file in this distribution for the full text.
 */

#include "globals.h"
#include <string.h>
#include <windows.h>

#define VKM_SHIFT 0x100
#define VKM_CTRL 0x200
#define VKM_CTRLASCII 0x400

#define CTRL_PRESSED (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED)

static HANDLE cin = INVALID_HANDLE_VALUE;
static HANDLE cout = INVALID_HANDLE_VALUE;
static CONSOLE_SCREEN_BUFFER_INFO csbi;
static CHAR_INFO* buffer = NULL;
static CHAR_INFO defaultChar;
static int screenWidth;
static int screenHeight;

static uni_t queued[4];
static int numqueued = 0;

static uni_t dequeue(void)
{
    uni_t c = queued[0];
    queued[0] = queued[1];
    queued[1] = queued[2];
    queued[2] = queued[3];
    numqueued--;
    return c;
}

static void queue(uni_t c)
{
    if (numqueued >= (sizeof(queued) / sizeof(*queued)))
        return;

    queued[numqueued] = c;
    numqueued++;
}

void dpy_init(const char* argv[]) {}

static bool update_buffer_info(void)
{
    GetConsoleScreenBufferInfo(cout, &csbi);

    int newscreenWidth = 1 + csbi.srWindow.Right - csbi.srWindow.Left;
    int newscreenHeight = 1 + csbi.srWindow.Bottom - csbi.srWindow.Top;
    if ((newscreenWidth != screenWidth) || (newscreenHeight != screenHeight))
    {
        screenWidth = newscreenWidth;
        screenHeight = newscreenHeight;

        free(buffer);
        buffer = calloc(sizeof(*buffer), screenWidth * screenHeight);

        return true;
    }

    return false;
}

void dpy_start(void)
{
    cin = GetStdHandle(STD_INPUT_HANDLE);
    if (cin == INVALID_HANDLE_VALUE)
    {
        AllocConsole();
        cin = GetStdHandle(STD_INPUT_HANDLE);
    }
    cout = GetStdHandle(STD_OUTPUT_HANDLE);

    SetConsoleMode(cin, ENABLE_WINDOW_INPUT | ENABLE_MOUSE_INPUT);

    defaultChar.Char.UnicodeChar = ' ';
    defaultChar.Attributes = 0x07;

    SetConsoleTitleA("WordGrinder");

    update_buffer_info();
}

void dpy_shutdown(void)
{
    dpy_clearscreen();
    dpy_setcursor(0, 0, true);
    dpy_sync();
    free(buffer);
}

void dpy_clearscreen(void)
{
    dpy_cleararea(0, 0, screenWidth - 1, screenHeight - 1);
}

void dpy_getscreensize(int* x, int* y)
{
    *x = screenWidth;
    *y = screenHeight;
}

void dpy_getmouse(uni_t key, int* x, int* y, bool* p)
{
    x = y = 0;
    p = false;
}

void dpy_sync(void)
{
    COORD buffersize = {screenWidth, screenHeight};
    COORD buffercoord = {0, 0};
    SMALL_RECT destregion = csbi.srWindow;

    WriteConsoleOutputW(cout, buffer, buffersize, buffercoord, &destregion);
}

void dpy_setcursor(int x, int y, bool shown)
{
    COORD coord = {x + csbi.srWindow.Left, y + csbi.srWindow.Top};
    SetConsoleCursorPosition(cout, coord);
}

void dpy_setattr(int andmask, int ormask)
{
    static int attr = 0;
    attr &= andmask;
    attr |= ormask;

    int fg = 0x7;
    int bg = 0;
    if (attr & DPY_UNDERLINE)
        fg = FOREGROUND_RED | FOREGROUND_GREEN;
    if (attr & DPY_DIM)
        fg = FOREGROUND_BLUE;
    if (attr & (DPY_BOLD | DPY_ITALIC))
        fg |= FOREGROUND_INTENSITY;
    if (attr & DPY_REVERSE)
    {
        int i = fg;
        fg = bg;
        bg = i | FOREGROUND_INTENSITY;
    }

    defaultChar.Attributes = (bg << 4) | fg;
    ;
}

void dpy_setcolour(const colour_t* fg, const colour_t* bg) {}

void dpy_writechar(int x, int y, uni_t c)
{
    if ((x < 0) || (y < 0) || (x >= screenWidth) || (y >= screenHeight))
        return;

    buffer[y * screenWidth + x] = defaultChar;
    buffer[y * screenWidth + x].Char.UnicodeChar = c;
}

static void clipBounds(int* x, int* y)
{
    if (*x < 0)
        *x = 0;
    if (*x >= screenWidth)
        *x = screenWidth - 1;
    if (*y < 0)
        *y = 0;
    if (*y >= screenHeight)
        *y = screenHeight - 1;
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
    clipBounds(&x1, &y1);
    clipBounds(&x2, &y2);

    for (int y = y1; y <= y2; y++)
        for (int x = x1; x <= x2; x++)
            buffer[y * screenWidth + x] = defaultChar;
}

static bool get_key_code(KEY_EVENT_RECORD* event, uni_t* r1, uni_t* r2)
{
    if (!event->bKeyDown)
        return false;

    int vk = event->wVirtualKeyCode;
    if ((vk == VK_SHIFT) || (vk == VK_CONTROL) || (vk == VK_MENU))
        return false;

    uni_t c = event->uChar.UnicodeChar;
    int state = event->dwControlKeyState;

    *r1 = *r2 = 0;

    /* Special handling for CTRL+SPACE. */

    if ((vk == VK_SPACE) && (state & CTRL_PRESSED))
    {
        int mods = VKM_CTRLASCII;
        if (state & SHIFT_PRESSED)
            mods |= VK_SHIFT;

        *r1 = -(mods | 0);
        return true;
    }

    /* Distinguish between CTRL+char and special keys... */

    if ((vk == VK_TAB) || (vk == VK_RETURN) || (vk == VK_BACK) ||
        (vk == VK_ESCAPE))
        c = 0;

    /* CTRL + printable character. */

    if ((c > 0) && (c < 32))
    {
        int mods = VKM_CTRLASCII;
        if (state & SHIFT_PRESSED)
            mods |= VK_SHIFT;

        *r1 = -(mods | c);
        return true;
    }

    /* Control keys. */

    if (c == 0)
    {
        int mods = 0;

        if (state & (LEFT_CTRL_PRESSED | RIGHT_CTRL_PRESSED))
            mods |= VKM_CTRL;

        if (state & SHIFT_PRESSED)
            mods |= VKM_SHIFT;

        *r1 = -(vk | mods);
        return true;
    }

    /* Anything else must be printable. */

    if (emu_wcwidth(c) > 0)
    {
        if (state & (LEFT_ALT_PRESSED | RIGHT_ALT_PRESSED))
        {
            *r1 = -27;
            *r2 = c;
            return true;
        }

        *r1 = c;
        return true;
    }
    return false;
}

uni_t dpy_getchar(double timeout)
{
    for (;;)
    {
        if (numqueued)
            return dequeue();

        INPUT_RECORD buffer;
        DWORD numread;
        if (timeout != -1)
            if (WaitForSingleObject(cin, timeout * 1000) == WAIT_TIMEOUT)
                return -KEY_TIMEOUT;

        ReadConsoleInputW(cin, &buffer, 1, &numread);

        switch (buffer.EventType)
        {
            case KEY_EVENT:
            {
                uni_t q1, q2;
                if (get_key_code(&buffer.Event.KeyEvent, &q1, &q2))
                {
                    if (q1)
                        queue(q1);
                    if (q2)
                        queue(q2);
                }
            }
        }

        if (update_buffer_info())
            queue(-KEY_RESIZE);
    }
}

const char* dpy_getkeyname(uni_t k)
{
    switch (-k)
    {
        case KEY_RESIZE:
            return "KEY_RESIZE";
        case KEY_TIMEOUT:
            return "KEY_TIMEOUT";
    }

    int mods = -k;
    int key = (-k & 0xFF);
    static char buffer[32];

    if (mods & VKM_CTRLASCII)
    {
        sprintf(buffer, "KEY_%s^%c", (mods & VKM_SHIFT) ? "S" : "", key + 64);
        return buffer;
    }

    const char* template = NULL;
    switch (key)
    {
        case VK_NUMLOCK:
            return NULL;

        case VK_DOWN:
            template = "DOWN";
            break;
        case VK_UP:
            template = "UP";
            break;
        case VK_LEFT:
            template = "LEFT";
            break;
        case VK_RIGHT:
            template = "RIGHT";
            break;
        case VK_HOME:
            template = "HOME";
            break;
        case VK_END:
            template = "END";
            break;
        case VK_BACK:
            template = "BACKSPACE";
            break;
        case VK_DELETE:
            template = "DELETE";
            break;
        case VK_INSERT:
            template = "INSERT";
            break;
        case VK_NEXT:
            template = "PGDN";
            break;
        case VK_PRIOR:
            template = "PGUP";
            break;
        case VK_TAB:
            template = "TAB";
            break;
        case VK_RETURN:
            template = "RETURN";
            break;
        case VK_ESCAPE:
            template = "ESCAPE";
            break;
    }

    if (template)
    {
        sprintf(buffer,
            "KEY_%s%s%s",
            (mods & VKM_SHIFT) ? "S" : "",
            (mods & VKM_CTRL) ? "^" : "",
            template);
        return buffer;
    }

    if ((key >= VK_F1) && (key <= (VK_F24)))
    {
        sprintf(buffer,
            "KEY_%s%sF%d",
            (mods & VKM_SHIFT) ? "S" : "",
            (mods & VKM_CTRL) ? "^" : "",
            key - VK_F1 + 1);
        return buffer;
    }

    sprintf(buffer, "KEY_UNKNOWN_%d", -k);
    return buffer;
}
