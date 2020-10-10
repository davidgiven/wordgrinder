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

	if Cmd.GotoPreviousChar() then
		-- If that worked, we weren't at the beginning of the word.
		Document.co = 1
	else
		Document.cw = Document.cw - 1
		Document.co = 1
	end

	QueueRedraw()
	return true
end

function Cmd.GotoNextWord()
	local p = Document[Document.cp]
	if (Document.cw == #p) then
		Document.co = #(p[Document.cw]) + 1
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
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local paragraph = Document[cp]
	local word = paragraph[cw]

	local s, co = InsertIntoWord(word, c, co, GetCurrentStyleHint())
	if not co then
		return false
	end

	Document[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		s,
		paragraph:sub(cw+1))
	Document.co = co

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
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local styleprime = ""
	local styleprimelen = 0

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

	local paragraph = Document[cp]
	local word = paragraph[cw]
	local left = DeleteFromWord(word, co, #word+1)
	local right = DeleteFromWord(word, 1, co)

	Document[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		left,
		styleprime..right,
		paragraph:sub(cw+1))

	Document.cw = cw + 1
	Document.co = 1 + styleprimelen -- yes, this means that co has a minimum of 2

	DocumentSet:touch()
	QueueRedraw()
	return true
end

function Cmd.JoinWithNextParagraph()
	local cp, cw, co = Document.cp, Document.cw, Document.co
	if (cp == #Document) then
		return false
	end

	Document[cp] = CreateParagraph(Document[cp].style,
		Document[cp],
		Document[cp+1])
	Document:deleteParagraphAt(cp+1)

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
		paragraph = Document[cp]
	end

	local word, co, _ = InsertIntoWord(paragraph[cw+1], paragraph[cw], 1, 0)
	Document.co = co
	Document[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		word,
		paragraph:sub(cw+2))

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
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local paragraph = Document[cp]
	local word = paragraph[cw]
	local nextco = NextCharInWord(word, co)
	if not nextco then
		return Cmd.JoinWithNextWord()
	end

	Document[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		DeleteFromWord(word, co, nextco),
		paragraph:sub(cw+1))

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
	local cp = Document.cp
	local cw = Document.cw
	local co = Document.co
	local paragraph = Document[cp]
	local word = paragraph[cw]

	Document[cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw-1),
		DeleteFromWord(word, 1, co),
		paragraph:sub(cw+1))
	Document.co = 1

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

	Cmd.GotoEndOfWord()
	Cmd.DeleteWordLeftOfCursor()
	if Document.cw ~= 1 then
		Cmd.DeletePreviousChar()
	end
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
	else
		DocumentSet:touch()
		QueueRedraw()
	end

	local cp, cw = Document.cp, Document.cw
	local paragraph = Document[cp]
	local p1 = CreateParagraph(paragraph.style, paragraph:sub(1, cw-1))
	local p2 = CreateParagraph(paragraph.style, paragraph:sub(cw))

	Document[cp] = p2
	Document:insertParagraphBefore(p1, cp)
	Document.cp = Document.cp + 1
	Document.cw = 1
	Document.co = 1
	QueueRedraw()
	return true
end

function Cmd.GotoXPosition(pos)
	local paragraph = Document[Document.cp]
	local lines = paragraph:wrap(Document.wrapwidth)
	local ln = paragraph:getLineOfWord(Document.cw)

	local line = lines[ln]
	local wordofline = #line

	pos = pos - paragraph:getIndentOfLine(ln)
	if (pos < 0) then
		pos = 0
	end

	while (wordofline > 0) do
		if (paragraph.xs[line[wordofline]] <= pos) then
			break
		end
		wordofline = wordofline - 1
	end

	if (wordofline == 0) then
		wordofline = 1
	end

	local wn = line[wordofline]
	local word = paragraph[wn]
	local wordx = paragraph.xs[wn]
	wo = GetOffsetFromWidth(word, pos - wordx)

	Document.cw = paragraph:getWordOfLine(ln) + wordofline - 1
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
	x = x + GetWidthFromOffset(word, Document.co) + paragraph:getIndentOfLine(ln)

	return x, ln, lines
end

function Cmd.GotoNextLine()
	local x, ln, lines = getpos()

	if (ln == #lines) then
		if (Document.cp == #Document) then
			return Cmd.GotoEndOfParagraph()
		end

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
		if (Document.cp == 1) then
			return Cmd.GotoBeginningOfParagraph()
		end

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
				word, Document.co = ApplyStyleToWord(word, sor, sand, fo, lo, co)
			else
				word = ApplyStyleToWord(word, sor, sand, fo, lo, 0)
			end

			words[#words+1] = word
		end

		Document[p] = CreateParagraph(paragraph.style,
			paragraph:sub(1, firstword-1),
			words,
			paragraph:sub(lastword+1))
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

function Cmd.ChangeParagraphStyle(style)
	if not DocumentStyles[style] then
		ModalMessage("Unknown paragraph style", "Sorry! I don't recognise that style. (This user interface will be improved.)")
		return false
	end

	local first, last
	if Document.mp then
		local _
		first, _, _, last, _, _ = Document:getMarks()
	else
		first = Document.cp
		last = first
	end

	for p = first, last do
		Document[p] = CreateParagraph(style, Document[p])
	end

	DocumentSet:touch()
	QueueRedraw()
	return Cmd.UnsetMark()
end

local function rewind_past_style_bytes(p, w, o)
	local word = Document[p][w]
	o = PrevCharInWord(word, o)
	if o then
		o = NextCharInWord(word, o)
	else
		o = 1
	end
	return o
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
		Document.mo = rewind_past_style_bytes(Document.cp, Document.cw, Document.co)
		Document.sticky_selection = true
	end

	QueueRedraw()
	return true
end

function Cmd.SetMark()
	if not Document.mp then
		Document.mp = Document.cp
		Document.mw = Document.cw
		Document.mo = rewind_past_style_bytes(Document.cp, Document.cw, Document.co)
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
	if Document.mp and not Document.sticky_selection then
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
	word = paragraph[#paragraph]
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
	NonmodalMessage(buffer.wordcount.." words copied to clipboard.")
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

	Document[Document.cp] = CreateParagraph(paragraph.style,
		paragraph:sub(1, cw),
		buffer[1],
		paragraph:sub(cw+1))
	Document.cw = Document.cw + #buffer[1]
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
			local paragraph = buffer[p]
			Document:insertParagraphBefore(
				CreateParagraph(paragraph.style, paragraph),
				Document.cp)

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

	DocumentSet.findtext = findtext
	DocumentSet._findpatterns = nil
	DocumentSet.replacetext = replacetext
	return Cmd.FindNext()
end

local function compile_patterns(text)
	patterns = {}
	local words = SplitString(text, "%s")
	local smartquotes = DocumentSet.addons.smartquotes or {}

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
	if not DocumentSet.findtext then
		return false
	end

	ImmediateMessage("Searching...")

	-- Get the compiled pattern for the text we're searching for.

	if not DocumentSet._findpatterns then
		DocumentSet._findpatterns = compile_patterns(DocumentSet.findtext)
	end
	local patterns = DocumentSet._findpatterns

	-- Start at the current cursor position.

	local cp, cw, co = Document.cp, Document.cw, Document.co
	if (#patterns == 0) then
		QueueRedraw()
		NonmodalMessage("Nothing to search for.")
		return false
	end

	local pattern = patterns[1]

	-- Keep looping until we reach the starting point again.

	while true do
		local word = Document[cp][cw]
		local s, e = pattern(word, co)

		if s then
			-- We got a match! First, though, check to see if the remaining
			-- words in the pattern match.

			local ep, ew = cp, cw
			local pi = 2
			local found = true
			while (pi <= #patterns) do
				ew = ew + 1
				if (ew > #Document[ep]) then
					ep = ep + 1
					ew = 1
					if (ep > #Document) then
						found = false
						break
					end
				end

				word = Document[ep][ew]
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
				Document.cp = ep
				Document.cw = ew
				Document.co = e
				Document.mp = cp
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
