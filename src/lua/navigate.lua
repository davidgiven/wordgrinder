-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local int = math.floor
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetStringWidth = wg.getstringwidth
local NextCharInWord = wg.nextcharinword
local PrevCharInWord = wg.prevcharinword
local InsertIntoWord = wg.insertintoword
local DeleteFromWord = wg.deletefromword
local ApplyStyleToWord = wg.applystyletoword
local ReadU8 = wg.readu8
local WriteU8 = wg.writeu8
local table_concat = table.concat

function Cmd.GotoBeginningOfWord()
	Document.co = 1
	QueueRedraw()
	return true
end

function Cmd.GotoEndOfWord()
	Document.co = Document[Document.cp][Document.cw].text:len() + 1
	QueueRedraw()
	return true
end

function Cmd.GotoBeginningOfParagraph()
	Document.cw = 1
	return Cmd.GotoBeginningOfWord()
end

function Cmd.GotoEndOfParagraph()
	Document.cw = #Document[Document.cp]
	return Cmd.GotoEndOfWord()
end

function Cmd.GotoBeginningOfDocument()
	Document.cp = 1
	return Cmd.GotoBeginningOfParagraph()
end

function Cmd.GotoEndOfDocument()
	Document.cp = #Document
	return Cmd.GotoEndOfParagraph()
end

function Cmd.GotoPreviousParagraph()
	if (Document.cp == 1) then
		QueueRedraw()
		return false
	end
	
	Document.cp = Document.cp - 1
	Document.cw = 1
	Document.co = 1

	QueueRedraw()
	return true
end
	
