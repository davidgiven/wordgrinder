#!/usr/bin/env -S wordgrinder --lua

-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- This user script is a file diagnostic tool for debugging v2 dumpfiles. It
-- will dump the entire contents of the file as structured text.
--
-- It's theoretically possible to regenerate a dumpfile from the text, but
-- I haven't done that (there shouldn't really be a need).
--
-- To use:
--
--     wordgrinder --lua dumpdoc.lua nameofwgfile.wg

local ParseWord = wg.parseword
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local time = wg.time
local compress = wg.compress
local decompress = wg.decompress
local writeu8 = wg.writeu8
local readu8 = wg.readu8
local string_rep = string.rep
local string_format = string.format
local string_byte = string.byte
local table_concat = table.concat
local math_min = math.min

local MAGIC = "WordGrinder dumpfile v1: this is not a text file!"
local ZMAGIC = "WordGrinder dumpfile v2: this is not a text file!"

local STOP = 0
local TABLE = 1
local BOOLEANTRUE = 2
local BOOLEANFALSE = 3
local STRING = 4
local NUMBER = 5
local CACHE = 6
local NEGNUMBER = 7
local BRIEFWORD = 8

local DOCUMENTSETCLASS = 100
local DOCUMENTCLASS = 101
local PARAGRAPHCLASS = 102
local WORDCLASS = 103
local MENUCLASS = 104

local outfp

local function dprint(s)
	outfp:write(s, "\n")
end

local function loadfromstreamz(fp)
	local cache = {}
	local load
	local data = decompress(fp:read("*a"))
	local offset = 1
	local indent = 0
	
	local function spaces()
		return string_rep(" ", indent)
	end

	local function dumpdata(startpos, endpos)
		local len = endpos - startpos
		local s = {spaces(), string_format("-- 0x%08x+%x: ", startpos, len)}
		for i = startpos, math_min(startpos+16, endpos-1, #data) do
			s[#s+1] = string_format("%02x ", string_byte(data, i))
		end
		if (len > 16) then
			s[#s+1] = "..."
		end
		dprint(table_concat(s))
	end

	local function populate_table(t, tag)
		local n
		n, offset = readu8(data, offset)
		dprint(spaces().."@"..(#cache).." "..tag.."("..n..")")
		dprint(spaces().."{")
		indent = indent + 1

		for i = 1, n do
			dprint(spaces().."-- index "..i)
			indent = indent + 1
			t[i] = load()
			indent = indent - 1
		end
		
		while true do
			dprint(spaces().."-- key:")
			indent = indent + 1
			local k = load()
			indent = indent - 1
			if not k then
				break
			end
			
			dprint(spaces().."-- value:")
			indent = indent + 1
			t[k] = load()
			indent = indent - 1
		end
		
		indent = indent - 1
		dprint(spaces().."}")
		return t
	end
	
	local load_cb = {
		[CACHE] = function()
			local n
			n, offset = readu8(data, offset)
			dprint(spaces().."ref @"..n)
			return cache[n]
		end,
		
		[DOCUMENTSETCLASS] = function()
			local t = {}
			setmetatable(t, {__index = DocumentSetClass})
			cache[#cache + 1] = t
			return populate_table(t, "documentset")
		end,
		
		[DOCUMENTCLASS] = function()
			local t = {}
			setmetatable(t, {__index = DocumentClass})
			cache[#cache + 1] = t
			return populate_table(t, "document")
		end,
		
		[PARAGRAPHCLASS] = function()
			local t = {}
			setmetatable(t, {__index = ParagraphClass})
			cache[#cache + 1] = t
			return populate_table(t, "paragraph")
		end,
		
		[WORDCLASS] = function()
			local t = {}
			setmetatable(t, {__index = WordClass})
			cache[#cache + 1] = t
			return populate_table(t, "word")
		end,
		
		[MENUCLASS] = function()
			local t = {}
			setmetatable(t, {__index = MenuClass})
			cache[#cache + 1] = t
			return populate_table(t, "menu")
		end,
		
		[TABLE] = function()
			local t = {}
			cache[#cache + 1] = t
			return populate_table(t, "table")
		end,
		
		[STRING] = function()
			local n
			n, offset = readu8(data, offset)
			local s = data:sub(offset, offset+n-1)
			offset = offset + n

			cache[#cache + 1] = s
			dprint(spaces().."@"..(#cache).." string"..string_format("(%d, %q)", n, s))
			return s
		end,
		
		[NUMBER] = function()
			local n
			n, offset = readu8(data, offset)
			cache[#cache + 1] = n
			dprint(spaces().."@"..(#cache).." number("..n..")")
			return n
		end,
		
		[NEGNUMBER] = function()
			local n
			n, offset = readu8(data, offset)
			cache[#cache + 1] = n
			dprint(spaces().."@"..(#cache).." negnumber("..(-n)..")")
			return n
		end,
		
		[BOOLEANTRUE] = function()
			cache[#cache + 1] = true
			dprint(spaces().."@"..(#cache).." true")
			return true
		end,
		
		[BOOLEANFALSE] = function()
			cache[#cache + 1] = false
			dprint(spaces().."@"..(#cache).." false")
			return false
		end,
		
		[BRIEFWORD] = function()
			local o = {}
			cache[#cache + 1] = o
			dprint(spaces().."@"..(#cache).." briefword")
			indent = indent + 1
			load()
			indent = indent - 1
			return o
		end,

		[STOP] = function()
			return nil
		end
	}
	
	load = function()
		local n
		dprint(spaces()..string_format("-- 0x%08x", offset))
		local oldoffset = offset
		n, offset = readu8(data, offset)
		
		local f = load_cb[n]
		if not f then
			dprint(spaces().."-- load error!")
			dumpdata(offset-1, offset+32)
			error("can't load type "..n.." at offset "..offset)
		end
		local v = f()
		dumpdata(oldoffset, offset)
		return v
	end
	
	return load()		
end

local function loaddocument(filename)
	local fp, e = io.open(filename, "rb")
	if not fp then
		return "'"..filename.."' could not be opened: "..e
	end
	local loader = nil
	local magic = fp:read("*l")
	if (magic ~= ZMAGIC) then
		fp:close()
		return "can only dump v2 files."
	end

	loadfromstreamz(fp)
	fp:close()
end

-- Main program

local function main(filename)
	if not filename then
		print("You must specify a filename to dump.")
		os.exit(1)
	end

	outfp = io.open("dumpfile.txt", "w")
	print("writing output to dumpfile.txt")

	dprint("dump of "..filename)
	local e = loaddocument(filename)
	if e then
		print("dump failed with: "..e)
	end
end

main(...)
os.exit(0)

