require("tests/testsuite")

Cmd.InsertStringIntoParagraph("foo")

AssertEquals(1, #Document)
AssertEquals(1, #Document[1])
AssertEquals("foo", Document[1][1])

Cmd.DeletePreviousChar()
AssertEquals("fo", Document[1][1])

Cmd.InsertStringIntoParagraph("o bar")

AssertEquals(1, #Document)
AssertEquals(2, #Document[1])
AssertEquals("foo", Document[1][1])
AssertEquals("bar", Document[1][2])

Cmd.GotoBeginningOfWord()
Cmd.DeletePreviousChar()

AssertEquals(1, #Document)
AssertEquals(1, #Document[1])
AssertEquals("foobar", Document[1][1])
AssertEquals(1, Document.cp)
AssertEquals(1, Document.cw)
AssertEquals(4, Document.co)

Cmd.SplitCurrentWord()

AssertEquals(1, #Document)
AssertEquals(2, #Document[1])
AssertEquals("foo", Document[1][1])
AssertEquals("\016bar", Document[1][2])

Cmd.GotoBeginningOfWord()
Cmd.DeletePreviousChar()
Cmd.SplitCurrentParagraph()

AssertEquals(2, #Document)
AssertEquals(1, #Document[1])
AssertEquals(1, #Document[2])
AssertEquals("foo", Document[1][1])
AssertEquals("\016bar", Document[2][1])

