require("tests/testsuite")

Cmd.SetMark()
Cmd.InsertStringIntoParagraph("foo")
Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.SetStyle("o")
Cmd.InsertStringIntoParagraph("bar")

AssertTableEquals({"\24foo", "bar"}, Document[1])

Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.DeletePreviousChar()

AssertEquals(8, GetCurrentStyleHint()) -- bold on
AssertTableEquals({"\24foo\16bar"}, Document[1])

Cmd.SplitCurrentWord()

AssertTableEquals({"\24foo", "\24\16bar"}, Document[1])

