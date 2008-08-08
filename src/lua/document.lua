-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local table_remove = table.remove
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

DocumentSetClass =
{
	-- remove any cached data prior to saving
	purge = function(self)
		for _, l in ipairs(self.documents) do
			l:purge()
		end
	end,
	
	touch = function(self)
		self.changed = true
		self.justchanged = true
	end,
	
	clean = function(self)
		self.changed = nil
		self.justchanged = nil
	end,
	
	_findDocument = function(self, name)
		for i, d in ipairs(self.documents) do
			if (d.name == name) then
				return i
			end
		end
		return nil
	end,
	
	findDocument = function(self, name)
		local document = self.documents[name]
		if not document then
			document = self.documents[self:_findDocument(name)]
			if document then
				ModalMessage("Document index inconsistency corrected",
					"Something freaky happened to '"..name.."'.")
				self.documents[name] = document
			end
		end
		return document
	end,
	
	addDocument = function(self, document, name)
		document.name = name
		
		local n = self:_findDocument(name) or (#self.documents + 1)
		self.documents[n] = document
		self.documents[name] = document
		if not self.current or (self.current.name == name) then
			self:setCurrent(name)
		end
		
		self:touch()
		RebuildDocumentsMenu(self.documents)
	end,
	
	deleteDocument = function(self, name)
		local n = self:_findDocument(name)
		if not n then
			return
		end
		
		table_remove(self.documents, n)
		self.documents[name] = nil
		
		self:touch()
		RebuildDocumentsMenu(self.documents)
		self:setCurrent(name)
	end,
	
	setCurrent = function(self, name)
		Document = self.documents[name]
		if not Document then
			Document = self.documents[1]
		end

		self:touch()
		self.current = Document
		ResizeScreen()
	end,
	
	renameDocument = function(self, oldname, newname)
		local d = self.documents[oldname]
		self.documents[oldname] = nil
		self.documents[newname] = d
		d.name = newname
		
		self:touch()
		RebuildDocumentsMenu(self.documents)
	end,
	
	setClipboard = function(self, clipboard)
		self.clipboard = clipboard
	end,
	
	getClipboard = function(self)
		return self.clipboard
	end,
}

DocumentClass =
{
	appendParagraph = function(self, p)
		self[#self+1] = p
	end,
	
	insertParagraphBefore = function(self, paragraph, pn)
		table.insert(self, pn, paragraph)
	end,
	
	deleteParagraphAt = function(self, pn)
		table.remove(self, pn)
	end,
	
	wrap = function(self, width)
		self.wrapwidth = width
	end,
	
	getMarks = function(self)
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
	purge = function(self)
		for _, l in ipairs(self) do
			l:touch()
		end
		self.topp = nil
		self.topw = nil
		self.botp = nil
		self.botw = nil
		self.wrapwidth = nil
	end,
	
	-- calculate space above this paragraph
	spaceAbove = function(self, pn)
		local paragraph = self[pn]
		local paragraphabove = self[pn - 1]
		
		local sa = paragraph.style.above or 0 -- FIXME
		local sb = 0
		if paragraphabove then
			sb = paragraphabove.style.below or 0 -- FIXME
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
		
		local sb = paragraph.style.below or 0 -- FIXME
		local sa = 0
		if paragraphbelow then
			sa = paragraphbelow.style.above or 0 -- FIXME
		end
		
		if (sa > sb) then
			return sa
		else
			return sb
		end
	end,
}

ParagraphClass =
{
	copy = function(self)
		local words = {}
		for _, w in ipairs(self) do
			words[#words+1] = w:copy()
		end
		
		return CreateParagraph(self.style, words)
	end,
	
	touch = function(self)
		self.lines = nil
		self.wrapwidth = nil
	end,
	
	wrap = function(self, width)
		width = width or Document.wrapwidth
		width = width - (self.style.indent or 0)
		
		if (self.wrapwidth ~= width) then
			local lines = {}
			local line = {wn = 1}
			local w = 0
			
			for wn, word in ipairs(self) do
				word.x = w
				local ww = word:getWidth()
				w = w + ww
				if (w >= width) then
					lines[#lines+1] = line
					line = {wn = wn}
					w = ww
					word.x = 0
				end
				
				line[#line+1] = word
			end
			
			if (#line > 0) then
				lines[#lines+1] = line
			end
			
			self.wrapwidth = width
			self.lines = lines
		end
		
		return self.lines
	end,

	renderLine = function(self, line, x, y)
		width = width or (ScreenWidth - x)

		local cstyle = self.style.cstyle
		local ostyle = 0
		for wn, w in ipairs(line) do
			local text = w.text
			
			ostyle = WriteStyled(x+w.x, y, text, ostyle, nil, nil, cstyle)
		end
	end,

	renderMarkedLine = function(self, line, x, y, width, pn)
		width = width or (ScreenWidth - x)
		marked = marked or false
		
		local lwn = line.wn		
		local mp1, mw1, mo1, mp2, mw2, mo2 = Document:getMarks()

		local cstyle = self.style.cstyle
		local ostyle = 0
		for wn, w in ipairs(line) do
			local s, e
			
			wn = lwn + wn - 1
			
			if (pn < mp1) or (pn > mp2) then
				s = nil
			elseif (pn > mp1) and (pn < mp2) then
				s = 1
			else
				if (pn == mp1) and (pn == mp2) then
					if (wn == mw1) and (wn == mw2) then
						s = mo1
						e = mo2
					elseif (wn == mw1) then
						s = mo1
					elseif (wn == mw2) then
						s = 1
						e = mo2
					elseif (wn > mw1) and (wn < mw2) then
						s = 1
					end
				elseif (pn == mp1) then
					if (wn > mw1) then
						s = 1
					elseif (wn == mw1) then
						s = mo1
					end
				else
					s = 1
					if (wn > mw2) then
						s = nil
					elseif (wn == mw2) then
						e = mo2
					end
				end
			end
			
			ostyle = WriteStyled(x+w.x, y, w.text, ostyle, s, e, cstyle)
		end
	end,

	-- returns: line number, word number in line
	getLineOfWord = function(self, wn)
		local lines = self:wrap()
		for ln, l in ipairs(lines) do
			if (wn <= #l) then
				return ln, wn
			end
			
			wn = wn - #l
		end
		
		return nil, nil
	end,
	
	-- returns: word number
	getWordOfLine = function(self, ln)
		local lines = self:wrap()
		return lines[ln].wn
	end,
	
	-- returns: X offset, line number, word number in line
	getXOffsetOfWord = function(self, wn)
		local lines = self:wrap()
		local x = self[wn].x
		local ln, wn = self:getLineOfWord(wn)
		return x, ln, wn
	end,
	
	deleteWordAt = function(self, pos)
		table.remove(self, pos)
		self:touch()
	end,
	
	insertWordBefore = function(self, pos, word)
		table.insert(self, pos, word)
		self:touch()
	end,
	
	appendWord = function(self, word)
		self[#self+1] = word
		self:touch()
	end,
	
	appendWords = function(self, words)
		for _, w in ipairs(words) do
			self:appendWord(w)
		end
		self:touch()
	end,
	
	split = function(self, wn)
		local p1 = CreateParagraph(self.style)
		local p2 = CreateParagraph(self.style)
		
		for i=1, wn-1 do
			p1:appendWord(self[i])
		end
		
		for i=wn, #self do
			p2:appendWord(self[i])
		end
		
		return p1, p2
	end,
	
	truncateAtWord = function(self, wn)
		while (self[wn]) do
			table.remove(self, wn)
		end
		self:touch()
	end,
	
	changeStyle = function(self, style)
		self.style = style
		self:touch()
	end,
	
	-- return an unstyled string containing the contents of the paragraph.
	asString = function(self)
		local s = {}
		for _, w in ipairs(self) do
			s[#s+1] = w:asString()
		end
		
		return table_concat(s, " ")
	end
}

WordClass =
{
	copy = function(self)
		return CreateWord(self.text)
	end,
			
	getWidth = function(self)
		return GetStringWidth(self.text) + 1
	end,
	
	-- converts byte offset to X position
	getXOffsetOfChar = function(self, o)
		return GetStringWidth(self.text:sub(1, o-1))
	end,
	
	-- converts X position to byte offset
	getByteOfChar = function(self, x)
		local text = self.text
		
		local len = text:len()
		local o = 1
		while (o <= len) do
			local charlen = GetBytesOfCharacter(string.byte(text, o))
			local char = text:sub(o, o+charlen-1)
			local ww = GetStringWidth(char)
			if (ww > x) then
				return o
			end
			
			x = x - ww
			o = o + charlen
		end
		
		return len + 1
	end,
	
	-- returns an unstyled string containing the word contents
	asString = function(self)
		return GetWordText(self.text)
	end,
}

local function create_styles()
	local styles =
	{
		{
			desc = "Plain text",
			name = "P",
			html = "P",
			above = 1,
			below = 1,
		},
		{
			desc = "Heading #1",
			name = "H1",
			html = "H1",
			cstyle = 3,
			above = 3,
			below = 1,
		},
		{
			desc = "Heading #2",
			name = "H2",
			html = "H2",
			cstyle = 3,
			above = 2,
			below = 1,
		},
		{
			desc = "Heading #3",
			name = "H3",
			html = "H3",
			cstyle = 1,
			above = 1,
			below = 1,
		},
		{
			desc = "Heading #4",
			name = "H4",
			html = "H4",
			cstyle = 1,
			above = 1,
			below = 1,
		},
		{
			desc = "Indented text",
			name = "Q",
			html = "BLOCKQUOTE",
			indent = 4,
			above = 1,
			below = 1,
		},
		{
			desc = "List item with bullet",
			name = "LB",
			html = "LI",
			cstyle = 0,
			above = 1,
			below = 1,
			indent = 4,
			bullet = "-",
		},
		{
			desc = "List item without bullet",
			name = "L",
			html = "LI",
			cstyle = 0,
			above = 1,
			below = 1,
			indent = 4,
		},
		{
			desc = "Indented text, run together",
			name = "V",
			html = "BLOCKQUOTE",
			indent = 4,
			above = 0,
			below = 0
		}
	}
	
	for _, s in ipairs(styles) do
		styles[s.name] = s
	end
	
	return styles
end
	
function CreateDocumentSet()
	local ds =
	{
		fileformat = FILEFORMAT,
		statusbar = true,
		idletime = 3,
		documents = {},
		styles = create_styles(),
		addons = {},
	}
	
	setmetatable(ds, {__index = DocumentSetClass})
	return ds
end

function CreateDocument()
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
	
	local p = CreateParagraph(DocumentSet.styles["P"], {CreateWord()})
	d:appendParagraph(p)
	return d
end

function CreateParagraph(style, words)
	words = words or {}
	words.style = style or DocumentSet.styles["P"]
	setmetatable(words, {__index = ParagraphClass})
	return words
end

function CreateWord(text)
	local w =
	{
		text = text or ""
	}
	
	setmetatable(w, {__index = WordClass})
	return w
end
