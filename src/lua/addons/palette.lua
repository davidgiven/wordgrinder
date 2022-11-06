-- © 2022 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_insert = table.insert
local table_remove = table.remove
local string_char = string.char

Palette = {
	Desktop      = {0.135, 0.135, 0.135},
	Paper        = {0.200, 0.200, 0.200},
	MarkerFG     = {0.100, 0.500, 0.500},
	StatusbarBG  = {0.140, 0.220, 0.400},
	StatusbarFG  = {0.800, 0.700, 0.200},
	TextP        = {1.000, 1.000, 1.000},
	TextH1       = {1.000, 1.000, 1.000},
	TextH2       = {1.000, 1.000, 1.000},
	TextH3       = {1.000, 1.000, 1.000},
	TextH4       = {1.000, 1.000, 1.000},
	TextQ        = {1.000, 1.000, 1.000},
	TextLB       = {1.000, 1.000, 1.000},
	TextLBN      = {1.000, 1.000, 1.000},
	TextL        = {1.000, 1.000, 1.000},
	TextV        = {1.000, 1.000, 1.000},
	TextPRE      = {1.000, 1.000, 1.000},
	TextRAW      = {1.000, 1.000, 1.000},
	StyleFG      = {0.500, 0.500, 0.500},
	Red          = {1.000, 0.000, 0.000},
}

-----------------------------------------------------------------------------
-- Addon registration. Create the default global settings.

do
	local function cb()
		GlobalSettings.palette = GlobalSettings.palette or {}
	end

	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Actually sets a style for drawing.

function SetColour(fg, bg)
	if not fg then
		fg = {1.0, 1.0, 1.0}
	end
	if not bg then
		bg = {0.0, 0.0, 0.0}
	end

	wg.setcolour(fg, bg)
end

