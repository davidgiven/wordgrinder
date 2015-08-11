-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local GetWordText = wg.getwordtext

local USER_DICTIONARY_NAME = "User dictionary"

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.spellchecker = DocumentSet.addons.spellchecker or {
			enabled = false,
			usesystemdictionary = true,
			useuserdictionary = true
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Utilities.

local user_dictionary_cache

local function user_dictionary_document_modified()
	user_dictionary_cache = nil
end

local function get_user_dictionary_document()
	local d = DocumentSet:findDocument(USER_DICTIONARY_NAME)
	if not d then
		d = CreateDocument()
		DocumentSet:addDocument(d, USER_DICTIONARY_NAME)
		NonmodalMessage("Creating scrapbook in document '"
				..USER_DICTIONARY_NAME.."'.")

		d[1] = CreateParagraph(
				DocumentSet.styles["P"],
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

		local vstyle = DocumentSet.styles["V"]
		for _, p in ipairs(d) do
			if (p.style == vstyle) then
				local w = GetWordText(p[1])
				user_dictionary_cache[w] = true
			end
		end
	end
	return user_dictionary_cache
end

function IsWordMisspelt(word)
	local settings = DocumentSet.addons.spellchecker or {}
	if settings.enabled then
		local misspelt = true
		if settings.useuserdictionary and GetUserDictionary()[word] then
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
	local word = GetWordText(Document[Document.cp][Document.cw])

	if (word ~= "") then
		if not GetUserDictionary()[word] then
			local d = get_user_dictionary_document()
			d:appendParagraph(CreateParagraph(DocumentSet.styles["V"], word))
			d:touch()
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
		if IsWordMisspelt(payload.word) then
			payload.cstyle = bit32.bor(payload.cstyle, wg.DIM)
		end
	end

	AddEventListener(Event.DrawWord, cb) 
end

-----------------------------------------------------------------------------
-- Configuration user interface.

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
--		systemdictionary_checkbox,
		userdictionary_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 32, y2 = 1,
			align = Form.Left,
			value = "Display misspelt words:"
		},
		
--		Form.Label {
--			x1 = 1, y1 = 3,
--			x2 = 32, y2 = 3,
--			align = Form.Left,
--			value = "Use system dictionary:"
--		},
		
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
