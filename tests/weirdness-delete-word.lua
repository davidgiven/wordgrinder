require("tests/testsuite")

Cmd.SetMark()
Cmd.InsertStringIntoParagraph("foo bar baz")

AssertTableEquals({"foo", "bar", "baz"}, Document[1])

Cmd.DeleteWordLeftOfCursor()
AssertTableEquals({"foo", "bar", ""}, Document[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foo", "bar"}, Document[1])

Cmd.GotoPreviousCharW()
Cmd.DeleteWordLeftOfCursor()
AssertTableEquals({"foo", "r"}, Document[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foor"}, Document[1])

Cmd.DeleteWord()
AssertTableEquals({""}, Document[1])

