-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetStringWidth = wg.getstringwidth
local NextCharInWord = wg.nextcharinword
local PrevCharInWord = wg.prevcharinword
local InsertIntoWord = wg.insertintoword
local DeleteFromWord = wg.deletefromword
local ApplyStyleToWord = wg.applystyletoword
local GetStyleFromWord = wg.getstylefromword
local CreateStyleByte = wg.createstylebyte
local ReadU8 = wg.readu8
local WriteU8 = wg.writeu8
local table_concat = table.concat
local unpack = unpack or table.unpack

function Cmd.GotoBeginningOfWord()
	Document.co = 1
	QueueRedraw()
	return true
end

function Cmd.GotoEndOfWord()
	Document.co = #Document[Document.cp][Document.cw] + 1
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
	local co = PrevCharInWord(word, Document.co)
	if not co then
		return false
	end
	
	Document.co = co

	QueueRedraw()
	return true
end

function Cmd.GotoNextChar()
	local word = Document[Document.cp][Document.cw]
	local co = NextCharInWord(word, Document.co)
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
	
	local s, co = InsertIntoWord(word, c, Document.co, GetCurrentStyleHint())
	if not co then
		return false
	end
	
	local payload =
	{
		word = s,
		wn = Document.cw,
		paragraph = paragraph
	}
	FireEvent(Event.WordModified, payload)
	local news = payload.word

	paragraph[Document.cw] = news
	Document.co = co + (#news - #s)
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
	local cw = Document.cw
	local co = Document.co
	local word = paragraph[cw]
	local styleprime = ""

	if not Document.mp then
		local stylehint = GetCurrentStyleHint()
		-- This is a bit evil. We want to prime the new word with the current
		-- style hint, so that when the cursor moves we don't lose the user's
		-- style hint in favour of the one read from the old word, which will
		-- be stale.
		--
		-- However, we don't want to insert any actual *text* in the new style.
		-- This means that the frameworks we have for applying style won't
		-- work. Instead, we exploit our knowledge of how the style bytes
		-- are implemented to do it manually.
		
		styleprime = CreateStyleByte(stylehint)
	end

	local left = DeleteFromWord(word, co, #word+1)
	local right = DeleteFromWord(word, 1, co)

	paragraph[cw] = styleprime .. right
	paragraph:insertWordBefore(cw, left)

	Document.cw = cw + 1
	Document.co = 1 + #styleprime
	
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
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local paragraph = Document[cp]

	if (cw == #paragraph) then
		if not Cmd.JoinWithNextParagraph() then
			return false
		end
	end

	if (cw ~= #paragraph) then
		Document[cp] = CreateParagraph(paragraph.style,
			paragraph:sub(1, cw-1),
			{(InsertIntoWord(paragraph[cw+1], paragraph[cw], 1, 0))},
			paragraph:sub(cw+2))
	end
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeletePreviousChar()
	return Cmd.GotoPreviousCharW() and Cmd.DeleteNextChar()
end

function Cmd.DeleteSelectionOrPreviousChar()
	if Document.mp then
		return Cmd.Delete()
	else
		return Cmd.DeletePreviousChar()
	end
end

function Cmd.DeleteNextChar()
	local paragraph = Document[Document.cp]
	local cw = Document.cw
	local co = Document.co
	local word = paragraph[cw]
	local nextco = NextCharInWord(word, co)
	if not nextco then
		return Cmd.JoinWithNextWord()
	end
	
	paragraph[cw] = DeleteFromWord(word, co, nextco)
	paragraph:touch()
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeleteSelectionOrNextChar()
	if Document.mp then
		return Cmd.Delete()
	else
		return Cmd.DeleteNextChar()
	end
end

function Cmd.DeleteWordLeftOfCursor()
	local paragraph = Document[Document.cp]
	local cw = Document.cw
	local co = Document.co

	paragraph[cw] = DeleteFromWord(paragraph[cw], 1, co)
	Document.co = 1
	paragraph:touch()
	
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeleteWord()
	if (Document.co == 1) and (Document.cw == 1) then
		return Cmd.DeletePreviousChar()
	end

	if (Document.co == 1) then
		Cmd.DeletePreviousChar()
	end
	return Cmd.DeleteWordLeftOfCursor()
end

function Cmd.SplitCurrentParagraph()
	if (Document.co == 1) and (Document.cw == 1) then
		-- Beginning of paragraph; we're going to create a new, empty paragraph
		-- so we need to split to make sure there's an empty word for it to
		-- contain.
		Cmd.SplitCurrentWord()
	elseif (Document.co > 1) then
		-- Otherwise, only split if we're not at the beginning of a word.
		Cmd.SplitCurrentWord()
	end
	
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

	pos = pos - (paragraph.style.indent or 0)
	if (pos < 0) then
		pos = 0
	end
	
	while (wn > 0) do
		if (paragraph.xs[wn] <= pos) then
			break
		end
		wn = wn - 1
	end
	
	if (wn == 0) then
		wn = 1
	end

	wo = GetOffsetFromWidth(paragraph[wn], pos - paragraph.xs[wn])
	
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
	x = x + GetWidthFromOffset(word, Document.co)
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
	["b"] = {wg.BOLD, 15},
	["u"] = {wg.UNDERLINE, 15},
	["i"] = {wg.ITALIC, 15},
	["o"] = {0, 0},
}

function Cmd.ApplyStyleToSelection(s)
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
		
		for wn = firstword, lastword do
			local word = paragraph[wn]
			
			local fo = 1
			local lo = #word + 1
			
			if (p == mp1) and (wn == mw1) then
				fo = mo1
			end
			
			if (p == mp2) and (wn == mw2) then
				lo = mo2
			end
			
			if (p == cp) and (wn == cw) then
				word, Document.co = ApplyStyleToWord(word, sor, sand, fo, lo, co)
			else
				word = ApplyStyleToWord(word, sor, sand, fo, lo, 0)
			end

			paragraph[wn] = word
		end
		
		paragraph:touch()
	end
	
	Cmd.UnsetMark()
	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.SetStyle(s)
	if Document.mp then
		return Cmd.ApplyStyleToSelection(s)
	end

	local sor, sand = unpack(style_tab[s])
	SetCurrentStyleHint(sor, sand)
	QueueRedraw()
	return true;
end

function GetStyleAtCursor()
	local cp = Document.cp
	local cw = Document.cw
	local co = Document.co

	return GetStyleFromWord(Document[cp][cw], co)
end

function GetStyleToLeftOfCursor()
	local cp = Document.cp
	local cw = Document.cw
	local co = Document.co

	if (co == 1) then
		if (cw == 1) then
			return 0
		end
		cw = cw - 1
		co = #Document[cp][cw]
	end

	return GetStyleFromWord(Document[cp][cw], co)
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
		Document.sticky_selection = false
	else
		Document.mp = Document.cp
		Document.mw = Document.cw
		Document.mo = Document.co
		Document.sticky_selection = true
	end
	
	QueueRedraw()
	return true
end

function Cmd.SetMark()
	if not Document.mp then
		Document.mp = Document.cp
		Document.mw = Document.cw
		Document.mo = Document.co
		Document.sticky_selection = false
	end
	return true
end

function Cmd.UnsetMark()
	Document.mp = nil
	Document.mw = nil
	Document.mo = nil
	
	QueueRedraw()
	return true
end

function Cmd.MoveWhileSelected()
	if Document.mp and not Document.sticky_selection then
		return Cmd.UnsetMark()
	end
	return true
end

function Cmd.TypeWhileSelected()
	if Document.mp then
		return Cmd.Delete()
	end
	return true
end

function Cmd.SelectWord()
	return Cmd.UnsetMark() and
		Cmd.GotoBeginningOfWord() and
		Cmd.SetMark() and
		Cmd.GotoEndOfWord()
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
	
	local paragraph
	if (mw1 > 1) then
		paragraph = buffer[1]
		buffer[1] = CreateParagraph(paragraph.style,
			paragraph:sub(mw1))
		if (mp1 == mp2) then
			mw2 = mw2 - mw1
		end
	end
	
	-- Remove any words in the last paragraph that weren't copied.
	
	paragraph = buffer[#buffer]
	if (mw2 < #paragraph) then
		buffer[#buffer] = CreateParagraph(paragraph.style,
			paragraph:sub(1, mw2))
	end
	
	-- Remove any characters in the leading word that weren't copied.
	
	paragraph = buffer[1]
	word = paragraph[1]
	if word then
		buffer[1] = CreateParagraph(paragraph.style,
			{DeleteFromWord(word, 1, mo1)},
			paragraph:sub(2))
		if (mp1 == mp2) and (mw1 == mw2) then
			mo2 = mo2 - mo1 + 1
		end
	end
	
	-- Remove any characters in the trailing word that weren't copied.
	
	paragraph = buffer[#buffer]
	word = paragraph[#paragraph]
	if word then
		buffer[#buffer] = CreateParagraph(paragraph.style,
			paragraph:sub(1, #paragraph-1),
			DeleteFromWord(word, mo2, word:len()+1))
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

	local newwords = {}
	for wn, word in ipairs(buffer[1]) do
		local payload = {
			word = word,
			wn = wn,
			paragraph = paragraph
		}
		FireEvent(Event.WordModified, payload)
		newwords[#newwords+1] = payload.word
	end

	Document[Document.cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw),
		newwords,
		paragraph:sub(cw+1))
	Document.cw = Document.cw + #newwords
	Document.co = 1
	
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
			local paragraph = buffer[p]:copy()
			Document:insertParagraphBefore(paragraph, Document.cp)
			for wn, word in ipairs(paragraph) do
				local payload =
				{
					word = word,
					wn = wn,
					paragraph = paragraph
				}
				FireEvent(Event.WordModified, payload)
				paragraph[wn] = payload.word
			end

			Document.cp = Document.cp + 1
			Document.cw = 1
			Document.co = 1
		end
	end
	
	-- Splice the last word of the section just pasted.
	
	NonmodalMessage("Clipboard copied to cursor position.")
	return Cmd.GotoBeginningOfWord() and Cmd.GotoPreviousCharW()
		and Cmd.JoinWithNextWord()
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
	return Cmd.GotoPreviousWordW() and
	       Cmd.GotoEndOfWord() and
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
		patterns[i] = "^%c*"..patterns[i].."%c*$"
	end
	
	if (#patterns > 1) then
		patterns[1] = patterns[1].."%c*$"
		patterns[#patterns] = "^%c*"..patterns[#patterns]
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
		local s, e = word:find(pattern, co)
		
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
				
				_, e = word:find(patterns[pi])
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
