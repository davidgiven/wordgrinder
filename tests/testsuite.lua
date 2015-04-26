function AssertEquals(want, got)
	if (want ~= got) then
		error(
			string.format("Assertion failed: wanted %q; got %q\n",
				tostring(want), tostring(got)))
	end
end

local function rendertable(t)
	local ts = {}
	for _, n in ipairs(t) do
		local s
		if (type(n) == "string") then
			s = string.format("%q", n)
		elseif (type(n) == "number") then
			s = tostring(n)
		else
			s = "unknown"
		end
		ts[#ts+1] = s
	end

	return "{"..table.concat(ts, ", ").."}"
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
				rendertable(want), rendertable(got)))
	end
end

return {}
