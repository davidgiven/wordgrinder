--!nonstrict
loadfile("tests/testsuite.lua")()

-- See https://github.com/davidgiven/wordgrinder/issues/206

--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.SetStyle("i")
Cmd.InsertStringIntoParagraph("foo")
Cmd.SetStyle("o")
Cmd.InsertStringIntoParagraph("bar")
AssertEquals("\017foo\016bar", currentDocument[1][1])

Cmd.GotoBeginningOfParagraph()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()
AssertTableEquals({1, 1, 5}, currentDocument:cursor())

Cmd.DeleteNextChar()
AssertEquals("\017foo\016ar", currentDocument[1][1])

