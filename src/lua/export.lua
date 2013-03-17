-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_lower = string.lower

-- Renders the document by calling the appropriate functions on the cb
-- table.
 
function ExportFileUsingCallbacks(document, cb)
	cb.prologue()
	
	local listmode = false
	local rawmode = false
	local italic, underline
	local olditalic, oldunderline
	local firstword
	local wordbreak
	local emptyword
	
	local wordwriter = function (style, text)
		italic = bit(style, ITALIC)
		underline = bit(style, UNDERLINE)
		
		local writer
		if rawmode then
			writer = cb.rawtext
		else
			writer = cb.text
		end
		
		if not italic and olditalic then
			cb.italic_off()
		end
		if not underline and oldunderline then
			cb.underline_off()
		end
		
		if wordbreak then
			writer(' ')
			wordbreak = false
		end
	
		if underline and not oldunderline then
			cb.underline_on()
		end
		if italic and not olditalic then
			cb.italic_on()
		end
		writer(text)

		emptyword = false
		olditalic = italic
		oldunderline = underline
	end

	for _, paragraph in ipairs(Document) do
		local style = paragraph.style
		if (style.name == "L") or (style.name == "LB") then
			if not listmode then
				cb.list_start()
				listmode = true
			end
		elseif listmode then
			cb.list_end()
			listmode = false
		end
		
		rawmode = (style.name == "RAW")
		
		cb.paragraph_start(style.name)
	
		if (#paragraph == 1) and (#paragraph[1].text == 0) then
			cb.notext()
		else
			firstword = true
			wordbreak = false	
			olditalic = false
			oldunderline = false

			for wn, word in ipairs(paragraph) do
				if firstword then
					firstword = false
				else
					wordbreak = true
				end
				
				emptyword = true
				italic = false
				underline = false
				ParseWord(word.text, 0, wordwriter) -- FIXME
				if emptyword then
					wordwriter(0, "")
				end
			end
			if italic then
				cb.italic_off()
			end
			if underline then
				cb.underline_off()
			end
		end
		
		cb.paragraph_end(style.name)
	end
	if listmode then
		cb.list_end()
	end
	cb.epilogue()
end

-- Prompts the user to export a document, and then calls
-- callback(fp, document) to actually do the work.

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
	end
	
	ImmediateMessage("Exporting...")
	local fp, e = io.open(filename, "w")
	if not fp then
		ModalMessage(nil, "Unable to open the output file "..e..".")
		QueueRedraw()
		return false
	end
	
	callback(fp, Document)
	fp:close()
	
	QueueRedraw()
	return true
end
