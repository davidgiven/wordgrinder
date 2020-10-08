-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local function callback(writer, document)
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
		end,
		
		rawtext = function(s)
			writer(s)
		end,
		
		text = function(s)
			writer(s)
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
		
		bold_on = function()
		end,
		
		bold_off = function()
		end,
		
		list_start = function()
		end,
		
		list_end = function()
		end,
		
		paragraph_start = function(para)
		end,		
		
		paragraph_end = function(para)
			writer('\n')
		end,
		
		epilogue = function()
		end
	})
end

function Cmd.ExportTextFile(filename)
	return ExportFileWithUI(filename, "Export Text File", ".txt",
		callback)
end

function Cmd.ExportToTextString()
	return ExportToString(Document, callback)
end
