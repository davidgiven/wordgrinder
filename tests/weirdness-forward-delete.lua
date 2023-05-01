--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("abcd")
Cmd.GotoBeginningOfParagraph()
Cmd.InsertStringIntoParagraph(" ")
Cmd.DeleteNextChar()

AssertTableEquals({"bcd", style="P"}, currentDocument[1])
AssertTableEquals({1, 1, 1}, currentDocument:cursor())

