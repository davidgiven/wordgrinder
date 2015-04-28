require "tests/testsuite"

Cmd.InsertStringIntoParagraph("foobar")
Cmd.GotoPreviousChar()
Cmd.GotoPreviousChar()
Cmd.GotoPreviousChar()
Cmd.SplitCurrentWord()
Cmd.SplitCurrentWord()

AssertEquals(3, Document.cw)
AssertEquals(2, Document.co)
AssertTableEquals({"foo", "", "\016bar"}, Document[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foo", "bar"}, Document[1])

