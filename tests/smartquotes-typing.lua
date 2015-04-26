require("tests/testsuite")

DocumentSet.addons.smartquotes.singlequotes = true
DocumentSet.addons.smartquotes.doublequotes = true
DocumentSet.addons.smartquotes.notinraw = true

Cmd.InsertStringIntoParagraph("'Hello, world!'")
FlushAsyncEvents()
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.InsertStringIntoParagraph('"Hello, world!"')
FlushAsyncEvents()
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.InsertStringIntoParagraph("flob's")
FlushAsyncEvents()
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.ChangeParagraphStyle("RAW")
Cmd.InsertStringIntoParagraph("not'd")
FlushAsyncEvents()

DocumentSet.addons.smartquotes.rightsingle = "%"
Cmd.SplitCurrentParagraph()
FlushAsyncEvents()
Cmd.ChangeParagraphStyle("P")
Cmd.InsertStringIntoParagraph("blorb's")
FlushAsyncEvents()

AssertEquals("‘Hello,", Document[1][1])
AssertEquals("world!’", Document[1][2])
AssertEquals("“Hello,", Document[2][1])
AssertEquals("world!”", Document[2][2])
AssertEquals("flob’s", Document[3][1])
AssertEquals("not'd", Document[4][1])
AssertEquals("blorb%s", Document[5][1])


