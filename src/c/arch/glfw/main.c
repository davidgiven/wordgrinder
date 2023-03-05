#include "globals.h"
#include "gui.h"
#include "stb_ds.h"
#include <GLFW/glfw3.h>

#define VKM_SHIFT 0x10000
#define VKM_CTRL 0x20000
#define VKM_CTRLASCII 0x40000

static GLFWwindow* window;
static int currentAttr;
static colour_t currentFg;
static colour_t currentBg;
static int screenWidth;
static int screenHeight;
static cell_t* screen;
static int cursorx;
static int cursory;
static bool cursorShown;
static uni_t* keyboardQueue;
static bool pendingRedraw;
static bool fullScreen;
static int oldWindowX;
static int oldWindowY;
static int oldWindowW;
static int oldWindowH;

static void queueRedraw()
{
    if (!pendingRedraw)
    {
        arrins(keyboardQueue, 0, -KEY_RESIZE);
        pendingRedraw = true;
    }
}

static int convert_numpad_key(int key)
{
    switch (key)
    {
        case GLFW_KEY_KP_0:
            return GLFW_KEY_INSERT;
        case GLFW_KEY_KP_1:
            return GLFW_KEY_END;
        case GLFW_KEY_KP_2:
            return GLFW_KEY_DOWN;
        case GLFW_KEY_KP_3:
            return GLFW_KEY_PAGE_DOWN;
        case GLFW_KEY_KP_4:
            return GLFW_KEY_LEFT;
        case GLFW_KEY_KP_5:
            return 0;
        case GLFW_KEY_KP_6:
            return GLFW_KEY_RIGHT;
        case GLFW_KEY_KP_7:
            return GLFW_KEY_HOME;
        case GLFW_KEY_KP_8:
            return GLFW_KEY_UP;
        case GLFW_KEY_KP_9:
            return GLFW_KEY_PAGE_UP;
        case GLFW_KEY_KP_DECIMAL:
            return GLFW_KEY_DELETE;
    }
    return key;
}

static void key_cb(
    GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (action == GLFW_RELEASE)
        return;

    if (mods & GLFW_MOD_CONTROL)
    {
        if ((key >= GLFW_KEY_A) && (key <= GLFW_KEY_Z))
        {
            arrins(keyboardQueue, 0, -((key - GLFW_KEY_A + 1) | VKM_CTRLASCII));
            return;
        }
        if (key == GLFW_KEY_SPACE)
        {
            arrins(keyboardQueue, 0, -VKM_CTRLASCII);
            return;
        }
    }
    if (mods & GLFW_MOD_ALT)
    {
        if (key == GLFW_KEY_ENTER)
        {
            /* Toggle full screen. */

            if (fullScreen)
            {
                glfwSetWindowMonitor(window,
                    NULL,
                    oldWindowX,
                    oldWindowY,
                    oldWindowW,
                    oldWindowH,
                    0);
                fullScreen = false;
            }
            else
            {
                glfwGetWindowPos(window, &oldWindowX, &oldWindowY);
                glfwGetWindowSize(window, &oldWindowW, &oldWindowH);
                GLFWmonitor* monitor = glfwGetPrimaryMonitor();
                const GLFWvidmode* mode = glfwGetVideoMode(monitor);
                glfwSetWindowMonitor(window,
                    monitor,
                    0,
                    0,
                    mode->width,
                    mode->height,
                    mode->refreshRate);
                fullScreen = true;
            }

            return;
        }
        if ((key >= GLFW_KEY_A) && (key <= GLFW_KEY_Z))
        {
            arrins(keyboardQueue, 0, -GLFW_KEY_ESCAPE);
            arrins(keyboardQueue, 0, 'A' + (key - GLFW_KEY_A));
            return;
        }
    }

    if (!(mods & GLFW_MOD_NUM_LOCK))
    {
        key = convert_numpad_key(key);
        if (!key)
            return;
    }

    switch (key)
    {
        default:
            if ((key < GLFW_KEY_F1) || (key > GLFW_KEY_F25))
                return;

            /* fall through */
        case GLFW_KEY_ESCAPE:
        case GLFW_KEY_ENTER:
        case GLFW_KEY_TAB:
        case GLFW_KEY_BACKSPACE:
        case GLFW_KEY_INSERT:
        case GLFW_KEY_DELETE:
        case GLFW_KEY_RIGHT:
        case GLFW_KEY_LEFT:
        case GLFW_KEY_DOWN:
        case GLFW_KEY_UP:
        case GLFW_KEY_PAGE_UP:
        case GLFW_KEY_PAGE_DOWN:
        case GLFW_KEY_HOME:
        case GLFW_KEY_END:
        {
            int imods = 0;
            if (mods & GLFW_MOD_SHIFT)
                imods |= VKM_SHIFT;
            if (mods & GLFW_MOD_CONTROL)
                imods |= VKM_CTRL;
            arrins(keyboardQueue, 0, -(key | imods));
            break;
        }
    }
}

