--!strict
-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- Global definitions that the various source files need.

Cmd = {} :: {[string]: any}

BLINK_ON_TIME = 0.8
BLINK_OFF_TIME = 0.53
IDLE_TIME = (BLINK_ON_TIME + BLINK_OFF_TIME) * 5

-- Polyfills for Luau.

function loadfile(filename: string)
	local data, e = wg.readfile(filename)
	if data then
		return loadstring(data, filename)
	end
	return nil, e
end

-- Global declarations.

CLIError = nil
CliConvert = nil
CreateDocument = nil
CreateParagraph = nil
EngageCLI = nil
GetMaximumAllowedWidth = nil
GetThemes = nil
GlobalSettings = nil :: table
LAlignInField = nil
MenuTreeClass = {}
ModalMessage = nil
Palette = nil :: ColourMap
RAlignInField = nil
RebuildDocumentsMenu = nil
RebuildParagraphStylesMenu = nil
ResizeScreen = nil
RunMenuAction = nil
ScreenHeight = 0
ScreenWidth = 0
SetColour = nil
SetCurrentStyleHint = nil
SetTheme = nil
SpellcheckerOff = nil
SpellcheckerRestore = nil
UpdateDocumentStyles = nil
WantFullStopSpaces = nil


