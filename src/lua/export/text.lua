-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id: export.lua 58 2008-08-06 00:08:24Z dtrg $
-- $URL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/src/lua/export.lua $

local function callback(fp, document)
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
		end,
		
		text = function(s)
			fp:write(s)
		end,
		
		notext = function(s)
		end,
		
		italic_on = function()
		end,
		
		italic_off = function()
		end,
		
		underline_on = function()
		end,
		
		underline_off = function()
		end,
		
		list_start = function()
		end,
		
		list_end = function()
		end,
		
		paragraph_start = function(style)
		end,		
		
		paragraph_end = function(style)
			fp:write('\n')
		end,
		
		epilogue = function()
		end
	})
end

function Cmd.ExportTextFile(filename)
	return ExportFileWithUI(filename, "Export Text File", ".txt",
		callback)
end
