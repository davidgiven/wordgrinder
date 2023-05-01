--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph three")

AssertEquals(3, #currentDocument)
AssertEquals("P", currentDocument[1].style)
AssertEquals("P", currentDocument[2].style)
AssertEquals("P", currentDocument[3].style)

currentDocument.cp = 2
currentDocument.cw = 1

Cmd.ChangeParagraphStyle("H1")
AssertEquals("P", currentDocument[1].style)
AssertEquals("H1", currentDocument[2].style)
AssertTableEquals({"paragraph", "two"}, currentDocument[2])
AssertEquals("P", currentDocument[3].style)

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()
Cmd.ChangeParagraphStyle("H2")
AssertEquals("H2", currentDocument[1].style)
AssertEquals("H2", currentDocument[2].style)
AssertTableEquals({"paragraph", "two"}, currentDocument[2])
AssertEquals("H2", currentDocument[3].style)

