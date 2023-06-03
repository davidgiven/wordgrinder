--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("foo")
Cmd.SplitCurrentWord()
Cmd.InsertStringIntoParagraph("bar")
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.SplitCurrentParagraph()
Cmd.GotoNextCharW()
Cmd.DeletePreviousChar()

AssertTableEquals({"foo"}, currentDocument[1])
AssertTableEquals({"bar"}, currentDocument[2])
AssertTableEquals({2, 1, 1}, {currentDocument.cp, currentDocument.cw, currentDocument.co})

