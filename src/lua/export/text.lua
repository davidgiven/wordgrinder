-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local function callback(fp, document)
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
		end,
		
		rawtext = function(s)
			fp:write(s)
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
