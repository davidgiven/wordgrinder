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
    local nb = 0
    local lastPos
    for part, pos in str:gmatch(pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if (nb == maxNb) then
			break
		end
    end
    -- Handle the last field
    if nb ~= maxNb then
        result[nb + 1] = str:sub(lastPos)
    end
    return result
end

--- Simple table renderer (no recursion).
--
-- @param t                  input table
-- @return                   a string

function TableToString(t)
	local ts = {}
	for _, n in ipairs(t) do
		local s
		if (type(n) == "string") then
			s = string.format("%q", n)
		elseif (type(n) == "number") then
			s = tostring(n)
		elseif (n == nil) then
			s = nil
		else
			s = "unknown " .. type(n)
		end
		ts[#ts+1] = s
	end

	return "{"..table.concat(ts, ", ").."}"
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

			getRawArray = function(self)
				return o
			end
		}
	)
	return p
end

