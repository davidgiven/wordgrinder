#include "gui.h"

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
static std::deque<uni_t> keyQueue;

static const int openGLArgs[] = {
    WX_GL_RGBA, WX_GL_DOUBLEBUFFER, WX_GL_DEPTH_SIZE, 16, 0};

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
    void Sync() {
        int fontWidth, fontHeight;
        getFontSize(fontWidth, fontHeight);

        auto size = GetSize();
        int newScreenWidth = size.x / fontWidth;
        int newScreenHeight = size.y / fontHeight;

        if ((screenWidth != newScreenWidth) || (screenHeight != newScreenHeight))
        {
            screenWidth = newScreenWidth;
            screenHeight = newScreenHeight;
            screen.resize(screenWidth * screenHeight);
            keyQueue.push_front(-VK_RESIZE);
        }

        frontBuffer = screen;
        Refresh();
    }

private:
    void prepare2DViewport()
    {
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glEnable(GL_TEXTURE_2D);
        glEnable(GL_COLOR_MATERIAL);
        glEnable(GL_BLEND);
        glDisable(GL_DEPTH_TEST);
        glDisable(GL_LIGHTING);
        glDisable(GL_CULL_FACE);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

        auto size = GetSize();
        glViewport(0, 0, size.x, size.y);

        glMatrixMode(GL_PROJECTION);
        glLoadIdentity();
        gluOrtho2D(0, size.x, size.y, 0);

        glMatrixMode(GL_MODELVIEW);
        glLoadIdentity();
    }

    void OnPaint(wxPaintEvent&)
    {
        wxPaintDC(this);

        /* Lazily create and bind the context. */

        if (!_ctx)
        {
            printf("create context\n");
            _ctx = std::make_unique<wxGLContext>(this);
            SetCurrent(*_ctx);
        }

        prepare2DViewport();
        glClear(GL_COLOR_BUFFER_BIT);

        glLoadIdentity();
        glColor3f(1.0f, 1.0f, 1.0f);

        int fontWidth, fontHeight;
        getFontSize(fontWidth, fontHeight);

        for (int y=0; y<screenHeight; y++)
        {
            for (int x=0; x<screenWidth; x++)
            {
                auto& cell = frontBuffer.at(x + y*screenWidth);
                double sx = x * fontWidth;
                double sy = y * fontHeight;
                printChar(cell.c, cell.attr, sx, sy);
            }
        }

        glFlush();
        SwapBuffers();
    }

private:
    wxDECLARE_EVENT_TABLE();
    std::unique_ptr<wxGLContext> _ctx;
};

// clang-format off
wxBEGIN_EVENT_TABLE(CustomView, wxWindow)
    EVT_PAINT(CustomView::OnPaint)
wxEND_EVENT_TABLE();
// clang-format on

void dpy_init(const char* argv[]) {}

void dpy_start(void)
{
    runOnUiThread(
        []
        {
            mainWindow = new wxFrame(nullptr, wxID_ANY, "WordGrinder");

            auto* sizer = new wxBoxSizer(wxHORIZONTAL);
            customView = new CustomView(mainWindow);
            sizer->Add(customView, 1, wxEXPAND);

            mainWindow->SetSizer(sizer);
            mainWindow->SetAutoLayout(true);

            mainWindow->Show(true);
        });
}

void dpy_shutdown(void)
{
    mainWindow->Close();
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
    if (keyQueue.empty())
        return -VK_TIMEOUT;

    uni_t key = keyQueue.back();
    keyQueue.pop_back();
    return key;
}

const char* dpy_getkeyname(uni_t k)
{
    static char buffer[32];
    switch (-k)
    {
        case VK_RESIZE:      return "KEY_RESIZE";
        case VK_TIMEOUT:     return "KEY_TIMEOUT";
        case VK_QUIT:        return "KEY_QUIT";
    }

#if 0
    int mods = -k;
    int key = (-k & 0xfff0ffff);

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
        case SDLK_MENU:        template = "MENU"; break;
    }

    if (template)
    {
        sprintf(buffer, "KEY_%s%s%s",
                (mods & VKM_SHIFT) ? "S" : "",
                (mods & VKM_CTRL) ? "^" : "",
                template);
        return buffer;
    }

    if ((key >= SDLK_F1) && (key <= (SDLK_F24)))
    {
        sprintf(buffer, "KEY_%s%sF%d",
                (mods & VKM_SHIFT) ? "S" : "",
                (mods & VKM_CTRL) ? "^" : "",
                key - SDLK_F1 + 1);
        return buffer;
    }
#endif

    sprintf(buffer, "KEY_UNKNOWN_%d", -k);
    return buffer;
}

// vim: sw=4 ts=4 et
