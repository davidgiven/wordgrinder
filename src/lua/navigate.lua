--!nonstrict
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
local P = M.P
local table_concat = table.concat
local unpack = rawget(_G, "unpack") or table.unpack

function Cmd.GotoBeginningOfWord()
	currentDocument.co = 1
	QueueRedraw()
	return true
end

function Cmd.GotoEndOfWord()
	currentDocument.co = #currentDocument[currentDocument.cp][currentDocument.cw] + 1
	QueueRedraw()
	return true
end

function Cmd.GotoBeginningOfParagraph()
	currentDocument.cw = 1
	return Cmd.GotoBeginningOfWord()
end

function Cmd.GotoEndOfParagraph()
	currentDocument.cw = #currentDocument[currentDocument.cp]
	return Cmd.GotoEndOfWord()
end

function Cmd.GotoBeginningOfDocument()
	currentDocument.cp = 1
	return Cmd.GotoBeginningOfParagraph()
end

function Cmd.GotoEndOfDocument()
	currentDocument.cp = #currentDocument
	return Cmd.GotoEndOfParagraph()
end

function Cmd.GotoPreviousParagraph()
	if (currentDocument.cp == 1) then
		QueueRedraw()
		return false
	end

	currentDocument.cp = currentDocument.cp - 1
	currentDocument.cw = 1
	currentDocument.co = 1

	QueueRedraw()
	return true
end

