--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local GetBytesOfCharacter = wg.getbytesofcharacter
local ReadU8 = wg.readu8
local WriteU8 = wg.writeu8
local string_byte = string.byte
local string_format = string.format
local string_find = string.find
local string_gmatch = string.gmatch
local string_sub = string.sub
local table_concat = table.concat
local table_remove = table.remove
local HUGE = math.huge
local math_floor = math.floor
local Mkdir = wg.mkdir
local EEXIST = wg.EEXIST
local EACCES = wg.EACCES
local EISDIR = wg.EISDIR

--- Transcodes a string.
-- Converts the string to guaranteed valid UTF-8.
--
-- @param s                  string to process
-- @return                   canonicalised string

function CanonicaliseString(s: string): string
	return wg.transcode(s)
end

--- Chooses between a singular or a plural string.
--
-- @param n                  number
-- @param singular           returned if number == 1
-- @param plural             returned if number ~= 1
-- @return                   either singular or plural

function Pluralise(n: number, singular: string, plural: string): string
	if (n == 1) then
		return singular
	else
		return plural
	end
end

--- Extracts the leaf part of a filename by returning everything after the last / or \.
--
-- @param filename           filename
-- @return                   leaf

function Leafname(filename: string): string
	local _, _, f = filename:find("([^/\\]*)$")
	if f then
		return f
	end
	return filename
end

--- Extracts the directory part of a filename by truncating at the last / or \.
--
-- @param filename           filename
-- @return                   directory

function Dirname(filename: string): string
	local _, _, f = filename:find("(.*)[/\\][^/\\]*$")
	if f then
		if (f == "") then
			return "/"
		end
		return f
	end
	return "."
end

--- Splits a string by specifying the delimiter pattern.
--
-- @param str                the input string
-- @param delim              the delimiter
-- @return                   the list of words

function SplitString(str: string, delim: string): {string}
    -- Eliminate bad cases...
    if not str:find(delim) then
    	return {str}
    end

    local result = {}
    local pat = "(.-)" .. delim .. "()"
    local lastPos: number
    for part, pos: any in str:gmatch(pat) do
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

function TableToString(t: any): string
	local function stringify(n)
		if (type(n) == "string") then
			return string.format("%q", n)
		elseif (type(n) == "number") then
			return tostring(n)
		elseif (n == nil) then
			return "nil"
		elseif (type(n) == "boolean") then
			return tostring(n)
		elseif (type(n) == "function") then
			return "function()"
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

--- Insert element between elements of an array.
-- The old array is left untouched.
--
-- @param array              the array
-- @param spacer             the element to insert
-- @return                   a new array

function Intersperse(array: any, spacer: any): any
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

function MergeTables<T>(old: T, new: T): T
	local nt = new::any
	if old then
		for k, v in pairs(old::any) do
			nt[k] = v
		end
	end
	return new
end

--- Return a partially immutable proxy for an object.
-- This only handles direct assignment to array members.
--
-- @param o                  object
-- @return                   the proxy

function ImmutabliseArray(o: any): any
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

function GetClass(t: any): any
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

-- string.format("%q"); early Luas don't support control codes, so we emulate it.

