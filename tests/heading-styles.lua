--!nonstrict
loadfile("tests/testsuite.lua")()

ResetDocumentSet()
Cmd.ChangeParagraphStyle("H1")
Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")

AssertEquals(2, #currentDocument)
AssertEquals("H1", currentDocument[1].style)
AssertEquals("P", currentDocument[2].style)


ResetDocumentSet()
Cmd.ChangeParagraphStyle("H1")
Cmd.InsertStringIntoParagraph("paragraph one")
currentDocument.cw = 1
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")

AssertEquals(2, #currentDocument)
AssertEquals("H1", currentDocument[1].style)
AssertEquals("P", currentDocument[2].style)


ResetDocumentSet()
Cmd.ChangeParagraphStyle("H1")
Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.SplitCurrentParagraph()

AssertEquals(2, #currentDocument)
AssertEquals("H1", currentDocument[1].style)
AssertEquals("P", currentDocument[2].style)


ResetDocumentSet()
Cmd.ChangeParagraphStyle("LB")
Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")

AssertEquals(2, #currentDocument)
AssertEquals("LB", currentDocument[1].style)
AssertEquals("LB", currentDocument[2].style)


