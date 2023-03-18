loadfile("tests/testsuite.lua")()

-- See https://github.com/davidgiven/wordgrinder/issues/206

loadfile("tests/testsuite.lua")()

Cmd.SetStyle("i")
Cmd.InsertStringIntoParagraph("foo")
Cmd.SetStyle("o")
Cmd.InsertStringIntoParagraph("bar")
AssertEquals("\017foo\016bar", Document[1][1])

Cmd.GotoBeginningOfParagraph()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()
AssertTableEquals({1, 1, 5}, Document:cursor())

Cmd.DeleteNextChar()
AssertEquals("\017foo\016ar", Document[1][1])

