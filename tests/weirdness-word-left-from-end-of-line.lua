--!nonstrict
loadfile("tests/testsuite.lua")()

ScreenWidth = 80
currentDocument:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("foo bar baz")

AssertEquals(1, #currentDocument)

Cmd.GotoEndOfLine()
Cmd.GotoPreviousWord()

AssertTableEquals({currentDocument.cp, currentDocument.cw, currentDocument.co}, {1, 3, 1})
