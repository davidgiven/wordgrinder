--!nonstrict
loadfile("tests/testsuite.lua")()

-- Make sure that toggling the style hint just before typing a space
-- works correctly.

Cmd.SetStyle("b")
Cmd.InsertStringIntoWord("foo")
AssertTableEquals({"\24foo"}, currentDocument[1])

Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.InsertStringIntoWord("bar")
AssertTableEquals({"\24foo", "bar"}, currentDocument[1])

Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.GotoPreviousCharW()
Cmd.GotoNextCharW()
Cmd.InsertStringIntoWord("baz")
AssertTableEquals({"\24foo", "bar", "baz"}, currentDocument[1])

