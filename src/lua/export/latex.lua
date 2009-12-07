-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

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

local style_tab =
{
	["H1"] = {'\\section{',           '}'},
	["H2"] = {'\\subsection{',        '}'},
	["H3"] = {'\\subsubsection{',     '}'},
	["H4"] = {'\\paragraph{',         '}'},
	["P"] =  {'',                     '\n'},
	["L"] =  {'\\item[]{',            '}'},
	["LB"] = {'\\item{',              '}'},
	["Q"] =  {'\\begin{quotation}\n', '\n\\end{quotation}'},
	["V"] =  {'\\begin{quotation}\n', '\n\\end{quotation}'},
	["RAW"] = {'', ''},
	["PRE"] = {'\\begin{verbatim}\n', '\n\\end{verbatim}'}
}

local function callback(fp, document)
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			fp:write('%% This document automatically generated by '..
				'WordGrinder '..VERSION..'.\n')
			fp:write('\\documentclass{article}\n')
			fp:write('\\usepackage{xunicode, setspace}\n')
			fp:write('\\sloppy\n')
			fp:write('\\onehalfspacing\n')
			fp:write('\\begin{document}\n')
			fp:write('\\title{', untex(Document.name), '}\n')
			fp:write('\\author{(no author)}\n')
			fp:write('\\maketitle\n')
		end,
		
		rawtext = function(s)
			fp:write(s)
		end,
		
		text = function(s)
			fp:write(untex(s))
		end,
		
		notext = function(s)
			fp:write('\\paragraph{}')
		end,
		
		italic_on = function()
			fp:write('\\emph{')
		end,
		
		italic_off = function()
			fp:write('}')
		end,
		
		underline_on = function()
			fp:write('\\underline{')
		end,
		
		underline_off = function()
			fp:write('}')
		end,
		
		list_start = function()
			fp:write('\\begin{itemize}\n')
		end,
		
		list_end = function()
			fp:write('\\end{itemize}\n')
		end,
		
		paragraph_start = function(style)
			fp:write(style_tab[style][1] or "")
		end,		
		
		paragraph_end = function(style)
			fp:write(style_tab[style][2] or "")
			fp:write('\n')
		end,
		
		epilogue = function()
			fp:write('\\end{document}\n')	
		end
	})
end

function Cmd.ExportLatexFile(filename)
	return ExportFileWithUI(filename, "Export LaTeX File", ".tex",
		callback)
end
