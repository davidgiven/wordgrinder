require("tests/testsuite")

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

AssertTableEquals({"foo"}, Document[1])
AssertTableEquals({"bar"}, Document[2])
AssertTableEquals({2, 1, 1}, {Document.cp, Document.cw, Document.co})

