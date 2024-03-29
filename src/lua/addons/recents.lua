--!nonstrict
-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_insert = table.insert
local table_remove = table.remove
local string_char = string.char

local NUMBER_OF_RECENTS = 10

-----------------------------------------------------------------------------
-- Addon registration. Create the default global settings.

do
	local function cb()
		GlobalSettings.recents = GlobalSettings.recents or ({} :: {string})
	end

	AddEventListener("RegisterAddons", cb)
end

-----------------------------------------------------------------------------
-- Adds a document to the recents list.

do
	local function cb()
		local recents = GlobalSettings.recents
		local name = documentSet.name
		if not name then
			return
		end

		for i, v in ipairs(recents) do
			if (v == name) then
				table_remove(recents, i)
				table_insert(recents, 1, name)
				SaveGlobalSettings()
				return
			end
		end

		table_insert(recents, 1, name)
		recents[NUMBER_OF_RECENTS] = nil
		SaveGlobalSettings()
	end

	AddEventListener("DocumentLoaded", cb)
end

-----------------------------------------------------------------------------
-- Actually does the work.

function Cmd.LoadRecentDocument()
	local recents = GlobalSettings.recents
	local m: {MenuItem} = {}
	for i, v in pairs(recents) do
		m[#m+1] = {
			id = nil,
			mk = string_char(48 + i),
			label = Leafname(v),
			ak = nil,
			fn = function()
				return Cmd.LoadDocumentSet(v)
			end
		}
	end

	return CreateMenu("Recent documents", m)
end

