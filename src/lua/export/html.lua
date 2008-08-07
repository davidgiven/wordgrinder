-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id: export.lua 58 2008-08-06 00:08:24Z dtrg $
-- $URL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/src/lua/export.lua $

local function unhtml(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local style_tab =
{
	["H1"] = {'<h1>', '</h1>'},
	["H2"] = {'<h2>', '</h2>'},
	["H3"] = {'<h3>', '</h3>'},
	["H4"] = {'<h4>', '</h4>'},
	["P"] =  {'<p>', '</p>'},
	["L"] =  {'<li style="list-style-type: none;">', '</li>'},
	["LB"] = {'<li>', '</li>'},
	["Q"] =  {'<blockquote>', '</blockquote>'},
	["V"] =  {'<blockquote>', '</blockquote>'},
}

local function callback(fp, document)
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			fp:write('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n')
			fp:write('<html><head>\n')
			fp:write('<meta http-equiv="Content-Type" content="text/html;charset=utf-8">\n')
			fp:write('<meta name="generator" content="WordGrinder '..VERSION..'">\n')
			fp:write('<title>', unhtml(document.name), '</title>\n')
			fp:write('</head><body>\n')
		end,
		
		text = function(s)
			fp:write(unhtml(s))
		end,
		
		notext = function(s)
			fp:write('<br/>')
		end,
		
		italic_on = function()
			fp:write('<i>')
		end,
		
		italic_off = function()
			fp:write('</i>')
		end,
		
		underline_on = function()
			fp:write('<u>')
		end,
		
		underline_off = function()
			fp:write('</u>')
		end,
		
		list_start = function()
			fp:write('<ul>')
		end,
		
		list_end = function()
			fp:write('</ul>')
		end,
		
		paragraph_start = function(style)
			fp:write(style_tab[style][1] or "<p>")
		end,		
		
		paragraph_end = function(style)
			fp:write(style_tab[style][2] or "</p>")
			fp:write('\n')
		end,
		
		epilogue = function()
			fp:write('</body>\n')	
			fp:write('</html>\n')
		end
	})
end

function Cmd.ExportHTMLFile(filename)
	return ExportFileWithUI(filename, "Export HTML File", ".html",
		callback)
end
