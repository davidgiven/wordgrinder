-- © 2021 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the global settings.

do
	local function cb()
		GlobalSettings.gui = GlobalSettings.gui or {
			font_size = 20,
			window_width = 800,
			window_height = 600,
            font_regular = "extras/fonts/FantasqueSansMono-Regular.ttf",
            font_italic = "extras/fonts/FantasqueSansMono-Italic.ttf",
            font_bold = "extras/fonts/FantasqueSansMono-Bold.ttf",
            font_bolditalic = "extras/fonts/FantasqueSansMono-BoldItalic.ttf"
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

