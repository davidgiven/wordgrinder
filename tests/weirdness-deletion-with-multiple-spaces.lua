--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("foobar")
Cmd.GotoPreviousChar()
Cmd.GotoPreviousChar()
Cmd.GotoPreviousChar()
Cmd.SplitCurrentWord()
Cmd.SplitCurrentWord()

AssertEquals(3, currentDocument.cw)
AssertEquals(2, currentDocument.co)
AssertTableEquals({"foo", "", "\016bar"}, currentDocument[1])

Cmd.DeletePreviousChar()
AssertTableEquals({"foo", "bar"}, currentDocument[1])

