-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
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

local cp = Cmd.Checkpoint

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
	{"FEmd",   "M", "Export to Markdown...",     nil,         Cmd.ExportMarkdownFile},
	{"FEtxt",  "T", "Export to plain text...",   nil,         Cmd.ExportTextFile},
	{"FEtex",  "L", "Export to LaTeX...",        nil,         Cmd.ExportLatexFile},
	{"FEtr",   "F", "Export to Troff...",        nil,         Cmd.ExportTroffFile},
--	{"FErtf",  "R", "Export to Rtf...",          nil,         Cmd.ExportRTFFile},
})

local DocumentSettingsMenu = addmenu("Document settings",
{
    {"FSautosave",     "A", "Autosave...",           nil,         Cmd.ConfigureAutosave},
    {"FSscrapbook",    "S", "Scrapbook...",          nil,         Cmd.ConfigureScrapbook},
    {"FSHTMLExport",   "H", "HTML export...",        nil,         Cmd.ConfigureHTMLExport},
	{"FSPageCount",    "P", "Page count...",         nil,         Cmd.ConfigurePageCount},
	{"FSSmartquotes",  "Q", "Smart quotes...",       nil,         Cmd.ConfigureSmartQuotes},
	{"FSSpellchecker", "K", "Spellchecker...",       nil,         Cmd.ConfigureSpellchecker},
})

local GlobalSettingsMenu = addmenu("Global settings",
{
	{"FSlookandfeel","L", "Change look and feel...",       nil,   Cmd.ConfigureLookAndFeel},
	{"FSDictionary", "D", "Load new system dictionary...", nil,   Cmd.ConfigureSystemDictionary},
	"-",
	{"FSDebug",      "X", "Debugging options...",    nil,         Cmd.ConfigureDebug},
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
	{"EScut",      "T", "Cut to scrapbook",          nil,         { cp, Cmd.CutToScrapbook }},
	{"EScopy",     "C", "Copy to scrapbook",         nil,         Cmd.CopyToScrapbook},
	{"ESpaste",    "P", "Paste to scrapbook",        nil,         { cp, Cmd.PasteToScrapbook }},
})

local SpellcheckMenu = addmenu("Spellchecker",
{
	{"ECfind",     "F", "Find next misspelt word",        "^L",   Cmd.FindNextMisspeltWord },
	{"ECadd",      "A", "Add current word to dictionary", "^M",   { cp, Cmd.AddToUserDictionary }},
})

local EditMenu = addmenu("Edit",
{
	{"ET",         "T", "Cut",                       "^X",        { cp, Cmd.Cut }},
	{"EC",         "C", "Copy",                      "^C",        Cmd.Copy},
	{"EP",         "P", "Paste",                     "^V",        { cp, Cmd.Paste }},
	{"ED",         "D", "Delete",                    nil,         { cp, Cmd.Delete }},
	"-",
	{"Eundo",      "U", "Undo",                      "^Z",        Cmd.Undo},
	{"Eredo",      "E", "Redo",                      "^Y",        Cmd.Redo},
	"-",
	{"EF",         "F", "Find and replace...",       "^F",        Cmd.Find},
	{"EN",         "N", "Find next",                 "^K",        Cmd.FindNext},
	{"ER",         "R", "Replace then find",         "^R",        { cp, Cmd.ReplaceThenFind }},
	{"Esq",        "Q", "Smartquotify selection",    nil,         Cmd.Smartquotify},
	{"Eusq",       "W", "Unsmartquotify selection",  nil,         Cmd.Unsmartquotify},
	"-",
	{"EG",         "G", "Go to...",                  "^G",        Cmd.Goto},
	{"Escrapbook", "S", "Scrapbook ▷",               nil,         ScrapbookMenu},
	{"Espell",     "K", "Spellchecker ▷",            nil,         SpellcheckMenu},
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
	{"SI",     "I", "Set italic",                 "^I",        { cp, function() Cmd.SetStyle("i") end }},
	{"SU",     "U", "Set underline",              "^U",        { cp, function() Cmd.SetStyle("u") end }},
	{"SB",     "B", "Set bold",                   "^B",        { cp, function() Cmd.SetStyle("b") end }},
	{"SO",     "O", "Set plain",                  "^O",        { cp, function() Cmd.SetStyle("o") end }},
	"-",
	{"SP",     "P", "Change paragraph style ▷",   "^P",        ParagraphStylesMenu},
	{"SM",     "M", "Set margin mode ▷",          nil,         MarginMenu},
	{"SS",     "S", "Toggle status bar",          nil,         Cmd.ToggleStatusBar},
})

