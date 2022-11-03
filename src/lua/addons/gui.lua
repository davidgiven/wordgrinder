-- © 2021 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the global settings.

local DEFAULT_GUI_SETTINGS = {
	font_size = 20,
	window_width = 800,
	window_height = 600,
	font_regular = "extras/fonts/FantasqueSansMono-Regular.ttf",
	font_italic = "extras/fonts/FantasqueSansMono-Italic.ttf",
	font_bold = "extras/fonts/FantasqueSansMono-Bold.ttf",
	font_bolditalic = "extras/fonts/FantasqueSansMono-BoldItalic.ttf",
}

do
	local function cb()
		GlobalSettings.gui = GlobalSettings.gui or {}
		local s = GlobalSettings.gui
		for k, v in pairs(DEFAULT_GUI_SETTINGS) do
			s[k] = s[k] or v
		end
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end
--
-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureGui()
	local settings = GlobalSettings.gui

	local L = 24
	local R = -2
	local windowwidth_textfield =
		Form.TextField {
			x1 = L, y1 = 1,
			x2 = L+10, y2 = 1,
			value = tostring(settings.window_width)
		}

	local windowheight_textfield =
		Form.TextField {
			x1 = L, y1 = 3,
			x2 = L+10, y2 = 3,
			value = tostring(settings.window_height)
		}

	local fontsize_textfield =
		Form.TextField {
			x1 = L, y1 = 5,
			x2 = L+10, y2 = 5,
			value = tostring(settings.font_size)
		}

	local fontregular_textfield =
		Form.TextField {
			x1 = L, y1 = 7,
			x2 = R, y2 = 7,
			value = settings.font_regular
		}

	local fontitalic_textfield =
		Form.TextField {
			x1 = L, y1 = 9,
			x2 = R, y2 = 9,
			value = settings.font_italic
		}

	local fontbold_textfield =
		Form.TextField {
			x1 = L, y1 = 11,
			x2 = R, y2 = 11,
			value = settings.font_bold
		}

	local fontbolditalic_textfield =
		Form.TextField {
			x1 = L, y1 = 13,
			x2 = R, y2 = 13,
			value = settings.font_bolditalic
		}

	local dialogue =
	{
		title = "Configure GUI",
		width = Form.Large,
		height = 16,
		stretchy = false,

		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
	
		["KEY_^R"] = function()
			windowwidth_textfield.value = tostring(DEFAULT_GUI_SETTINGS.window_width)
			windowheight_textfield.value = tostring(DEFAULT_GUI_SETTINGS.window_height)
			fontsize_textfield.value = tostring(DEFAULT_GUI_SETTINGS.font_size)
			fontregular_textfield.value = DEFAULT_GUI_SETTINGS.font_regular
			fontitalic_textfield.value = DEFAULT_GUI_SETTINGS.font_italic
			fontbold_textfield.value = DEFAULT_GUI_SETTINGS.font_bold
			fontbolditalic_textfield.value = DEFAULT_GUI_SETTINGS.font_bolditalic
			return "redraw"
		end,

		windowwidth_textfield,
		windowheight_textfield,
		fontsize_textfield,
		fontregular_textfield,
		fontitalic_textfield,
		fontbold_textfield,
		fontbolditalic_textfield,

		Form.Label {
			x1 = 1, y1 = 1,
			x2 = L-1, y2 = 1,
			align = Form.Left,
			value = "Default window width:"
		},

		Form.Label {
			x1 = 1, y1 = 3,
			x2 = L-1, y2 = 3,
			align = Form.Left,
			value = "Default window height:"
		},


		Form.Label {
			x1 = 1, y1 = 5,
			x2 = L-1, y2 = 5,
			align = Form.Left,
			value = "Font size:"
		},

		Form.Label {
			x1 = 1, y1 = 7,
			x2 = L-1, y2 = 7,
			align = Form.Left,
			value = "Normal font:"
		},

		Form.Label {
			x1 = 1, y1 = 9,
			x2 = L-1, y2 = 9,
			align = Form.Left,
			value = "Bold font:"
		},

		Form.Label {
			x1 = 1, y1 = 11,
			x2 = L-1, y2 = 11,
			align = Form.Left,
			value = "Italic font:"
		},

		Form.Label {
			x1 = 1, y1 = 13,
			x2 = L-1, y2 = 13,
			align = Form.Left,
			value = "Bold/italic font:"
		},

		Form.Label {
			x1 = 1, y1 = -1,
			x2 = -1, y2 = -1,
			align = Form.Centre,
			value = "<^R to reset to default>"
		},
	}

	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, "..ESCAPE_KEY.." to cancel")
		if not result then
			return false
		end

		local window_width = tonumber(windowwidth_textfield.value)
		local window_height = tonumber(windowheight_textfield.value)
		local font_size = tonumber(fontsize_textfield.value)
		if not window_width or (window_width < 50) then
			ModalMessage("Invalid parameter", "Invalid window width")
		elseif not window_height or (window_height < 50) then
			ModalMessage("Invalid parameter", "Invalid window height")
		elseif not font_size or (font_size < 1) then
			ModalMessage("Invalid parameter", "Invalid font size")
		else
			settings.window_width = window_width
			settings.window_height = window_height
			settings.font_size = font_size
			settings.font_regular = fontregular_textfield.value
			settings.font_italic = fontitalic_textfield.value
			settings.font_bold = fontbold_textfield.value
			settings.font_bolditalic = fontbolditalic_textfield.value
			break
		end
	end

	wg.deinitscreen()
	wg.initscreen()
	FireEvent(Event.ScreenInitialised)
	SaveGlobalSettings()

	return true
end

