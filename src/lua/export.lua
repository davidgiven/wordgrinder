-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local BOLD = wg.BOLD
local ParseWord = wg.parseword
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_lower = string.lower
local time = wg.time

-- Renders the document by calling the appropriate functions on the cb
-- table.

function ExportFileUsingCallbacks(document, cb)
	document:renumber()
	cb.prologue()

	local listmode = false
	local rawmode = false
	local italic, underline, bold
	local olditalic, oldunderline, oldbold
	local firstword
	local wordbreak
	local emptyword

	local wordwriter = function (style, text)
		italic = bit(style, ITALIC)
		underline = bit(style, UNDERLINE)
		bold = bit(style, BOLD)

		local writer
		if rawmode then
			writer = cb.rawtext
		else
			writer = cb.text
		end

		-- Underline is stopping, so do so *before* the space
		if wordbreak and not underline and oldunderline then
			cb.underline_off()
		end

		if wordbreak then
			writer(' ')
			wordbreak = false
		end

		if not wordbreak and oldunderline then
			cb.underline_off()
		end
		if oldbold then
			cb.bold_off()
		end
		if olditalic then
			cb.italic_off()
		end
		if italic then
			cb.italic_on()
		end
		if bold then
			cb.bold_on()
		end
		if underline then
			cb.underline_on()
		end
		writer(text)

		emptyword = false
		olditalic = italic
		oldunderline = underline
		oldbold = bold
	end

	for _, paragraph in ipairs(Document) do
		local name = paragraph.style
		local style = DocumentStyles[name]

		if listmode and not style.list then
			cb.list_end(listmode)
			listmode = false
		end
		if not listmode and style.list then
			cb.list_start(name)
			listmode = true
		end

		rawmode = (name == "RAW")

		cb.paragraph_start(paragraph)

		if (#paragraph == 1) and (#paragraph[1] == 0) then
			cb.notext()
		else
			firstword = true
			wordbreak = false
			olditalic = false
			oldunderline = false
			oldbold = false

			for wn, word in ipairs(paragraph) do
				if firstword then
					firstword = false
				else
					wordbreak = true
				end

				emptyword = true
				italic = false
				underline = false
				bold = false
				ParseWord(word, 0, wordwriter) -- FIXME
				if emptyword then
					wordwriter(0, "")
				end
			end

			if underline then
				cb.underline_off()
			end
			if bold then
				cb.bold_off()
			end
			if italic then
				cb.italic_off()
			end
		end

		cb.paragraph_end(paragraph)
	end
	if listmode then
		cb.list_end()
	end
	cb.epilogue()
end

-- Prompts the user to export a document, and then calls
-- exportcb(writer, document) to actually do the work.

function ExportFileWithUI(filename, title, extension, callback)
	if not filename then
		filename = Document.name
		if filename then
			if not filename:find("%..-$") then
				filename = filename .. extension
			else
				filename = filename:gsub("%..-$", extension)
			end
		else
			filename = "(unnamed)"
		end

		filename = FileBrowser(title, "Export as:", true,
			filename)
		if not filename then
			return false
		end
		if filename:find("/[^.]*$") then
			filename = filename .. extension
		end
	end

	ImmediateMessage("Exporting...")
	local fp, e = io.open(filename, "w")
	if not fp then
		ModalMessage(nil, "Unable to open the output file "..e..".")
		QueueRedraw()
		return false
	end

	local fpw = fp.write
	local writer = function(...)
		fpw(fp, ...)
	end

	callback(writer, Document)
	fp:close()

	QueueRedraw()
	return true
end

--- Converts a document into a local string.

function ExportToString(document, callback)
	local ss = {}
	local writer = function(...)
		for _, s in ipairs({...}) do
			ss[#ss+1] = s
		end
	end

	callback(writer, document)

	return table.concat(ss)
end

