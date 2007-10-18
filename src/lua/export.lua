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

local function savehtmlfile(fp, document)
	fp:write('<html><head>\n')
	fp:write('<meta http-equiv="Content-Type" content="text/html;charset=utf-8">\n')
	fp:write('<title>', Document.name, '</title>')
	
	local listmode = false
	local italic, underline
	local olditalic, oldunderline
	local firstword
	
	local wordwriter = function (style, text)
		italic = bit(style, ITALIC)
		underline = bit(style, UNDERLINE)
		
		if not italic and olditalic then
			fp:write('</i>')
		end
		if not underline and oldunderline then
			fp:write('</u>')
		end
		if underline and not oldunderline then
			fp:write('<u>')
		end
		if italic and not olditalic then
			fp:write('<i>')
		end
		fp:write(text)
		
		olditalic = italic
		oldunderline = underline
	end
		
	fp:write('<body>\n')
	for _, paragraph in ipairs(Document) do
		local style = paragraph.style.html
		if (style == "LI") then
			if not listmode then
				fp:write("<UL>")
				listmode = true
			end
		elseif listmode then
			fp:write("</UL>")
		end
			
		fp:write('<', style, '>')
		
		firstword = true		
		olditalic = false
		oldunderline = false
		for wn, word in ipairs(paragraph) do
			if not firstword then
				fp:write(' ')
			end
			firstword = false
		
			italic = false
			underline = false
			ParseWord(word.text, style.cstyle or 0, wordwriter) -- FIXME
		end
		if italic then
			fp:write('</i>')
		end
		if underline then
			fp:write('</u>')
		end
		fp:write('</', style, '>\n')
	end
	if listmode then
		fp:write('</UL>')
	end
	fp:write('</body>\n')
	
	fp:write('</html>\n')
end

local function savetextfile(fp, document)
	local firstword
	
	local wordwriter = function (style, text)
		fp:write(text)
	end
		
	for _, paragraph in ipairs(document) do
		firstword = true
		
		for wn, word in ipairs(paragraph) do
			if not firstword then
				fp:write(' ')
			end
			firstword = false
		
			ParseWord(word.text, 0, wordwriter)
		end
		fp:write('\n')
	end
end

local function exportgenericfile(filename, title, extension, callback)
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
	local fp = io.open(filename, "w")
	if not fp then
		ModalMessage(nil, "The export failed for some reason.")
		QueueRedraw()
		return false
	end
	
	callback(fp, Document)
	fp:close()
	
	QueueRedraw()
	return true
end

function Cmd.ExportHTMLFile(filename)
	return exportgenericfile(filename, "Export HTML File", ".html",
		savehtmlfile)
end

function Cmd.ExportTextFile(filename)
	return exportgenericfile(filename, "Export Text File", ".txt",
		savetextfile)
end
