--!nonstrict
loadfile("tests/testsuite.lua")()

local function rep(n, f)
	for i = 1, n do
		f()
	end
end

local function assert_sel(top, bot)
	AssertEquals(not not currentDocument.mp, true)
	AssertTableEquals(top, {currentDocument.mp, currentDocument.mw, currentDocument.mo})
	AssertTableEquals(bot, {currentDocument.cp, currentDocument.cw, currentDocument.co})
end

Cmd.InsertStringIntoParagraph("123←→456")
Cmd.GotoBeginningOfWord()
rep(6, Cmd.GotoNextChar)
Cmd.SetMark()
rep(5, Cmd.GotoPreviousChar)
Cmd.SetStyle("b")
AssertTableEquals({"1\02423←→4\01656"}, currentDocument[1])

Cmd.GotoEndOfWord()
rep(1, Cmd.GotoPreviousChar)
Cmd.SetMark()
rep(5, Cmd.GotoPreviousChar)
Cmd.SetStyle("u")
AssertTableEquals({"1\0242\0263←→4\0185\0166"}, currentDocument[1])

Cmd.GotoBeginningOfParagraph()
Cmd.SetMark()
Cmd.GotoEndOfParagraph()
assert_sel({1, 1, 1}, {1, 1, 17})
Cmd.SetStyle("i")
AssertTableEquals({1, 1, 18}, {currentDocument.cp, currentDocument.cw, currentDocument.co})
AssertTableEquals({"\0171\0252\0273←→4\0195\0176"}, currentDocument[1])

