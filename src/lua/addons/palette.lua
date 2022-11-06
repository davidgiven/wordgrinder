-- © 2022 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_insert = table.insert
local table_remove = table.remove
local string_char = string.char

local white = {1, 1, 1}
local lightgrey = {0.8, 0.8, 0.8}
local black = {0, 0, 0}

local Palettes = {
	Dark = {
		Desktop      = {0.135, 0.135, 0.135},
		Paper        = {0.200, 0.200, 0.200},
		MarkerFG     = {0.100, 0.500, 0.500},
		StatusbarBG  = {0.140, 0.220, 0.400},
		StatusbarFG  = {0.800, 0.700, 0.200},
		MessageBG    = {0.140, 0.220, 0.400},
		MessageFG    = {0.800, 0.700, 0.200},
		TextP        = white,
		TextH1       = white,
		TextH2       = white,
		TextH3       = white,
		TextH4       = white,
		TextQ        = white,
		TextLB       = white,
		TextLBN      = white,
		TextL        = white,
		TextV        = white,
		TextPRE      = white,
		TextRAW      = white,
		StyleFG      = {0.500, 0.500, 0.500},
		ControlFG    = {1.000, 1.000, 0.000},
		ControlBG    = {0.140, 0.220, 0.400},
	},

	Light = {
		Desktop      = {0.510, 0.500, 0.470},
		Paper        = {0.760, 0.760, 0.730},
		MarkerFG     = {0.250, 0.250, 0.250},
		StatusbarBG  = {0.140, 0.220, 0.400},
		StatusbarFG  = {0.800, 0.700, 0.200},
		MessageBG    = {0.140, 0.220, 0.400},
		MessageFG    = {0.800, 0.700, 0.200},
		TextP        = black,
		TextH1       = black,
		TextH2       = black,
		TextH3       = black,
		TextH4       = black,
		TextQ        = black,
		TextLB       = black,
		TextLBN      = black,
		TextL        = black,
		TextV        = black,
		TextPRE      = black,
		TextRAW      = black,
		StyleFG      = {0.200, 0.200, 0.200},
		ControlFG    = {0.200, 0.200, 0.200},
		ControlBG    = {0.850, 0.850, 0.850},
	},

	Classic = {
		Desktop      = black,
		Paper        = black,
		MarkerFG     = white,
		StatusbarFG  = black,
		StatusbarBG  = white,
		MessageFG    = black,
		MessageBG    = white,
		TextP        = lightgrey,
		TextH1       = white,
		TextH2       = white,
		TextH3       = white,
		TextH4       = white,
		TextQ        = lightgrey,
		TextLB       = lightgrey,
		TextLBN      = lightgrey,
		TextL        = lightgrey,
		TextV        = lightgrey,
		TextPRE      = lightgrey,
		TextRAW      = lightgrey,
		StyleFG      = {0.500, 0.500, 0.500},
		ControlFG    = white,
		ControlBG    = black,
	}
}

-----------------------------------------------------------------------------
-- Addon registration. Create the default global settings.

do
	local function cb()
		GlobalSettings.palette = GlobalSettings.palette or "Light"
		Palette = Palettes[GlobalSettings.palette] or {}
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

