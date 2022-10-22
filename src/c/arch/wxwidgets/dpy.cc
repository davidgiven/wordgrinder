extern "C"
{
#include "globals.h"
}

#include <stdio.h>
#include <stdlib.h>
#include <wx/wx.h>

#define VK_RESIZE 0x80000
#define VK_TIMEOUT 0x80001
#define VK_QUIT 0x80002

class MainWindow : public wxFrame
{
public:
    MainWindow():
        wxFrame(
            nullptr, wxID_ANY, "MainWindow", wxPoint(50, 50), wxSize(450, 340))
    {
    }

private:
    wxDECLARE_EVENT_TABLE();
};

// clang-format off
wxBEGIN_EVENT_TABLE(MainWindow, wxFrame)
    // EVT_MENU(ID_Hello,   MyFrame::OnHello)
    // EVT_MENU(wxID_EXIT,  MyFrame::OnExit)
    // EVT_MENU(wxID_ABOUT, MyFrame::OnAbout)
wxEND_EVENT_TABLE();
// clang-format on

class WordGrinderApp : public wxApp
{
public:
    WordGrinderApp() {}

public:
    bool OnInit() override
    {
        _mainWindow = new MainWindow();
        _mainWindow->Show(true);
        return true;
    }

private:
    MainWindow* _mainWindow;
};
wxDECLARE_APP(WordGrinderApp);

void dpy_init(const char* argv[]) {}

void dpy_start(void) {}

void dpy_shutdown(void) {}

void dpy_clearscreen(void) {}

void dpy_getscreensize(int* x, int* y) {}

void dpy_sync(void) {}

void dpy_setcursor(int x, int y, bool shown) {}

void dpy_setattr(int andmask, int ormask) {}

void dpy_writechar(int x, int y, uni_t c) {}

void dpy_cleararea(int x1, int y1, int x2, int y2) {}

uni_t dpy_getchar(double timeout)
{
    return -VK_TIMEOUT;
}

const char* dpy_getkeyname(uni_t k)
{
    static char buffer[32];
#if 0
    switch (-k)
    {
        case VK_RESIZE:      return "KEY_RESIZE";
        case VK_TIMEOUT:     return "KEY_TIMEOUT";
        case VK_QUIT:        return "KEY_QUIT";
    }

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

#undef main
wxIMPLEMENT_APP(WordGrinderApp);

// vim: sw=4 ts=4 et