function Cmd.GotoNextParagraph()
	if (currentDocument.cp == #currentDocument) then
		QueueRedraw()
		return false
	end

	currentDocument.cp = currentDocument.cp + 1
	currentDocument.cw = 1
	currentDocument.co = 1

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
	if (currentDocument.cw == 1) then
		QueueRedraw()
		return false
	end

	if Cmd.GotoPreviousChar() then
		-- If that worked, we weren't at the beginning of the word.
		currentDocument.co = 1
	else
		currentDocument.cw = currentDocument.cw - 1
		currentDocument.co = 1
	end

	QueueRedraw()
	return true
end

function Cmd.GotoNextWord()
	local p = currentDocument[currentDocument.cp]
	if (currentDocument.cw == #p) then
		currentDocument.co = #(p[currentDocument.cw]) + 1
		QueueRedraw()
		return false
	end

	currentDocument.cw = currentDocument.cw + 1
	currentDocument.co = 1

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
	local word = currentDocument[currentDocument.cp][currentDocument.cw]
	local co = PrevCharInWord(word, currentDocument.co)
	if not co then
		return false
	else
		currentDocument.co = co

		QueueRedraw()
		return true
	end
end

function Cmd.GotoNextChar()
	local word = currentDocument[currentDocument.cp][currentDocument.cw]
	local co = NextCharInWord(word, currentDocument.co)
	if not co then
		return false
	else
		currentDocument.co = co

		QueueRedraw()
		return true
	end
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
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local paragraph = currentDocument[cp]
	local word = paragraph[cw]

	local s, co = InsertIntoWord(word, c, co, GetCurrentStyleHint())
	if not co then
		return false
	else
		currentDocument[cp] = CreateParagraph(paragraph.style,
			paragraph:sub(1, cw-1),
			s,
			paragraph:sub(cw+1))
		currentDocument.co = co

		documentSet:touch()
		QueueRedraw()
		return true
	end
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
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local styleprime = ""
	local styleprimelen = 0

	if not currentDocument.mp then
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
		--
		-- We *also* don't want to change the actual style of the text. So the
		-- prime code needs to be followed by an unprime code. The cursor will
		-- be placed between these. (As soon as the user types, all this
		-- insanity will be undone.)

		styleprime = CreateStyleByte(stylehint)
		if (stylehint ~= 0) then
			-- Only add this is needed to prevent stupid control code buildup.
			styleprime = styleprime .. CreateStyleByte(0)
		end
		styleprimelen = 1
	end

	local paragraph = currentDocument[cp]
	local word = paragraph[cw]
	local left = DeleteFromWord(word, co, #word+1)
	local right = DeleteFromWord(word, 1, co)

	currentDocument[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		left,
		styleprime..right,
		paragraph:sub(cw+1))

	currentDocument.cw = cw + 1
	currentDocument.co = 1 + styleprimelen -- yes, this means that co has a minimum of 2

	documentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.JoinWithNextParagraph()
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	if (cp == #currentDocument) then
		return false
	end

	currentDocument[cp] = CreateParagraph(currentDocument[cp].style,
		currentDocument[cp],
		currentDocument[cp+1])
	currentDocument:deleteParagraphAt(cp+1)

	documentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.JoinWithNextWord()
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local paragraph = currentDocument[cp]

	if (cw == #paragraph) then
		if not Cmd.JoinWithNextParagraph() then
			return false
		end
		paragraph = currentDocument[cp]
	end

	local word, co, _ = InsertIntoWord(paragraph[cw+1], paragraph[cw], 1, 0)
	if word and co then
		currentDocument.co = co
		currentDocument[cp] = CreateParagraph(paragraph.style,
			paragraph:sub(1, cw-1),
			word,
			paragraph:sub(cw+2))

		documentSet:touch()
		QueueRedraw()
		return true
	else
		return false
	end
end

function Cmd.DeletePreviousChar()
	return Cmd.GotoPreviousCharW() and Cmd.DeleteNextChar()
end

function Cmd.DeleteSelectionOrPreviousChar()
	if currentDocument.mp then
		return Cmd.Delete()
	else
		return Cmd.DeletePreviousChar()
	end
end

function Cmd.DeleteNextChar()
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local paragraph = currentDocument[cp]
	local word = paragraph[cw]
	local nextco = NextCharInWord(word, co)
	if not nextco then
		return Cmd.JoinWithNextWord()
	end
	assert(nextco)

	currentDocument[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		DeleteFromWord(word, co, nextco),
		paragraph:sub(cw+1))

	documentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeleteSelectionOrNextChar()
	if currentDocument.mp then
		return Cmd.Delete()
	else
		return Cmd.DeleteNextChar()
	end
end

function Cmd.DeleteWordLeftOfCursor()
	local cp = currentDocument.cp
	local cw = currentDocument.cw
	local co = currentDocument.co
	local paragraph = currentDocument[cp]
	local word = paragraph[cw]

	currentDocument[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		DeleteFromWord(word, 1, co),
		paragraph:sub(cw+1))
	currentDocument.co = 1

	documentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.DeleteWord()
	if (currentDocument.co == 1) and (currentDocument.cw == 1) then
		return Cmd.DeletePreviousChar()
	end

	if (currentDocument.co == 1) then
		Cmd.DeletePreviousChar()
	end

	Cmd.GotoEndOfWord()
	Cmd.DeleteWordLeftOfCursor()
	if currentDocument.cw ~= 1 then
		Cmd.DeletePreviousChar()
	end
	return true
end

function Cmd.SplitCurrentParagraph()
	if (currentDocument.co == 1) and (currentDocument.cw == 1) then
		-- Beginning of paragraph; we're going to create a new, empty paragraph
		-- so we need to split to make sure there's an empty word for it to
		-- contain.
		Cmd.SplitCurrentWord()
	elseif (currentDocument.co > 1) then
		-- Otherwise, only split if we're not at the beginning of a word.
		Cmd.SplitCurrentWord()
	else
		documentSet:touch()
		QueueRedraw()
	end

	local cp, cw = currentDocument.cp, currentDocument.cw
	local paragraph = currentDocument[cp]
	local p1 = CreateParagraph(paragraph.style, paragraph:sub(1, cw-1))
	local p2 = CreateParagraph(paragraph.style, paragraph:sub(cw))

	currentDocument[cp] = p2
	currentDocument:insertParagraphBefore(p1, cp)
	currentDocument.cp = currentDocument.cp + 1
	currentDocument.cw = 1
	currentDocument.co = 1
	QueueRedraw()
	return true
end

function Cmd.GotoXPosition(pos: number)
	local paragraph = currentDocument[currentDocument.cp]
	local wd = paragraph:wrap()
	wg.printerr(TableToString(wd))
	local ln = paragraph:getLineOfWord(currentDocument.cw)
	if not ln then
		return false
	end
	assert(ln)

	local line = wd.lines[ln]
	local wordofline = #line

	pos = pos - paragraph:getIndentOfLine(ln)
	if (pos < 0) then
		pos = 0
	end

	while (wordofline > 0) do
		if (wd.xs[line[wordofline]] <= pos) then
			break
		end
		wordofline = wordofline - 1
	end

	if (wordofline == 0) then
		wordofline = 1
	end

	local wn = line[wordofline]
	local word = paragraph[wn]
	local wordx = wd.xs[wn]
	local wo = GetOffsetFromWidth(word, pos - wordx)

	currentDocument.cw = paragraph:getWordOfLine(ln) + wordofline - 1
	currentDocument.co = wo

	QueueRedraw()
	return false
end

function Cmd.GotoXYPosition(x: number, y: number)
	local r = GetPositionOfLine(y)
	if r then
		currentDocument.cp = r.p
		currentDocument.cw = r.w
		return Cmd.GotoXPosition(x - r.x)
	end
	return false
end

local function getpos()
	local paragraph = currentDocument[currentDocument.cp]
	local wd = paragraph:wrap()
	local cw = currentDocument.cw
	local word = paragraph[cw]
	local x, ln, wn = paragraph:getXOffsetOfWord(cw)
	x = x + GetWidthFromOffset(word, currentDocument.co) + paragraph:getIndentOfLine(ln)

	return x, ln, wd.lines
end

function Cmd.GotoNextLine()
	local x, ln, lines = getpos()

	if (ln == #lines) then
		if (currentDocument.cp == #currentDocument) then
			return Cmd.GotoEndOfParagraph()
		end

		return Cmd.GotoNextParagraph() and
		       Cmd.GotoBeginningOfParagraph() and
		       Cmd.GotoXPosition(x)
	end

	currentDocument.cw = currentDocument[currentDocument.cp]:getWordOfLine(ln + 1)
	return Cmd.GotoXPosition(x)
end

function Cmd.GotoPreviousLine()
	local x, ln, lines = getpos()

	if (ln == 1) then
		if (currentDocument.cp == 1) then
			return Cmd.GotoBeginningOfParagraph()
		end

		return Cmd.GotoPreviousParagraph() and
		       Cmd.GotoEndOfParagraph() and
		       Cmd.GotoXPosition(x)
	end

	currentDocument.cw = currentDocument[currentDocument.cp]:getWordOfLine(ln - 1)
	return Cmd.GotoXPosition(x)
end

function Cmd.GotoBeginningOfLine()
	return Cmd.GotoXPosition(0)
end

function Cmd.GotoEndOfLine()
	return Cmd.GotoXPosition(ScreenWidth)
end

function Cmd.GotoPreviousPage()
	if currentDocument._topp and currentDocument._topw then
		local x, _, _ = getpos()
		currentDocument.cp = currentDocument._topp
		currentDocument.cw = currentDocument._topw
		currentDocument.co = 1
		return Cmd.GotoXPosition(x)
	end
	return false
end

function Cmd.GotoNextPage()
	if currentDocument._botp and currentDocument._botw then
		local x, _, _ = getpos()
		currentDocument.cp = currentDocument._botp
		currentDocument.cw = currentDocument._botw
		currentDocument.co = 1
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
	if not currentDocument.mp then
		return false
	end

	local mp1, mw1, mo1, mp2, mw2, mo2 = currentDocument:getMarks()
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local sor, sand = unpack(style_tab[s])

	for p = mp1, mp2 do
		local paragraph = currentDocument[p]
		local firstword = 1
		local lastword = #paragraph

		if (p == mp1) then
			firstword = mw1
		end
		if (p == mp2) then
			lastword = mw2
		end

		local words = {}
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
				word, currentDocument.co = ApplyStyleToWord(word, sor, sand, fo, lo, co)
			else
				word = ApplyStyleToWord(word, sor, sand, fo, lo, 0)
			end

			words[#words+1] = word
		end

		currentDocument[p] = CreateParagraph(paragraph.style,
			paragraph:sub(1, firstword-1),
			words,
			paragraph:sub(lastword+1))
	end

	Cmd.UnsetMark()
	documentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.SetStyle(s)
	if currentDocument.mp then
		return Cmd.ApplyStyleToSelection(s)
	end

	local sor, sand = unpack(style_tab[s])
	SetCurrentStyleHint(sor, sand)
	QueueRedraw()
	return true;
end

function GetStyleAtCursor()
	local cp = currentDocument.cp
	local cw = currentDocument.cw
	local co = currentDocument.co

	return GetStyleFromWord(currentDocument[cp][cw], co)
end

function GetStyleToLeftOfCursor()
	local cp = currentDocument.cp
	local cw = currentDocument.cw
	local co = currentDocument.co

	if (co == 1) then
		if (cw == 1) then
			return 0
		end
		cw = cw - 1
		co = #currentDocument[cp][cw]
	end

	return GetStyleFromWord(currentDocument[cp][cw], co)
end

function Cmd.ActivateMenu(menu)
	documentSet.menu:activate(menu)
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
	if documentSet._changed then
		if not PromptForYesNo("currentDocument set not saved!", "Some of the documents in this document set contain unsaved edits. Are you sure you want to discard them, without saving first?") then
			return false
		end
	end
	return true
end

function Cmd.TerminateProgram()
	if ConfirmDocumentErasure() then
		wg.exit(0)
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

function Cmd.ChangeParagraphStyle(style)
	if not documentStyles[style] then
		ModalMessage("Unknown paragraph style", "Sorry! I don't recognise that style. (This user interface will be improved.)")
		return false
	end

	local first, last
	if currentDocument.mp then
		local _
		first, _, _, last, _, _ = currentDocument:getMarks()
	else
		first = currentDocument.cp
		last = first
	end

	for p = first, last do
		currentDocument[p] = CreateParagraph(style, currentDocument[p])
	end

	documentSet:touch()
	QueueRedraw()
	return Cmd.UnsetMark()
end

local function rewind_past_style_bytes(p: number, w: number, o: number)
	local word = currentDocument[p][w]
	local no = PrevCharInWord(word, o)
	if no then
		return NextCharInWord(word, no)
	else
		return 1
	end
end


function Cmd.ToggleMark()
	if currentDocument.mp then
		currentDocument.mp = nil
		currentDocument.mw = nil
		currentDocument.mo = nil
		currentDocument.sticky_selection = false
	else
		currentDocument.mp = currentDocument.cp
		currentDocument.mw = currentDocument.cw
		currentDocument.mo = rewind_past_style_bytes(currentDocument.cp, currentDocument.cw, currentDocument.co)
		currentDocument.sticky_selection = true
	end

	QueueRedraw()
	return true
end

function Cmd.SetMark()
	if not currentDocument.mp then
		currentDocument.mp = currentDocument.cp
		currentDocument.mw = currentDocument.cw
		currentDocument.mo = rewind_past_style_bytes(currentDocument.cp, currentDocument.cw, currentDocument.co)
		currentDocument.sticky_selection = false
	end
	return true
end

function Cmd.UnsetMark()
	currentDocument.mp = nil
	currentDocument.mw = nil
	currentDocument.mo = nil

	QueueRedraw()
	return true
end

function Cmd.MoveWhileSelected()
	if currentDocument.mp and not currentDocument.sticky_selection then
		return Cmd.UnsetMark()
	end
	return true
end

function Cmd.TypeWhileSelected()
	if currentDocument.mp and not currentDocument.sticky_selection then
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
	if not documentSet:findDocument(name) then
		return false
	end

	documentSet:setCurrent(name)
	QueueRedraw()
	return true
end

function Cmd.Cut()
	return Cmd.Copy(true) and Cmd.Delete()
end

function Cmd.Copy(keepselection: boolean?)
	if not currentDocument.mp then
		return false
	end

	local mp1, mw1, mo1, mp2, mw2, mo2 = currentDocument:getMarks()
	local buffer = CreateDocument()

	-- Copy all the paragraphs from the selected area into the clipboard.

	for p = mp1, mp2 do
		local paragraph = currentDocument[p]

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
			mw2 = mw2 - mw1 + 1
		end
		mw1 = 1
	end

	-- Remove any words in the last paragraph that weren't copied.

	paragraph = buffer[#buffer]
	if (mw2 < #paragraph) then
		buffer[#buffer] = CreateParagraph(paragraph.style,
			paragraph:sub(1, mw2))
	end

	-- Remove any characters in the trailing word that weren't copied.

	paragraph = buffer[#buffer]
	local word = paragraph[#paragraph]
	if word then
		buffer[#buffer] = CreateParagraph(paragraph.style,
			paragraph:sub(1, #paragraph-1),
			DeleteFromWord(word, mo2, word:len()+1))
	end

	-- Remove any characters in the leading word that weren't copied.

	paragraph = buffer[1]
	local word = paragraph[1]
	if word then
		buffer[1] = CreateParagraph(paragraph.style,
			{DeleteFromWord(word, 1, mo1)},
			paragraph:sub(2))
	end

	buffer:renumber()
	SetClipboard(buffer)

	NonmodalMessage(buffer.wordcount.." words copied to clipboard.")
	if not keepselection then
		return Cmd.UnsetMark()
	else
		return true
	end
end

function Cmd.Paste()
	local buffer = GetClipboard()
	if not buffer then
		return false
	end
	if currentDocument.mp then
		if not Cmd.Delete() then
			return false
		end
	end

	-- Insert the first paragraph of the clipboard into the current paragraph.

	local cw = currentDocument.cw
	Cmd.SplitCurrentWord()
	local paragraph = currentDocument[currentDocument.cp]

	currentDocument[currentDocument.cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw),
		buffer[1],
		paragraph:sub(cw+1))
	currentDocument.cw = currentDocument.cw + #buffer[1]
	currentDocument.co = 1

	-- Splice the first word of the section just pasted.

	do
		local ow = currentDocument.cw
		currentDocument.cw = cw
		Cmd.JoinWithNextWord()
		currentDocument.cw = ow - 1
	end

	-- More than one paragraph?

	if (#buffer > 1) then
		-- Copy any remaining paragraphs in whole.

		Cmd.SplitCurrentParagraph()

		local p = 2
		for p = 2, #buffer do
			local paragraph = buffer[p]
			currentDocument:insertParagraphBefore(
				CreateParagraph(paragraph.style, paragraph),
				currentDocument.cp)

			currentDocument.cp = currentDocument.cp + 1
			currentDocument.cw = 1
			currentDocument.co = 1
		end
	end

	-- Splice the last word of the section just pasted.

	NonmodalMessage("Clipboard copied to cursor position.")
	return Cmd.GotoBeginningOfWord() and Cmd.GotoPreviousCharW()
		and Cmd.JoinWithNextWord()
end

function Cmd.Delete()
	if not currentDocument.mp then
		return false
	end

	local mp1, mw1, mo1, mp2, mw2, mo2 = currentDocument:getMarks()

	-- Put the cursor at the end of the selection and split.

	currentDocument.cp = mp2
	currentDocument.cw = mw2
	currentDocument.co = mo2
	if not Cmd.SplitCurrentParagraph() then
		return false
	end

	-- Put the cursor at the beginning of the selection and split.

	currentDocument.cp = mp1
	currentDocument.cw = mw1
	currentDocument.co = mo1
	if not Cmd.SplitCurrentParagraph() then
		return false
	end

	-- We now have a whole number of paragraphs containing the area to delete.
	-- Delete them.

	for i = 1, (mp2 - mp1 + 1) do
		currentDocument:deleteParagraphAt(currentDocument.cp)
	end

	-- And merge the two areas together again.

	if not (Cmd.GotoPreviousWordW() and
	        Cmd.GotoEndOfWord() and
			Cmd.JoinWithNextWord()) then
		return false
	end

	-- If the selection started at a word boundary, make sure it's preserved.

	if (mo1 == 1) and (mw1 > 1) then
		if not Cmd.SplitCurrentWord() then
			return false
		end
	end

	NonmodalMessage("Selected area deleted.")
	return Cmd.UnsetMark()
end

function Cmd.Find(findtext, replacetext)
	if not findtext then
		findtext, replacetext = FindAndReplaceDialogue()
		if not findtext or (findtext == "") then
			return false
		end
	end

	documentSet.findtext = findtext
	documentSet._findpatterns = nil
	documentSet.replacetext = replacetext
	return Cmd.FindNext()
end

local function compile_patterns(text)
	local patterns = {}
	local words = SplitString(text, "%s")
	local smartquotes = documentSet.addons.smartquotes or {}

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
			local c: any = WriteU8((ReadU8(w, i)))
			i = i + GetBytesOfCharacter(c)

			if ((c >= "A") and (c <= "Z")) or
			    ((c >= "a") and (c <= "z")) then
				c = P("["..c:upper()..c:lower().."]")
			elseif (c == "'") then
				c = P("'") + P(smartquotes.leftsingle) + P(smartquotes.rightsingle)
			elseif (c == '"') then
				c = P('"') + P(smartquotes.leftdouble) + P(smartquotes.rightdouble)
			end

			wp[#wp+1] = P(c)
		end

		patterns[#patterns + 1] = P(unpack(Intersperse(wp, "%c*")))
	end

	for i = 2, (#patterns - 1) do
		patterns[i] = P("^%c*", patterns[i], "%c*$")
	end

	if (#patterns > 1) then
		patterns[1] = P(patterns[1], "%c*$")
		patterns[#patterns] = P("^%c*", patterns[#patterns])
	end

	for i = 1, #patterns do
		patterns[i] = P("()", patterns[i], "()")
	end

	for i = 1, #patterns do
		patterns[i] = patterns[i]:compile()
	end

	return patterns
end

function Cmd.FindNext()
	if not documentSet.findtext then
		return false
	end

	ImmediateMessage("Searching...")

	-- Get the compiled pattern for the text we're searching for.

	if not documentSet._findpatterns then
		documentSet._findpatterns = compile_patterns(documentSet.findtext)
	end
	assert(documentSet._findpatterns)
	local patterns = documentSet._findpatterns

	-- Start at the current cursor position.

	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	if (#patterns == 0) then
		QueueRedraw()
		NonmodalMessage("Nothing to search for.")
		return false
	end

	local pattern = patterns[1]

	-- Keep looping until we reach the starting point again.

	while true do
		local word = currentDocument[cp][cw]
		local s, e = pattern(word, co)
		local _

		if s then
			-- We got a match! First, though, check to see if the remaining
			-- words in the pattern match.

			local ep, ew = cp, cw
			local pi = 2
			local found = true
			while (pi <= #patterns) do
				ew = ew + 1
				if (ew > #currentDocument[ep]) then
					ep = ep + 1
					ew = 1
					if (ep > #currentDocument) then
						found = false
						break
					end
				end

				word = currentDocument[ep][ew]
				if not word then
					found = false
					break
				end

				_, e = patterns[pi](word)
				if not e then
					found = false
					break
				end

				pi = pi + 1
			end

			if found then
				assert(s)
				assert(e)
				currentDocument.cp = ep
				currentDocument.cw = ew
				currentDocument.co = e
				currentDocument.mp = cp
				currentDocument.mw = cw
				currentDocument.mo = s
				NonmodalMessage("Found.")
				QueueRedraw()
				return true
			end
		end

		-- Nothing. Move on to the next word.

		co = 1
		cw = cw + 1
		if (cw > #currentDocument[cp]) then
			cw = 1
			cp = cp + 1
			if (cp > #currentDocument) then
				cp = 1
			end
		end

		-- Check to see if we've scanned everything.

		if (cp == currentDocument.cp) and (cw == currentDocument.cw) and (co == 1) then
			break
		end
	end

	QueueRedraw()
	NonmodalMessage("Not found.")
	return false
end

function Cmd.ReplaceThenFind()
	if currentDocument.mp then
		local e = Cmd.Delete() and Cmd.UnsetMark()
		if not e then
			return false
		end

		e = true
		local words = SplitString(documentSet.replacetext, "%s")
		for i, w in ipairs(words) do
			if (i > 1) then
				Cmd.SplitCurrentWord()
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
	if documentSet.statusbar then
		documentSet.statusbar = false
		NonmodalMessage("Status bar disabled.")
	else
		documentSet.statusbar = true
		NonmodalMessage("Status bar enabled.")
	end

	QueueRedraw()
	return true
end

function Cmd.AboutWordGrinder()
	AboutDialogue()
end
