require("tests/testsuite")

Cmd.InsertStringIntoParagraph("12345")
Cmd.SplitCurrentParagraph()
Cmd.SetStyle("b")
Cmd.InsertStringIntoParagraph("67890")
Cmd.GotoPreviousCharW()

-- GotoPrevious/NextLine won't work without this.
Document:wrap(80)

Cmd.GotoBeginningOfDocument()

AssertEquals(1, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextLine()

AssertEquals(2, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextCharW()
Cmd.GotoPreviousCharW()

AssertEquals(2, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

