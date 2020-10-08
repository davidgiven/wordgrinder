function AssertEquals(want, got)
	if (want ~= got) then
		error(
			string.format("Assertion failed: wanted %q; got %q\n",
				tostring(want), tostring(got)))
	end
end

function AssertNull(got)
	if got then
		error(
			string.format("Assertion failed: wanted null(ish); got %q\n",
				tostring(got)))
	end
end

function AssertNotNull(got)
	if not got then
		error(
			string.format("Assertion failed: wanted not null(ish); got %q\n",
				tostring(got)))
	end
end

function AssertTableEquals(want, got)
	local failed = false
	if (#want ~= #got) then
		failed = true
	else
		for k, v in ipairs(want) do
			if (want[k] ~= got[k]) then
				failed = true
				break
			end
		end
	end

	if failed then
		error(
			string.format("Assertion failed: wanted %s; got %s\n",
				TableToString(want), TableToString(got)))
	end
end

local function TableEquals(want, got)
	local wantkeys = {}
	for k, v in pairs(want) do
		wantkeys[k] = true
	end

	for k, v in pairs(got) do
		if not wantkeys[k] then
			return false
		else
			local wantv = want[k]
			if (type(v) ~= type(wantv)) then
				return false
			elseif (v ~= wantv) then
				if (type(v) ~= "table") then
					return false
				end

				if not TableEquals(wantv, v) then
					return false
				end
			end
			wantkeys[k] = nil
		end
	end

	if next(wantkeys) then
		return false
	end

	return true
end

function AssertTableAndPropertiesEquals(want, got)
	if not TableEquals(want, got) then
		error(
			string.format("Assertion failed: wanted %s; got %s\n",
				TableToString(want), TableToString(got)))
	end
end

function LoggingObject()
	local object = {}
	local result = {}
	setmetatable(object, {
		__index = function(self, k)
			local log = (result[k] or {})
			result[k] = log

			return function(...)
				table.insert(log, {...})
			end
		end
	})

	return object, result
end

function LoggingCallback()
	local log = {}

	local function cb(...)
		table.insert(log, {...})
	end

	return cb, log
end

local hidemessages =
{
	["Document upgraded"] = true
}

function AddAllowedMessage(m)
	hidemessages[m] = true
end

function ModalMessage(s1, s2)
	if not hidemessages[s1] then
		print(s1)
		print(s2)
	end
end

local oldSaveGlobalSettings = SaveGlobalSettings
function SaveGlobalSettings(f)
	if f then
		return oldSaveGlobalSettings(f)
	end
end

GlobalSettings.systemdictionary.filename = nil

return {}
