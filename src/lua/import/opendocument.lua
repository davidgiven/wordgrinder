-- © 2008-2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local WriteU8 = wg.writeu8
local ReadFromZip = wg.readfromzip
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat

local OFFICE_NS = "urn:oasis:names:tc:opendocument:xmlns:office:1.0"
local STYLE_NS = "urn:oasis:names:tc:opendocument:xmlns:style:1.0"
local FO_NS = "urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"

-----------------------------------------------------------------------------
-- The importer itself.

local function loadhtmlfile(fp)
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
		["<li>"] = function() flush() style = "LB" end,
		["<i>"] = function() importer:style_on(ITALIC) end,
		["</i>"] = function() importer:style_off(ITALIC) end,
		["<em>"] = function() importer:style_on(ITALIC) end,
		["</em>"] = function() importer:style_off(ITALIC) end,
		["<u>"] = function() importer:style_on(UNDERLINE) end,
		["</u>"] = function() importer:style_off(UNDERLINE) end,
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

	return document
end

local function parse_style(styles, xml)
	local NAME = STYLE_NS .. " name"
	local FAMILY = STYLE_NS .. " family"
	local PARENT_NAME = STYLE_NS .. " parent-name"
	local TEXT_PROPERTIES = STYLE_NS .. " text-properties"
	local FONT_STYLE = FO_NS .. " font-style"
	local UNDERLINE_STYLE = STYLE_NS .. " underline-style"
	
	if (xml[FAMILY] ~= "text") then
		return
	end

	local name = xml[NAME]
	local style =
	{
		parent = xml[PARENT_NAME]
	}

	for _, element in ipairs(xml) do
		if (element._name == TEXT_PROPERTIES) then
			if (element[FONT_STYLE] == "italic") then
				style.italic = true
			end
			if (element[UNDERLINE_STYLE] == "solid") then
				style.underline = true
			end
		end
	end

	styles[name] = style
end

local function resolve_parent_styles(styles)
	local function recursively_fetch(name, attr)
		local style = styles[name]
		if style[attr] then
			return true
		end
		if style.parent then
			return recursively_fetch(style.parent, attr)
		end
		return nil
	end

	for k, v in pairs(styles) do
		v.italic = recursively_fetch(k, "italic")
		v.underline = recursively_fetch(k, "underline")
	end
end

local function collect_styles(styles, xml)
	local STYLES = OFFICE_NS .. " styles"
	local AUTOMATIC_STYLES = OFFICE_NS .. " automatic-styles"
	local STYLE = STYLE_NS .. " style"

	for _, element in ipairs(xml) do
		if (element._name == STYLES) or (element._name == AUTOMATIC_STYLES) then
			for _, element in ipairs(element) do
				if (element._name == STYLE) then
					parse_style(styles, element)
				end
			end
		end
	end
end

function Cmd.ImportODTFile(filename)
	if not filename then
		filename = FileBrowser("Import ODT File", "Import from:", false)
		if not filename then
			return false
		end
	end
	
	ImmediateMessage("Importing...")	

	-- Load the styles and content subdocuments.
	
	local stylesxml = ReadFromZip(filename, "styles.xml")
	local contentxml = ReadFromZip(filename, "content.xml")
	if not stylesxml or not contentxml then
		ModalMessage(nil, "The import failed, probably because the file could not be found.")
		QueueRedraw()
		return false
	end
		
	stylesxml = ParseXML(stylesxml)
	contentxml = ParseXML(contentxml)

	local styles = {}
	collect_styles(styles, stylesxml)
	collect_styles(styles, contentxml)
	resolve_parent_styles(styles)

	for k, v in pairs(styles) do
		print(k, v.italic, v.underline)
	end
	print("loaded")
--[[
	fp:close()
	
	-- All the importers produce a blank line at the beginning of the
	-- document (the default content made by CreateDocument()). Remove it.
	
	if (#document > 1) then
		document:deleteParagraphAt(1)
	end
	
	-- Add the document to the document set.
	
	local docname = Leafname(filename)

	if DocumentSet.documents[docname] then
		local id = 1
		while true do
			local f = docname.."-"..id
			if not DocumentSet.documents[f] then
				docname = f
				break
			end
		end
	end
	
	DocumentSet:addDocument(document, docname)
	DocumentSet:setCurrent(docname)

	QueueRedraw()
	return true
--]]
end

