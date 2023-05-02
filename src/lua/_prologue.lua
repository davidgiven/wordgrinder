--!strict
-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- Global definitions that the various source files need.

declare Cmd: {[string]: any}
Cmd = {}

declare Form: {[string]: any}

declare MenuTree: {[string]: any}
declare M: {[string]: any}
declare GlobalSettings: {[string]: {[any]: any}}

type Colour = {number}
type ColourMap = {[string]: Colour}

declare ScreenWidth: number
declare ScreenHeight: number
declare Palette: ColourMap

declare ESCAPE_KEY: string

declare BLINK_ON_TIME: number
declare BLINK_OFF_TIME: number
declare IDLE_TIME: number

BLINK_ON_TIME = 0.8
BLINK_OFF_TIME = 0.53
IDLE_TIME = (BLINK_ON_TIME + BLINK_OFF_TIME) * 5

type StatusbarField = {
	priority: number,
	value: string
}

-- Polyfills for Luau.

function loadfile(filename: string)
	local data, e = wg.readfile(filename)
	if data then
		return loadstring(data, filename)
	end
	return nil, e
end

