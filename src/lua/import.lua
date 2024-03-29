--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local WriteU8 = wg.writeu8
local ReadFile = wg.readfile
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat

type Importer = {
	reset: (Importer) -> (),
	style_on: (Importer, number) -> (),
	style_off: (Importer, number) -> (),
	text: (Importer, string) -> (),
	flushword: (Importer, boolean?) -> (),
	flushparagraph: (Importer, string) -> (),
}

-- Import helper functions. These functions build styled words and paragraphs.

function CreateImporter(document: Document): Importer
	local pbuffer
	local wbuffer
	local oldattr
	local attr

	return
	{
		reset = function(self)
			pbuffer = {}
			wbuffer = {}
			oldattr = 0
			attr = 0
		end,

		style_on = function(self, a)
			attr = bitor(attr, a)
		end,

		style_off = function(self, a)
			attr = bitxor(bitor(attr, a), a)
		end,

		text = function(self, t)
			if (oldattr ~= attr) then
				wbuffer[#wbuffer + 1] = string_char(16 + attr)
				oldattr = attr
			end

			wbuffer[#wbuffer + 1] = t
		end,

		flushword = function(self, force)
			if (#wbuffer > 0) or force then
				local s = table_concat(wbuffer)
				pbuffer[#pbuffer + 1] = s
				wbuffer = {}
				oldattr = 0
			end
		end,

		flushparagraph = function(self, style)
			style = style or "P"

			if (#wbuffer > 0) then
				self:flushword()
			end

			if (#pbuffer > 0) then
				local p = CreateParagraph(style, pbuffer)
				document:appendParagraph(p)

				pbuffer = {}
			end
		end
	}
end

-- Does the standard selector-box-and-progress UI for each importer.

function ImportFileWithUI(filename, title, callback: (string) -> Document?): boolean
	if not filename then
		filename = FileBrowser(title, "Import from:", false)
		if not filename then
			return false
		end
	end
	assert(filename)

	ImmediateMessage("Importing...")

	-- Actually import the file.

	local data, e = ReadFile(filename)
	if not data then
		return false
	end

	assert(data)
	local document = callback(data)
	if not document then
		ModalMessage(nil, "The import failed, probably because the file could not be found.")
		QueueRedraw()
		return false
	end
	assert(document)

	-- Add the document to the document set.

	local docname = Leafname(filename)

	if documentSet:_findDocument(docname) then
		local id = 1
		while true do
			local f = docname.."-"..id
			if not documentSet:_findDocument(f) then
				docname = f
				break
			end
			id = id + 1
		end
	end

	documentSet:addDocument(document, docname)
	documentSet:setCurrent(docname)

	QueueRedraw()
	return true
end
