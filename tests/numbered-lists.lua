--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.ChangeParagraphStyle("LN")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")
Cmd.ChangeParagraphStyle("LN")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph three")
Cmd.ChangeParagraphStyle("LN")

AssertEquals(3, #currentDocument)
AssertEquals("LN", currentDocument[1].style)
AssertEquals("LN", currentDocument[2].style)
AssertEquals("LN", currentDocument[3].style)
FireEvent("Changed")
AssertEquals(1, currentDocument[1].number)
AssertEquals(2, currentDocument[2].number)
AssertEquals(3, currentDocument[3].number)

currentDocument.cp = 2
Cmd.ChangeParagraphStyle("P")

FireEvent("Changed")
AssertEquals(1, currentDocument[1].number)
AssertEquals(1, currentDocument[3].number)

currentDocument.cp = 2
Cmd.ChangeParagraphStyle("LN")

FireEvent("Changed")
AssertEquals(1, currentDocument[1].number)
AssertEquals(3, currentDocument[3].number)

currentDocument.cp = 2
Cmd.ChangeParagraphStyle("L")

FireEvent("Changed")
AssertEquals(1, currentDocument[1].number)
AssertEquals(2, currentDocument[3].number)

currentDocument.cp = 2
Cmd.ChangeParagraphStyle("LB")

FireEvent("Changed")
AssertEquals(1, currentDocument[1].number)
AssertEquals(2, currentDocument[3].number)

