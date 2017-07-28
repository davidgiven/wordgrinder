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

Cmd.SetStyle("b")
Cmd.InsertStringIntoParagraph("'fnord'")
Cmd.SplitCurrentParagraph()
Cmd.SetStyle("o")

Cmd.SetStyle("i")
Cmd.InsertStringIntoParagraph("'")
Cmd.SetStyle("b")
Cmd.InsertStringIntoParagraph("fnord'")
Cmd.SetStyle("o")
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("RAW")
Cmd.InsertStringIntoParagraph("not'd")
AssertEquals("RAW", Document[Document.cp].style)
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("P")
Cmd.InsertStringIntoParagraph([["Once upon a time," said K'trx'frn, "there was an aardvark called Albert."]])
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("\"'nested'\"")
Cmd.SplitCurrentParagraph()

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()
DocumentSet.addons.smartquotes.singlequotes = true
DocumentSet.addons.smartquotes.doublequotes = true
Cmd.Smartquotify()

AssertTableEquals({"‘Hello,", "world!’"}, Document[1])
AssertTableEquals({"“Hello,", "world!”"}, Document[2])
AssertTableEquals({"flob’s"}, Document[3])
AssertTableEquals({"\24‘fnord’"}, Document[4])
AssertTableEquals({"\17‘\25fnord’"}, Document[5])
AssertEquals("RAW", Document[6].style)
AssertTableEquals({"not'd"}, Document[6])
AssertTableEquals({"“Once", "upon", "a", "time,”", "said", "K’trx’frn,",
	"“there", "was", "an", "aardvark", "called", "Albert.”"}, Document[7])
AssertTableEquals({"“‘nested’”"}, Document[8])

Cmd.GotoBeginningOfDocument()
Cmd.Find("'Hello", "XXXX")
Cmd.ReplaceThenFind()

Cmd.GotoBeginningOfDocument()
Cmd.Find('"Hello', "YYYY")
Cmd.ReplaceThenFind()

AssertTableEquals({"XXXX,", "world!’"}, Document[1])
AssertTableEquals({"YYYY,", "world!”"}, Document[2])

Cmd.GotoEndOfDocument()
Cmd.GotoPreviousParagraph()
Cmd.SetMark()
Cmd.GotoPreviousParagraph()
Cmd.GotoBeginningOfParagraph()
Cmd.Unsmartquotify()

AssertTableEquals({'"Once', "upon", "a", 'time,"', "said", "K'trx'frn,",
	'"there', "was", "an", "aardvark", "called", 'Albert."'}, Document[7])

