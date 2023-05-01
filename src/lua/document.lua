-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_remove = table.remove
local table_insert = table.insert
local table_concat = table.concat
local Write = wg.write
local WriteStyled = wg.writestyled
local ClearToEOL = wg.cleartoeol
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetWordText = wg.getwordtext
local BOLD = wg.BOLD
local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local REVERSE = wg.REVERSE
local BRIGHT = wg.BRIGHT
local DIM = wg.DIM

type DocumentStyle = {
	desc: string,
	name: string,
	above: number,
	below: number,
	indent: number?,
	bullet: string?,
	list: boolean?,
	firstindent: number?,
}

type DocumentStyles = {[number | string]: DocumentStyle}
DocumentStyles = {} :: DocumentStyles

type DocumentClassFields = {
	[number]: Paragraph,

	name: string,

	cp: number,
	cw: number,
	co: number,

	mp: number,
	mw: number,
	mo: number,
}

local stylemarkup =
{
	["H1"] = ITALIC + BRIGHT + BOLD + UNDERLINE,
	["H2"] = BRIGHT + BOLD + UNDERLINE,
	["H3"] = ITALIC + BRIGHT + BOLD,
	["H4"] = BRIGHT + BOLD
}

DocumentClass =
{
	cursor = function(self: Document)
		return { self.cp, self.cw, self.co }
	end,

	appendParagraph = function(self: Document, p)
		self[#self+1] = p
	end,

	insertParagraphBefore = function(self: Document, paragraph, pn)
		table.insert(self, pn, paragraph)
	end,

	deleteParagraphAt = function(self: Document, pn)
		table.remove(self, pn)
	end,

	wrap = function(self: Document, width)
		self.wrapwidth = width
	end,

	getMarks = function(self: Document)
		if not self.mp then
			return
		end

		local mp1 = self.mp
		local mw1 = self.mw
		local mo1 = self.mo
		local mp2 = self.cp
		local mw2 = self.cw
		local mo2 = self.co

		if (mp1 > mp2) or
		   ((mp1 == mp2) and
		       ((mw1 > mw2) or ((mw1 == mw2) and (mo1 > mo2)))
		   ) then
			return mp2, mw2, mo2, mp1, mw1, mo1
		end

		return mp1, mw1, mo1, mp2, mw2, mo2
	end,

	-- remove any cached data prior to saving
	purge = function(self: Document)
		for _, paragraph in ipairs(self) do
			paragraph:touch()
		end

		self.topp = nil
		self.topw = nil
		self.botp = nil
		self.botw = nil
		self.wrapwidth = nil

		-- These should no longer exist; this dates from a previous attempt
		-- at undo with file version 6. We're not storing the undo buffer
		-- in files any more.
		self.undostack = nil
		self.redostack = nil
	end,

	-- calculate space above this paragraph
	spaceAbove = function(self, pn)
		local paragraph = self[pn]
		local paragraphabove = self[pn - 1]

		local sa = DocumentStyles[paragraph.style].above or 0 -- FIXME
		local sb = 0
		if paragraphabove then
			sb = DocumentStyles[paragraphabove.style].below or 0 -- FIXME
		end

		if (sa > sb) then
			return sa
		else
			return sb
		end
	end,

	-- calculate space below this paragraph
	spaceBelow = function(self, pn)
		local paragraph = self[pn]
		local paragraphbelow = self[pn + 1]

		local sb = DocumentStyles[paragraph.style].below or 0 -- FIXME
		local sa = 0
		if paragraphbelow then
			sa = DocumentStyles[paragraphbelow.style].above or 0 -- FIXME
		end

		if (sa > sb) then
			return sa
		else
			return sb
		end
	end,

	touch = function(self)
		FireEvent(Event.DocumentModified, self)
	end,

	renumber = function(self)
		local wc = 0
		local pn = 1

		for _, p in ipairs(self) do
			wc = wc + #p

			local style = DocumentStyles[p.style]
			if style.numbered then
				p.number = pn
				pn = pn + 1
			elseif not style.list then
				pn = 1
			end
		end

		self.wordcount = wc
	end
}

type Document = typeof(setmetatable(
		{} :: DocumentClassFields, {__index = DocumentClass}))
Document = {} :: Document

-- Returns how many screen spaces a portion of a string takes up.
function GetWidthFromOffset(s, o)
	return GetStringWidth(s:sub(1, o-1))
end

-- Returns the offset into a string needed for a screen width.
function GetOffsetFromWidth(s, x)
		local len = #s
		local o = 1
		while (o <= len) do
			if (x == 0) then
				return o
			end

			local charlen = GetBytesOfCharacter(string.byte(s, o))
			local char = s:sub(o, o+charlen-1)
			local ww = GetStringWidth(char)
			if (ww > x) then
				return o
			end

			x = x - ww
			o = o + charlen
		end

		return len + 1
end

function GetWordSimpleText(s: string): string
	s = GetWordText(s)
	s = UnSmartquotify(s)
	s = s:gsub('[~#&^$"<>]+', "")
	s = s:gsub("^[.'([{]+", "")
	s = s:gsub("[',.!?:;)%]}]+$", "")
	return s
end

function OnlyFirstCharIsUppercase(s: string): boolean
    -- Return true if only first character is uppercase
    local first_char = s:sub(0, 1)
    if first_char:upper() == first_char then
        local remaining_chars = s:sub(2, s:len())
        if remaining_chars:lower() == remaining_chars then
            return true
        end
    end
    return false
end

function UpdateDocumentStyles()
	local plaintext =
	{
		desc = "Plain text",
		name = "P",
	}

	if WantDenseParagraphLayout() then
		plaintext.above = 0
		plaintext.below = 0
		plaintext.firstindent = 4
	else
		plaintext.above = 1
		plaintext.below = 1
		plaintext.firstindent = 0
	end

	local styles: {[number|string]: DocumentStyle} =
	{
		plaintext,
		{
			desc = "Heading #1",
			name = "H1",
			above = 3,
			below = 1,
		},
		{
			desc = "Heading #2",
			name = "H2",
			above = 2,
			below = 1,
		},
		{
			desc = "Heading #3",
			name = "H3",
			above = 1,
			below = 1,
		},
		{
			desc = "Heading #4",
			name = "H4",
			above = 1,
			below = 1,
		},
		{
			desc = "Indented text",
			name = "Q",
			indent = 4,
			above = 1,
			below = 1,
		},
		{
			desc = "List item with bullet",
			name = "LB",
			above = 1,
			below = 1,
			indent = 4,
			bullet = "-",
			list = true,
		},
		{
			desc = "List item with number",
			name = "LN",
			above = 1,
			below = 1,
			indent = 4,
			numbered = true,
			list = true,
		},
		{
			desc = "List item without bullet",
			name = "L",
			above = 1,
			below = 1,
			indent = 4,
			list = true,
		},
		{
			desc = "Indented text, run together",
			name = "V",
			indent = 4,
			above = 0,
			below = 0
		},
		{
			desc = "Preformatted text",
			name = "PRE",
			indent = 4,
			above = 0,
			below = 0
		},
		{
			desc = "Raw data exported to output file",
			name = "RAW",
			indent = 0,
			above = 0,
			below = 0
		}
	}

	for _, s in ipairs(styles) do
		styles[s.name] = s
	end

	DocumentStyles = styles
end

function CreateDocument(): Document
	local d =
	{
		wrapwidth = nil,
		viewmode = 1,
		margin = 0,
		cp = 1,
		cw = 1,
		co = 1,
	}

	setmetatable(d, {__index = DocumentClass})

	local p = CreateParagraph("P", {""})
	d:appendParagraph(p)
	return d
end

