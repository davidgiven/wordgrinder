-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Fetch the maximum allowed width.

function GetMaximumAllowedWidth(screenwidth)
	local settings = GlobalSettings.lookandfeel
	if not settings or not settings.enabled then
		return screenwidth
	end
	return math.min(screenwidth, settings.maxwidth)
end

-----------------------------------------------------------------------------
-- Show the terminators?

function WantTerminators()
	local settings = GlobalSettings.lookandfeel
	if settings then
		return settings.terminators
	end
	return true
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		GlobalSettings.lookandfeel = MergeTables(GlobalSettings.lookandfeel,
			{
				enabled = false,
				maxwidth = 80,
				terminators = true
			}
		)
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureLookAndFeel()
	local settings = GlobalSettings.lookandfeel

	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 50, y2 = 1,
			label = "Enable widescreen mode",
			value = settings.enabled
		}

	local maxwidth_textfield =
		Form.TextField {
			x1 = 50, y1 = 3,
			x2 = 60, y2 = 3,
			value = tostring(settings.maxwidth)
		}
		
	local terminators_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 5,
			x2 = 50, y2 = 5,
			label = "Show terminators above and below document",
			value = settings.terminators
		}

	local dialogue =
	{
		title = "Configure Look and Feel",
		width = Form.Large,
		height = 7,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Maximum allowed width",
		},
		maxwidth_textfield,

		terminators_checkbox
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local maxwidth = tonumber(maxwidth_textfield.value)
		if not maxwidth or (maxwidth < 20) then
			ModalMessage("Parameter error", "The maximum width must be a valid number that's at least 20.")
		else
			settings.enabled = enabled_checkbox.value
			settings.maxwidth = maxwidth
			settings.terminators = terminators_checkbox.value
			SaveGlobalSettings()

			return true
		end
	end
		
	return false
end
