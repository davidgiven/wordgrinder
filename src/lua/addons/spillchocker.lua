-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local GetWordText = wg.getwordtext
local GetCwd = wg.getcwd
local ChDir = wg.chdir

local USER_DICTIONARY_NAME = "User dictionary"

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function find_default_dictionary()
		if (ARCH == "windows") then
			return WINDOWS_INSTALL_DIR .. "/Dictionaries/"
		else
			return "/etc/dictionaries-common/words"
		end
	end

	local function cb()
		DocumentSet.addons.spellchecker = DocumentSet.addons.spellchecker or {
			enabled = false,
			usesystemdictionary = true,
			useuserdictionary = true
		}

		GlobalSettings.systemdictionary = GlobalSettings.systemdictionary or {
			filename = find_default_dictionary()
		}
	end

	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Allow the spellchecker to be temporarily disabled (so we don't end up
-- spellchecking dialogue boxes, etc).

function SpellcheckerOff()
	local settings = DocumentSet.addons.spellchecker or {}
	local state = settings.enabled
	settings.enabled = false
	return state
end

function SpellcheckerRestore(s)
	local settings = DocumentSet.addons.spellchecker or {}
	settings.enabled = s
end

-----------------------------------------------------------------------------
-- Utilities.

local user_dictionary_cache
local user_dictionary_cache
local system_dictionary_cache

local function user_dictionary_document_modified()
	user_dictionary_cache = nil
	user_dictionary_cache = nil
end

local function get_user_dictionary_document()
	local d = DocumentSet:findDocument(USER_DICTIONARY_NAME)
	if not d then
		d = CreateDocument()
		DocumentSet:addDocument(d, USER_DICTIONARY_NAME)
		NonmodalMessage("Creating dictionary in document '"
				..USER_DICTIONARY_NAME.."'.")

		d[1] = CreateParagraph(
				"P",
				SplitString("This is your user dictionary --- place words, "
						.. "one at a time, in V paragraphs and they will be "
						.. "considered valid in your document.", "%s")
			)

		AddEventListener(Event.DocumentModified,
			function(self, token, document)
				if (document == d) then
					user_dictionary_document_modified(d)
				end
			end
		)
	end
	return d
end

function GetUserDictionary()
	if not user_dictionary_cache then
		local d = get_user_dictionary_document()
		user_dictionary_cache = {}

		for _, p in ipairs(d) do
			if (p.style == "V") then
				local w = GetWordSimpleText(p[1])
				user_dictionary_cache[w:lower()] = w
			end
		end
	end
	return user_dictionary_cache
end

function GetSystemDictionary()
	local settings = GlobalSettings.systemdictionary or {}
	if not system_dictionary_cache then
		system_dictionary_cache = {}

		if settings.filename then
			NonmodalMessage("Loading system dictionary '"
				.. settings.filename .. "'")
			local fp, e = io.open(settings.filename, "r")
			if fp then
				for s in fp:lines() do
					system_dictionary_cache[s:lower()] = s
				end
				fp:close()
			else
				NonmodalMessage("Failed to load system dictionary: " .. e)
			end
			QueueRedraw()
		end
	end
	return system_dictionary_cache
end

function SetSystemDictionaryForTesting(array)
	system_dictionary_cache = {}
	for _, w in ipairs(array) do
		system_dictionary_cache[w:lower()] = w
	end
end

