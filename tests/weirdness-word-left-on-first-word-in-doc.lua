--!nonstrict
loadfile("tests/testsuite.lua")()

ScreenWidth = 80
currentDocument:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("foobarbaz")

AssertEquals(1, #currentDocument)

Cmd.GotoPreviousWord()
AssertTableEquals({1, 1, 1}, {currentDocument.cp, currentDocument.cw, currentDocument.co})