static void character_cb(GLFWwindow* window, unsigned int c)
{
    arrins(keyboardQueue, 0, c);
}

static void resize_cb(GLFWwindow* window, int width, int height)
{
    queueRedraw();
}

static void refresh_cb(GLFWwindow* window)
{
    queueRedraw();
}

static void close_cb(GLFWwindow* window)
{
    arrins(keyboardQueue, 0, -KEY_QUIT);
}

static void handle_mouse(double x, double y, bool b)
{
    static bool motion = false;
    if (!b && !motion)
        return;
    motion = b;

    int ix = x / fontWidth;
    int iy = y / fontHeight;
    static int oldix = -1;
    static int oldiy = -1;
    static bool oldb = false;

    if ((ix != oldix) || (iy != oldiy) || (b != oldb))
    {
        arrins(keyboardQueue, 0, -encode_mouse_event(ix, iy, b));
        oldix = ix;
        oldiy = iy;
        oldb = b;
    }
}

static void mousepos_cb(GLFWwindow* window, double x, double y)
{
    handle_mouse(x, y, glfwGetMouseButton(window, GLFW_MOUSE_BUTTON_LEFT));
}

static void mousebutton_cb(GLFWwindow* window, int button, int action, int mods)
{
    switch (button)
    {
        case GLFW_MOUSE_BUTTON_LEFT:
        {
            double x, y;
            glfwGetCursorPos(window, &x, &y);
            handle_mouse(x, y, (action == GLFW_PRESS) ? true : false);
            break;
        }

        case GLFW_MOUSE_BUTTON_RIGHT:
            if (action == GLFW_PRESS)
                arrins(keyboardQueue, 0, -KEY_MENU);
            break;
    }
}

void scroll_cb(GLFWwindow* window, double xoffset, double yoffset)
{
    if (yoffset < 0)
        arrins(keyboardQueue, 0, -KEY_SCROLLDOWN);
    else
        arrins(keyboardQueue, 0, -KEY_SCROLLUP);
}

void dpy_init(const char* argv[]) {}

void dpy_start(void)
{
    if (!glfwInit())
    {
        fprintf(stderr, "OpenGL initialisation failed\n");
        exit(1);
    }

    window = glfwCreateWindow(get_ivar("window_width"),
        get_ivar("window_height"),
        "WordGrinder",
        NULL,
        NULL);
    glfwMakeContextCurrent(window);
    glfwSwapInterval(1);

    glfwSetInputMode(window, GLFW_LOCK_KEY_MODS, GLFW_TRUE);
    glfwSetCursor(window, glfwCreateStandardCursor(GLFW_IBEAM_CURSOR));
    glfwSetKeyCallback(window, key_cb);
    glfwSetCharCallback(window, character_cb);
    glfwSetCursorPosCallback(window, mousepos_cb);
    glfwSetMouseButtonCallback(window, mousebutton_cb);
    glfwSetWindowSizeCallback(window, resize_cb);
    glfwSetWindowRefreshCallback(window, refresh_cb);
    glfwSetWindowCloseCallback(window, close_cb);
    glfwSetScrollCallback(window, scroll_cb);

    extern uint8_t icon_data[];
    GLFWimage image;
    image.width = 128;
    image.height = 128;
    image.pixels = icon_data;
    glfwSetWindowIcon(window, 1, &image);

    loadFonts();
}

void dpy_shutdown(void)
{
    unloadFonts();
    flushFontCache();
    glfwDestroyWindow(window);
    glfwTerminate();
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
    pendingRedraw = false;

    double t1 = gettime();

    /* Configure viewport for 2D graphics. */

    glClearColor(0.0, 0.0, 0.0, 0.0);
    glDisable(GL_TEXTURE_2D);
    glEnable(GL_COLOR_MATERIAL);
    glDisable(GL_BLEND);
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_LIGHTING);
    glDisable(GL_CULL_FACE);
    glDisable(GL_LINE_SMOOTH);
    glEnable(GL_POLYGON_SMOOTH);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glLineWidth(1);

    int w, h;
    glfwGetFramebufferSize(window, &w, &h);
    glViewport(0, 0, w, h);

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, w, h, 0, 0, 1);

    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glClear(GL_COLOR_BUFFER_BIT);

    int sw = w / fontWidth;
    int sh = h / fontHeight;
    if (!screen || (screenWidth != sw) || (screenHeight != sh))
    {
        free(screen);
        screenWidth = sw;
        screenHeight = sh;
        screen = calloc(screenWidth * screenHeight, sizeof(cell_t));
        arrins(keyboardQueue, 0, -KEY_RESIZE);
    }
    else
    {
        const cell_t* p = &screen[0];
        for (int y = 0; y < screenHeight; y++)
        {
            float sy = y * fontHeight;
            for (int x = 0; x < screenWidth; x++)
            {
                float sx = x * fontWidth;
                printChar(p, sx, sy);
                p++;
            }
        }

        if (cursorShown)
        {
            int x = cursorx * fontWidth - 1;
            if (x < 0)
                x = 0;
            int y = cursory * fontHeight;

            glColor3f(1.0f, 1.0f, 1.0f);
            glLogicOp(GL_XOR);
            glDisable(GL_BLEND);
            glDisable(GL_POLYGON_SMOOTH);
            glEnable(GL_COLOR_LOGIC_OP);
            glRecti(x, y, x + fontWidth, y + fontHeight);
            glLogicOp(GL_CLEAR);
            glDisable(GL_COLOR_LOGIC_OP);
        }
    }

    glfwSwapBuffers(window);
}