local NavigationMenu = addmenu("Navigation",
{
	{"ZU",     nil, "Cursor up",                    "UP",        { Cmd.MoveWhileSelected, Cmd.GotoPreviousLine }},
	{"ZR",     nil, "Cursor right",                 "RIGHT",     { Cmd.MoveWhileSelected, Cmd.GotoNextCharW }},
	{"ZD",     nil, "Cursor down",                  "DOWN",      { Cmd.MoveWhileSelected, Cmd.GotoNextLine }},
	{"ZL",     nil, "Cursor left",                  "LEFT",      { Cmd.MoveWhileSelected, Cmd.GotoPreviousCharW }},
	{"ZSU",    nil, "Selection up",                 "SUP",       { Cmd.SetMark, Cmd.GotoPreviousLine }},
	{"ZSR",    nil, "Selection right",              "SRIGHT",    { Cmd.SetMark, Cmd.GotoNextCharW }},
	{"ZSD",    nil, "Selection down",               "SDOWN",     { Cmd.SetMark, Cmd.GotoNextLine }},
	{"ZSL",    nil, "Selection left",               "SLEFT",     { Cmd.SetMark, Cmd.GotoPreviousCharW }},
	{"ZSW",    nil, "Select word",                  "^W",        Cmd.SelectWord },
	{"ZWL",    nil, "Goto previous word",           "^LEFT",     { Cmd.MoveWhileSelected, Cmd.GotoPreviousWordW }},
	{"ZWR",    nil, "Goto next word",               "^RIGHT",    { Cmd.MoveWhileSelected, Cmd.GotoNextWordW }},
	{"ZNP",    nil, "Goto next paragraph",          "^DOWN",     { Cmd.MoveWhileSelected, Cmd.GotoNextParagraphW }},
	{"ZPP",    nil, "Goto previous paragraph",      "^UP",       { Cmd.MoveWhileSelected, Cmd.GotoPreviousParagraphW }},
	{"ZSWL",   nil, "Select to previous word",      "S^LEFT",    { Cmd.SetMark, Cmd.GotoPreviousWordW }},
	{"ZSWR",   nil, "Select to next word",          "S^RIGHT",   { Cmd.SetMark, Cmd.GotoNextWordW }},
	{"ZSNP",   nil, "Select to next paragraph",     "S^DOWN",    { Cmd.SetMark, Cmd.GotoNextParagraphW }},
	{"ZSPP",   nil, "Select to previous paragraph", "S^UP",      { Cmd.SetMark, Cmd.GotoPreviousParagraphW }},
	{"ZH",     nil, "Goto beginning of line",       "HOME",      { Cmd.MoveWhileSelected, Cmd.GotoBeginningOfLine }},
	{"ZE",     nil, "Goto end of line",             "END",       { Cmd.MoveWhileSelected, Cmd.GotoEndOfLine }},
	{"ZSH",    nil, "Select to beginning of line",  "SHOME",     { Cmd.SetMark, Cmd.GotoBeginningOfLine }},
	{"ZSE",    nil, "Select to end of line",        "SEND",      { Cmd.SetMark, Cmd.GotoEndOfLine }},
	{"ZBD",    nil, "Goto beginning of document",   "^PGUP",     { Cmd.MoveWhileSelected, Cmd.GotoBeginningOfDocument }},
	{"ZED",    nil, "Goto end of document",         "^PGDN",     { Cmd.MoveWhileSelected, Cmd.GotoEndOfDocument }},
	{"ZSBD",   nil, "Select to beginning of document", "S^PGUP", { Cmd.SetMark, Cmd.GotoBeginningOfDocument }},
	{"ZSED",   nil, "Select to end of document",    "S^PGDN",    { Cmd.SetMark, Cmd.GotoEndOfDocument }},
	{"ZPGUP",  nil, "Page up",                      "PGUP",      { Cmd.MoveWhileSelected, Cmd.GotoPreviousPage }},
	{"ZPGDN",  nil, "Page down",                    "PGDN",      { Cmd.MoveWhileSelected, Cmd.GotoNextPage }},
	{"ZSPGUP", nil, "Selection page up",            "SPGUP",     { Cmd.SetMark, Cmd.GotoPreviousPage }},
	{"ZSPGDN", nil, "Selection page down",          "SPGDN",     { Cmd.SetMark, Cmd.GotoNextPage }},
	{"ZDPC",   nil, "Delete previous character",    "BACKSPACE", { cp, Cmd.DeleteSelectionOrPreviousChar }},
	{"ZDNC",   nil, "Delete next character",        "DELETE",    { cp, Cmd.DeleteSelectionOrNextChar }},
	{"ZDW",    nil, "Delete word",                  "^E",        { cp, Cmd.TypeWhileSelected, Cmd.DeleteWord }},
	{"ZM",     nil, "Toggle mark",                  "^@",        Cmd.ToggleMark},
})

