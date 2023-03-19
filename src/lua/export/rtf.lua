--!nonstrict
-- © 2011 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local NextCharInWord = wg.nextcharinword
local ReadU8 = wg.readu8
local string_len = string.len
local string_char = string.char
local string_format = string.format
local string_gsub = string.gsub
local table_concat = table.concat

-----------------------------------------------------------------------------
-- The exporter itself.

local function unrtf(s)
	local ss = {}
	local o = 1
	local n = string_len(s)
	
	while (o <= n) do
		local c = ReadU8(s, o)
		o = NextCharInWord(s, o)
		if (c == 92) then
			ss[#ss+1] = "\\"
		elseif (c == 123) then
			ss[#ss+1] = "\\{"
		elseif (c == 125) then
			ss[#ss+1] = "\\}"
		elseif (c < 127) then
			ss[#ss+1] = string_char(c)
		elseif (c < 0x10000) then
			ss[#ss+1] = string_format('\\u%d ', c)
		else
			c = c - 0x10000
			ss[#ss+1] = string_format('\\u%d', 0xd800 + (c / 0x400)) 
			ss[#ss+1] = string_format('\\u%d ', 0xdc00 + (c % 0x400)) 
		end
	end
	
	return table_concat(ss)
end

local style_tab =
{
	["H1"] = {1, '\\fs40\\sb400\\b\\sbasedon0 H1'},
	["H2"] = {2, '\\fs36\\sb360\\b\\sbasedon0 H2'},
	["H3"] = {3, '\\fs32\\sb320\\b\\sbasedon0 H3'},
	["H4"] = {4, '\\fs28\\sb280\\b\\sbasedon0 H4'},
	["P"] =  {5, '\\fs28\\sb140\\sbasedon0 P'},
	["L"] =  {6, '\\fs28\\sb140\\sbasedon5 L'},
	["LB"] = {7, '\\fs28\\sb140\\sbasedon5 LB'},
	["Q"] =  {8, '\\fs28\\sb140\\li500\\sbasedon5 Q'},
	["V"] =  {9, '\\fs28\\sb140\\li500\\sbasedon5 V'},
	["PRE"] = {10, '\\fs28\\sb140\\sbasedon5 PRE'},
}

local function callback(writer, document)
	local settings = DocumentSet.addons.htmlexport
	
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			writer('{\\rtf1\\ansi\\deff0')
			writer('{\\fonttbl{\\f0 Times New Roman}}')
			writer('\\deflang1033\\widowctrl')
			writer('\\uc0')
			
			writer('{\\listtable\n')
			
			writer('{\\list\\listtemplateid1\\listsimple\n')
			writer('{\\listlevel\\levelnfc23{\\levelfollow1\\leveltext \\u8226;}\\fi-300\\li500}\n')
			writer('\\listid1\\listname LB;}\n')
			
			writer('}\n')
			
			writer('{\\listoverridetable\n')
			writer('{\\listoverride\\listid1\\listoverridecount0\\ls1}\n')
			writer('}\n')
			
			writer('{\\stylesheet\n')
			writer('{\\s0 Normal;}\n')
			for _, s in pairs(style_tab) do
				writer('{\\s', s[1], ' ', s[2], ';}\n')
			end
			writer('}\n')
			writer('\n')
		end,
		
		rawtext = function(s)
			writer(s)
		end,
		
		text = function(s)
			writer(unrtf(s))
		end,
		
		notext = function(s)
		end,
		
		italic_on = function()
			writer('\\i ')
		end,
		
		italic_off = function()
			writer('\\i0 ')
		end,
		
		underline_on = function()
			writer('\\ul ')
		end,
		
		underline_off = function()
			writer('\\ul0 ')
		end,
		
		list_start = function()
			writer('<ul>')
		end,
		
		list_end = function()
			writer('</ul>')
		end,
		
		paragraph_start = function(style)
			writer('{\\pard\\s', style_tab[style][1])
			if (style == "LB") then
				writer('\\ls1')
			end
			writer(' ')
			italic = false
			underline = false
			--changepara(style)
		end,		
		
		paragraph_end = function(style)
			writer('\\par}\n')
		end,
		
		epilogue = function()
			writer('}')
		end
	})
end

function Cmd.ExportRTFFile(filename)
	return ExportFileWithUI(filename, "Export RTF File", ".rtf",
		callback)
end
