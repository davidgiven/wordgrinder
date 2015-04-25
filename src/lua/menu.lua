-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Write = wg.write
local ClearToEOL = wg.cleartoeol
local GetChar = wg.getchar
local GotoXY = wg.gotoxy
local SetBold = wg.setbold
local SetBright = wg.setbright
local SetReverse = wg.setreverse
local SetNormal = wg.setnormal
local GetStringWidth = wg.getstringwidth

local menu_tab = {}
local key_tab = {}
local menu_stack = {}

local function addmenu(n, m, menu)
	local w = n:len()
	menu = menu or {}
	menu.label = n
	menu.mks = {}
	
	for i, _ in ipairs(menu) do
		menu[i] = nil
	end
	
	for _, data in ipairs(m) do
		if (data == "-") then
			menu[#menu+1] = "-"
		else
			local item = {
				id = data[1],
				mk = data[2],
				label = data[3],
				ak = data[4],
				fn = data[5]
			}
			menu[#menu+1] = item
			
			if item.mk then
				if menu.mks[item.mk] then
					error("Duplicate menu action key "..item.mk)
				end
				menu.mks[item.mk] = item
			end
			
			if menu_tab[item.id] then
				error("Dupicate menu ID "..item.id)
			end
			menu_tab[item.id] = item
			
			if item.ak then
				key_tab[item.ak] = item.id
			end
			
			if (item.label:len() > w) then
				w = item.label:len()
			end
		end
	end
	
	menu.maxwidth = w
	return menu
end

local function submenu(menu)
	for _, item in ipairs(menu) do
		menu_tab[item.id] = nil
		if item.ak then
			key_tab[item.ak] = nil
		end
	end
end

local DocumentsMenu = addmenu("Documents", {})
local ParagraphStylesMenu = addmenu("Paragraph Styles", {})

local ImportMenu = addmenu("Import new document",
{
	{"FIodt",  "O", "Import ODT file...",        nil,         Cmd.ImportODTFile},
	{"FIhtml", "H", "Import HTML file...",       nil,         Cmd.ImportHTMLFile},
	{"FItxt",  "T", "Import text file...",       nil,         Cmd.ImportTextFile},
})

local ExportMenu = addmenu("Export current document",
{
	{"FEodt",  "O", "Export to ODT...",          nil,         Cmd.ExportODTFile},
	{"FEhtml", "H", "Export to HTML...",         nil,         Cmd.ExportHTMLFile},
	{"FEtxt",  "T", "Export to plain text...",   nil,         Cmd.ExportTextFile},
	{"FEtex",  "L", "Export to LaTeX...",        nil,         Cmd.ExportLatexFile},
	{"FEtr",   "F", "Export to Troff...",        nil,         Cmd.ExportTroffFile},
--	{"FErtf",  "R", "Export to Rtf...",        nil,         Cmd.ExportRTFFile},
})

local DocumentSettingsMenu = addmenu("Document settings",
{
    {"FSautosave", "A", "Autosave...",               nil,         Cmd.ConfigureAutosave},
    {"FSscrapbook", "S", "Scrapbook...",             nil,         Cmd.ConfigureScrapbook},
    {"FSHTMLExport", "H", "HTML export...",          nil,         Cmd.ConfigureHTMLExport},
	{"FSPageCount", "P", "Page count...",            nil,         Cmd.ConfigurePageCount},
})

local GlobalSettingsMenu = addmenu("Global settings",
{
	{"FSWidescreen", "W", "Widescreen mode...",      nil,         Cmd.ConfigureWidescreen},
})

local FileMenu = addmenu("File",
{
	{"FN",         "N", "New document set",          nil,         Cmd.CreateBlankDocumentSet},
	{"FO",         "O", "Load document set...",      nil,         Cmd.LoadDocumentSet},
	{"FS",         "S", "Save document set",         "^S",        Cmd.SaveCurrentDocument},
	{"FA",         "A", "Save document set as...",   nil,         Cmd.SaveCurrentDocumentAs},
	"-",
	{"FB",         "B", "Add new blank document",    nil,         Cmd.AddBlankDocument},
	{"FI",         "I", "Import new document ▷",     nil,         ImportMenu},
	{"FE",         "E", "Export current document ▷", nil,         ExportMenu},
	{"Fdocman",    "D", "Manage documents...",       nil,         Cmd.ManageDocumentsUI},
	"-",
	{"Fsettings",  "T", "Document settings ▷",       nil,         DocumentSettingsMenu},
	{"Fglobals",   "G", "Global settings ▷",         nil,         GlobalSettingsMenu},
	"-",
	{"Fabout",     "Z", "About WordGrinder...",      nil,         Cmd.AboutWordGrinder},
	{"FQ",         "X", "Exit",                      "^Q",        Cmd.TerminateProgram}
})

local ScrapbookMenu = addmenu("Scrapbook",
{
	{"EScut",      "T", "Cut to scrapbook",          nil,         Cmd.CutToScrapbook},
	{"EScopy",     "C", "Copy to scrapbook",         nil,         Cmd.CopyToScrapbook},
	{"ESpaste",    "P", "Paste to scrapbook",        nil,         Cmd.PasteToScrapbook},
})

local EditMenu = addmenu("Edit",
{
	{"ET",         "T", "Cut",                       "^X",        Cmd.Cut},
	{"EC",         "C", "Copy",                      "^C",        Cmd.Copy},
	{"EP",         "P", "Paste",                     "^V",        Cmd.Paste},
	{"ED",         "D", "Delete",                    nil,         Cmd.Delete},
	"-",
	{"EF",         "F", "Find and replace...",       "^F",        Cmd.Find},
	{"EN",         "N", "Find next",                 "^K",        Cmd.FindNext},
	{"ER",         "R", "Replace then find",         "^R",        Cmd.ReplaceThenFind},
	"-",
	{"EG",         "G", "Go to...",                  "^G",        Cmd.Goto},
	{"Escrapbook", "S", "Scrapbook ▷",               nil,         ScrapbookMenu},
})

local MarginMenu = addmenu("Margin",
{
	{"SM1",    "H", "Hide margin",                nil,         function() Cmd.SetViewMode(1) end},
	{"SM2",    "S", "Show paragraph styles",      nil,         function() Cmd.SetViewMode(2) end},
	{"SM3",    "N", "Show paragraph numbers",     nil,         function() Cmd.SetViewMode(3) end},
	{"SM4",    "W", "Show paragraph word counts", nil,         function() Cmd.SetViewMode(4) end},
})
	
local StyleMenu = addmenu("Style",
{
	{"SI",     "I", "Set italic",                 "^I",        function() Cmd.SetStyle("i") end},
	{"SU",     "U", "Set underline",              "^U",        function() Cmd.SetStyle("u") end},
	{"SB",     "B", "Set bold",                   "^B",        function() Cmd.SetStyle("b") end},
	{"SO",     "O", "Set plain",                  "^O",        function() Cmd.SetStyle("o") end},
	"-",
	{"SP",     "P", "Change paragraph style ▷",   "^P",        ParagraphStylesMenu},
	{"SM",     "M", "Set margin mode ▷",          nil,         MarginMenu},
	{"SS",     "S", "Toggle status bar",          nil,         Cmd.ToggleStatusBar},
})

local NavigationMenu = addmenu("Navigation",
{
	{"ZU",     nil, "Cursor up",                  "UP",       
						function() Cmd.MoveWhileSelected() Cmd.GotoPreviousLine() end},
	{"ZR",     nil, "Cursor right",               "RIGHT",    
						function() Cmd.MoveWhileSelected() Cmd.GotoNextCharW() end},
	{"ZD",     nil, "Cursor down",                "DOWN",     
						function() Cmd.MoveWhileSelected() Cmd.GotoNextLine() end},
	{"ZL",     nil, "Cursor left",                "LEFT",     
						function() Cmd.MoveWhileSelected() Cmd.GotoPreviousCharW() end},
	{"ZSU",    nil, "Selection up",               "SUP",      
						function() Cmd.SetMark() Cmd.GotoPreviousLine() end},
	{"ZSR",    nil, "Selection right",            "SRIGHT",   
						function() Cmd.SetMark() Cmd.GotoNextCharW() end},
	{"ZSD",    nil, "Selection down",             "SDOWN",    
						function() Cmd.SetMark() Cmd.GotoNextLine() end},
	{"ZSL",    nil, "Selection left",             "SLEFT",    
						function() Cmd.SetMark() Cmd.GotoPreviousCharW() end},
	{"ZSW",    nil, "Select word",                "^W",       
						Cmd.SelectWord},
	{"ZWL",    nil, "Goto previous word",         "^LEFT",    
						function() Cmd.MoveWhileSelected() Cmd.GotoPreviousWordW() end},
	{"ZWR",    nil, "Goto next word",             "^RIGHT",   
						function() Cmd.MoveWhileSelected() Cmd.GotoNextWordW() end},
	{"ZNP",    nil, "Goto next paragraph",        "^DOWN",    
						function() Cmd.MoveWhileSelected() Cmd.GotoNextParagraphW() end},
	{"ZPP",    nil, "Goto previous paragraph",    "^UP",      
						function() Cmd.MoveWhileSelected() Cmd.GotoPreviousParagraphW() end},
	{"ZH",     nil, "Goto beginning of line",     "HOME",     
						function() Cmd.MoveWhileSelected() Cmd.GotoBeginningOfLine() end},
	{"ZE",     nil, "Goto end of line",           "END",      
						function() Cmd.MoveWhileSelected() Cmd.GotoEndOfLine() end},
	{"ZBD",    nil, "Goto beginning of document", "^PGUP",    
						function() Cmd.MoveWhileSelected() Cmd.GotoBeginningOfDocument() end},
	{"ZED",    nil, "Goto end of document",       "^PGDN",    
						function() Cmd.MoveWhileSelected() Cmd.GotoEndOfDocument() end},
	{"ZPGUP",  nil, "Page up",                    "PGUP",      
						function() Cmd.MoveWhileSelected() Cmd.GotoPreviousPage() end},
	{"ZPGDN",  nil, "Page down",                  "PGDN",      
						function() Cmd.MoveWhileSelected() Cmd.GotoNextPage() end},
	{"ZDPC",   nil, "Delete previous character",  "BACKSPACE",
						function() Cmd.TypeWhileSelected() Cmd.DeletePreviousChar() end},
	{"ZDNC",   nil, "Delete next character",      "DELETE",    
						function() Cmd.TypeWhileSelected() Cmd.DeleteNextChar() end},
	{"ZDW",    nil, "Delete word",                "^E",        
						function() Cmd.TypeWhileSelected() Cmd.DeleteWord() end},
	{"ZM",     nil, "Toggle mark",                "^@",        Cmd.ToggleMark},
})

local MainMenu = addmenu("Main Menu",
{
	{"F",  "F", "File ▷",           nil,  FileMenu},
	{"E",  "E", "Edit ▷",           nil,  EditMenu},
	{"S",  "S", "Style ▷",          nil,  StyleMenu},
	{"D",  "D", "Documents ▷",      nil,  DocumentsMenu},
	{"Z",  "Z", "Navigation ▷",     nil,  NavigationMenu}
})

--- MENU DRIVER CLASS ---

MenuClass = {
	activate = function(self, menu)
		menu = menu or MainMenu
		self:runmenu(0, 0, menu)
		QueueRedraw()
		SetNormal()
	end,
	
	drawmenu = function(self, x, y, menu, n)
		local akw = 0
		for _, item in ipairs(menu) do
			local ak = self.accelerators[item.id]
			if ak then
				local l = GetStringWidth(ak)
				if (akw < l) then
					akw = l
				end
			end
		end
		if (akw > 0) then
			akw = akw + 1
		end
		
		local w = menu.maxwidth + 4 + akw
		DrawTitledBox(x, y, w, #menu, menu.label)
		
		for i, item in ipairs(menu) do
			local ak = self.accelerators[item.id]
			
			if (item == "-") then
				if (i == n) then
					SetReverse()
				end
				SetBright()
				Write(x+1, y+i, string.rep("─", w))
			else
				if (i == n) then
					SetReverse()
					Write(x+1, y+i, string.rep(" ", w))
				end
				
				Write(x+4, y+i, item.label)

				SetBold()
				SetBright()
				if ak then
					local l = GetStringWidth(ak)
					Write(x+w-l, y+i, ak)
				end
		
				if item.mk then
					Write(x+2, y+i, item.mk)
				end
			end
			
			SetNormal()
		end
		GotoXY(ScreenWidth-1, ScreenHeight-1)
		
		DrawStatusLine("^V rebinds a menu item; ^X unbinds it; ^R resets all bindings to default.")
	end,
	
	drawmenustack = function(self)
		local osb = DocumentSet.statusbar
		DocumentSet.statusbar = true
		RedrawScreen()
		DocumentSet.statusbar = osb
		
		local o = 0
		for _, menu in ipairs(menu_stack) do
			self:drawmenu(o*4, o*2, menu.menu, menu.n)
			o = o + 1
		end
	end,
	
	runmenu = function(self, x, y, menu)
		local n = 1
		
		while true do
			local id
			
			while true do
				self:drawmenu(x, y, menu, n)
				
				local c = GetChar():upper()
				if (c == "KEY_UP") and (n > 1) then
					n = n - 1
				elseif (c == "KEY_DOWN") and (n < #menu) then
					n = n + 1
				elseif (c == "KEY_RETURN") or (c == "KEY_RIGHT") then
					if (type(menu[n]) ~= "string") then
						id = menu[n].id
						break
					end
				elseif (c == "KEY_LEFT") then
					return nil
				elseif (c == "KEY_ESCAPE") then
					return false
				elseif (c == "KEY_^C") then
					return false
				elseif (c == "KEY_^X") then
					local item = menu[n]
					if (type(item) ~= "string") then
						local ak = self.accelerators[item.id]
						if ak then
							self.accelerators[ak] = nil
							self.accelerators[item.id] = nil
							self:drawmenustack()
						end
					end
				elseif (c == "KEY_^V") then
					local item = menu[n]
					if (type(item) ~= "string") and 
							not self.accelerators[item.id] then
						DrawStatusLine("Press new accelerator key for menu item.")
						
						local ak = GetChar():upper()
						if ak:match("^KEY_") then
							ak = ak:gsub("^KEY_", "")
							if self.accelerators[ak] then
								NonmodalMessage("Sorry, "..ak.." is already bound elsewhere.")
							elseif (ak == "ESCAPE") or (ak == "RESIZE") then
								NonmodalMessage("You can't bind that key.")
							else
								self.accelerators[ak] = item.id
								self.accelerators[item.id] = ak
							end
							self:drawmenustack()
						end
					end
				elseif (c == "KEY_^R") then
					if PromptForYesNo("Reset menu keybindings?",
						"Are you sure you want to reset all the menu "..
						"keybindings back to their defaults?") then
						DocumentSet.menu = CreateMenu()
						DocumentSet:touch()
						NonmodalMessage("All keybindings have been reset to their default settings.")
						menu_stack = {}
						return false
					end
					self:drawmenustack()
				elseif menu.mks[c] then
					id = menu.mks[c].id
					break
				end
			end
			
			local item = menu_tab[id]
			local f = item.fn
			
			if (type(f) == "table") then
				menu_stack[#menu_stack+1] = {
					menu = menu,
					n = n
				}
				
				local r = self:runmenu(x+4, y+2, f)
				menu_stack[#menu_stack] = nil

				if (r == true) then
					return true
				elseif (r == false) then
					return false
				end
				
				self:drawmenustack()
			else
				if not f then
					ModalMessage("Not implemented yet", "Sorry, that feature isn't implemented yet. (This should never happen. Complain.)")
				else
					local _, msg = f()
					if msg then
						NonmodalMessage(msg)
					end
				end
				menu_stack = {}
				return true
			end
		end
	end,
	
	lookupAccelerator = function(self, c)
		c = c:gsub("^KEY_", "")

		-- Check the overrides table and only then the documentset keymap.
		
		local id = CheckOverrideTable(c) or self.accelerators[c]
		if not id then
			return nil
		end
		
		-- Found something? Find out what function the menu ID corresponds to.
		-- (Or maybe it's a raw function.)
		
		local f
		if (type(id) == "function") then
			f = id
		else
			local item = menu_tab[id]
			if not item then
				f = function()
					NonmodalMessage("Menu item with ID "..id.." not found.")
				end
			else
				f = item.fn
			end
		end
		return f
	end,
}

function CreateMenu()
	local my_key_tab = {}
	for ak, id in pairs(key_tab) do
		my_key_tab[ak] = id
		my_key_tab[id] = ak
	end
	
	local m = {
		accelerators = my_key_tab
	}
	setmetatable(m, {__index = MenuClass})
	return m
end

function RebuildParagraphStylesMenu(styles)
	submenu(ParagraphStylesMenu)
	
	local m = {}
	
	for id, style in ipairs(styles) do
		local shortcut
		if (id <= 10) then
			shortcut = tostring(id - 1)
		else
			shortcut = string.char(id + 54)
		end
		
		m[#m+1] = {"SP"..id, shortcut, style.name..": "..style.desc, nil,
			function()
				Cmd.ChangeParagraphStyle(style.name)
			end}
	end

	addmenu("Paragraph Styles", m, ParagraphStylesMenu)
end

function RebuildDocumentsMenu(documents)
	-- Remember any accelerator keys and unhook the old menu.
	
	local ak_tab = {}
	for _, item in ipairs(DocumentsMenu) do
		local ak = DocumentSet.menu.accelerators[item.id]
		if ak then
			ak_tab[item.label] = ak
		end
	end
	submenu(DocumentsMenu)
	
	-- Construct the new menu.
	
	local m = {}
	for id, document in ipairs(documents) do
		local ak = ak_tab[document.name]
		local shortcut
		if (id <= 10) then
			shortcut = tostring(id - 1)
		else
			shortcut = string.char(id + 54)
		end
		
		m[#m+1] = {"D"..id, shortcut, document.name, ak,
			function()
				Cmd.ChangeDocument(document.name)
			end}
	end
	
	-- Hook it.
	
	addmenu("Documents", m, DocumentsMenu)
end

function ListMenuItems()
	local function list(menu)
		for _, item in ipairs(menu) do
			if (type(item) == "table") then
				io.stdout:write(
					string.format("%15s %s\n", item.id, item.label))
				if (type(item.fn) == "table") then
					list(item.fn)
				end
			end
		end
	end

	io.stdout:write("All supported menu items:\n\n")
	list(MainMenu)
end

