#include "gui.h"
#include <wx/rawbmp.h>

#define VKM_SHIFT 0x10000
#define VKM_CTRL 0x20000
#define VKM_CTRLASCII 0x40000
#define VK_RESIZE 0x80000
#define VK_TIMEOUT 0x80001
#define VK_QUIT 0x80002

struct Cell
{
    uni_t c;
    uint8_t attr;
};

class CustomView;

static wxFrame* mainWindow;
static CustomView* customView;
static int screenWidth = -1;
static int screenHeight = -1;
static int cursorx;
static int cursory;
static bool cursorShown;
static uint8_t currentAttr = 0;
static std::vector<Cell> screen;
static std::vector<Cell> frontBuffer;
static std::deque<uni_t> keyboardQueue;
static wxMutex keyboardMutex;
static wxSemaphore keyboardSemaphore(0);

static const int openGLArgs[] = {
    WX_GL_RGBA, WX_GL_DOUBLEBUFFER, WX_GL_DEPTH_SIZE, 16, 0};

static void pushKey(uni_t key)
{
    wxMutexLocker m(keyboardMutex);
    keyboardQueue.push_front(key);
    keyboardSemaphore.Post();
}

class CustomView : public wxGLCanvas
{
private:
public:
    CustomView(wxWindow* parent):
        wxGLCanvas(parent,
            wxID_ANY,
            openGLArgs,
            wxDefaultPosition,
            wxDefaultSize,
            wxFULL_REPAINT_ON_RESIZE)
    {
        SetBackgroundStyle(wxBG_STYLE_CUSTOM);
        loadFonts();
    }

public:
    void Sync()
    {
        int fontWidth, fontHeight;
        getFontSize(fontWidth, fontHeight);

        auto size = GetSize();
        int newScreenWidth = size.x / fontWidth;
        int newScreenHeight = size.y / fontHeight;

        if ((screenWidth != newScreenWidth) ||
            (screenHeight != newScreenHeight))
        {
            screenWidth = newScreenWidth;
            screenHeight = newScreenHeight;
            screen.resize(screenWidth * screenHeight);
            pushKey(-VK_RESIZE);
        }

        frontBuffer = screen;
        Refresh();
        Update();
    }

private:
    void OnPaint(wxPaintEvent&)
    {
        wxPaintDC(this);

        /* Lazily create and bind the context. */

        if (!_ctx)
        {
            _ctx = std::make_unique<wxGLContext>(this);
            SetCurrent(*_ctx);
        }

        /* Configure viewport. */

        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glEnable(GL_TEXTURE_2D);
        glEnable(GL_COLOR_MATERIAL);
        glEnable(GL_BLEND);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_LIGHTING);
        glDisable(GL_CULL_FACE);
        glDisable(GL_LINE_SMOOTH);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glLineWidth(1);

        auto size = GetSize();
        glViewport(0, 0, size.x, size.y);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluOrtho2D(0, size.x, size.y, 0);

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();

        glClear(GL_COLOR_BUFFER_BIT);

        /* Draw the text. */

        int fontWidth, fontHeight;
        getFontSize(fontWidth, fontHeight);

        auto* cell = &frontBuffer[0];
        for (int y = 0; y < screenHeight; y++)
        {
            double sy = y * fontHeight;
            for (int x = 0; x < screenWidth; x++)
            {
                double sx = x * fontWidth;
                printChar(cell->c, cell->attr, sx, sy);
                cell++;
            }
        }

        glFlush();
        SwapBuffers();
    }

    void OnChar(wxKeyEvent& event)
    {
        uni_t uni = event.GetUnicodeKey();
        if ((uni != 0) && (uni != 27) && (uni != 8) && (uni != 13))
        {
            if (event.ControlDown())
            {
                uni |= VKM_CTRLASCII;
                pushKey(-uni);
            }
            else if (event.AltDown())
                pushKey(-27);
            pushKey(uni);
        }
        else
        {
            uni = event.GetKeyCode();
            if (event.ControlDown())
                uni |= VKM_CTRL;
            if (event.ShiftDown())
                uni |= VKM_SHIFT;
            pushKey(-uni);
        }
    }

    void OnResize(wxSizeEvent&)
    {
        pushKey(-VK_RESIZE);
    }

private:
    wxDECLARE_EVENT_TABLE();
    std::unique_ptr<wxGLContext> _ctx;
};

// clang-format off
wxBEGIN_EVENT_TABLE(CustomView, wxWindow)
    EVT_PAINT(CustomView::OnPaint)
    EVT_CHAR(CustomView::OnChar)
    EVT_SIZE(CustomView::OnResize)
