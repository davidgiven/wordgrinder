#include "gui.h"

static wxSemaphore execSemaphore(0);

class ExecEvent;
wxDEFINE_EVENT(EXEC_EVENT_TYPE, ExecEvent);
class ExecEvent : public wxThreadEvent
{
public:
    ExecEvent(wxEventType commandType = EXEC_EVENT_TYPE, int id = 0):
        wxThreadEvent(commandType, id)
    {
    }

    ExecEvent(const ExecEvent& event):
        wxThreadEvent(event),
        _callback(event._callback)
    {
    }

    wxEvent* Clone() const
    {
        return new ExecEvent(*this);
    }

    void SetCallback(const std::function<void()> callback)
    {
        _callback = callback;
    }

    void RunCallback() const
    {
        _callback();
    }

private:
    std::function<void()> _callback;
};

class WordGrinderApp : public wxApp, public wxThreadHelper
{
public:
    WordGrinderApp() {}

public:
    bool OnInit() override
    {
        Bind(EXEC_EVENT_TYPE, &WordGrinderApp::OnExec, this);
        CreateThread(wxTHREAD_JOINABLE);
        GetThread()->Run();
        return true;
    }

private:
    void OnExec(const ExecEvent& event)
    {
        event.RunCallback();
        execSemaphore.Post();
    }

protected:
    virtual wxThread::ExitCode Entry()
    {
        return (wxThread::ExitCode)(intptr_t)appMain(argc, argv);
    }
};
wxDECLARE_APP(WordGrinderApp);

void runOnUiThread(std::function<void()> callback)
{
    ExecEvent* event = new ExecEvent();
    event->SetCallback(callback);
    wxGetApp().QueueEvent(event);
    execSemaphore.Wait();
}

#undef main
wxIMPLEMENT_APP(WordGrinderApp);

// vim: sw=4 ts=4 et
