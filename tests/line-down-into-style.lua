require("tests/testsuite")

Cmd.InsertStringIntoParagraph("12345")
FlushAsyncEvents()
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.SetStyle("b")
Cmd.InsertStringIntoParagraph("67890")
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

-- GotoPrevious/NextLine won't work without this.
Document:wrap(80)

Cmd.GotoBeginningOfDocument()
FlushAsyncEvents()

AssertEquals(1, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextLine()
FlushAsyncEvents()

AssertEquals(2, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextCharW()
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

AssertEquals(2, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(1, Document.co)
AssertEquals(0, GetCurrentStyleHint())

