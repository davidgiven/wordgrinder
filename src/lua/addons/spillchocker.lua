-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.spellchecker = DocumentSet.addons.spellchecker or {
			highlight = false,
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureSpellchecker()
	local settings = DocumentSet.addons.spellchecker

	local highlight_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 33, y2 = 1,
			label = "",
			value = settings.enabled
		}

	local dialogue =
	{
		title = "Configure Spellchecker",
		width = Form.Large,
		height = 5,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		highlight_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 32, y2 = 1,
			align = Form.Left,
			value = "Display misspelt words:"
		},
	}
	
	local result = Form.Run(dialogue, RedrawScreen,
		"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
	if not result then
		return false
	end
	
	settings.highlight = highlight_checkbox.value
	return true
end
