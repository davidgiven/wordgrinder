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
		return settings.terminators or false
	end
	return true
end

-----------------------------------------------------------------------------
-- Use the dense paragraph layout? (Indents, no space between paragraphs.)

function WantDenseParagraphLayout()
	local settings = GlobalSettings.lookandfeel
	if settings then
		return settings.denseparagraphs or false
	end
	return true
end

-----------------------------------------------------------------------------
-- Display an extra space after full stops?

function WantFullStopSpaces()
	local settings = GlobalSettings.lookandfeel
	if settings then
		return settings.fullstopspaces or false
	end
	return false
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default global settings.

do
	local function cb()
		GlobalSettings.lookandfeel = MergeTables(GlobalSettings.lookandfeel,
			{
				enabled = false,
				maxwidth = 80,
				terminators = true,
				denseparagraphs = false
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

	local denseparagraphs_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 7,
			x2 = 50, y2 = 7,
			label = "Use dense paragraph layout",
			value = settings.denseparagraphs
		}

	local fullstopspaces_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 9,
			x2 = 50, y2 = 9,
			label = "Show an extra space after full stops",
			value = settings.fullstopspaces
		}

	local dialogue =
	{
		title = "Configure Look and Feel",
		width = Form.Large,
		height = 11,
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

		terminators_checkbox,
		denseparagraphs_checkbox,
		fullstopspaces_checkbox,
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
			settings.denseparagraphs = denseparagraphs_checkbox.value
			settings.fullstopspaces = fullstopspaces_checkbox.value
			SaveGlobalSettings()
			UpdateDocumentStyles()

			return true
		end
	end

	return false
end
