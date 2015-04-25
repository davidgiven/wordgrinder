require("tests/testsuite")

Cmd.InsertStringIntoParagraph("12345")
FlushAsyncEvents()
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.InsertStringIntoParagraph("67890")
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

-- GotoPrevious/NextLine won't work without this.
Document:wrap(80)

AssertEquals(2, Document.cp)
AssertEquals(5, Document.co)

Cmd.GotoPreviousLine()
FlushAsyncEvents()

AssertEquals(1, Document.cp)
AssertEquals(5, Document.co)