function Cmd.GotoNextParagraph()
	if (Document.cp == #Document) then
		QueueRedraw()
		return false
	end

	Document.cp = Document.cp + 1
	Document.cw = 1
	Document.co = 1

	QueueRedraw()
	return true
end
	
function Cmd.GotoPreviousParagraphW()
	return Cmd.GotoPreviousParagraph()
end

function Cmd.GotoNextParagraphW()
	return Cmd.GotoNextParagraph()
end

function Cmd.GotoPreviousWord()
	if (Document.cw == 1) then
		QueueRedraw()
		return false
	end
	
	Document.cw = Document.cw - 1
	Document.co = 1

	QueueRedraw()
	return true
end
	
function Cmd.GotoNextWord()
	local p = Document[Document.cp]
	if (Document.cw == #p) then
		QueueRedraw()
		return false
	end
	
	Document.cw = Document.cw + 1
	Document.co = 1

	QueueRedraw()
	return true
end

function Cmd.GotoPreviousWordW()
	if not Cmd.GotoPreviousWord() then
		return Cmd.GotoPreviousParagraphW() and Cmd.GotoEndOfParagraph()
	end
	return true
end

function Cmd.GotoNextWordW()
	if not Cmd.GotoNextWord() then
		return Cmd.GotoNextParagraphW() and Cmd.GotoBeginningOfParagraph()
	end
	return true
end

function Cmd.GotoPreviousChar()
	local word = Document[Document.cp][Document.cw]
	local co = PrevCharInWord(word.text, Document.co)
	if not co then
		return false
	end
	
	Document.co = co

	QueueRedraw()
	return true
end

function Cmd.GotoNextChar()
	local word = Document[Document.cp][Document.cw]
	local co = NextCharInWord(word.text, Document.co)
	if not co then
		return false
	end
	
	Document.co = co

	QueueRedraw()
	return true
end

function Cmd.GotoPreviousCharW()
	if not Cmd.GotoPreviousChar() then
		return Cmd.GotoPreviousWordW() and Cmd.GotoEndOfWord()
	end
	return true
end

function Cmd.GotoNextCharW()
	if not Cmd.GotoNextChar() then
		return Cmd.GotoNextWordW() and Cmd.GotoBeginningOfWord()
	end
	return true
end

function Cmd.InsertStringIntoWord(c)
	local paragraph = Document[Document.cp]
	local word = paragraph[Document.cw]
	
	local s, co = InsertIntoWord(word.text, c, Document.co)
	if not co then
		return false
	end
	
	word.text = s
	Document.co = co
	paragraph:touch()
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.InsertStringIntoParagraph(c)
	local first = true
	for word in c:gmatch("[^%s]+") do
		if not first then
			Cmd.SplitCurrentWord()
		end
		
		Cmd.InsertStringIntoWord(word)
		
		first = false
	end
	return true
end

function Cmd.SplitCurrentWord()
	local paragraph = Document[Document.cp]
	local word = paragraph[Document.cw]
	local text = word.text
	local co = Document.co
	
	local left = DeleteFromWord(text, co, text:len()+1)
	local newword = CreateWord(left)

	word.text = DeleteFromWord(text, 1, co)
	
	paragraph:insertWordBefore(Document.cw, newword)
	Document.cw = Document.cw + 1
	Document.co = 1
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.JoinWithNextParagraph()
	if (Document.cp == #Document) then
		return false
	end
	
	Document[Document.cp]:appendWords(Document[Document.cp+1])
	Document:deleteParagraphAt(Document.cp+1)
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.JoinWithNextWord()
	local paragraph = Document[Document.cp]
	local word = paragraph[Document.cw]

	if (Document.cw == #paragraph) then
		if not Cmd.JoinWithNextParagraph() then
			return false
		end
	end

	if (Document.cw ~= #paragraph) then
		word.text = InsertIntoWord(paragraph[Document.cw+1].text, word.text, 1)
		paragraph:deleteWordAt(Document.cw+1)
	end
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeletePreviousChar()
	return Cmd.GotoPreviousCharW() and Cmd.DeleteNextChar()
end

function Cmd.DeleteNextChar()
	local paragraph = Document[Document.cp]
	local word = paragraph[Document.cw]
	local co = Document.co
	local nextco = NextCharInWord(word.text, co)
	if not nextco then
		return Cmd.JoinWithNextWord()
	end
	
	word.text = DeleteFromWord(word.text, co, nextco)
	paragraph:touch()
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.SplitCurrentParagraph()
	Cmd.SplitCurrentWord()
	
	local p1, p2 = Document[Document.cp]:split(Document.cw)
	
	Document:deleteParagraphAt(Document.cp)
	Document:insertParagraphBefore(p2, Document.cp)
	Document:insertParagraphBefore(p1, Document.cp)
	Document.cp = Document.cp + 1
	Document.cw = 1
	Document.co = 1
	return true
end

function Cmd.GotoXPosition(pos)
	local paragraph = Document[Document.cp]
	local lines = paragraph:wrap()
	local ln = paragraph:getLineOfWord(Document.cw)
	
	local l = lines[ln]
	local wn = #l
	local word

	pos = pos - (paragraph.style.indent or 0)
	if (pos < 0) then
		pos = 0
	end
	
	while (wn > 0) do
		word = l[wn]
		
		if (word.x <= pos) then
			break
		end
		wn = wn - 1
	end
	
	if (wn == 0) then
		wn = 1
	end

	wo = word:getByteOfChar(pos - word.x) 
	
	Document.cw = paragraph:getWordOfLine(ln) + wn - 1
	Document.co = wo

	QueueRedraw()
	return false
end

local function getpos()
	local paragraph = Document[Document.cp]
	local lines = paragraph:wrap()
	local cw = Document.cw
	local word = paragraph[cw]
	local x, ln, wn = paragraph:getXOffsetOfWord(cw)
	x = x + word:getXOffsetOfChar(Document.co)
	x = x + (paragraph.style.indent or 0)

	return x, ln, lines
end

function Cmd.GotoNextLine()
	local x, ln, lines = getpos()

	if (ln == #lines) then
		return Cmd.GotoNextParagraph() and
		       Cmd.GotoBeginningOfParagraph() and
		       Cmd.GotoXPosition(x)
	end
	
	Document.cw = Document[Document.cp]:getWordOfLine(ln + 1)
	return Cmd.GotoXPosition(x)
end

function Cmd.GotoPreviousLine()
	local x, ln, lines = getpos()

	if (ln == 1) then
		return Cmd.GotoPreviousParagraph() and
		       Cmd.GotoEndOfParagraph() and
		       Cmd.GotoXPosition(x)
	end
	
	Document.cw = Document[Document.cp]:getWordOfLine(ln - 1)
	return Cmd.GotoXPosition(x)
end

function Cmd.GotoBeginningOfLine()
	return Cmd.GotoXPosition(0)
end

function Cmd.GotoEndOfLine()
	return Cmd.GotoXPosition(ScreenWidth)
end

function Cmd.GotoPreviousPage()
	if Document.topp and Document.topw then
		local x, _, _ = getpos()
		Document.cp = Document.topp
		Document.cw = Document.topw
		Document.co = 1
		return Cmd.GotoXPosition(x)
	end
	return false
end

function Cmd.GotoNextPage()
	if Document.botp and Document.botw then
		local x, _, _ = getpos()
		Document.cp = Document.botp
		Document.cw = Document.botw
		Document.co = 1
		return Cmd.GotoXPosition(x)
	end
	return false
end

local style_tab =
{
	["u"] = {2, 15},
	["i"] = {1, 15},
	["o"] = {0, 0},
}

function Cmd.ToggleStyle(s)
	if not Document.mp then
		return false
	end
	
	local mp1, mw1, mo1, mp2, mw2, mo2 = Document:getMarks()
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local sor, sand = unpack(style_tab[s])
	
	for p = mp1, mp2 do
		local paragraph = Document[p]
		local firstword = 1
		local lastword = #paragraph
		
		if (p == mp1) then
			firstword = mw1
		end
		if (p == mp2) then
			lastword = mw2
		end
		
		for w = firstword, lastword do
			local word = paragraph[w]
			
			local fo = 1
			local lo = word.text:len() + 1
			
			if (p == mp1) and (w == mw1) then
				fo = mo1
			end
			
			if (p == mp2) and (w == mw2) then
				lo = mo2
			end
			
			if (p == cp) and (w == cw) then
				word.text, Document.co = ApplyStyleToWord(word.text, sor, sand, fo, lo, co)
			else
				word.text = ApplyStyleToWord(word.text, sor, sand, fo, lo, 0)
			end
		end
		
		paragraph:touch()
	end
	
	Cmd.UnsetMark()
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.ActivateMenu(menu)
	DocumentSet.menu:activate(menu)
	ResizeScreen()
	QueueRedraw()
	return true
end

--- Checks that it's all right to erase the current document set.
-- If the current document set has unsaved modifications, asks the user
-- for permission to erase them.
--
-- @return                   true if it's all right to go ahead, false to cancel

function ConfirmDocumentErasure()
	if DocumentSet.changed then
		if not PromptForYesNo("Document set not saved!", "Some of the documents in this document set contain unsaved edits. Are you sure you want to discard them, without saving first?") then
			return false
		end
	end
	return true
end

function Cmd.TerminateProgram()
	if ConfirmDocumentErasure() then
		os.exit()
	end
	
	return false
end

function Cmd.CreateBlankDocumentSet()
	if ConfirmDocumentErasure() then
		ResetDocumentSet()
		QueueRedraw()
		return true
	end
	
	return false
end

local function styles()
	local s = {}
	for _, style in pairs(DocumentSet.styles) do
		s[#s+1] = style.name .. " (HTML: " .. style.html ..")"
	end
	return s
end
	
function Cmd.ChangeParagraphStyle(style)
	local paragraph = Document[Document.cp]
	if not style then
		-- style = PromptForString("Change paragraph style", "Please enter the new paragraph style:", paragraph.style.name)
		style = Browser("Change paragraph style", "Please select the new paragraph style from the list, or enter a style name:", "Style:", styles())
		
	end
	if not style then
		return false
	end
	
	style = DocumentSet.styles[style]
	if not style then
		ModalMessage("Unknown paragraph style", "Sorry! I don't recognise that style. (This user interface will be improved.)")
		return false
	end

	if Document.mp then	
		local mp1, _, _, mp2, _, _ = Document:getMarks()
		
		for p = mp1, mp2 do
			Document[p]:changeStyle(style)
		end
	else
		paragraph:changeStyle(style)
	end
	
	DocumentSet:touch()
	QueueRedraw()
	return Cmd.UnsetMark()
end

function Cmd.ToggleMark()
	if Document.mp then
		Document.mp = nil
		Document.mw = nil
		Document.mo = nil
	else
		Document.mp = Document.cp
		Document.mw = Document.cw
		Document.mo = Document.co
	end
	
	QueueRedraw()
	return true
end

function Cmd.UnsetMark()
	Document.mp = nil
	Document.mw = nil
	Document.mo = nil
	
	QueueRedraw()
	return true
end

function Cmd.ChangeDocument(name)
	if not DocumentSet:findDocument(name) then
		return false
	end
	
	DocumentSet:setCurrent(name)
	QueueRedraw()
	return true
end

function Cmd.Cut()
	return Cmd.Copy(true) and Cmd.Delete()
end

function Cmd.Copy(keepselection)
	if not Document.mp then
		return false
	end
	
	local mp1, mw1, mo1, mp2, mw2, mo2 = Document:getMarks()
	local buffer = CreateDocument()
	DocumentSet:setClipboard(buffer)
	
	-- Copy all the paragraphs from the selected area into the clipboard.
	
	for p = mp1, mp2 do
		local paragraph = Document[p]

		buffer:appendParagraph(paragraph:copy())
	end
	
	-- Remove the default content of the clipboard document.
	
	buffer:deleteParagraphAt(1)
	
	-- Remove any words in the first paragraph that weren't copied.
	
	local paragraph = buffer[1]
	while (mw1 > 1) do
		paragraph:deleteWordAt(1)
		mw1 = mw1 - 1
		if (mp1 == mp2) then
			mw2 = mw2 - 1
		end
	end
	
	-- Remove any words in the last paragraph that weren't copied.
	
	paragraph = buffer[#buffer]
	while (mw2 < #paragraph) do
		paragraph:deleteWordAt(#paragraph)
	end
	
	-- Remove any characters in the leading word that weren't copied.
	
	paragraph = buffer[1]
	word = paragraph[1]
	if word then
		word.text = DeleteFromWord(word.text, 1, mo1)
		if (mp1 == mp2) and (mw1 == mw2) then
			mo2 = mo2 - mo1 + 1
		end
	end
	
	-- Remove any characters in the trailing word that weren't copied.
	
	paragraph = buffer[#buffer]
	word = paragraph[#paragraph]
	if word then
		word.text = DeleteFromWord(word.text, mo2, word.text:len()+1)
	end
	
	NonmodalMessage("Selected area copied to clipboard.")
	if not keepselection then
		return Cmd.UnsetMark()
	else
		return true
	end
end

function Cmd.Paste()
	local buffer = DocumentSet:getClipboard()
	if not buffer then
		return false
	end
	if Document.mp then
		if not Cmd.Delete() then
			return false
		end
	end
	
	-- Insert the first paragraph of the clipboard into the current paragraph.
	
	local cw = Document.cw
	Cmd.SplitCurrentWord()
	local paragraph = Document[Document.cp]
	for _, word in ipairs(buffer[1]) do
		paragraph:insertWordBefore(Document.cw, word:copy())
		Document.cw = Document.cw + 1
	end
	
	-- Splice the first word of the section just pasted.
	
	do
		local ow = Document.cw
		Document.cw = cw
		Cmd.JoinWithNextWord()
		Document.cw = ow - 1
	end

	-- More than one paragraph?
	
	if (#buffer > 1) then	
		-- Copy any remaining paragraphs in whole.
		
		Cmd.SplitCurrentParagraph()
		
		local p = 2
		for p = 2, #buffer do	
			local copy = buffer[p]:copy()
			Document:insertParagraphBefore(copy, Document.cp)
			Document.cp = Document.cp + 1
			Document.cw = 1
			Document.co = 1
		end
	end
	
	-- Splice the last word of the section just pasted.
	
	NonmodalMessage("Clipboard copied to cursor position.")
	return Cmd.GotoPreviousCharW() and Cmd.JoinWithNextWord()
end

function Cmd.Delete()
	if not Document.mp then
		return false
	end
	
	local mp1, mw1, mo1, mp2, mw2, mo2 = Document:getMarks()
	
	-- Put the cursor at the end of the selection and split.
	
	Document.cp = mp2
	Document.cw = mw2
	Document.co = mo2
	if not Cmd.SplitCurrentParagraph() then
		return false
	end
	
	-- Put the cursor at the beginning of the selection and split.
	
	Document.cp = mp1
	Document.cw = mw1
	Document.co = mo1
	if not Cmd.SplitCurrentParagraph() then
		return false
	end
	
	-- We now have a whole number of paragraphs containing the area to delete.
	-- Delete them.
	
	for i = 1, (mp2 - mp1 + 1) do
		Document:deleteParagraphAt(Document.cp)
	end
	
	-- And merge the two areas together again.
	
	NonmodalMessage("Selected area deleted.")
	return Cmd.GotoPreviousCharW() and
	       Cmd.JoinWithNextWord() and
	       Cmd.UnsetMark()
end

function Cmd.Find(findtext, replacetext)
	if not findtext then
		findtext, replacetext = FindAndReplaceDialogue()
		if not findtext or (findtext == "") then
			return false
		end
	end

	-- Convert the search text into a pattern.
	
	local patterns = {}
	local words = SplitString(findtext, "%s")
	for _, w in ipairs(words) do
		-- w is a word from the pattern. We need to perform the following
		-- changes:
		--   - we need to insert %c* between all letters, to allow it to match
		--     control codes;
		--   - we want to  convert single letters like 'q' into '[qQ]' to make
		--     the pattern case insensitive;
		--   - we want to anchor internal word boundaries with ^ and $ to make
		--     them match whole words.
		-- This is done in several stages, for simplicity.
		
		local wp = {}
		local i = 1
		local len = w:len()
		while (i <= len) do
			local c = WriteU8(ReadU8(w, i)) 
			i = i + GetBytesOfCharacter(w:byte(i))

			if ((c >= "A") and (c <= "Z")) or
			    ((c >= "a") and (c <= "z")) then
				c = "["..c:upper()..c:lower().."]"
			end
			
			wp[#wp+1] = c
		end
		
		patterns[#patterns + 1] = table_concat(wp, "%c*")
	end
	
	for i = 2, (#patterns - 1) do
		patterns[i] = "^"..patterns[i].."$"
	end
	
	if (#patterns > 1) then
		patterns[1] = patterns[1].."$"
		patterns[#patterns] = "^"..patterns[#patterns]
	end
	
	DocumentSet.findtext = patterns
	DocumentSet.replacetext = replacetext
	return Cmd.FindNext()	
end

function Cmd.FindNext()
	if not DocumentSet.findtext then
		return false
	end

	ImmediateMessage("Searching...")
	
	-- Start at the current cursor position.
	
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local patterns = DocumentSet.findtext
	if (#patterns == 0) then
		QueueRedraw()
		NonmodalMessage("Nothing to search for.")
		return false
	end
	
	local pattern = patterns[1]

	-- Keep looping until we reach the starting point again.
	
	while true do
		local word = Document[cp][cw]
		local s, e = word.text:find(pattern, co)
		
		if s then
			-- We got a match! First, though, check to see if the remaining
			-- words in the pattern match.
	
			local endword = cw
			local pi = 2
			local found = true
			while (pi <= #patterns) do
				endword = endword + 1
				
				word = Document[cp][endword]
				if not word then
					found = false
					break
				end
				
				_, e = word.text:find(patterns[pi])
				if not e then
					found = false
					break
				end
				
				pi = pi + 1
			end
			 
			if found then
				Document.cp = cp
				Document.cw = endword
				Document.co = e + 1
				Document.mp = Document.cp
				Document.mw = cw
				Document.mo = s
				NonmodalMessage("Found.")
				QueueRedraw()
				return true
			end
		end
	
		-- Nothing. Move on to the next word.
		
		co = 1
		cw = cw + 1
		if (cw > #Document[cp]) then
			cw = 1
			cp = cp + 1
			if (cp > #Document) then
				cp = 1
			end
		end
		
		-- Check to see if we've scanned everything.
		
		if (cp == Document.cp) and (cw == Document.cw) and (co == 1) then
			break
		end
	end
	
	QueueRedraw()
	NonmodalMessage("Not found.")
	return false
end

function Cmd.ReplaceThenFind()
	if Document.mp then
		local e = Cmd.Delete() and Cmd.UnsetMark()
		if not e then
			return false
		end
		
		e = true
		local words = SplitString(DocumentSet.replacetext, "%s")
		for i, w in ipairs(words) do
			if (i > 1) then
				i = Cmd.SplitCurrentWord()
			end
			
			e = e and Cmd.InsertStringIntoWord(w)
		end
		 
		if not e then
			return false
		end
		NonmodalMessage("Replaced text.")
	end
	
	return Cmd.FindNext()
end

function Cmd.ToggleStatusBar()
	if DocumentSet.statusbar then
		DocumentSet.statusbar = false
		NonmodalMessage("Status bar disabled.")
	else
		DocumentSet.statusbar = true
		NonmodalMessage("Status bar enabled.")
	end

	QueueRedraw()
	return true
end

function Cmd.AboutWordGrinder()
	AboutDialogue()
end