wxEND_EVENT_TABLE();
// clang-format on

void dpy_init(const char* argv[]) {}

static wxIcon createIcon()
{
    wxImage image(128, 128);
    image.SetAlpha();
    wxImagePixelData data(image);
    wxImagePixelData::Iterator pp(data);
    extern const uint8_t icon_data[];
    const uint8_t* dp = icon_data;
    for (int i = 0; i < 128 * 128; i++)
    {
        pp.Red() = *dp++;
        pp.Green() = *dp++;
        pp.Blue() = *dp++;
        pp.Alpha() = *dp++;
        pp++;
    }

    wxIcon icon;
    icon.CopyFromBitmap(image);
    return icon;
}

void dpy_start(void)
{
    runOnUiThread(
        []
        {
            mainWindow = new wxFrame(nullptr,
                wxID_ANY,
                "WordGrinder",
                wxDefaultPosition,
                {getIvar("window_width"), getIvar("window_height")});

            mainWindow->SetIcon(createIcon());

            auto* sizer = new wxBoxSizer(wxHORIZONTAL);
            customView = new CustomView(mainWindow);
            sizer->Add(customView, 1, wxEXPAND);

            mainWindow->SetSizer(sizer);
            mainWindow->SetAutoLayout(true);

            mainWindow->Bind(wxEVT_CLOSE_WINDOW,
                [](auto& event)
                {
                    event.Veto();
                    pushKey(-VK_QUIT);
                });

            mainWindow->Show(true);
        });
}

void dpy_shutdown(void)
{
    runOnUiThread(
        []()
        {
            mainWindow->Close();
            flushFontCache();
        });
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
    runOnUiThread(
        []()
        {
            customView->Sync();
        });
}

void dpy_setattr(int andmask, int ormask)
{
    currentAttr &= andmask;
    currentAttr |= ormask;
}

void dpy_writechar(int x, int y, uni_t c)
{
    if ((x < 0) || (x >= screenWidth))
        return;
    if ((y < 0) || (y >= screenHeight))
        return;

    auto& cell = screen.at(x + y * screenWidth);
    cell.c = c;
    cell.attr = currentAttr;
}

void dpy_cleararea(int x1, int y1, int x2, int y2)
{
    if (screen.empty())
        return;

    for (int y = y1; y <= y2; y++)
    {
        auto* p = &screen.at(y * screenWidth + x1);
        for (int x = x1; x <= x2; x++)
        {
            p->c = ' ';
            p->attr = currentAttr;
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
    auto endTime = wxGetLocalTimeMillis() + (timeout * 1000.0);
    for (;;)
    {
        /* Wait until the queue is non-empty. */

        if (timeout == -1)
            keyboardSemaphore.Wait();
        else
        {
            long delta = (endTime - wxGetLocalTimeMillis()).ToLong();
            if (delta <= 0)
                return -VK_TIMEOUT;
            keyboardSemaphore.WaitTimeout(delta);
        }

        /* If there's a key in the queue, pop it. */

        {
            wxMutexLocker m(keyboardMutex);
            if (!keyboardQueue.empty())
            {
                uni_t key = keyboardQueue.back();
                keyboardQueue.pop_back();
                return key;
            }
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
        case WXK_DOWN:        t = "DOWN"; break;
        case WXK_UP:          t = "UP"; break;
        case WXK_LEFT:        t = "LEFT"; break;
        case WXK_RIGHT:       t = "RIGHT"; break;
        case WXK_HOME:        t = "HOME"; break;
        case WXK_END:         t = "END"; break;
        case WXK_BACK:        t = "BACKSPACE"; break;
        case WXK_DELETE:      t = "DELETE"; break;
        case WXK_INSERT:      t = "INSERT"; break;
        case WXK_PAGEUP:      t = "PGUP"; break;
        case WXK_PAGEDOWN:    t = "PGDN"; break;
        case WXK_TAB:         t = "TAB"; break;
        case WXK_RETURN:      t = "RETURN"; break;
        case WXK_ESCAPE:      t = "ESCAPE"; break;
        case WXK_MENU:        t = "MENU"; break;
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

    if ((key >= WXK_F1) && (key <= (WXK_F24)))
    {
        sprintf(buffer,
            "KEY_%s%sF%d",
            (mods & VKM_SHIFT) ? "S" : "",
            (mods & VKM_CTRL) ? "^" : "",
            key - WXK_F1 + 1);
        return buffer;
    }

    sprintf(buffer, "KEY_UNKNOWN_%d", -k);
    return buffer;
}

// vim: sw=4 ts=4 et
