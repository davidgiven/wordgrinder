-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local bitand = wg.bitand
local bitor = wg.bitor
local bitxor = wg.bitxor
local bit = wg.bit
local string_lower = string.lower

local function unhtml(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function savehtmlfile(fp, document)
	fp:write('<html><head>\n')
	fp:write('<meta http-equiv="Content-Type" content="text/html;charset=utf-8">\n')
	fp:write('<title>', unhtml(Document.name), '</title>')
	
	local listmode = false
	local italic, underline
	local olditalic, oldunderline
	local firstword
	local wordbreak
	
	local wordwriter = function (style, text)
		italic = bit(style, ITALIC)
		underline = bit(style, UNDERLINE)
		
		if not italic and olditalic then
			fp:write('</i>')
		end
		if not underline and oldunderline then
			fp:write('</u>')
		end
		
		if wordbreak then
			fp:write(' ')
			wordbreak = false
		end
		
		if underline and not oldunderline then
			fp:write('<u>')
		end
		if italic and not olditalic then
			fp:write('<i>')
		end
		fp:write(unhtml(text))
		
		olditalic = italic
		oldunderline = underline
	end
		
	fp:write('<body>\n')
	for _, paragraph in ipairs(Document) do
		local style = paragraph.style
		local htmlstyle = string_lower(style.html)
		if (htmlstyle == "li") then
			if not listmode then
				fp:write("<ul>")
				listmode = true
			end
		elseif listmode then
			fp:write("</ul>")
			listmode = false
		end
			
		if (htmlstyle == "li") then
			if style.bullet then
				fp:write('<li>')
			else
				fp:write('<li style="list-style-type: none;">')
			end
		else
			fp:write('<', htmlstyle, '>')
		end
		
		if (#paragraph == 1) and (#paragraph[1].text == 0) then
			fp:write("<br/>")
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
							
				italic = false
				underline = false
				ParseWord(word.text, 0, wordwriter)
			end
			if italic then
				fp:write('</i>')
			end
			if underline then
				fp:write('</u>')
			end
		end
		fp:write(' </', htmlstyle, '>\n')
	end
	if listmode then
		fp:write('</ul>')
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

local untextab = {
	["#"] = "\\#",
	["$"] = "\\$",
	["&"] = "\\&",
	["{"] = "\\{",
	["}"] = "\\}",
	["_"] = "\\_{}",
	["^"] = "\\^{}",
	["~"] = "\\~{}",
	["%"] = "\\%",
	["<"] = "$\\langle$",
	[">"] = "$\\rangle$",
	["\\"] = "$\\backslash$"
}

local function untex(s)
	s = s:gsub("[#$&{}\\_^~%%<>]", untextab)
	return s
end

local function savelatexfile(fp, document)
	fp:write('\\documentclass{article}\n')
	fp:write('\\usepackage{xunicode, setspace}\n')
	fp:write('\\sloppy\n')
	fp:write('\\onehalfspacing\n')
	fp:write('\\begin{document}\n')
	fp:write('\\title{', untex(Document.name), '}\n')
	fp:write('\\author{(no author)}\n')
	fp:write('\\maketitle\n')
	
	local listmode = false
	local italic, underline
	local olditalic, oldunderline
	local firstword
	local wordbreak
	
	local LISTSTYLE = {}
	local styletab = {
		["LI"] = LISTSTYLE,
		["H1"] = "\\section",
		["H2"] = "\\subsection",
		["H3"] = "\\subsubsection",
		["H4"] = "\\paragraph",
		["Q"]  = "\\",
	}
	
	local wordwriter = function (style, text)
		italic = bit(style, ITALIC)
		underline = bit(style, UNDERLINE)
		
		if not italic and olditalic then
			fp:write('}')
		end
		if not underline and oldunderline then
			fp:write('}')
		end
		
		if wordbreak then
			fp:write(' ')
			wordbreak = false
		end
	
		if underline and not oldunderline then
			fp:write('\\underline{')
		end
		if italic and not olditalic then
			fp:write('\\emph{')
		end
		fp:write(untex(text))
		
		olditalic = italic
		oldunderline = underline
	end

	for _, paragraph in ipairs(Document) do
		local style = paragraph.style
		local htmlstyle = style.html
		if (htmlstyle == "LI") then
			if not listmode then
				fp:write("\\begin{itemize}\n")
				listmode = true
			end
		elseif listmode then
			fp:write("\\end{itemize}\n")
			listmode = false
		end
	
		local texstyle = styletab[htmlstyle]
		if texstyle then
			if (texstyle == LISTSTYLE) then
				if style.bullet then
					fp:write("\\item{")
				else
					fp:write("\\item[]{")
				end
			else
				fp:write(texstyle, "{")
			end
		end		
		
		if (#paragraph == 1) and (#paragraph[1].text == 0) then
			fp:write("\\paragraph{}")
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
				
				italic = false
				underline = false
				ParseWord(word.text, 0, wordwriter) -- FIXME
			end
			if italic then
				fp:write('}')
			end
			if underline then
				fp:write('}')
			end
		end
		
		if texstyle then
			fp:write('}')
		end
		fp:write('\n\n')
	end
	if listmode then
		fp:write('\\end{itemize}\n')
	end
	fp:write('\\end{document}\n')
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

function Cmd.ExportHTMLFile(filename)
	return exportgenericfile(filename, "Export HTML File", ".html",
		savehtmlfile)
end

function Cmd.ExportTextFile(filename)
	return exportgenericfile(filename, "Export Text File", ".txt",
		savetextfile)
end

function Cmd.ExportLatexFile(filename)
	return exportgenericfile(filename, "Export LaTeX file", ".tex",
		savelatexfile)
end