function Format(w: string): string
	local ss = {'"'}

	local i = 1
	local len = w:len()
	while (i <= len) do
		local c = ReadU8(w, i)
		i = i + GetBytesOfCharacter(w:byte(i))
		if c < 32 then
			ss[#ss+1] = string_format("\\%d", c)
		else
			if (c == 92) or (c == 34) then
				ss[#ss+1] = '\\'
			end
			ss[#ss+1] = WriteU8(c)
		end
	end
	ss[#ss+1] = '"'
	return table_concat(ss)
end

-- Splits a string by whitespace.

function ParseStringIntoWords(s: string): {string}
	local words = {}
	for w in s:gmatch("[^ \t\r\n]+") do
		words[#words + 1] = w
	end
	if (#words == 0) then
		return {""}
	end
	return words
end

-- Convert an array to a map.

function ArrayToMap(array: any): any
	local map = {}
	for _, i in ipairs(array) do
		map[i] = true
	end
	return map
end

-- Argument parser.

declare FILENAME_ARG: {}
declare UNKNOWN_ARG: {}
FILENAME_ARG = {}
UNKNOWN_ARG = {}
function ParseArguments(argv: {string}, callbacks: {[any]: any})
	local function popn(n)
		if (n == nil) then
			return
		end
		if (n < 0) then
			CLIError("malformed argument")
		end
		while (n ~= 0) do
			table_remove(argv, 1)
			n = n - 1
		end
	end

	while next(argv) do
		local o = argv[1]
		table_remove(argv, 1)

		if (o:byte(1) == 45) then
			-- This is an option.
			if (o:byte(2) == 45) then
				-- ...with a -- prefix.
				o = o:sub(3)
				local fn = callbacks[o]
				if not fn then
					callbacks[UNKNOWN_ARG](o)
					return
				end
				popn(fn(unpack(argv)))
			else
				-- ...without a -- prefix.
				local od = o:sub(2, 2)
				local fn = callbacks[od]
				if not fn then
					callbacks[UNKNOWN_ARG](od)
					return
				end
				local op = o:sub(3)
				if (op == "") then
					popn(fn(unpack(argv)))
				else
					popn(fn(op, unpack(argv)) - 1)
				end
			end
		else
			local fn = callbacks[FILENAME_ARG]
			popn(fn(o, unpack(argv)) - 1)
		end
	end
end

-- Returns the largest common prefix of the array.

function LargestCommonPrefix(array: {string}): string?
	if (#array == 0) then
		return nil
	end

	local function all_strings_contain(p1: number, p2: number, s: string)
		s = s:sub(p1, p2)
		for _, ss in ipairs(array) do
			if (ss:sub(p1, p2) ~= s) then
				return false
			end
		end
		return true
	end

	local index = HUGE
	for _, s in ipairs(array) do
		if (#s < index) then
			index = #s
		end
	end

	local prefix = ""
	local low = 1
	local high = index
	while (low <= high) do
		local mid = math_floor((low + high) / 2)
		if all_strings_contain(low, mid, array[1]) then
			prefix = prefix .. array[1]:sub(low, mid)
			low = mid + 1
		else
			high = mid - 1
		end
	end

	return prefix
end

-- As for LargestCommonPrefix, but case insensitive.

function LargestCommonPrefixCaseInsensitive(array: {string}): string?
	if (#array == 0) then
		return nil
	end

	local function all_strings_contain(p1: number, p2: number, s: string)
		s = s:sub(p1, p2):lower()
		for _, ss in ipairs(array) do
			if (ss:sub(p1, p2):lower() ~= s) then
				return false
			end
		end
		return true
	end

	local index = HUGE
	for _, s in ipairs(array) do
		if (#s < index) then
			index = #s
		end
	end

	local prefix = ""
	local low = 1
	local high = index
	while (low <= high) do
		local mid = math_floor((low + high) / 2)
		if all_strings_contain(low, mid, array[1]) then
			prefix = prefix .. array[1]:sub(low, mid)
			low = mid + 1
		else
			high = mid - 1
		end
	end

	return prefix
end

-- Flattens an array, in depth first order.

function FlattenArray(array)
	local t = {}
	for _, v in ipairs(array) do
		if (type(v) == "table") then
			for _, vv in ipairs(FlattenArray(v)) do
				t[#t+1] = vv
			end
		else
			t[#t+1] = v
		end
	end
	return t
end

-- Given an array, returns a new array with x between each item.

function InterleaveArray(array, x)
	local t = {}
	for i, v in ipairs(array) do
		if (i ~= 1) then
			t[#t+1] = x
		end
		t[#t+1] = v
	end
	return t
end

-- Create an input stream, from which lines can be read as if it were a file.
-- It's incredibly limited to just the functions we need.

function CreateIStream(data: string): any
	local ptr = 1
	local o = {}
	setmetatable(o,
	{
		__index =
		{
			read = function(self, a: string): string?
				if a == "*l" then
					local _, e, s, n = string_find(data, "([^\n]*)(\n?)", ptr)
					if (s == "") and (n == "") then
						return nil
					end
					assert(e)
					ptr = e + 1
					return s
				elseif a == "*a" then
					local s = data:sub(ptr)
					ptr = #data
					return s
				else
					error("unsupported read parameter '"..a.."'")
				end
			end,

			lines = function(self)
				return function()
					return self:read("*l")
				end
			end
		}
	})

	return o
end

