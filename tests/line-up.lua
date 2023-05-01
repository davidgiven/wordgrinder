--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("12345")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("67890")
Cmd.GotoPreviousCharW()

-- GotoPrevious/NextLine won't work without this.
currentDocument:wrap(80)

AssertEquals(2, currentDocument.cp)
AssertEquals(5, currentDocument.co)

Cmd.GotoPreviousLine()

AssertEquals(1, currentDocument.cp)
AssertEquals(5, currentDocument.co)

