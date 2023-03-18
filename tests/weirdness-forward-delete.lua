--!strict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("abcd")
Cmd.GotoBeginningOfParagraph()
Cmd.InsertStringIntoParagraph(" ")
Cmd.DeleteNextChar()

AssertTableEquals({"bcd", style="P"}, Document[1])
AssertTableEquals({1, 1, 1}, Document:cursor())

