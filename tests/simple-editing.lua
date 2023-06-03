--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("foo")

AssertEquals(1, #currentDocument)
AssertEquals(1, #currentDocument[1])
AssertEquals("foo", currentDocument[1][1])

Cmd.DeletePreviousChar()
AssertEquals("fo", currentDocument[1][1])

Cmd.InsertStringIntoParagraph("o bar")

AssertEquals(1, #currentDocument)
AssertEquals(2, #currentDocument[1])
AssertEquals("foo", currentDocument[1][1])
AssertEquals("bar", currentDocument[1][2])

Cmd.GotoBeginningOfWord()
Cmd.DeletePreviousChar()

AssertEquals(1, #currentDocument)
AssertEquals(1, #currentDocument[1])
AssertEquals("foobar", currentDocument[1][1])
AssertEquals(1, currentDocument.cp)
AssertEquals(1, currentDocument.cw)
AssertEquals(4, currentDocument.co)

Cmd.SplitCurrentWord()

AssertEquals(1, #currentDocument)
AssertTableEquals({"foo", "\016bar"}, currentDocument[1])

Cmd.GotoBeginningOfWord()
Cmd.DeletePreviousChar()
Cmd.SplitCurrentParagraph()

AssertEquals(2, #currentDocument)
AssertTableEquals({"foo"}, currentDocument[1])
AssertTableEquals({"\016bar"}, currentDocument[2])

Cmd.InsertStringIntoParagraph("o bar")
Cmd.GotoEndOfWord()
Cmd.DeleteWord()
AssertEquals(1, currentDocument.cw)
AssertEquals(2, currentDocument.co)
AssertTableEquals({"o"}, currentDocument[2])

