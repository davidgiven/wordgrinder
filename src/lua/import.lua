-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL: $

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local bitand = wg.bitand
local bitor = wg.bitor
local bitxor = wg.bitxor
local bit = wg.bit

function ParseStringIntoWords(s)
	local words = {}
	for w in s:gmatch("[^ \t\r\n]+") do
		words[#words + 1] = CreateWord(w)
	end
	if (#words == 0) then
		return {CreateWord()}
	end
	return words
end

local function loadtextfile(filename)
	local fp = io.open(filename)
	if not fp then
		return nil
	end
	
	local document = CreateDocument()
	for l in fp:lines() do
		local p = CreateParagraph(DocumentSet.styles["P"], ParseStringIntoWords(l))
		document:appendParagraph(p)
	end
	
	fp:close()
	
	filename = filename:gsub("%.txt$", "")
	document.name = filename .. ".wg"
	return document
end

function Cmd.ImportTextFile(filename)
	if not filename then
		filename = FileBrowser("Import Text File", "Import from:", false)
		if not filename then
			return false
		end
	end
	
	ImmediateMessage("Importing...")	
	local d = loadtextfile(filename)
	if not d then
		ModalMessage(nil, "The import failed, probably because the file could not be found.")
		QueueRedraw()
		return false
	end
		
	if DocumentSet.documents[filename] then
		local id = 1
		while true do
			local f = filename.."-"..id
			if not DocumentSet.documents[f] then
				filename = f
				break
			end
		end
	end
	
	DocumentSet:addDocument(d, filename)
	DocumentSet:setCurrent(filename)

	QueueRedraw()
	return true
end
