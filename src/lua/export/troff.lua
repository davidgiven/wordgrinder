-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local NextCharInWord = wg.nextcharinword
local ReadU8 = wg.readu8
local string_len = string.len
local string_char = string.char
local string_format = string.format
local string_gsub = string.gsub

local style_tab =
{
	["H1"] = '.NH 1',
	["H2"] = '.NH 2',
	["H3"] = '.NH 3',
	["H4"] = '.NH 4',
	["P"] =  '.LP',
	["L"] =  '.IP',
	["LB"] = '.IP \\[bu]',
	["Q"] =  '.IP',
	["V"] =  '.IP',
	["RAW"] = '',
	["PRE"] = '.LD 1',
}

local function callback(writer, document)
	local currentstyle = nil
	local ul = false
	local it = false
	local linestart = true
	
	local function emit_text(s)
		if linestart then
			s = string_gsub(s, "^([.'])", '\\%1')
			s = string_gsub(s, '^%s+', '')
			linestart = false
		end
		
		s = string_gsub(s, '\\', '\\\\')
		
		local o = 1
		local n = string_len(s)
		
		while (o <= n) do
			local c = ReadU8(s, o)
			o = NextCharInWord(s, o)
			if (c < 127) then
				writer(string_char(c))
			else
				writer(string_format('\\[char%d]', c))
			end
		end
	end
	
	local function changestate(newit, newul)
		if not newit and it then
			writer('\\fR')
			linestart = false
		end
		
		if not newul and ul then
			writer('"\n')
			linestart = true
		end
		
		if newul and not ul then
			writer('\n.UL "')
			linestart = false
		end
		
		if newit and not it then
			writer('\\fI')
			linestart = false
		end
	
		it = newit
		ul = newul
	end
	
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			writer('.\\" This document automatically generated by '..
				'WordGrinder '..VERSION..'.\n')
			writer('.\\" Use the .ms macro package!\n')
			writer('.TL\n')
			emit_text(Document.name)
			writer('\n')
			linestart = true
		end,
		
		text = emit_text,
		
		rawtext = function(s)
			writer(s)
		end,
		
		notext = function(s)
		end,
		
		italic_on = function()
			changestate(true, ul)
		end,
		
		italic_off = function()
			changestate(false, ul)
		end,
		
		underline_on = function()
			changestate(it, true)
		end,
		
		underline_off = function()
			changestate(it, false)
		end,
		
		list_start = function()
		end,
		
		list_end = function()
		end,
		
		paragraph_start = function(style)
			if (currentstyle ~= "PRE") or (style ~= "PRE") then
				if (currentstyle == "PRE") then
					writer(".DE\n")
				end
				writer(style_tab[style] or ".LP")
				writer('\n')
			end
			linestart = true
			currentstyle = style
		end,		
		
		paragraph_end = function(style)
			writer('\n')
			linestart = true
		end,
		
		epilogue = function()
		end
	})
end

function Cmd.ExportTroffFile(filename)
	return ExportFileWithUI(filename, "Export Troff File", ".tr",
		callback)
end
