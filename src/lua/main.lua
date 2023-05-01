--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local table_remove = table.remove
local Mkdirs = wg.mkdirs
local Write = wg.write
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local GetStringWidth = wg.getstringwidth
local GetCwd = wg.getcwd
local Stat = wg.stat
local SetUnicode = wg.setunicode
local PrintErr = wg.printerr
local PrintOut = wg.printout
local ReadFile = wg.readfile

local redrawpending = true

-- Determine the user's home directory.

HOME = wg.getenv("HOME") or wg.getenv("USERPROFILE")
CONFIGDIR = HOME .. "/.wordgrinder"
local configfile = CONFIGDIR.."/startup.lua"

-- Determine the installation directory (Windows only).

if (ARCH == "windows") then
    local exe = wg.getenv("WINDOWS_EXE")
    local _, _, dir = exe:find("^(.*)[/\\][^/\\]*$")
    WINDOWS_INSTALL_DIR = dir
end

Quitting = false
function QuitForcedBySystem()
    Quitting = true
end
function CancelQuit()
    Quitting = false
end

local oldcp, oldcw, oldco
function QueueRedraw()
    redrawpending = true
    if Document then
        if (oldcp ~= Document.cp) or (oldcw ~= Document.cw) or
                (oldco ~= Document.co) then
            oldcp = Document.cp
            oldcw = Document.cw
            oldco = Document.co
            FireEvent(Event.Moved)
        end

        if not Document.wrapwidth then
            ResizeScreen()
        end
    end
end

function ResetDocumentSet()
    UpdateDocumentStyles()
    DocumentSet = CreateDocumentSet()
    DocumentSet.menu = CreateMenuTree()
    Document = CreateDocument()
    DocumentSet:addDocument(CreateDocument(), "main")
    RebuildParagraphStylesMenu(DocumentStyles)
    RebuildDocumentsMenu(DocumentSet.documents)
    DocumentSet:purge()
    DocumentSet:clean()

    FireEvent(Event.DocumentCreated)
    FireEvent(Event.RegisterAddons)
end

do
    local function cb(event, token)
        oldcp = 1
        oldcw = 1
        oldco = 1
        SetCurrentStyleHint(0, 0)
    end

    AddEventListener(Event.DocumentLoaded, cb)
    AddEventListener(Event.DocumentCreated, cb)
end

-- This function contains the word processor proper, including the main event
-- loop.

function WordProcessor(filename)
    ResetDocumentSet()

    -- Move legacy config files.

    do
        local _, e = Mkdirs(CONFIGDIR)
        if e then
            CLIError("cannot create configuration directory: "..e)
        end

        local function movefile(src, dest)
            if not Stat(src) then
                return
            end
            if Stat(dest) then
                CLIError("both old and new config files exist: delete one and try again ("
                    ..src.." vs "..dest)
            end
            
            local _, e = wg.rename(src, dest)
            if e then
                CLIError("unable to migrate legacy config file: "..e)
            end
        end

        movefile(HOME.."/.wordgrinder.settings", CONFIGDIR.."/settings.dat")
        movefile(HOME.."/.wordgrinder.lua", CONFIGDIR.."/startup.lua")
    end

    -- Which config file are we loading?

    do
        local data, e, errno = ReadFile(configfile)
        if data then
            f, e = loadstring(data, configfile)
            if f then
                xpcall(f, CLIError)
            else
                CLIError("config file compilation error: "..e)
            end
        elseif (errno ~= wg.ENOENT) then
            CLIError("config file load error: "..e)
        end
    end

    wg.initscreen()
	FireEvent(Event.ScreenInitialised)
    ResizeScreen()
    RedrawScreen()

    if filename then
        if not Cmd.LoadDocumentSet(filename) then
            -- As a special case, if we tried to load a document from the command line and it
            -- doesn't exist, then we prime the document name so that saving the file is easy.
            DocumentSet.name = filename
        end
    else
        FireEvent(Event.DocumentLoaded)
    end

    local masterkeymap: {[string]: MenuCallback} = {
        ["KEY_RESIZE"] = { ResizeScreen, RedrawScreen },
        ["KEY_REDRAW"] = { RedrawScreen },

        [" "] = { Cmd.Checkpoint, Cmd.TypeWhileSelected,
            Cmd.SplitCurrentWord },
        ["KEY_RETURN"] = { Cmd.Checkpoint, Cmd.TypeWhileSelected,
            Cmd.SplitCurrentParagraph },
        ["KEY_ESCAPE"] = { Cmd.ActivateMenu },
        ["KEY_MENU"] = { Cmd.ActivateMenu },
        ["KEY_QUIT"] = { Cmd.TerminateProgram },
    }

    local function handle_key_event(c)
        -- Anything in masterkeymap overrides everything else.
        local f = masterkeymap[c]
        if f then
            RunMenuAction(f)
        else
            -- It's not in masterkeymap. If it's printable, insert it; if it's
            -- not, look it up in the menu hierarchy.

            if not c:match("^KEY_") then
                Cmd.Checkpoint()
                Cmd.TypeWhileSelected()

                local payload = { value = c }
                FireEvent(Event.KeyTyped, payload)

                Cmd.InsertStringIntoWord(payload.value)
            else
                f = DocumentSet.menu:lookupAccelerator(c)
                if f then
                    RunMenuAction(f)
                else
                    NonmodalMessage(c:gsub("^KEY_", "").." is not bound --- try ESCAPE for a menu")
                end
            end
        end
    end

    local oldmb = false
    local oldmx, oldmy
    local function handle_mouse_event(m)
        if m.b and not oldmb then
            oldmx = m.x
            oldmy = m.y
            Cmd.UnsetMark()
            Cmd.GotoXYPosition(m.x, m.y)
            Cmd.SetMark()
        else
            Cmd.GotoXYPosition(m.x, m.y)
        end
        if not m.b and oldmb and (m.x == oldmx) and (m.y == oldmy) then
            Cmd.UnsetMark();
        end
        oldmb = m.b
    end

    local function eventloop()
        local nl = string.char(13)
        while true do
            if DocumentSet.justchanged then
                FireEvent(Event.Changed)
                DocumentSet.justchanged = false
            end

            FlushAsyncEvents()
            FireEvent(Event.WaitingForUser)
            local c = "KEY_TIMEOUT"
            while (c == "KEY_TIMEOUT") do
                if redrawpending then
                    RedrawScreen()
                    redrawpending = false
                end

                c = GetCharWithBlinkingCursor(IDLE_TIME)
                if (c == "KEY_TIMEOUT") then
                    FireEvent(Event.Idle)
                end
            end
            if c ~= "KEY_RESIZE" then
                ResetNonmodalMessages()
            end
            if type(c) == "table" then
                handle_mouse_event(c)
            else
                handle_key_event(c)
            end

            -- Process system quit messages.

            if Quitting then
                CancelQuit()
                Cmd.TerminateProgram()
            end
        end
    end

    NonmodalMessage("Welcome to WordGrinder! Press ESC to show the menu.")
    while true do
        local f, e = xpcall(eventloop, debug.traceback)
        if not f then
            print(e)
            ModalMessage("Internal error!",
                "Something went wrong inside WordGrinder! I'll try and "..
                "continue but you should save your work immediately (under a "..
                "different filename), exit, and send the following technical "..
                "information to the author:\n\n" .. e)
        end
    end
