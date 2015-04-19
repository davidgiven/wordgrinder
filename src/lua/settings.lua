-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

GlobalSettings = {}

local filename = HOME .. "/.wordgrinder.settings"

function LoadGlobalSettings()
	local s = LoadFromStream(filename)
	if s then
		GlobalSettings = s
	end
end

function SaveGlobalSettings()
	local r, e = SaveToStream(filename, GlobalSettings)
	return r
end

