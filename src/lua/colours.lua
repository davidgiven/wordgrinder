--!strict
-- © 2022 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_insert = table.insert
local table_remove = table.remove
local string_char = string.char

local function MakeDark()
	local ink = {1, 1, 1}
	local paper = {0.2, 0.2, 0.2}
	local headerfg = {1, 1, 0}
	local headerbg = {0.3, 0.3, 0.3}

	return {
		Desktop      = {0.135, 0.135, 0.135},
		Paper        = paper,
		MarkerFG     = {0.100, 0.500, 0.500},
		StatusbarBG  = {0.140, 0.220, 0.400},
		StatusbarFG  = {0.800, 0.700, 0.200},
		MessageBG    = {0.140, 0.220, 0.400},
		MessageFG    = {0.800, 0.700, 0.200},
		StyleFG      = {0.500, 0.500, 0.500},
		ControlFG    = {1.000, 1.000, 0.000},
		ControlBG    = {0.140, 0.220, 0.400},
		H1_BG        = headerbg,
		H1_FG        = headerfg,
		H2_BG        = headerbg,
		H2_FG        = headerfg,
		H3_BG        = paper,
		H3_FG        = headerfg,
		H4_BG        = paper,
		H4_FG        = headerfg,
		LN_BG        = paper,
		LN_FG        = ink,
		LB_BG        = paper,
		LB_FG        = ink,
		L_BG         = paper,
		L_FG         = ink,
		PRE_BG       = paper,
		PRE_FG       = ink,
		P_BG		 = paper,
		P_FG         = ink,
		Q_BG         = paper,
		Q_FG         = ink,
		RAW_BG       = paper,
		RAW_FG       = ink,
		V_BG         = paper,
		V_FG         = ink,
	}
end

local function MakeLight()
	local ink = {0, 0, 0}
	local paper = {0.760, 0.760, 0.730}
	local headerfg = {0.14, 0.22, 0.40}
	local headerbg = {0.66, 0.66, 0.66}

	return {
		Desktop      = {0.510, 0.500, 0.470},
		Paper        = paper,
		MarkerFG     = {0.250, 0.250, 0.250},
		StatusbarBG  = {0.140, 0.220, 0.400},
		StatusbarFG  = {0.800, 0.700, 0.200},
		MessageBG    = {0.140, 0.220, 0.400},
		MessageFG    = {0.800, 0.700, 0.200},
		StyleFG      = {0.200, 0.200, 0.200},
		ControlFG    = {0.200, 0.200, 0.200},
		ControlBG    = {0.850, 0.850, 0.850},
		H1_BG        = headerbg,
		H1_FG        = headerfg,
		H2_BG        = headerbg,
		H2_FG        = headerfg,
		H3_BG        = paper,
		H3_FG        = ink,
		H4_BG        = paper,
		H4_FG        = ink,
		LN_BG        = paper,
		LN_FG        = ink,
		LB_BG        = paper,
		LB_FG        = ink,
		L_BG         = paper,
		L_FG         = ink,
		PRE_BG       = paper,
		PRE_FG       = ink,
		P_BG         = paper,
		P_FG         = ink,
		Q_BG         = paper,
		Q_FG         = ink,
		RAW_BG       = paper,
		RAW_FG       = ink,
		V_BG         = paper,
		V_FG         = ink,
	}
end

local function MakeClassic()
	local ink = {0.8, 0.8, 0.8}
	local white = {1, 1, 1}
	local black = {0, 0, 0}
	local yellow = {1, 1, 0}

	return {
		Desktop      = black,
		Paper        = black,
		MarkerFG     = white,
		StatusbarFG  = black,
		StatusbarBG  = white,
		MessageFG    = black,
		MessageBG    = white,
		StyleFG      = {0.500, 0.500, 0.500},
		ControlFG    = white,
		ControlBG    = black,
		H1_BG        = black,
		H1_FG        = yellow,
		H2_BG        = black,
		H2_FG        = yellow,
		H3_BG        = black,
		H3_FG        = yellow,
		H4_BG        = black,
		H4_FG        = yellow,
		LN_BG        = black,
		LN_FG        = ink,
		LB_BG        = black,
		LB_FG        = ink,
		L_BG         = black,
		L_FG         = ink,
		PRE_BG       = black,
		PRE_FG       = ink,
		P_BG         = black,
		P_FG         = ink,
		Q_BG         = black,
		Q_FG         = ink,
		RAW_BG       = black,
		RAW_FG       = ink,
		V_BG         = black,
		V_FG         = ink,
	}
end

local Palettes = {
	Dark = MakeDark(),
	Light = MakeLight(),
	Classic = MakeClassic(),
}

-----------------------------------------------------------------------------
-- Gets the list of themes.

function GetThemes()
	local t = {}
	for n, _ in pairs(Palettes) do
		t[#t+1] = n
	end
	return t
end

-----------------------------------------------------------------------------
-- Configures the current theme.

function SetTheme(theme)
	Palette = Palettes[theme] or {}
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

