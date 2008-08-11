-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

function include(fn)
	local c, e = loadfile(LUA_SRC_DIR .. fn)
	if e then
		error(e)
	end
	c()
end

require "lfs"

include "utils.lua"
include "events.lua"
include "redraw.lua"
include "document.lua"
include "forms.lua"
include "ui.lua"
include "browser.lua"
include "html.lua"

Cmd = {}
include "margin.lua"
include "fileio.lua"
include "export.lua"
include "export/text.lua"
include "export/html.lua"
include "export/latex.lua"
include "export/troff.lua"
include "import.lua"
include "navigate.lua"
include "addons/goto.lua"
include "addons/autosave.lua"
include "addons/docsetman.lua"

include "menu.lua"

local int = math.floor
local Write = wg.write
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local GetStringWidth = wg.getstringwidth

local redrawpending = true

function QueueRedraw()
	redrawpending = true
	if not Document.wrapwidth then
		ResizeScreen()
	end
end

function ResetDocumentSet()
	DocumentSet = CreateDocumentSet()
	DocumentSet:addDocument(CreateDocument(), "main")
	DocumentSet:setCurrent("main")
	DocumentSet.menu = CreateMenu()
	RebuildParagraphStylesMenu(DocumentSet.styles)
	RebuildDocumentsMenu(DocumentSet.documents)
	DocumentSet:purge()
	DocumentSet:clean()
	
	FireEvent(Event.DocumentCreated)
	FireEvent(Event.RegisterAddons)
end

-- This function contains the word processor proper, including the main event
-- loop.

function WordProcessor(filename)
	ResetDocumentSet()
	wg.initscreen()
	ResizeScreen()
	RedrawScreen()
	
	if filename then
		Cmd.LoadDocumentSet(filename)
	end
	
	--ModalMessage("Welcome!", "Welcome to WordGrinder! While editing, you may press ESC for the menu, or ESC, F, X to exit (or ALT+F, X if your terminal supports it).")
	
	local masterkeymap = {
		["KEY_RESIZE"] = function() -- resize
			ResizeScreen()
			RedrawScreen()
		end,
		
		[" "] = Cmd.SplitCurrentWord,
		["KEY_RETURN"] = Cmd.SplitCurrentParagraph,
		["KEY_ESCAPE"] = Cmd.ActivateMenu,
	}	
		
	local nl = string.char(13)
	while true do
		if DocumentSet.justchanged then
			FireEvent(Event.Changed)
			DocumentSet.justchanged = false
		end
		
		FireEvent(Event.WaitingForUser)
		local c = nil
		while not c do
			if redrawpending then
				RedrawScreen()
				redrawpending = false
			end
		
			c = wg.getchar(DocumentSet.idletime)
			if not c then
				FireEvent(Event.Idle)
			end
		end
		
		ResetNonmodalMessages()
		
		-- Anything in masterkeymap overrides everything else.
		local f = masterkeymap[c]
		if f then
			f()
		else
			-- It's not in masterkeymap. If it's printable, insert it; if it's
			-- not, look it up in the menu hierarchy.
			
			if not c:match("^KEY_") then
				Cmd.InsertStringIntoWord(c)
			else
				f = DocumentSet.menu:lookupAccelerator(c)
				if f then
					if (type(f) == "function") then
						f()
					else
						Cmd.ActivateMenu(f)
					end
				else
					NonmodalMessage(c:gsub("^KEY_", "").." is not bound --- try ESCAPE for a menu")
				end
			end
		end
	end
end

-- Parse any command-line arguments.

local filename = nil
do
	local stdout = io.stdout
	local stderr = io.stderr
	
	local function message(...)
		stderr:write("wordgrinder: ", ...)
		stderr:write("\n")
	end

	local function usererror(...)
		message(...)
		os.exit(1)
	end
	
	local function do_help(opt)
		stdout:write("WordGrinder version ", VERSION, " © 2007-2008 David Given\n")
		if DEBUG then
			stdout:write("(This version has been compiled with debugging enabled.)\n")
		end
		
		stdout:write([[
Syntax: wordgrinder [<options...>] [<filename>]
Options:
   -h    --help        Displays this message.

Only one filename may be specified, which is the name of a WordGrinder
file to load on startup. If not given, you get a blank document instead.
]])
		if DEBUG then
			-- List debugging options here.
		end
		
		os.exit(0)
	end
	
	local function do_profile(opt)
		profiler.start()
		return 0
	end
	
	local function needarg(opt)
		if not opt then
			usererror("missing option parameter")
		end
	end
	
	local argmap = {
		["h"]           = do_help,
		["help"]        = do_help,
	}
	
	if DEBUG then
		-- argmap["p"] = do_profile
		-- argmap["profile"] = do_profile
	end
	 
	-- Called on an unrecognised option.
	
	local function unrecognisedarg(arg)
		usererror("unrecognised option '", arg, "' --- try --help for help")
	end
	
	-- Do the actual argument parsing.
	
	local arg = {...}
	for i = 2, #arg do
		local o = arg[i]
		local op
		
		if (o:byte(1) == 45) then
			-- This is an option.
			if (o:byte(2) == 45) then
				-- ...with a -- prefix.
				o = o:sub(3)
				local fn = argmap[o]
				if not fn then
					unrecognisedarg("--"..o)
				end
				local op = arg[i+1]
				i = i + fn(op)
			else
				-- ...without a -- prefix.
				local od = o:sub(2, 2)
				local fn = argmap[od]
				if not fn then
					unrecognisedarg("-"..od)
				end
				op = o:sub(3)
				if (op == "") then
					op = arg[i+1]
					i = i + fn(op)
				else
					fn(op)
				end
			end
		else
			if filename then
				usererror("you may only specify one filename")
			end
			filename = o
		end	
	end
end

WordProcessor(filename)
