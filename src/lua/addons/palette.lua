-- © 2022 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_insert = table.insert
local table_remove = table.remove
local string_char = string.char
local SetColour = wg.setcolour
local DefineColour = wg.definecolour

local colours = {
	bg           = {0.000, 0.000, 0.000},
	fg           = {1.000, 1.000, 1.000},
	desk_bg      = {0.135, 0.135, 0.135},
	paper_bg     = {0.200, 0.200, 0.200},
	statusbar_fg = {0.140, 0.220, 0.400},
	statusbar_bg = {0.800, 0.700, 0.200},
	black        = {0.000, 0.000, 0.000},
	red          = {1.000, 0.000, 0.000},
}

local styles = {
	normal =    { colours.fg,           colours.bg },
	desktop =   { colours.fg,           colours.desk_bg },
	P =         { colours.fg,           colours.paper_bg },
	H1 =        { colours.fg,           colours.paper_bg },
	H2 =        { colours.fg,           colours.paper_bg },
	H3 =        { colours.fg,           colours.paper_bg },
	H4 =        { colours.fg,           colours.paper_bg },
	Q =         { colours.fg,           colours.paper_bg },
	LB =        { colours.fg,           colours.paper_bg },
	LN =        { colours.fg,           colours.paper_bg },
	L =         { colours.fg,           colours.paper_bg },
	V =         { colours.fg,           colours.paper_bg },
	PRE =       { colours.fg,           colours.paper_bg },
	RAW =       { colours.fg,           colours.paper_bg },
	statusbar = { colours.statusbar_fg, colours.statusbar_bg }, -- reversed
	message =   { colours.statusbar_bg, colours.statusbar_fg }, -- reversed
	debug =     { colours.black,        colours.red },
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

function SetStyle(name)
	local sp = styles[name]
	if not sp then
		sp = styles.normal
	end
	SetColour(sp[1], sp[2])
end

