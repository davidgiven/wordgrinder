require("tests/testsuite")

Cmd.InsertStringIntoParagraph("paragraph one")
Cmd.ChangeParagraphStyle("LN")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph two")
Cmd.ChangeParagraphStyle("LN")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("paragraph three")
Cmd.ChangeParagraphStyle("LN")

AssertEquals(3, #Document)
AssertEquals("LN", Document[1].style)
AssertEquals("LN", Document[2].style)
AssertEquals("LN", Document[3].style)
FireEvent(Event.Changed)
AssertEquals(1, Document[1].number)
AssertEquals(2, Document[2].number)
AssertEquals(3, Document[3].number)

Document.cp = 2
Cmd.ChangeParagraphStyle("P")

FireEvent(Event.Changed)
AssertEquals(1, Document[1].number)
AssertEquals(1, Document[3].number)

Document.cp = 2
Cmd.ChangeParagraphStyle("LN")

FireEvent(Event.Changed)
AssertEquals(1, Document[1].number)
AssertEquals(3, Document[3].number)

Document.cp = 2
Cmd.ChangeParagraphStyle("L")

FireEvent(Event.Changed)
AssertEquals(1, Document[1].number)
AssertEquals(2, Document[3].number)

Document.cp = 2
Cmd.ChangeParagraphStyle("LB")

FireEvent(Event.Changed)
AssertEquals(1, Document[1].number)
AssertEquals(2, Document[3].number)

