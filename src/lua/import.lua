-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL: $

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local bitand = wg.bitand
local bitor = wg.bitor
local bitxor = wg.bitxor
local bit = wg.bit
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat

function ParseStringIntoWords(s)
	local words = {}
	for w in s:gmatch("[^ \t\r\n]+") do
		words[#words + 1] = CreateWord(w)
	end
	if (#words == 0) then
		return {CreateWord()}
	end
	return words
end

-- Import helper functions. These functions build styled words and paragraphs.

local pbuffer
local wbuffer
local oldattr
local attr

local function reset()
	pbuffer = {}
	wbuffer = {}
	oldattr = 0
	attr = 0
end

local function style_on(a)
	attr = bitor(attr, a)
end

local function style_off(a)
	attr = bitxor(bitor(attr, a), a)
end

local function text(t)
	if (oldattr ~= attr) then
		wbuffer[#wbuffer + 1] = string_char(16 + attr)
		oldattr = attr
	end
	
	wbuffer[#wbuffer + 1] = t
end
 
local function flushword()
	if (#wbuffer > 0) then
		local s = table_concat(wbuffer)
		pbuffer[#pbuffer + 1] = CreateWord(s)
		wbuffer = {}
		oldattr = 0
	end
end

local function flushparagraph(document, style)
	style = style or "P"
	
	if (#wbuffer > 0) then
		flushword()
	end
	
	if (#pbuffer > 0) then
		local p = CreateParagraph(DocumentSet.styles[style], pbuffer)
		document:appendParagraph(p)
		
		pbuffer = {}
	end
end

-- The importers themselves.

local function loadtextfile(fp)
	local document = CreateDocument()
	for l in fp:lines() do
		local p = CreateParagraph(DocumentSet.styles["P"], ParseStringIntoWords(l))
		document:appendParagraph(p)
	end
	
	return document
end

local function loadhtmlfile(fp)
	local data = fp:read("*a")
	local pos = 1
	
	-- Collapse whitespace; this makes things far easier to parse.
	
	data = data:gsub("[ \t\n\r]+", " ")
	
	-- Collapse complex elements.
	
	data = data:gsub("< ?(%w+) ?[^>]*(/?)>", "<%1%2>")
	
	-- Helper function for reading tokens from the HTML stream.
	
	local len = data:len()
	local function tokens()
		if (pos >= len) then
			return nil
		end
		
		local s, e, t
		s, e = string_find(data, "^ ", pos)
		if s then pos = e+1 return " " end
		
		s, e, t = string_find(data, "^(<[^>]*>)", pos)
		if s then pos = e+1 return t:lower() end
		
		s, e, t = string_find(data, "^(&.-;)", pos)
		if s then pos = e+1 return t end
		
		s, e, t = string_find(data, "^([^ <\t\n\r]+)", pos)
		if s then pos = e+1 return t end
		
		t = string_sub(data, 1, 1)
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
	local style = "P"
	
	local function flush()
		flushparagraph(document, style)
		
		style = "P"
	end
	
	local elements =
	{
		[" "] = flushword,
		["<p>"] = flush,
		["<br>"] = flush,
		["<br/>"] = flush,
		["</h1>"] = flush,
		["</h2>"] = flush,
		["</h3>"] = flush,
		["</h4>"] = flush,
		["<h1>"] = function() flush() style = "H1" end,
		["<h2>"] = function() flush() style = "H2" end,
		["<h3>"] = function() flush() style = "H3" end,
		["<h4>"] = function() flush() style = "H4" end,
		["<i>"] = function() style_on(ITALIC) end,
		["</i>"] = function() style_off(ITALIC) end,
		["<u>"] = function() style_on(UNDERLINE) end,
		["</u>"] = function() style_off(UNDERLINE) end,
		["&amp;"] = "&",
		["&gt;"] = ">",
		["&lt;"] = "<",
		["&quot;"] = '"',
		["&acute;"] = "´",
		["&cedil;"] = "¸",
		["&circ;"] = "ˆ",
		["&macr;"] = "¯",
		["&middot;"] = "·",
		["&tilde;"] = "˜",
		["&uml;"] = "¨",
		["&Aacute;"] = "Á",
		["&aacute;"] = "á",
		["&Acirc;"] = "Â",
		["&acirc;"] = "â",
		["&AElig;"] = "Æ",
		["&aelig;"] = "æ",
		["&Agrave;"] = "À",
		["&agrave;"] = "à",
		["&Aring;"] = "Å",
		["&aring;"] = "å",
		["&Atilde;"] = "Ã",
		["&atilde;"] = "ã",
		["&Auml;"] = "Ä",
		["&auml;"] = "ä",
		["&Ccedil;"] = "Ç",
		["&ccedil;"] = "ç",
		["&Eacute;"] = "É",
		["&eacute;"] = "é",
		["&Ecirc;"] = "Ê",
		["&ecirc;"] = "ê",
		["&Egrave;"] = "È",
		["&egrave;"] = "è",
		["&ETH;"] = "Ð",
		["&eth;"] = "ð",
		["&Euml;"] = "Ë",
		["&euml;"] = "ë",
		["&Iacute;"] = "Í",
		["&iacute;"] = "í",
		["&Icirc;"] = "Î",
		["&icirc;"] = "î",
		["&Igrave;"] = "Ì",
		["&igrave;"] = "ì",
		["&Iuml;"] = "Ï",
		["&iuml;"] = "ï",
		["&Ntilde;"] = "Ñ",
		["&ntilde;"] = "ñ",
		["&Oacute;"] = "Ó",
		["&oacute;"] = "ó",
		["&Ocirc;"] = "Ô",
		["&ocirc;"] = "ô",
		["&OElig;"] = "Œ",
		["&oelig;"] = "œ",
		["&Ograve;"] = "Ò",
		["&ograve;"] = "ò",
		["&Oslash;"] = "Ø",
		["&oslash;"] = "ø",
		["&Otilde;"] = "Õ",
		["&otilde;"] = "õ",
		["&Ouml;"] = "Ö",
		["&ouml;"] = "ö",
		["&Scaron;"] = "Š",
		["&scaron;"] = "š",
		["&szlig;"] = "ß",
		["&THORN;"] = "Þ",
		["&thorn;"] = "þ",
		["&Uacute;"] = "Ú",
		["&uacute;"] = "ú",
		["&Ucirc;"] = "Û",
		["&ucirc;"] = "û",
		["&Ugrave;"] = "Ù",
		["&ugrave;"] = "ù",
		["&Uuml;"] = "Ü",
		["&uuml;"] = "ü",
		["&Yacute;"] = "Ý",
		["&yacute;"] = "ý",
		["&yuml;"] = "ÿ",
		["&Yuml;"] = "Ÿ",
		["&cent;"] = "¢",
		["&curren;"] = "¤",
		["&euro;"] = "€",
		["&pound;"] = "£",
		["&yen;"] = "¥",
		["&brvbar;"] = "¦",
		["&bull;"] = "•",
		["&copy;"] = "©",
		["&dagger;"] = "†",
		["&Dagger;"] = "‡",
		["&frasl;"] = "⁄",
		["&hellip;"] = "…",
		["&iexcl;"] = "¡",
		["&image;"] = "ℑ",
		["&iquest;"] = "¿",
		["&lrm;"] = "‎",
		["&mdash;"] = "—",
		["&ndash;"] = "–",
		["&not;"] = "¬",
		["&oline;"] = "‾",
		["&ordf;"] = "ª",
		["&ordm;"] = "º",
		["&para;"] = "¶",
		["&permil;"] = "‰",
		["&prime;"] = "′",
		["&Prime;"] = "″",
		["&real;"] = "ℜ",
		["&reg;"] = "®",
		["&rlm;"] = "‏",
		["&sect;"] = "§",
		["&shy;"] = "­",
		["&sup1;"] = "¹",
		["&trade;"] = "™",
		["&weierp;"] = "℘",
		["&bdquo;"] = "„",
		["&laquo;"] = "«",
		["&ldquo;"] = "“",
		["&lsaquo;"] = "‹",
		["&lsquo;"] = "‘",
		["&raquo;"] = "»",
		["&rdquo;"] = "”",
		["&rsaquo;"] = "›",
		["&rsquo;"] = "’",
		["&sbquo;"] = "‚",
		-- Some of these space constants are magic. Edit with care.
		["&emsp;"] = " ",
		["&ensp;"] = " ",
		["&nbsp;"] = " ",
		["&thinsp;"] = " ",
		["&zwj;"] = "‍",
		["&zwnj;"] = "‌",
		["&deg;"] = "°",
		["&divide;"] = "÷",
		["&frac12;"] = "½",
		["&frac14;"] = "¼",
		["&frac34;"] = "¾",
		["&ge;"] = "≥",
		["&le;"] = "≤",
		["&minus;"] = "−",
		["&sup2;"] = "²",
		["&sup3;"] = "³",
		["&times;"] = "×",
		["&alefsym;"] = "ℵ",
		["&and;"] = "∧",
		["&ang;"] = "∠",
		["&asymp;"] = "≈",
		["&cap;"] = "∩",
		["&cong;"] = "≅",
		["&cup;"] = "∪",
		["&empty;"] = "∅",
		["&equiv;"] = "≡",
		["&exist;"] = "∃",
		["&fnof;"] = "ƒ",
		["&forall;"] = "∀",
		["&infin;"] = "∞",
		["&int;"] = "∫",
		["&isin;"] = "∈",
		["&lang;"] = "〈",
		["&lceil;"] = "⌈",
		["&lfloor;"] = "⌊",
		["&lowast;"] = "∗",
		["&micro;"] = "µ",
		["&nabla;"] = "∇",
		["&ne;"] = "≠",
		["&ni;"] = "∋",
		["&notin;"] = "∉",
		["&nsub;"] = "⊄",
		["&oplus;"] = "⊕",
		["&or;"] = "∨",
		["&otimes;"] = "⊗",
		["&part;"] = "∂",
		["&perp;"] = "⊥",
		["&plusmn;"] = "±",
		["&prod;"] = "∏",
		["&prop;"] = "∝",
		["&radic;"] = "√",
		["&rang;"] = "〉",
		["&rceil;"] = "⌉",
		["&rfloor;"] = "⌋",
		["&sdot;"] = "⋅",
		["&sim;"] = "∼",
		["&sub;"] = "⊂",
		["&sube;"] = "⊆",
		["&sum;"] = "∑",
		["&sup;"] = "⊃",
		["&supe;"] = "⊇",
		["&there4;"] = "∴",
		["&Alpha;"] = "Α",
		["&alpha;"] = "α",
		["&Beta;"] = "Β",
		["&beta;"] = "β",
		["&Chi;"] = "Χ",
		["&chi;"] = "χ",
		["&Delta;"] = "Δ",
		["&delta;"] = "δ",
		["&Epsilon;"] = "Ε",
		["&epsilon;"] = "ε",
		["&Eta;"] = "Η",
		["&eta;"] = "η",
		["&Gamma;"] = "Γ",
		["&gamma;"] = "γ",
		["&Iota;"] = "Ι",
		["&iota;"] = "ι",
		["&Kappa;"] = "Κ",
		["&kappa;"] = "κ",
		["&Lambda;"] = "Λ",
		["&lambda;"] = "λ",
		["&Mu;"] = "Μ",
		["&mu;"] = "μ",
		["&Nu;"] = "Ν",
		["&nu;"] = "ν",
		["&Omega;"] = "Ω",
		["&omega;"] = "ω",
		["&Omicron;"] = "Ο",
		["&omicron;"] = "ο",
		["&Phi;"] = "Φ",
		["&phi;"] = "φ",
		["&Pi;"] = "Π",
		["&pi;"] = "π",
		["&piv;"] = "ϖ",
		["&Psi;"] = "Ψ",
		["&psi;"] = "ψ",
		["&Rho;"] = "Ρ",
		["&rho;"] = "ρ",
		["&Sigma;"] = "Σ",
		["&sigma;"] = "σ",
		["&sigmaf;"] = "ς",
		["&Tau;"] = "Τ",
		["&tau;"] = "τ",
		["&Theta;"] = "Θ",
		["&theta;"] = "θ",
		["&thetasym;"] = "ϑ",
		["&upsih;"] = "ϒ",
		["&Upsilon;"] = "Υ",
		["&upsilon;"] = "υ",
		["&Xi;"] = "Ξ",
		["&xi;"] = "ξ",
		["&Zeta;"] = "Ζ",
		["&zeta;"] = "ζ",
		["&crarr;"] = "↵",
		["&darr;"] = "↓",
		["&dArr;"] = "⇓",
		["&harr;"] = "↔",
		["&hArr;"] = "⇔",
		["&larr;"] = "←",
		["&lArr;"] = "⇐",
		["&rarr;"] = "→",
		["&rArr;"] = "⇒",
		["&uarr;"] = "↑",
		["&uArr;"] = "⇑",
		["&clubs;"] = "♣",
		["&diams;"] = "♦",
		["&hearts;"] = "♥",
		["&spades;"] = "♠",
		["&loz;"] = "◊",
	}
	
	-- Actually do the parsing.
	
	reset()
	for t in tokens do
		local e = elements[t]
		if (type(e) == "string") then
			text(e)
		elseif e then
			e()
		elseif string_find(t, "^<") then
			-- do nothing
		elseif string_find(t, "^&.*;") then
			-- do nothing
		else
			text(t)
		end
	end
	flush()

	return document
end

-- Does the standard selector-box-and-progress UI for each importer.

local function generic_importer(filename, title, callback)
	if not filename then
		filename = FileBrowser(title, "Import from:", false)
		if not filename then
			return false
		end
	end
	
	ImmediateMessage("Importing...")	

	-- Actually import the file.
	
	local fp = io.open(filename)
	if not fp then
		return nil
	end
	
	local document = callback(fp)
	if not document then
		ModalMessage(nil, "The import failed, probably because the file could not be found.")
		QueueRedraw()
		return false
	end
		
	fp:close()
	
	-- All the importers produce a blank line at the beginning of the
	-- document (the default content made by CreateDocument()). Remove it.
	
	if (#document > 1) then
		document:deleteParagraphAt(1)
	end
	
	-- Add the document to the document set.
	
	filename = filename:gsub("%..-$", "")
	document.name = filename .. ".wg"

	if DocumentSet.documents[filename] then
		local id = 1
		while true do
			local f = filename.."-"..id
			if not DocumentSet.documents[f] then
				filename = f
				break
			end
		end
	end
	
	DocumentSet:addDocument(document, filename)
	DocumentSet:setCurrent(filename)

	QueueRedraw()
	return true
end

-- Front ends.

function Cmd.ImportTextFile(filename)
	return generic_importer(filename, "Import Text File", loadtextfile)
end

function Cmd.ImportHTMLFile(filename)
	return generic_importer(filename, "Import HTML File", loadhtmlfile)
end
