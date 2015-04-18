-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Fetch the maximum allowed width.

function GetMaximumAllowedWidth(screenwidth)
	local settings = GlobalSettings.widescreen
	if not settings or not settings.enabled then
		return screenwidth
	end
	return math.min(screenwidth, settings.maxwidth)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		GlobalSettings.widescreen = GlobalSettings.widescreen or {
			enabled = false,
			maxwidth = 80
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureWidescreen()
	local settings = GlobalSettings.widescreen

	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 33, y2 = 1,
			label = "Enable widescreen mode",
			value = settings.enabled
		}

	local maxwidth_textfield =
		Form.TextField {
			x1 = 33, y1 = 3,
			x2 = 43, y2 = 3,
			value = tostring(settings.maxwidth)
		}
		
	local dialogue =
	{
		title = "Configure Widescreen Mode",
		width = Form.Large,
		height = 5,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Maximum allowed width:",
		},
		maxwidth_textfield,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local enabled = enabled_checkbox.value
		local maxwidth = tonumber(maxwidth_textfield.value)
		
		if not maxwidth or (maxwidth < 20) then
			ModalMessage("Parameter error", "The maximum width must be a valid number that's at least 20.")
		else
			settings.enabled = enabled
			settings.maxwidth = maxwidth
			SaveGlobalSettings()

			return true
		end
	end
		
	return false
end