local MainMenu = addmenu("Main Menu",
{
	{"F",  "F", "File ▷",           nil,  FileMenu},
	{"E",  "E", "Edit ▷",           nil,  EditMenu},
	{"S",  "S", "Style ▷",          nil,  StyleMenu},
	{"D",  "D", "Documents ▷",      nil,  DocumentsMenu},
	{"Z",  "Z", "Navigation ▷",     nil,  NavigationMenu}
})

function IsMenu(m)
	return (type(m) == "table") and (type(m[1]) ~= "function")
end

function RunMenuAction(ff)
	if (type(ff) == "function") then
		return ff()
	elseif IsMenu(ff) then
		Cmd.ActivateMenu(ff)
	else
		for _, f in ipairs(ff) do
			local result, e = f()
			if not result then
				return false, e
			end
		end
		return true
	end
end

--- MENU DRIVER CLASS ---

MenuClass = {
	activate = function(self, menu)
		menu = menu or MainMenu
		self:runmenu(0, 0, menu)
		QueueRedraw()
		SetNormal()
	end,

	drawmenu = function(self, x, y, menu, n, top)
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
		local visiblelen = min(#menu, ScreenHeight-y-3)
		top = max(1, min(#menu - visiblelen + 1, top))
		DrawTitledBox(x, y, w, visiblelen, menu.label)

		if (visiblelen < #menu) then
			local f1 = (top - 1) / #menu
			local f2 = (top + visiblelen - 1) / #menu
			local y1 = f1 * visiblelen + y + 1
			local y2 = f2 * visiblelen + y + 1
			SetBright()
			for yy = y1, y2 do
				Write(x+w+1, yy, "║")
			end
		end

		for i = top, top+visiblelen-1 do
			local item = menu[i]
			local ak = self.accelerators[item.id]
			local yy = y+i-top+1

			if (item == "-") then
				if (i == n) then
					SetReverse()
				end
				SetBright()
				Write(x+1, yy, string.rep("─", w))
			else
				SetNormal()
				if (i == n) then
					SetReverse()
					Write(x+1, yy, string.rep(" ", w))
				end

				Write(x+4, yy, item.label)

				SetBold()
				SetBright()
				if ak then
					local l = GetStringWidth(ak)
					Write(x+w-l, yy, ak)
				end

				if item.mk then
					Write(x+2, yy, item.mk)
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
		for _, m in ipairs(menu_stack) do
			self:drawmenu(o*4, o*2, m.menu, m.n, m.top)
			o = o + 1
		end
	end,

	runmenu = function(self, x, y, menu)
		local n = 1
		local top = 1

		while true do
			local id

			while true do
				local visiblelen = min(#menu, ScreenHeight-y-3)
				if (n < top) then
					top = n
				end
				if (n > (top+visiblelen-1)) then
					top = n - visiblelen + 1
				end

				self:drawmenu(x, y, menu, n, top)

				local c = GetChar():upper()
				if (c == "KEY_RESIZE") then
					ResizeScreen()
					RedrawScreen()
					self:drawmenustack()
				elseif (c == "KEY_UP") and (n > 1) then
					n = n - 1
				elseif (c == "KEY_DOWN") and (n < #menu) then
					n = n + 1
				elseif (c == "KEY_PGDN") then
					n = int(min(n + visiblelen/2, #menu))
				elseif (c == "KEY_PGUP") then
					n = int(max(n - visiblelen/2, 1))
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
					if (type(item) ~= "string") then
						DrawStatusLine("Press new accelerator key for menu item.")

						local oak = self.accelerators[item.id]
						local ak = GetChar():upper()
						if ak:match("^KEY_") then
							ak = ak:gsub("^KEY_", "")
							if self.accelerators[ak] then
								NonmodalMessage("Sorry, "..ak.." is already bound elsewhere.")
							elseif (ak == "ESCAPE") or (ak == "RESIZE") then
								NonmodalMessage("You can't bind that key.")
							else
								if oak then
									self.accelerators[oak] = nil
								end

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

			if IsMenu(f) then
				menu_stack[#menu_stack+1] = {
					menu = menu,
					n = n,
					top = top
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
					local _, msg = RunMenuAction(f)
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
		c = c:gsub("^KEY_", ""):upper()

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
			if IsMenu(item) then
				io.stdout:write(
					string.format("%15s %s\n", item.id, item.label))
				if IsMenu(item.fn) then
					list(item.fn)
				end
			end
		end
	end

	io.stdout:write("All supported menu items:\n\n")
	list(MainMenu)
end

