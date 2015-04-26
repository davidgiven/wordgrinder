require("tests/testsuite")

Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph three")

AssertEquals(3, #Document)
AssertEquals("P", Document[1].style.name)
AssertEquals("P", Document[2].style.name)
AssertEquals("P", Document[3].style.name)

Document.cp = 2
Document.cw = 1

Cmd.ChangeParagraphStyle("H1")
AssertEquals("P", Document[1].style.name)
AssertEquals("H1", Document[2].style.name)
AssertTableEquals({"paragraph", "two"}, Document[2])
AssertEquals("P", Document[3].style.name)

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()
Cmd.ChangeParagraphStyle("H2")
AssertEquals("H2", Document[1].style.name)
AssertEquals("H2", Document[2].style.name)
AssertTableEquals({"paragraph", "two"}, Document[2])
AssertEquals("H2", Document[3].style.name)

