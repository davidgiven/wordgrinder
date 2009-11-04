-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

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
-- Converts the string to guaranteed valid UTF-8, and removes any
-- control sequences.
--
-- @param s                  string to process
-- @return                   canonicalised string

function CanonicaliseString(s)
	s = wg.transcode(s)
	return s:gsub("%c+", "")
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
