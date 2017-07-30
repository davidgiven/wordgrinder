-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

function max(a, b)
	if (a > b) then
		return a
	else
		return b
	end
end

function min(a, b)
	if (a < b) then
		return a
	else
		return b
	end
end

--- Transcodes a string.
-- Converts the string to guaranteed valid UTF-8.
--
-- @param s                  string to process
-- @return                   canonicalised string

function CanonicaliseString(s)
	return wg.transcode(s)
end

--- Chooses between a singular or a plural string.
--
-- @param n                  number
-- @param singular           returned if number == 1
-- @param plural             returned if number ~= 1
-- @return                   either singular or plural

function Pluralise(n, singular, plural)
	if (n == 1) then
		return singular
	else
		return plural
	end
end

--- Extracts the leaf part of a filename by truncating at the last / or \.
--
-- @param filename           filename
-- @return                   leaf

function Leafname(filename)
	local _, _, f = filename:find("([^/\\]+)$")
	if f then
		return f
	end
	return filename
end

--- Produces an exception traceback.
--
-- @param e                  the error
-- @return                   the trace, as a string

function Traceback(e)
	local i = 1
	local s = {"Exception: "..e}
	while true do
		local t = debug.getinfo(i)
		if not t then
			break
		end
		s[#s+1] = t.short_src .. ":" .. t.currentline
		i = i + 1
	end

	return table.concat(s, "\n")
end

--- Splits a string by specifying the delimiter pattern.
--
-- @param str                the input string
-- @param delim              the delimiter
-- @return                   the list of words

function SplitString(str, delim)
    -- Eliminate bad cases...
    if not str:find(delim) then
    	return {str}
    end

    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local lastPos
    for part, pos in str:gmatch(pat) do
		result[#result+1] = part
		lastPos = pos
    end
	result[#result+1] = str:sub(lastPos)
    return result
end

--- Simple table renderer (no recursion).
--
-- @param t                  input table
-- @return                   a string

function TableToString(t)
	local function stringify(n)
		if (type(n) == "string") then
			return string.format("%q", n)
		elseif (type(n) == "number") then
			return tostring(n)
		elseif (n == nil) then
			return nil
		elseif (type(n) == "boolean") then
			return tostring(n)
		else
			return TableToString(n)
		end
	end

	local ts = {}
	for _, n in ipairs(t) do
		ts[#ts+1] = stringify(n)
	end

	for k, v in pairs(t) do
		if (type(k) ~= "number") then
			ts[#ts+1] = "["..stringify(k).."]="..stringify(v)
		end
	end

	return "{"..table.concat(ts, ", ").."}"
end

--- Return a table of the bytes of a string.

function StringBytesToString(s)
	local ts = {}
	for i = 1, #s do
		ts[#ts+1] = string.byte(s, i)
	end
	return TableToString(ts)
end

--- Insert element between elements of an array.
-- The old array is left untouched.
--
-- @param array              the array
-- @param spacer             the element to insert
-- @return                   a new array

function Intersperse(array, spacer)
	local a = {}
	for i = 1, #array-1 do
		a[#a+1] = array[i]
		a[#a+1] = spacer
	end
	if (#array > 0) then
		a[#a+1] = array[#array]
	end
	return a
end

--- Merge two tables.
-- Keys in old will override new if present.
--
-- @param old                old table (or nil)
-- @param new                new table
-- @return                   modified new table

function MergeTables(old, new)
	if old then
		for k, v in pairs(old) do
			new[k] = v
		end
	end
	return new
end

--- Return a partially immutable proxy for an object.
-- This only handles direct assignment to array members.
--
-- @param o                  object
-- @return                   the proxy

function ImmutabliseArray(o)
	local p = {}
	setmetatable(p,
		{
			__index = function(self, k)
				return o[k]
			end,

			__newindex = function(self, k, v)
				if (type(k) == "number") then
					error("write to immutable table")
				else
					o[k] = v
				end
			end,

			__len = function(self)
				return #o
			end,

			__ipairs = function(self)
				return ipairs(o)
			end,

			__pairs = function(self)
				return pairs(o)
			end,

			getRawArray = function(self)
				return o
			end
		}
	)
	return p
end

--- Returns the index metatable field of a table.
-- Immutable objects are handled correctly.

function GetClass(t)
	local index = nil
	local mt = getmetatable(t)
	if mt then
		index = mt.__index
		if (type(index) == "function") then
			t = mt.getRawArray()
			index = getmetatable(t).__index
		end
	end
	return index
end

-- Returns a load() callback which supplies a string.

function ChunkStream(text)
	return function()
		local t = text
		text = nil
		return t
	end
end
