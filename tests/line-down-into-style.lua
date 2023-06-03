--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("12345")
Cmd.SplitCurrentParagraph()
Cmd.SetStyle("b")
Cmd.InsertStringIntoParagraph("67890")
Cmd.GotoPreviousCharW()

-- GotoPrevious/NextLine won't work without this.
currentDocument:wrap(80)

Cmd.GotoBeginningOfDocument()

AssertEquals(1, currentDocument.cp)
AssertEquals(1, currentDocument.cw)
AssertEquals(1, currentDocument.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextLine()

AssertEquals(2, currentDocument.cp)
AssertEquals(1, currentDocument.cw)
AssertEquals(1, currentDocument.co)
AssertEquals(0, GetCurrentStyleHint())

Cmd.GotoNextCharW()
Cmd.GotoPreviousCharW()

AssertEquals(2, currentDocument.cp)
AssertEquals(1, currentDocument.cw)
AssertEquals(1, currentDocument.co)
AssertEquals(0, GetCurrentStyleHint())

