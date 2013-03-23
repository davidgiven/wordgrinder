-- © 2008-2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local WriteU8 = wg.writeu8
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat

-----------------------------------------------------------------------------
-- The importer itself.

local function loadtextfile(fp)
	local document = CreateDocument()
	for l in fp:lines() do
		l = CanonicaliseString(l)
		l = l:gsub("%c+", "")
		local p = CreateParagraph(DocumentSet.styles["P"], ParseStringIntoWords(l))
		document:appendParagraph(p)
	end
	
	return document
end

function Cmd.ImportTextFile(filename)
	return ImportFileWithUI(filename, "Import Text File", loadtextfile)
end
