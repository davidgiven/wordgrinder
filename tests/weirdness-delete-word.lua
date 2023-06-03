--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.SetMark()
Cmd.InsertStringIntoParagraph("foo bar baz")

AssertTableEquals({"foo", "bar", "baz"}, currentDocument[1])

Cmd.DeleteWordLeftOfCursor()
AssertTableEquals({"foo", "bar", ""}, currentDocument[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foo", "bar"}, currentDocument[1])

Cmd.GotoPreviousCharW()
Cmd.DeleteWordLeftOfCursor()
AssertTableEquals({"foo", "r"}, currentDocument[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foor"}, currentDocument[1])

Cmd.DeleteWord()
AssertTableEquals({""}, currentDocument[1])

