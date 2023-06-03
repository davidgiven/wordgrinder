--!nonstrict
loadfile("tests/testsuite.lua")()

documentSet.addons.smartquotes.singlequotes = false
documentSet.addons.smartquotes.doublequotes = false
documentSet.addons.smartquotes.notinraw = true

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
AssertEquals("RAW", currentDocument[currentDocument.cp].style)
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("P")
Cmd.InsertStringIntoParagraph([["Once upon a time," said K'trx'frn, "there was an aardvark called Albert."]])
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("\"'nested'\"")
Cmd.SplitCurrentParagraph()

Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoEndOfDocument()
documentSet.addons.smartquotes.singlequotes = true
documentSet.addons.smartquotes.doublequotes = true
Cmd.Smartquotify()

AssertTableEquals({"‘Hello,", "world!’"}, currentDocument[1])
AssertTableEquals({"“Hello,", "world!”"}, currentDocument[2])
AssertTableEquals({"flob’s"}, currentDocument[3])
AssertTableEquals({"\24‘fnord’"}, currentDocument[4])
AssertTableEquals({"\17‘\25fnord’"}, currentDocument[5])
AssertEquals("RAW", currentDocument[6].style)
AssertTableEquals({"not'd"}, currentDocument[6])
AssertTableEquals({"“Once", "upon", "a", "time,”", "said", "K’trx’frn,",
	"“there", "was", "an", "aardvark", "called", "Albert.”"}, currentDocument[7])
AssertTableEquals({"“‘nested’”"}, currentDocument[8])

Cmd.GotoBeginningOfDocument()
Cmd.Find("'Hello", "XXXX")
Cmd.ReplaceThenFind()

Cmd.GotoBeginningOfDocument()
Cmd.Find('"Hello', "YYYY")
Cmd.ReplaceThenFind()

AssertTableEquals({"XXXX,", "world!’"}, currentDocument[1])
AssertTableEquals({"YYYY,", "world!”"}, currentDocument[2])

Cmd.GotoEndOfDocument()
Cmd.GotoPreviousParagraph()
Cmd.SetMark()
Cmd.GotoPreviousParagraph()
Cmd.GotoBeginningOfParagraph()
Cmd.Unsmartquotify()

AssertTableEquals({'"Once', "upon", "a", 'time,"', "said", "K'trx'frn,",
	'"there', "was", "an", "aardvark", "called", 'Albert."'}, currentDocument[7])

