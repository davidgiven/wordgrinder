function AssertEquals(want, got)
	if (want ~= got) then
		error(
			string.format("Assertion failed: wanted %q; got %q\n",
				tostring(want), tostring(got)))
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

function SaveGlobalSettings()
end

GlobalSettings.systemdictionary.filename = nil

return {}
