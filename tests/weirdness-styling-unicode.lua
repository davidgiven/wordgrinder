require("tests/testsuite")

local function rep(n, f)
	for i = 1, n do
		f()
	end
end

local function assert_sel(top, bot)
	AssertEquals(not not Document.mp, true)
	AssertTableEquals(top, {Document.mp, Document.mw, Document.mo})
	AssertTableEquals(bot, {Document.cp, Document.cw, Document.co})
end

Cmd.InsertStringIntoParagraph("123←→456")
Cmd.GotoBeginningOfWord()
rep(6, Cmd.GotoNextChar)
Cmd.SetMark()
rep(5, Cmd.GotoPreviousChar)
Cmd.SetStyle("b")
AssertTableEquals({"1\02423←→4\01656"}, Document[1])

Cmd.GotoEndOfWord()
rep(1, Cmd.GotoPreviousChar)
Cmd.SetMark()
rep(5, Cmd.GotoPreviousChar)
Cmd.SetStyle("u")
AssertTableEquals({"1\0242\0263←→4\0185\0166"}, Document[1])

Cmd.GotoBeginningOfParagraph()
Cmd.SetMark()
Cmd.GotoEndOfParagraph()
assert_sel({1, 1, 1}, {1, 1, 17})
Cmd.SetStyle("i")
AssertTableEquals({1, 1, 18}, {Document.cp, Document.cw, Document.co})
AssertTableEquals({"\0171\0252\0273←→4\0195\0176"}, Document[1])

