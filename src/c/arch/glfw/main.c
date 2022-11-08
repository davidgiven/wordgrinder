#include "globals.h"
#include "gui.h"
#include <GLFW/glfw3.h>
#include "stb_ds.h"

#define VKM_SHIFT 0x10000
#define VKM_CTRL 0x20000
#define VKM_CTRLASCII 0x40000
#define VK_RESIZE 0x80000
#define VK_TIMEOUT 0x80001
#define VK_QUIT 0x80002

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
        arrins(keyboardQueue, 0, -VK_RESIZE);
        pendingRedraw = true;
    }
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
    arrins(keyboardQueue, 0, -VK_QUIT);
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

    glfwSetKeyCallback(window, key_cb);
    glfwSetCharCallback(window, character_cb);
    glfwSetWindowSizeCallback(window, resize_cb);
    glfwSetWindowRefreshCallback(window, refresh_cb);
    glfwSetWindowCloseCallback(window, close_cb);

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

void dpy_sync(void)
{
    pendingRedraw = false;

    /* Configure viewport for 2D graphics. */

    glClearColor(0.0, 0.0, 0.0, 1.0);
    glEnable(GL_TEXTURE_2D);
    glEnable(GL_COLOR_MATERIAL);
    glEnable(GL_BLEND);
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
        arrins(keyboardQueue, 0, -VK_RESIZE);
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
            int h = fontHeight;

            glColor3f(1.0f, 1.0f, 1.0f);
            glLogicOp(GL_XOR);
            glDisable(GL_BLEND);
            glEnable(GL_COLOR_LOGIC_OP);
            glBegin(GL_LINES);
            glVertex2i(x, y);
            glVertex2i(x, y + h);

            glVertex2i(x - 2, y);
            glVertex2i(x + 1, y);

            glVertex2i(x - 2, y + h);
            glVertex2i(x + 1, y + h);
            glEnd();
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
                return -VK_TIMEOUT;
            glfwWaitEventsTimeout(waitTime);
        }
    }
}

const char* dpy_getkeyname(uni_t k)
{
    static char buffer[32];
    switch (-k)
    {
        case VK_RESIZE:
            return "KEY_RESIZE";
        case VK_TIMEOUT:
            return "KEY_TIMEOUT";
        case VK_QUIT:
            return "KEY_QUIT";
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
