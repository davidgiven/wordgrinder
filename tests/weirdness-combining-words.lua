require("tests/testsuite")

Cmd.SetMark()
Cmd.InsertStringIntoParagraph("foo")
Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.InsertStringIntoParagraph("bar")

AssertTableEquals({"\24foo", "bar"}, Document[1])

Cmd.GotoBeginningOfWord()
Cmd.DeletePreviousChar()

AssertTableEquals({"\24foo\16bar"}, Document[1])

Cmd.SplitCurrentWord()

AssertTableEquals({"\24foo", "bar"}, Document[1])