end

-- Program entry point. Parses command line arguments and executes.

function Main(...)
    -- Set up the initial document so that the command line options have
    -- access. We can't save the settings until the document set is set up, but
    -- we can't set up the document set properly until the settings are loaded,
    -- so we have to do it twice to get it right.

    ResetDocumentSet()
    LoadGlobalSettings()
    ResetDocumentSet()

    local arg = {...}
    table_remove(arg, 1) -- contains the executable name
    local filename = nil
    do
        local function do_help()
            PrintErr("WordGrinder version ", VERSION, " © 2007-2020 David Given\n")
            if DEBUG then
                PrintErr("(This version has been compiled with debugging enabled.)\n")
            end

            PrintErr([[
Syntax: wordgrinder [<options...>] [<filename>]
Options:
   -h    --help                Displays this message.
         --lua file.lua        Loads and executes file.lua and then exits
                               (remaining arguments are passed to the script)
         --exec 'lua code'     Loads and executes the supplied code and then exits
                               (remaining arguments are passed to the script)
   -c    --convert src dest    Converts from one file format to another
         --config file.lua     Sets the name of the user config file

Only one filename may be specified, which is the name of a WordGrinder
file to load on startup. If not given, you get a blank document instead.

To convert documents, use --convert. The file type is autodetected from the
extension. To specify a document name, use :name as a suffix. e.g.:

    wordgrinder --convert filename.wg:"Chapter 1" chapter1.odt

The user config file is a Lua file which is loaded and executed before
the program starts up (but after any --lua files). It defaults to:

    ]] .. configfile .. [[


]])
            if DEBUG then
                -- List debugging options here.
            end

            wg.exit(0)
        end

        local function do_lua(opt, ...)
            if not opt then
                CLIError("--lua must have an argument")
            end

            local f, e = loadfile(opt)
            if e then
                CLIError("user script compilation error: "..e)
            end

            EngageCLI()
            f(...)
            wg.exit(0)
        end

        local function do_exec(opt, ...)
            if not opt then
                CLIError("--exec must have an argument")
            end

            local f, e = loadstring(opt)
            if e then
                CLIError("user script compilation error: "..e)
            end

            f(...)
            wg.exit(0)
        end

        local function do_convert(opt1, opt2)
            if not opt1 or not opt2 then
                CLIError("--convert must have two arguments")
            end

            CliConvert(opt1, opt2)
            return 2
        end

        local function do_config(opt)
            if not opt then
                CLIError("--config must have an argument")
            end

            configfile = opt
            return 1
        end

        local function do_filename(fn)
            if filename then
                CLIError("you may only specify one filename")
            end
            filename = fn
            return 1
        end

        local function do_8bit(opt)
            SetUnicode(false)
            return 0
        end

        local function unrecognisedarg(arg)
            CLIError("unrecognised option '", arg, "' --- try --help for help")
        end

        local argmap = {
            ["h"]          = do_help,
            ["help"]       = do_help,
            ["lua"]        = do_lua,
            ["exec"]       = do_exec,
            ["c"]          = do_convert,
            ["convert"]    = do_convert,
            ["config"]     = do_config,
            ["8"]          = do_8bit,
            [FILENAME_ARG] = do_filename,
            [UNKNOWN_ARG]  = unrecognisedarg,
        }

        -- Do the actual argument parsing.

        ParseArguments(arg, argmap)
    end

    if filename and
            not filename:find("^/") and
            not filename:find("^[a-zA-Z]:[/\\]") then
        filename = GetCwd() .. "/" .. filename
    end

    WordProcessor(filename)
end

-- vim: sw=4 ts=4 et

