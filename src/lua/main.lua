-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local Write = wg.write
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local GetStringWidth = wg.getstringwidth

local redrawpending = true

-- Determine the user's home directory.

HOME = os.getenv("HOME") or os.getenv("USERPROFILE")

function QueueRedraw()
	redrawpending = true
	if not Document.wrapwidth then
		ResizeScreen()
	end
end

function ResetDocumentSet()
	DocumentSet = CreateDocumentSet()
	DocumentSet.menu = CreateMenu()
	DocumentSet:addDocument(CreateDocument(), "main")
	DocumentSet:setCurrent("main")
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
		
		["KEY_REDRAW"] = RedrawScreen,
		
		[" "] = Cmd.SplitCurrentWord,
		["KEY_RETURN"] = Cmd.SplitCurrentParagraph,
		["KEY_ESCAPE"] = Cmd.ActivateMenu,
	}	
		
	local function eventloop()
		local nl = string.char(13)
		while true do
			if DocumentSet.justchanged then
				FireEvent(Event.Changed)
				DocumentSet.justchanged = false
			end
			
			FireEvent(Event.WaitingForUser)
			local c = "KEY_TIMEOUT"
			while (c == "KEY_TIMEOUT") do
				if redrawpending then
					RedrawScreen()
					redrawpending = false
				end
			
				c = wg.getchar(DocumentSet.idletime)
				if (c == "KEY_TIMEOUT") then
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
	
	while true do
		local f, e = xpcall(eventloop, Traceback)
		if not f then
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
	-- access.
	
	ResetDocumentSet()

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
   -h    --help              Displays this message.
         --lua file.lua      Loads and executes file.lua before startup
   -c    --convert src dest  Converts from one file format to another

Only one filename may be specified, which is the name of a WordGrinder
file to load on startup. If not given, you get a blank document instead.

To convert documents, use --convert. The file type is autodetected from the
extension. To specify a document name, use :name as a suffix. e.g.:

    wordgrinder --convert filename.wg:"Chapter 1" chapter1.odt
]])
			if DEBUG then
				-- List debugging options here.
			end
			
			os.exit(0)
		end
		
		local function do_lua(opt)
			if not opt then
				usererror("--lua must have an argument")
			end
			
			local f, e = loadfile(opt)
			if e then
				usererror("user script compilation error: "..e)
			end
			f()
			return 1
		end
		
		local function do_convert(opt1, opt2)
			if not opt1 or not opt2 then
				usererror("--convert must have two arguments")
			end
			
			CliConvert(opt1, opt2)
		end
		
		local function needarg(opt)
			if not opt then
				usererror("missing option parameter")
			end
		end
		
		local argmap = {
			["h"]           = do_help,
			["help"]        = do_help,
			["lua"]         = do_lua,
			["c"]           = do_convert,
			["convert"]     = do_convert,
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
		local i = 2
		while (i <= #arg) do
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
					i = i + fn(arg[i+1], arg[i+2])
				else
					-- ...without a -- prefix.
					local od = o:sub(2, 2)
					local fn = argmap[od]
					if not fn then
						unrecognisedarg("-"..od)
					end
					op = o:sub(3)
					if (op == "") then
						i = i + fn(arg[i+1], arg[i+2])
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

			i = i + 1
		end
	end
	
	if filename and
			not filename:find("^/") and
			not filename:find("^[a-zA-Z]:[/\\]") then
		filename = lfs.currentdir() .. "/" .. filename
	end
	
	WordProcessor(filename)
end
