-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Process incoming key events.

do
	local function escape(s)
		return (s:gsub("%%", "%%%%"))
	end

	local function cb(event, token, word, paragraph)
		local settings = DocumentSet.addons.smartquotes or {}

		if settings.notinraw and (paragraph.style.name ~= "RAW") then
			if settings.doublequotes then
				word.text = word.text:gsub('^"', escape(settings.leftdouble))
				word.text = word.text:gsub('"', escape(settings.rightdouble))
			end
			if settings.singlequotes then
				word.text = word.text:gsub("^'", settings.leftsingle)
				word.text = word.text:gsub("'", settings.rightsingle)
			end
		end
	end
	
	AddEventListener(Event.WordModified, cb)
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
		height = 11,
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