function IsWordMisspelt(word, firstword)
	local settings = DocumentSet.addons.spellchecker or {}
	if settings.enabled then
		local misspelt = true
		local systemdict = settings.usesystemdictionary and GetSystemDictionary() or {}
		local userdict = settings.useuserdictionary and GetUserDictionary() or {}
		local scs = GetWordSimpleText(word)
		local sci = scs:lower()
		if (sci == "")
			or (not sci:find("[a-zA-Z]"))
			or (#sci < 3)
			or (systemdict[sci] == scs)
			or (userdict[sci] == scs)
			or (firstword and OnlyFirstCharIsUppercase(scs) and (systemdict[sci] == sci))
			or (firstword and OnlyFirstCharIsUppercase(scs) and (userdict[sci] == sci))
		then
			misspelt = false
		end
		return misspelt
	else
		return false
	end
end

-----------------------------------------------------------------------------
-- Add the current word to the user dictionary.

function Cmd.AddToUserDictionary()
	local word = GetWordSimpleText(Document[Document.cp][Document.cw])

	if (word ~= "") then
		if (not GetUserDictionary()[word]) and
				(not GetSystemDictionary()[word]) then
			local d = get_user_dictionary_document()
			d:appendParagraph(CreateParagraph("V", word))
			d:touch()
			user_dictionary_cache = nil
			NonmodalMessage("Word '"..word.."' added to user dictionary")
		else
			NonmodalMessage("Word '"..word.."' already in user dictionary")
		end

		DocumentSet:touch()
		QueueRedraw()
	end
end

-----------------------------------------------------------------------------
-- The core of the live checker: looks up a word and determines whether
-- it's misspelt or not.

do
	local function cb(self, token, payload)
		if IsWordMisspelt(payload.word, payload.firstword) then
			payload.cstyle = bit32.bor(payload.cstyle, wg.DIM)
		end
	end

	AddEventListener(Event.DrawWord, cb)
end

-----------------------------------------------------------------------------
-- The core of the offline checker: scan forward looking for misspelt words.

function Cmd.FindNextMisspeltWord()
	ImmediateMessage("Searching...")

	-- If we have a selection, start checking from immediately
	-- afterwards. Otherwise, start at the current cursor position.

	local sp, sw, so
	if Document.mp then
		sp, sw, so = Document.mp, Document.mw + 1, 1
		if sw > #Document[sp] then
			sw = 1
			sp = sp + 1
			if sp > #Document then
				sp = 1
			end
		end
	else
		sp, sw, so = Document.cp, Document.cw, 1
	end
	local cp, cw, co = sp, sw, so

	-- Keep looping until we reach the starting point again.

	Document[1]:wrap()
	while true do
		local paragraph = Document[cp]
		local word = paragraph[cw]
		if IsWordMisspelt(word, paragraph.sentences[cw]) then
			Document.cp = cp
			Document.cw = cw
			Document.co = #word + 1
			Document.mp = cp
			Document.mw = cw
			Document.mo = 1
			NonmodalMessage("Misspelt word found.")
			QueueRedraw()
			return true
		end

		-- Nothing. Move on to the next word.

		co = 1
		cw = cw + 1
		if (cw > #Document[cp]) then
			cw = 1
			cp = cp + 1
			if (cp > #Document) then
				cp = 1
			end
			Document[cp]:wrap()
		end

		-- Check to see if we've scanned everything.

		if (cp == sp) and (cw == sw) and (co == 1) then
			break
		end
	end

	QueueRedraw()
	NonmodalMessage("No misspelt words found.")
	return false
end

-----------------------------------------------------------------------------
-- Per-document set configuration user interface.

function Cmd.ConfigureSpellchecker()
	local settings = DocumentSet.addons.spellchecker or {}

	local highlight_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 33, y2 = 1,
			label = "",
			value = settings.enabled
		}

	local systemdictionary_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 3,
			x2 = 33, y2 = 3,
			label = "",
			value = settings.usesystemdictionary
		}

	local userdictionary_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 5,
			x2 = 33, y2 = 5,
			label = "",
			value = settings.useuserdictionary
		}

	local dialogue =
	{
		title = "Configure Spellchecker",
		width = Form.Large,
		height = 7,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		highlight_checkbox,
		systemdictionary_checkbox,
		userdictionary_checkbox,

		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 32, y2 = 1,
			align = Form.Left,
			value = "Display misspelt words:"
		},

		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Use system dictionary:"
		},

		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Use user dictionary:"
		},
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
	if not result then
		return false
	end

	settings.enabled = highlight_checkbox.value
	settings.usesystemdictionary = systemdictionary_checkbox.value
	settings.useuserdictionary = userdictionary_checkbox.value
	DocumentSet:touch()
	return true
end

-----------------------------------------------------------------------------
-- System dictionary configuration interface.

function Cmd.ConfigureSystemDictionary()
	local settings = GlobalSettings.systemdictionary

	local oldcwd = GetCwd()
	local filename = FileBrowser(
		"Load new system dictionary",
		"Select the dictionary file to load.",
		false,
		settings.filename)
	ChDir(oldcwd)

	if filename then
		system_dictionary_cache = nil
		settings.filename = filename
		SaveGlobalSettings()
	end

	return true
end

