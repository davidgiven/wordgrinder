require("tests/testsuite")

Cmd.InsertStringIntoParagraph("foobar")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.SetStyle("b")

AssertEquals(1, #Document)
AssertEquals(1, #Document[1])
AssertEquals("foo\024bar", Document[1][1])

