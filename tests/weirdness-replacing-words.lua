require("tests/testsuite")

Cmd.InsertStringIntoParagraph("foo bar baz")
Cmd.GotoPreviousWord()
Cmd.GotoPreviousWord()
Cmd.GotoBeginningOfWord()
Cmd.SetMark()
Cmd.GotoEndOfWord()
Cmd.Delete()

AssertTableEquals({"foo", "", "baz"}, Document[1])

