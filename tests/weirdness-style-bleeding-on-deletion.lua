require("tests/testsuite")

-- See https://github.com/davidgiven/wordgrinder/issues/206

require("tests/testsuite")

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

