--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("foobar")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.SetStyle("b")

AssertEquals(1, #currentDocument)
AssertEquals(1, #currentDocument[1])
AssertEquals("foo\024bar", currentDocument[1][1])

