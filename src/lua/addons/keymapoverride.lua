-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local keyoverrides = {}

function OverrideKey(key, binding)
	if not binding then
		error("you tried to map something I don't recognise to "..key)
	end
	keyoverrides[key] = binding
end

function CheckOverrideTable(key)
	return keyoverrides[key]
end