void dpy_setattr(int andmask, int ormask)
{
    currentAttr &= andmask;
    currentAttr |= ormask;
}

void dpy_setcolour(const colour_t* fg, const colour_t* bg)
{
    currentFg = *fg;
    currentBg = *bg;
}

void dpy_writechar(int x, int y, uni_t c)
{
    if (!screen)
        return;
    if ((x < 0) || (x >= screenWidth))
        return;
    if ((y < 0) || (y >= screenHeight))
        return;

    cell_t* p = &screen[x + y * screenWidth];
    p->c = c;
    p->attr = currentAttr;
    p->fg = currentFg;
    p->bg = currentBg;
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
    if (!screen)
        return;

    clipBounds(&x1, &y1);
    clipBounds(&x2, &y2);

    for (int y = y1; y <= y2; y++)
    {
        cell_t* p = &screen[y * screenWidth + x1];
        for (int x = x1; x <= x2; x++)
        {
            p->c = ' ';
            p->attr = currentAttr;
            p->fg = currentFg;
            p->bg = currentBg;
            p++;
        }
    }
}

void dpy_setcursor(int x, int y, bool shown)
{
    cursorx = x;
    cursory = y;
    cursorShown = shown;
}

uni_t dpy_getchar(double timeout)
{
    double endTime = glfwGetTime() + timeout;
    for (;;)
    {
        if (arrlen(keyboardQueue) > 0)
            return arrpop(keyboardQueue);

        if (timeout == -1)
            glfwWaitEvents();
        else
        {
            double waitTime = endTime - glfwGetTime();
            if (waitTime < 0)
                return -KEY_TIMEOUT;
            glfwWaitEventsTimeout(waitTime);
        }
    }
}

const char* dpy_getkeyname(uni_t k)
{
    static char buffer[32];
    switch (-k)
    {
        case KEY_RESIZE:
            return "KEY_RESIZE";
        case KEY_TIMEOUT:
            return "KEY_TIMEOUT";
        case KEY_QUIT:
            return "KEY_QUIT";
        case KEY_SCROLLUP:
            return "KEY_SCROLLUP";
        case KEY_SCROLLDOWN:
            return "KEY_SCROLLDOWN";
        case KEY_MENU:
            return "KEY_MENU";
    }

    int mods = -k;
    int key = (-k & 0xfff0ffff);

    if (mods & VKM_CTRLASCII)
    {
        sprintf(buffer, "KEY_%s^%c", (mods & VKM_SHIFT) ? "S" : "", key + 64);
        return buffer;
    }

    const char* t = NULL;
    switch (key)
    {
            // clang-format off
        case GLFW_KEY_ESCAPE:    t = "ESCAPE"; break;
        case GLFW_KEY_ENTER:     t = "RETURN"; break;
        case GLFW_KEY_TAB:       t = "TAB"; break;
        case GLFW_KEY_BACKSPACE: t = "BACKSPACE"; break;
        case GLFW_KEY_INSERT:    t = "INSERT"; break;
        case GLFW_KEY_DELETE:    t = "DELETE"; break;
        case GLFW_KEY_RIGHT:     t = "RIGHT"; break;
        case GLFW_KEY_LEFT:      t = "LEFT"; break;
        case GLFW_KEY_DOWN:      t = "DOWN"; break;
        case GLFW_KEY_UP:        t = "UP"; break;
        case GLFW_KEY_PAGE_UP:   t = "PGUP"; break;
        case GLFW_KEY_PAGE_DOWN: t = "PGDN"; break;
        case GLFW_KEY_HOME:      t = "HOME"; break;
        case GLFW_KEY_END:       t = "END"; break;
            // clang-format on
    }

    if (t)
    {
        sprintf(buffer,
            "KEY_%s%s%s",
            (mods & VKM_SHIFT) ? "S" : "",
            (mods & VKM_CTRL) ? "^" : "",
            t);
        return buffer;
    }

    if ((key >= GLFW_KEY_F1) && (key <= (GLFW_KEY_F25)))
    {
        sprintf(buffer,
            "KEY_%s%sF%d",
            (mods & VKM_SHIFT) ? "S" : "",
            (mods & VKM_CTRL) ? "^" : "",
            key - GLFW_KEY_F1 + 1);
        return buffer;
    }

    sprintf(buffer, "KEY_UNKNOWN_%d", -k);
    return buffer;
}

// vim: sw=4 ts=4 et
