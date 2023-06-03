--!nonstrict
loadfile("tests/testsuite.lua")()

ScreenWidth = 80
currentDocument:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("foo bar baz")

AssertEquals(1, #currentDocument)

Cmd.GotoBeginningOfLine()
Cmd.GotoNextWord()
Cmd.GotoNextWord()
Cmd.GotoNextWord()

AssertTableEquals({1, 3, 4}, {currentDocument.cp, currentDocument.cw, currentDocument.co})
