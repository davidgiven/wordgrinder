require("tests/testsuite")

DocumentSet.addons.smartquotes.singlequotes = false
DocumentSet.addons.smartquotes.doublequotes = false
DocumentSet.addons.smartquotes.notinraw = true

Cmd.InsertStringIntoParagraph("'Hello, world!'")
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph('"Hello, world!"')
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("flob's")
Cmd.SplitCurrentParagraph()
Cmd.ChangeParagraphStyle("RAW")
Cmd.InsertStringIntoParagraph("not'd")
AssertEquals("RAW", Document[4].style.name)

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()

Cmd.Copy()

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()

DocumentSet.addons.smartquotes.singlequotes = true
DocumentSet.addons.smartquotes.doublequotes = true
Cmd.Paste()

AssertTableEquals({"‘Hello,", "world!’"}, Document[1])
AssertTableEquals({"“Hello,", "world!”"}, Document[2])
AssertTableEquals({"flob’s"}, Document[3])
AssertEquals("RAW", Document[4].style.name)
AssertTableEquals({"not'd"}, Document[4])



