-- © 2008-2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local BOLD = wg.BOLD
local ParseWord = wg.parseword
local WriteU8 = wg.writeu8
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat

-----------------------------------------------------------------------------
-- The importer itself.

function Cmd.ImportHTMLFileFromStream(fp)
	local data = fp:read("*a")

	-- Collapse whitespace; this makes things far easier to parse.

	data = data:gsub("[\t\f]", " ")
	data = data:gsub("\r\n", "\n")

	-- Canonicalise the string, making it valid UTF-8.

	data = CanonicaliseString(data)
	
	-- Collapse complex elements.
	
	data = data:gsub("< ?(%w+) ?[^>]*(/?)>", "<%1%2>")
	
	-- Helper function for reading tokens from the HTML stream.
	
	local pos = 1
	local len = data:len()
	local function tokens()
		if (pos >= len) then
			return nil
		end
		
		local s, e, t
		s, e, t = string_find(data, "^([ \n])", pos)
		if s then pos = e+1 return t end
		
		if string_find(data, "^%c") then
			pos = pos + 1
			return tokens()
		end
		
		s, e, t = string_find(data, "^(<[^>]*>)", pos)
		if s then pos = e+1 return t:lower() end
		
		s, e, t = string_find(data, "^(&[^;]-;)", pos)
		if s then pos = e+1 return t end
		
		s, e, t = string_find(data, "^([^ <&\n]+)", pos)
		if s then pos = e+1 return t end
		
		t = string_sub(data, pos, pos+1)
		pos = pos + 1
		return t
	end
	
	-- Skip tokens until we hit a <body>.
	
	for t in tokens do
		if (t == "<body>") then
			break
		end
	end

	-- Define the element look-up table.
	
	local document = CreateDocument()
	local importer = CreateImporter(document)
	local style = "P"
	local liststyle = "LB"
	local pre = false
	
	local function flush()
		importer:flushparagraph(style)
		style = "P"
	end
	
	local function flushword()
		importer:flushword(pre)
	end
	
	local function flushpre()
		flush()
		if pre then
			style = "PRE"
		end
	end

	local elements =
	{
		[" "] = flushword,
		["<p>"] = flush,
		["<br>"] = flushpre,
		["<br/>"] = flushpre,
		["</h1>"] = flush,
		["</h2>"] = flush,
		["</h3>"] = flush,
		["</h4>"] = flush,
		["<h1>"] = function() flush() style = "H1" end,
		["<h2>"] = function() flush() style = "H2" end,
		["<h3>"] = function() flush() style = "H3" end,
		["<h4>"] = function() flush() style = "H4" end,
		["<ol>"] = function() liststyle = "LN" end,
		["<ul>"] = function() liststyle = "LB" end,
		["<li>"] = function() flush() style = liststyle end,
		["<i>"] = function() importer:style_on(ITALIC) end,
		["</i>"] = function() importer:style_off(ITALIC) end,
		["<em>"] = function() importer:style_on(ITALIC) end,
		["</em>"] = function() importer:style_off(ITALIC) end,
		["<u>"] = function() importer:style_on(UNDERLINE) end,
		["</u>"] = function() importer:style_off(UNDERLINE) end,
		["<b>"] = function() importer:style_on(BOLD) end,
		["</b>"] = function() importer:style_off(BOLD) end,
		["<pre>"] = function() flush() style = "PRE" pre = true end,
		["</pre>"] = function() flush() pre = false end,
		["\n"] = function() if pre then flush() style = "PRE" else flushword() end end
	}
	
	-- Actually do the parsing.
	
	importer:reset()
	for t in tokens do
		local e = elements[t]
		if e then
			e()
		elseif string_find(t, "^<") then
			-- do nothing
		elseif string_find(t, "^&") then
			e = DecodeHTMLEntity(t)
			if e then
				importer:text(e)
			end
		else
			importer:text(t)
		end
	end
	flush()

	-- Remove the blank paragraph at the beginning of the document.
	
	if (#document > 1) then
		document:deleteParagraphAt(1)
	end
		
	return document
end

function Cmd.ImportHTMLFile(filename)
	return ImportFileWithUI(filename, "Import HTML File", Cmd.ImportHTMLFileFromStream)
end
