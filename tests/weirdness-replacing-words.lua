--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("foo bar baz")
Cmd.GotoPreviousWord()
Cmd.GotoPreviousWord()
Cmd.GotoBeginningOfWord()
Cmd.SetMark()
Cmd.GotoEndOfWord()
Cmd.Delete()

AssertTableEquals({"foo", "", "baz"}, currentDocument[1])

