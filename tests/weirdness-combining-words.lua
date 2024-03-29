--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.SetMark()
Cmd.InsertStringIntoParagraph("foo")
Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.SetStyle("o")
Cmd.InsertStringIntoParagraph("bar")

AssertTableEquals({"\24foo", "bar"}, currentDocument[1])

Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()
Cmd.DeletePreviousChar()

AssertEquals(8, GetCurrentStyleHint()) -- bold on
AssertTableEquals({"\24foo\16bar"}, currentDocument[1])

Cmd.SplitCurrentWord()

AssertTableEquals({"\24foo", "\24\16bar"}, currentDocument[1])

