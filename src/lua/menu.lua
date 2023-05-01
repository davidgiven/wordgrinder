--!nonstrict
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
local key_tab: {[string]: string} = {}
local menu_stack: {StackedMenu} = {}

local UseUnicode = wg.useunicode

type MenuItem = {
	label: string,
	id: string?,
	mk: string?,
	ak: string?,
	fn: MenuCallback?,
	menu: Menu?,
}

type Menu = {
	[number]: MenuItem,
	label: string,
	maxwidth: number,
	realwidth: number,
	mks: {[string]: MenuItem}
}

type MenuCallback = () -> (boolean | Menu, any?)

type StackedMenu = {
	menu: Menu,
	n: number,
	top: number
}

local MenuTree = {}
MenuTree.__index = MenuTree
type MenuTree = {
}

function CreateMenu(n: string, m: {MenuItem}, replaces: Menu?): Menu
	local w = n:len()
	local menu: Menu = {
		label = "",
		maxwidth = 0,
		realwidth = 0,
		mks = {}
	}
	if replaces then
		menu = replaces
	end

	menu.label = n
	menu.mks = {}

	for i, _ in ipairs(menu) do
		menu[i] = nil
	end

	for _, item in ipairs(m) do
		menu[#menu+1] = item

		if item.mk then
			if menu.mks[item.mk] then
				error("Duplicate menu action key "..item.mk)
			end
			menu.mks[item.mk] = item
		end

		if item.id then
			if menu_tab[item.id] then
				error("Dupicate menu ID "..item.id)
			end
			menu_tab[item.id] = item

			if item.ak then
				key_tab[item.ak] = item.id
			end
		end

		print(item.id)
		if (item.label:len() > w) then
			w = item.label:len()
		end
	end

	menu.maxwidth = w
	return menu
end

local function submenu(menu: Menu)
	for _, item in ipairs(menu) do
		if item.id then
			menu_tab[item.id] = nil
		end
		if item.ak then
			key_tab[item.ak] = nil
		end
	end
end

local DocumentsMenu = CreateMenu("Documents", {})
local ParagraphStylesMenu = CreateMenu("Paragraph Styles", {})

local cp = Cmd.Checkpoint

function GroupCallback(fns: {MenuCallback})
	return function()
		for _, f in fns do
			local result, e = f()
			if type(result) == "table" then
				return result
			end
			if not result then
				return false, e
			end
		end
		return true, nil
	end
end

local function E(id: string, mk: string?, label: string, ak: string?,
		...: MenuCallback): MenuItem
	return {
		id = id,
		mk = mk,
		label = label,
		ak = ak,
		fn = GroupCallback({...})
	}
end

local function M(id: string, mk: string?, label: string, ak: string?,
	menu: Menu): MenuItem
	return {
		id = id,
		mk = mk,
		label = label,
		ak = ak,
		menu = menu
	}
end

local separator: MenuItem = { label = "-" }

local ImportMenu = CreateMenu("Import new document",
{
	E("FIodt",  "O", "Import ODT file...",        nil,         Cmd.ImportODTFile),
	E("FIhtml", "H", "Import HTML file...",       nil,         Cmd.ImportHTMLFile),
	E("FImd",   "M", "Import Markdown file...",   nil,         Cmd.ImportMarkdownFile),
	E("FItxt",  "T", "Import text file...",       nil,         Cmd.ImportTextFile),
})

local ExportMenu = CreateMenu("Export current document",
{
	E("FEodt",  "O", "Export to ODT...",          nil,         Cmd.ExportODTFile),
	E("FEhtml", "H", "Export to HTML...",         nil,         Cmd.ExportHTMLFile),
	E("FEmd",   "M", "Export to Markdown...",     nil,         Cmd.ExportMarkdownFile),
	E("FEtxt",  "T", "Export to plain text...",   nil,         Cmd.ExportTextFile),
	E("FEtex",  "L", "Export to LaTeX...",        nil,         Cmd.ExportLatexFile),
	E("FEtr",   "F", "Export to Troff...",        nil,         Cmd.ExportTroffFile),
	E("FEorg",  "E", "Export to Emacs Org...",    nil,         Cmd.ExportOrgFile),
--	{"FErtf",  "R", "Export to Rtf...",          nil,         Cmd.ExportRTFFile},
})

local DocumentSettingsMenu = CreateMenu("Document settings",
{
    E("FSautosave",     "A", "Autosave...",       nil,         Cmd.ConfigureAutosave),
    E("FSscrapbook",    "S", "Scrapbook...",      nil,         Cmd.ConfigureScrapbook),
    E("FSHTMLExport",   "H", "HTML export...",    nil,         Cmd.ConfigureHTMLExport),
	E("FSPageCount",    "P", "Page count...",     nil,         Cmd.ConfigurePageCount),
	E("FSSmartquotes",  "Q", "Smart quotes...",   nil,         Cmd.ConfigureSmartQuotes),
	E("FSSpellchecker", "K", "Spellchecker...",   nil,         Cmd.ConfigureSpellchecker),
})

local GlobalSettingsMenu = CreateMenu("Global settings",
{
	E("FSgui",         "G", "Configure GUI...",              nil,   Cmd.ConfigureGui),
	E("FSlookandfeel", "L", "Change look and feel...",       nil,   Cmd.ConfigureLookAndFeel),
	E("FSDictionary",  "D", "Load new system dictionary...", nil,   Cmd.ConfigureSystemDictionary),
	E("FSdirectories", "R", "Change directories...",         nil,   Cmd.ConfigureDirectories),
	separator,
	E("FSDebug",       "X", "Debugging options...",    		 nil,   Cmd.ConfigureDebug),
})

local FileMenu = CreateMenu("File",
{
	E("FN",         "N", "New document set",          nil,         Cmd.CreateBlankDocumentSet),
	E("FO",         "O", "Load document set...",      nil,         Cmd.LoadDocumentSet),
	E("FS",         "S", "Save document set",         "^S",        Cmd.SaveCurrentDocument),
	E("FA",         "A", "Save document set as...",   nil,         Cmd.SaveCurrentDocumentAs),
	E("FR",         "R", "Load recent document >",    nil,         Cmd.LoadRecentDocument),
	separator,
	E("FCtemplate", "C", "Create from template...",   nil,         Cmd.CreateDocumentSetFromTemplate),
	E("FMtemplate", "M", "Save as template...",       nil,         Cmd.SaveCurrentDocumentAsTemplate),
	separator,
	E("FB",         "B", "Add new blank document",    nil,         Cmd.AddBlankDocument),
	M("FI",         "I", "Import new document >",     nil,         ImportMenu),
	M("FE",         "E", "Export current document >", nil,         ExportMenu),
	E("Fdocman",    "D", "Manage documents...",       nil,         Cmd.ManageDocumentsUI),
	separator,
	M("Fsettings",  "T", "Document settings >",       nil,         DocumentSettingsMenu),
	M("Fglobals",   "G", "Global settings >",         nil,         GlobalSettingsMenu),
	separator,
	E("Fabout",     "Z", "About WordGrinder...",      nil,         Cmd.AboutWordGrinder),
	E("FQ",         "X", "Exit",                      "^Q",        Cmd.TerminateProgram),
})

local ScrapbookMenu = CreateMenu("Scrapbook",
{
	E("EScut",      "T", "Cut to scrapbook",          nil,         cp, Cmd.CutToScrapbook),
	E("EScopy",     "C", "Copy to scrapbook",         nil,         Cmd.CopyToScrapbook),
	E("ESpaste",    "P", "Paste to scrapbook",        nil,         cp, Cmd.PasteToScrapbook),
})

local SpellcheckMenu = CreateMenu("Spellchecker",
{
	E("ECfind",     "F", "Find next misspelt word",        "^L",   Cmd.FindNextMisspeltWord),
	E("ECadd",      "A", "Add current word to dictionary", "^M",   cp, Cmd.AddToUserDictionary),
})

local EditMenu = CreateMenu("Edit",
{
	E("ET",         "T", "Cut",                       "^X",        cp, Cmd.Cut),
	E("EC",         "C", "Copy",                      "^C",        Cmd.Copy),
	E("EP",         "P", "Paste",                     "^V",        cp, Cmd.Paste),
	E("ED",         "D", "Delete",                    nil,         cp, Cmd.Delete),
	separator,
	E("Eundo",      "U", "Undo",                      "^Z",        Cmd.Undo),
	E("Eredo",      "E", "Redo",                      "^Y",        Cmd.Redo),
	separator,
	E("EF",         "F", "Find and replace...",       "^F",        Cmd.Find),
	E("EN",         "N", "Find next",                 "^K",        Cmd.FindNext),
	E("ER",         "R", "Replace then find",         "^R",        cp, Cmd.ReplaceThenFind),
	E("Esq",        "Q", "Smartquotify selection",    nil,         Cmd.Smartquotify),
	E("Eusq",       "W", "Unsmartquotify selection",  nil,         Cmd.Unsmartquotify),
	separator,
	E("EG",         "G", "Go to...",                  "^G",        Cmd.Goto),
	M("Escrapbook", "S", "Scrapbook >",               nil,         ScrapbookMenu),
	M("Espell",     "K", "Spellchecker >",            nil,         SpellcheckMenu),
})

local MarginMenu = CreateMenu("Margin",
{
	E("SM1",    "H", "Hide margin",                nil,         function() return Cmd.SetViewMode(1) end),
	E("SM2",    "S", "Show paragraph styles",      nil,         function() return Cmd.SetViewMode(2) end),
	E("SM3",    "N", "Show paragraph numbers",     nil,         function() return Cmd.SetViewMode(3) end),
	E("SM4",    "W", "Show paragraph word counts", nil,         function() return Cmd.SetViewMode(4) end),
})

local StyleMenu = CreateMenu("Style",
{
	E("SI",     "I", "Set italic",                 "^I",        cp, function() return Cmd.SetStyle("i") end),
	E("SU",     "U", "Set underline",              "^U",        cp, function() return Cmd.SetStyle("u") end),
	E("SB",     "B", "Set bold",                   "^B",        cp, function() return Cmd.SetStyle("b") end),
	E("SO",     "O", "Set plain",                  "^O",        cp, function() return Cmd.SetStyle("o") end),
	separator,
	M("SP",     "P", "Change paragraph style >",   "^P",        ParagraphStylesMenu),
	M("SM",     "M", "Set margin mode >",          nil,         MarginMenu),
	E("SS",     "S", "Toggle status bar",          nil,         Cmd.ToggleStatusBar),
})

local NavigationMenu = CreateMenu("Navigation",
{
	E("ZU",     nil, "Cursor up",                    "UP",         Cmd.MoveWhileSelected, Cmd.GotoPreviousLine),
	E("ZR",     nil, "Cursor right",                 "RIGHT",      Cmd.MoveWhileSelected, Cmd.GotoNextCharW),
	E("ZD",     nil, "Cursor down",                  "DOWN",       Cmd.MoveWhileSelected, Cmd.GotoNextLine),
	E("ZL",     nil, "Cursor left",                  "LEFT",       Cmd.MoveWhileSelected, Cmd.GotoPreviousCharW),
	E("ZMU",    nil, "Scroll up",                    "SCROLLUP",   Cmd.MoveWhileSelected, Cmd.GotoPreviousLine),
	E("ZMD",    nil, "Scroll down",                  "SCROLLDOWN", Cmd.MoveWhileSelected, Cmd.GotoNextLine),
	E("ZSU",    nil, "Selection up",                 "SUP",        Cmd.SetMark, Cmd.GotoPreviousLine),
	E("ZSR",    nil, "Selection right",              "SRIGHT",     Cmd.SetMark, Cmd.GotoNextCharW),
	E("ZSD",    nil, "Selection down",               "SDOWN",      Cmd.SetMark, Cmd.GotoNextLine),
	E("ZSL",    nil, "Selection left",               "SLEFT",      Cmd.SetMark, Cmd.GotoPreviousCharW),
	E("ZSW",    nil, "Select word",                  "^W",         Cmd.SelectWord),
	E("ZWL",    nil, "Goto previous word",           "^LEFT",      Cmd.MoveWhileSelected, Cmd.GotoPreviousWordW),
	E("ZWR",    nil, "Goto next word",               "^RIGHT",     Cmd.MoveWhileSelected, Cmd.GotoNextWordW),
	E("ZNP",    nil, "Goto next paragraph",          "^DOWN",      Cmd.MoveWhileSelected, Cmd.GotoNextParagraphW),
	E("ZPP",    nil, "Goto previous paragraph",      "^UP",        Cmd.MoveWhileSelected, Cmd.GotoPreviousParagraphW),
	E("ZSWL",   nil, "Select to previous word",      "S^LEFT",     Cmd.SetMark, Cmd.GotoPreviousWordW),
	E("ZSWR",   nil, "Select to next word",          "S^RIGHT",    Cmd.SetMark, Cmd.GotoNextWordW),
	E("ZSNP",   nil, "Select to next paragraph",     "S^DOWN",     Cmd.SetMark, Cmd.GotoNextParagraphW),
	E("ZSPP",   nil, "Select to previous paragraph", "S^UP",       Cmd.SetMark, Cmd.GotoPreviousParagraphW),
	E("ZH",     nil, "Goto beginning of line",       "HOME",       Cmd.MoveWhileSelected, Cmd.GotoBeginningOfLine),
	E("ZE",     nil, "Goto end of line",             "END",        Cmd.MoveWhileSelected, Cmd.GotoEndOfLine),
	E("ZSH",    nil, "Select to beginning of line",  "SHOME",      Cmd.SetMark, Cmd.GotoBeginningOfLine),
	E("ZSE",    nil, "Select to end of line",        "SEND",       Cmd.SetMark, Cmd.GotoEndOfLine),
	E("ZBD",    nil, "Goto beginning of document",   "^PGUP",      Cmd.MoveWhileSelected, Cmd.GotoBeginningOfDocument),
	E("ZED",    nil, "Goto end of document",         "^PGDN",      Cmd.MoveWhileSelected, Cmd.GotoEndOfDocument),
	E("ZSBD",   nil, "Select to beginning of document", "S^PGUP",  Cmd.SetMark, Cmd.GotoBeginningOfDocument),
	E("ZSED",   nil, "Select to end of document",    "S^PGDN",     Cmd.SetMark, Cmd.GotoEndOfDocument),
	E("ZPGUP",  nil, "Page up",                      "PGUP",       Cmd.MoveWhileSelected, Cmd.GotoPreviousPage),
	E("ZPGDN",  nil, "Page down",                    "PGDN",       Cmd.MoveWhileSelected, Cmd.GotoNextPage),
	E("ZSPGUP", nil, "Selection page up",            "SPGUP",      Cmd.SetMark, Cmd.GotoPreviousPage),
	E("ZSPGDN", nil, "Selection page down",          "SPGDN",      Cmd.SetMark, Cmd.GotoNextPage),
	E("ZDPC",   nil, "Delete previous character",    "BACKSPACE",  cp, Cmd.DeleteSelectionOrPreviousChar),
	E("ZDNC",   nil, "Delete next character",        "DELETE",     cp, Cmd.DeleteSelectionOrNextChar),
	E("ZDW",    nil, "Delete word",                  "^E",         cp, Cmd.TypeWhileSelected, Cmd.DeleteWord),
	E("ZM",     nil, "Toggle mark",                  "^@",         Cmd.ToggleMark),
})

local MainMenu = CreateMenu("Main Menu",
{
	M("F",  "F", "File >",           nil,  FileMenu),
	M("E",  "E", "Edit >",           nil,  EditMenu),
	M("S",  "S", "Style >",          nil,  StyleMenu),
	M("D",  "D", "Documents >",      nil,  DocumentsMenu),
	M("Z",  "Z", "Navigation >",     nil,  NavigationMenu),
})

--- MENU DRIVER CLASS ---

function MenuTree.activate(self, menu)
	menu = menu or MainMenu
	self:runmenu(0, 0, menu)
	QueueRedraw()
	SetNormal()
end

function MenuTree.drawmenu(self, x: number, y: number, menu: Menu, n: number, top: number)
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
	menu.realwidth = w
	local visiblelen = min(#menu, ScreenHeight-y-3)
	top = max(1, min(#menu - visiblelen + 1, top))
	SetColour(Palette.ControlFG, Palette.ControlBG)
	DrawTitledBox(x, y, w, visiblelen, menu.label)

	if (visiblelen < #menu) then
		local f1 = (top - 1) / #menu
		local f2 = (top + visiblelen - 1) / #menu
		local y1 = f1 * visiblelen + y + 1
		local y2 = f2 * visiblelen + y + 1
		SetBright()
		for yy = y1, y2 do
			Write(x+w+1, yy, UseUnicode() and "║" or "#")
		end
	end

	for i = top, top+visiblelen-1 do
		local item = menu[i]
		local ak = self.accelerators[item.id]
		local yy = y+i-top+1

		if (item.label == "-") then
			if (i == n) then
				SetReverse()
			end
			SetBright()
			Write(x+1, yy, string.rep(UseUnicode() and "─" or "-", w))
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
end

function MenuTree.drawmenustack(self)
	local osb = documentSet.statusbar
	documentSet.statusbar = true
	RedrawScreen()
	documentSet.statusbar = osb

	local o = 0
	for _, m in ipairs(menu_stack) do
		self:drawmenu(o*4, o*2, m.menu, m.n, m.top)
		o = o + 1
	end
end

function MenuTree.runmenu(self, x: number, y: number, menu: Menu): boolean?
	local n = 1
	local top = 1

	local function stackmenu(newmenu)
		return nil
	end

	while true do
		local item

		while not Quitting do
			local visiblelen = min(#menu, ScreenHeight-y-3)
			if (n < top) then
				top = n
			end
			if (n > (top+visiblelen-1)) then
				top = n - visiblelen + 1
			end

			self:drawmenu(x, y, menu, n, top)

			local c = GetChar()
			if typeof(c) == "table" then
				if c.b then
					-- Mouse event.
					if c.x < x then
						-- Go to the previous menu.
						return nil
					elseif c.x > (x + menu.realwidth) then
						-- Close all menus.
						return false
					else
						local row = top + c.y - y - 1
						if row < 1 then
							return nil
						elseif row > visiblelen then
							return false
						else
							item = menu[row]
							if (typeof(item) ~= "string") and item.id then
								n = row
								self:drawmenu(x, y, menu, n, top)
								break
							end
						end
					end
				end
			else
				-- Keyboard event.
				c = c:upper()
				if (c == "KEY_RESIZE") then
					ResizeScreen()
					RedrawScreen()
					self:drawmenustack()
				elseif (c == "KEY_QUIT") then
					QuitForcedBySystem()
					return false
				elseif (c == "KEY_UP") and (n > 1) then
					n = n - 1
				elseif (c == "KEY_DOWN") and (n < #menu) then
					n = n + 1
				elseif (c == "KEY_SCROLLUP") and (top > 1) then
					top = top - 1
					if (n > (top+visiblelen-1)) then
						n = n - 1
					end
				elseif (c == "KEY_SCROLLDOWN") and (top < (#menu - visiblelen)) then
					top = top + 1
					if (n < top) then
						n = n + 1
					end
				elseif (c == "KEY_PGDN") then
					n = int(min(n + visiblelen/2, #menu))
				elseif (c == "KEY_PGUP") then
					n = int(max(n - visiblelen/2, 1))
				elseif (c == "KEY_RETURN") or (c == "KEY_RIGHT") then
					if (typeof(menu[n]) ~= "string") then
						item = menu[n]
						break
					end
				elseif (c == "KEY_LEFT") then
					return nil
				elseif (c == "KEY_ESCAPE") then
					return false
				elseif (c == "KEY_MENU") then
					return false
				elseif (c == "KEY_^C") then
					return false
				elseif (c == "KEY_^X") then
					local item = menu[n]
					if (typeof(item) ~= "string") and item.id then
						local ak = self.accelerators[item.id]
						if ak then
							self.accelerators[ak] = nil
							self.accelerators[item.id] = nil
							self:drawmenustack()
						end
					end
				elseif (c == "KEY_^V") then
					local item = menu[n]
					if (typeof(item) ~= "string") and item.id then
						DrawStatusLine("Press new accelerator key for menu item.")

						local oak = self.accelerators[item.id]
						local ak = GetChar()
						if (typeof(ak) == "string") then
							ak = ak:upper()
							if (ak ~= "KEY_QUIT") and ak:match("^KEY_") then
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
					end
				elseif (c == "KEY_^R") then
					if PromptForYesNo("Reset menu keybindings?",
						"Are you sure you want to reset all the menu "..
						"keybindings back to their defaults?") then
						documentSet.menu = CreateMenuBindings()
						documentSet:touch()
						NonmodalMessage("All keybindings have been reset to their default settings.")
						menu_stack = {}
						return false
					end
					self:drawmenustack()
				elseif menu.mks[c] then
					item = menu.mks[c]
					break
				end
			end
		end
		if Quitting then
			return false
		end

		local newmenu = item.menu
		if item.fn then
			local f, msg = item.fn()
			if typeof(f) == "table" then
				newmenu = f
			else
				if msg then
					NonmodalMessage(msg)
				end
				menu_stack = {}
				return true
			end
		end

		if newmenu then
			menu_stack[#menu_stack+1] = {
				menu = menu,
				n = n,
				top = top
			}

			local r = self:runmenu(x+4, y+2, newmenu)
			menu_stack[#menu_stack] = nil

			if (r == true) then
				return true
			elseif (r == false) then
				return false
			end

			self:drawmenustack()
		end
	end
end

function MenuTree.lookupAccelerator(self, c)
	c = c:gsub("^KEY_", ""):upper()

	-- Check the overrides table and only then the documentset keymap.

	local id = CheckOverrideTable(c) or self.accelerators[c]
	if not id then
		return nil
	end

	-- Found something? Find out what function the menu ID corresponds to.
	-- (Or maybe it's a raw function.)

	local f: any
	if (typeof(id) == "function") then
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
end

function CreateMenuTree(): MenuTree
	local my_key_tab: {[string|boolean]: string|boolean} = {}
	for ak, id in pairs(key_tab) do
		my_key_tab[ak] = id
		my_key_tab[id] = ak
	end

	local m = {
		accelerators = my_key_tab
	}
	return (setmetatable(m, MenuTree)::any)::MenuTree
end

function RebuildParagraphStylesMenu(styles: DocumentStyles)
	submenu(ParagraphStylesMenu)

	local m: {MenuItem} = {}

	local id = 1

	while styles[id] do
		local style = styles[id]

		local shortcut
		if (id <= 10) then
			shortcut = tostring(id - 1)
		else
			shortcut = string.char(id + 54)
		end

		m[#m+1] = {
			id = "SP"..id,
			mk = shortcut,
			label = style.name..": "..style.desc,
			ak = nil,
			fn = function()
				return Cmd.ChangeParagraphStyle(style.name)
			end
		}

		id += 1
	end

	CreateMenu("Paragraph Styles", m, ParagraphStylesMenu)
end

function RebuildDocumentsMenu(documents)
	-- Remember any accelerator keys and unhook the old menu.

	local ak_tab: {[string]: string} = {}
	for _, item in ipairs(DocumentsMenu) do
		local ak = documentSet.menu.accelerators[item.id]
		if ak and item.label then
			ak_tab[item.label] = ak
		end
	end
	submenu(DocumentsMenu)

	-- Construct the new menu.

	local m: {MenuItem} = {}
	for id, document in ipairs(documents) do
		local ak = ak_tab[document.name]
		local shortcut
		if (id <= 10) then
			shortcut = tostring(id - 1)
		else
			shortcut = string.char(id + 54)
		end

		m[#m+1] = {
			id = "D"..id,
			mk = shortcut,
			label = document.name,
			ak = ak,
			fn = function(): boolean
				return Cmd.ChangeDocument(document.name)
			end
		}
	end

	-- Hook it.

	CreateMenu("Documents", m, DocumentsMenu)
end

function ListMenuItems()
	local function list(menu: Menu)
		for _, item in ipairs(menu) do
			if item.label ~= "-" then
				wg.printerr(
					string.format("%15s %s\n", item.id or "", item.label))
				if item.menu then
					list(item.menu)
				end
			end
		end
	end

	wg.printout("All supported menu items:\n\n")
	list(MainMenu)
end

