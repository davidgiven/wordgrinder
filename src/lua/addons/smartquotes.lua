-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local GetStringWidth = wg.getstringwidth
local P = M.P

local function escape(s)
	return (s:gsub("%%", "%%%%"))
end

-----------------------------------------------------------------------------
-- Process incoming key events.

do
	local function cb(event, token, payload)
		local settings = DocumentSet.addons.smartquotes or {}
		local start_of_word_pattern =
			(P("^") *
			 (P("[\"']") +
			  P(escape(settings.leftdouble)) +
			  P(escape(settings.leftsingle)) +
			  P("%c")
			 )^0 *
			 P("$")
			):compile()

		if settings.notinraw
				and (Document[Document.cp].style ~= "RAW") then
			local value = payload.value
			local word = Document[Document.cp][Document.cw]
			local prefix = word:sub(1, Document.co-1)
			local first = start_of_word_pattern(prefix) ~= nil

			if settings.doublequotes and (value == '"') then
				value = first and settings.leftdouble or settings.rightdouble
			end
			if settings.singlequotes and (value == "'") then
				value = first and settings.leftsingle or settings.rightsingle
			end
			payload.value = value
		end
	end

	AddEventListener(Event.KeyTyped, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.smartquotes = DocumentSet.addons.smartquotes or {
			doublequotes = false,
			singlequotes = false,
			notinraw = true,
			leftdouble = '“',
			rightdouble = '”',
			leftsingle = '‘',
			rightsingle = '’'
		}
	end

	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Undo any smart quotes.

function UnSmartquotify(s)
	local settings = DocumentSet.addons.smartquotes or {}
	s = s:gsub(escape(settings.leftdouble), '"')
	s = s:gsub(escape(settings.rightdouble), '"')
	s = s:gsub(escape(settings.leftsingle), "'")
	s = s:gsub(escape(settings.rightsingle), "'")
	return s
end

-----------------------------------------------------------------------------
-- Process the selection.

local function convert_clipboard()
	local settings = DocumentSet.addons.smartquotes or {}
	local clipboard = DocumentSet:getClipboard()

	local ld = escape(settings.leftdouble)
	local rd = escape(settings.rightdouble)
	local ls = escape(settings.leftsingle)
	local rs = escape(settings.rightsingle)

	local start_of_word_pattern =
		(P("^") *
		 (P("[\"']") +
		  P(ld) +
		  P(ls) +
		  P("%c")
		 )^0 *
		 P("$")
		):compile()

	for pn = 1, #clipboard do
		local para = clipboard[pn]
		if settings.notinraw and (para.style ~= "RAW") then
			local newwords = {}
			for _, w in ipairs(para) do
				w = w:gsub('()(["\'])',
					function(pos, s)
						local prefix = w:sub(1, pos-1)
						local first = start_of_word_pattern(prefix) ~= nil
						if first then
							if (s == "'") then
								return ls
							elseif (s == '"') then
								return ld
							end
						else
							if (s == "'") then
								return rs
							elseif (s == '"') then
								return rd
							end
						end
					end)

				newwords[#newwords+1] = w
			end

			clipboard[pn] = CreateParagraph(para.style, newwords)
		end
	end

	NonmodalMessage("Clipboard smartquotified.")
	return true
end

local function unconvert_clipboard()
	local settings = DocumentSet.addons.smartquotes or {}
	local clipboard = DocumentSet:getClipboard()

	local ld = escape(settings.leftdouble)
	local rd = escape(settings.rightdouble)
	local ls = escape(settings.leftsingle)
	local rs = escape(settings.rightsingle)

	for pn = 1, #clipboard do
		local para = clipboard[pn]
		if settings.notinraw and (para.style ~= "RAW") then
			local newwords = {}
			for _, w in ipairs(para) do
				w = w:gsub(ld, '"')
				w = w:gsub(rd, '"')
				w = w:gsub(ls, "'")
				w = w:gsub(rs, "'")
				newwords[#newwords+1] = w
			end

			clipboard[pn] = CreateParagraph(para.style, newwords)
		end
	end

	NonmodalMessage("Clipboard unsmartquotified.")
	return true
end

function Cmd.Smartquotify()
	return Cmd.Checkpoint() and
		Cmd.Copy(true) and
		convert_clipboard() and
		Cmd.Paste()
end

function Cmd.Unsmartquotify()
	return Cmd.Checkpoint() and
		Cmd.Copy(true) and
		unconvert_clipboard() and
		Cmd.Paste()
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureSmartQuotes()
	local settings = DocumentSet.addons.smartquotes

	local single_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 38, y2 = 1,
			label = "Convert single quotes while typing:",
			value = settings.singlequotes
		}

	local double_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 3,
			x2 = 38, y2 = 3,
			label = "Convert double quotes while typing:",
			value = settings.doublequotes
		}

	local leftsingle_textfield =
		Form.TextField {
			x1 = 41, y1 = 5,
			x2 = 46, y2 = 5,
			value = tostring(settings.leftsingle)
		}

	local rightsingle_textfield =
		Form.TextField {
			x1 = 51, y1 = 5,
			x2 = 56, y2 = 5,
			value = tostring(settings.rightsingle)
		}

	local leftdouble_textfield =
		Form.TextField {
			x1 = 41, y1 = 7,
			x2 = 46, y2 = 7,
			value = tostring(settings.leftdouble)
		}

	local rightdouble_textfield =
		Form.TextField {
			x1 = 51, y1 = 7,
			x2 = 56, y2 = 7,
			value = tostring(settings.rightdouble)
		}

	local notinraw_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 9,
			x2 = 38, y2 = 1,
			label = "Don't convert in RAW paragraphs:",
			value = settings.notinraw
		}

	local dialogue =
	{
		title = "Configure Smart Quotes",
		width = Form.Large,
		height = 13,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		single_checkbox,
		double_checkbox,
		leftsingle_textfield,
		rightsingle_textfield,
		leftdouble_textfield,
		rightdouble_textfield,
		notinraw_checkbox,

		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Text used for single quotes:"
		},

		Form.Label {
			x1 = 38, y1 = 5,
			x2 = 39, y2 = 5,
			align = Form.Left,
			value = "L:"
		},

		Form.Label {
			x1 = 48, y1 = 5,
			x2 = 49, y2 = 5,
			align = Form.Left,
			value = "R:"
		},

		Form.Label {
			x1 = 1, y1 = 7,
			x2 = 32, y2 = 7,
			align = Form.Left,
			value = "Text used for double quotes:"
		},

		Form.Label {
			x1 = 38, y1 = 7,
			x2 = 39, y2 = 7,
			align = Form.Left,
			value = "L:"
		},

		Form.Label {
			x1 = 48, y1 = 7,
			x2 = 49, y2 = 7,
			align = Form.Left,
			value = "R:"
		},

		Form.Label {
			x1 = 1, y1 = 11,
			x2 = -1, y2 = 11,
			align = Form.Centre,
			value = "To apply to existing text, copy and then paste it."
		}
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
	if not result then
		return false
	end

	settings.singlequotes = single_checkbox.value
	settings.doublequotes = double_checkbox.value
	settings.leftsingle = leftsingle_textfield.value
	settings.rightsingle = rightsingle_textfield.value
	settings.leftdouble = leftdouble_textfield.value
	settings.rightdouble = rightdouble_textfield.value
	settings.notinrawquotes = notinraw_checkbox.value
	DocumentSet:touch()

	return true
end
