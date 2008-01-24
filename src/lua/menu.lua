-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local Write = wg.write
local ClearToEOL = wg.cleartoeol
local GetChar = wg.getchar
local Goto = wg.goto
local SetBold = wg.setbold
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
	{"FIhtml", "H", "Import HTML file...",       nil,         Cmd.ImportHTMLFile},
	{"FItxt",  "T", "Import text file...",       nil,         Cmd.ImportTextFile},
})

local ExportMenu = addmenu("Export current document",
{
	{"FEhtml", "H", "Export to HTML...",         nil,         Cmd.ExportHTMLFile},
	{"FEtxt",  "T", "Export to plain text...",   nil,         Cmd.ExportTextFile},
})

local FileMenu = addmenu("File",
{
	{"FN",     "N", "New document set",          nil,         Cmd.CreateBlankDocumentSet},
	{"FO",     "O", "Load document set...",      nil,         Cmd.LoadDocumentSet},
	{"FS",     "S", "Save document set",         "^S",        Cmd.SaveCurrentDocument},
	{"FA",     "A", "Save document set as...",   nil,         Cmd.SaveCurrentDocumentAs},
	"-",
	{"FB",     "B", "Add new blank document",    nil,         Cmd.AddBlankDocument},
	{"FI",     "I", "Import new document ▷",     nil,         ImportMenu},
	{"FE",     "E", "Export current document ▷", nil,         ExportMenu},
	"-",
	{"FR",     "R", "Rename document...",        nil,         Cmd.RenameDocument},
	{"FD",     "D", "Delete document...",        nil,         Cmd.DeleteDocument},
	"-",
	{"Fabout", "Z", "About WordGrinder...",      nil,         Cmd.AboutWordGrinder},
	{"FQ",     "X", "Exit",                      "^Q",        Cmd.TerminateProgram}
})

local EditMenu = addmenu("Edit",
{
	{"ET",     "T", "Cut",                       "^X",        Cmd.Cut},
	{"EC",     "C", "Copy",                      "^C",        Cmd.Copy},
	{"EP",     "P", "Paste",                     "^V",        Cmd.Paste},
	{"ED",     "D", "Delete",                    nil,         Cmd.Delete},
	"-",
	{"EF",     "F", "Find and replace...",       "^F",        Cmd.Find},
	{"EN",     "N", "Find next",                 "^K",        Cmd.FindNext},
	{"ER",     "R", "Replace then find",         "^R",        Cmd.ReplaceThenFind},
})

local MarginMenu = addmenu("Margin",
{
	{"SM1",    "H", "Hide margin",               "",          function() Cmd.SetViewMode(1) end},
	{"SM2",    "S", "Show paragraph styles",     "",          function() Cmd.SetViewMode(2) end},
	{"SM3",    "N", "Show paragraph numbers",    "",          function() Cmd.SetViewMode(3) end},
	{"SM4",    "W", "Show paragraph word counts", "",         function() Cmd.SetViewMode(4) end},
})
	
local StyleMenu = addmenu("Style",
{
	{"SB",     "I", "Set italic",                "^I",        function() Cmd.ToggleStyle("i") end},
	{"SU",     "U", "Set underline",             "^U",        function() Cmd.ToggleStyle("u") end},
	{"SO",     "O", "Set plain",                 "^O",        function() Cmd.ToggleStyle("o") end},
	"-",
	{"SP",     "P", "Change paragraph style ▷",  "^P",        ParagraphStylesMenu},
	{"SM",     "M", "Set margin mode ▷",         "",          MarginMenu},
	{"SS",     "S", "Toggle status bar",         "^W",        Cmd.ToggleStatusBar},
})

local NavigationMenu = addmenu("Navigation",
{
	{"ZU",     nil, "Cursor up",                 "UP",        Cmd.GotoPreviousLine},
	{"ZR",     nil, "Cursor right",              "RIGHT",     Cmd.GotoNextCharW},
	{"ZD",     nil, "Cursor down",               "DOWN",      Cmd.GotoNextLine},
	{"ZL",     nil, "Cursor left",               "LEFT",      Cmd.GotoPreviousCharW},
	{"ZPGUP",  nil, "Page up",                   "PPAGE",     Cmd.GotoPreviousPage},
	{"ZPGDN",  nil, "Page down",                 "NPAGE",     Cmd.GotoNextPage},
	{"ZH",     nil, "Goto beginning of line",    "HOME",      Cmd.GotoBeginningOfLine},
	{"ZE",     nil, "Goto end of line",          "END",       Cmd.GotoEndOfLine},
	{"ZDPC",   nil, "Delete previous character", "BACKSPACE", Cmd.DeletePreviousChar},
	{"ZDNC",   nil, "Delete next character",     "DC",        Cmd.DeleteNextChar},
	{"ZM",     nil, "Toggle mark",               "^@",        Cmd.ToggleMark},
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
		SetBold()
		DrawTitledBox(x, y, w, #menu, menu.label)
		SetNormal()
		
		for i, item in ipairs(menu) do
			local ak = self.accelerators[item.id]
			
			if (item == "-") then
				if (i == n) then
					SetReverse()
				end
				Write(x+1, y+i, string.rep("─", w))
			else
				if (i == n) then
					SetReverse()
					Write(x+1, y+i, string.rep(" ", w))
				end
				
				Write(x+4, y+i, item.label)
				if ak then
					local l = GetStringWidth(ak)
					SetBold()
					Write(x+w-l, y+i, ak)
				end
		
				if item.mk then
					SetBold()
					Write(x+2, y+i, item.mk)
				end
			end
			
			SetNormal()
		end
		Goto(ScreenWidth-1, ScreenHeight-1)
		
		DrawStatusLine("^V rebinds a menu item; ^X unbinds it; ^R resets all bindings to default.")
	end,
	
	drawmenustack = function(self)
		RedrawScreen()
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
				if (r == true) then
					return true
				elseif (r == false) then
					return false
				end
				
				self:drawmenustack()
				menu_stack[#menu_stack] = nil
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
		local id = self.accelerators[c]
		if not id then
			return nil
		end
		
		local item = menu_tab[id]
		local f
		if not item then
			f = function()
				NonmodalMessage("Fnord: menu ID "..id.." not found.")
			end
		else
			f = item.fn
		end
		return f
	end
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
		m[#m+1] = {"SP"..id, tostring(id-1), style.name..": "..style.desc, nil,
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
