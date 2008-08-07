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
-- @param encoding           input encoding; defaults to UTF-8
-- @return                   canonicalised string

do
	local currentencoding = nil
	
	function CanonicaliseString(s, encoding)
		if not encoding then
			encoding = "utf-8"
		else
			encoding = encoding:lower()
		end
		if (encoding ~= currentencoding) then
			currentencoding = encoding
			wg.setencodings(currentencoding, "utf-8")
		end
		
		s = wg.transcode(s)
		return s:gsub("%c+", "")
	end
end

--- Chooses between a singular or a plural string.
--
-- @param n                  number
-- @param singular           returned if number == 1
-- @param plural             returned if number ~= 1
-- @return                   either singular or plural

function pluralise(n, singular, plural)
	if (n == 1) then
		return singular
	else
		return plural
	end
end
