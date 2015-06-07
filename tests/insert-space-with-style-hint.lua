require("tests/testsuite")

-- Make sure that toggling the style hint just before typing a space
-- works correctly.

Cmd.SetStyle("b")
Cmd.InsertStringIntoWord("foo")
AssertTableEquals({"\24foo"}, Document[1])

Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.InsertStringIntoWord("bar")
AssertTableEquals({"\24foo", "bar"}, Document[1])

Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
Cmd.GotoPreviousCharW()
Cmd.GotoNextCharW()
Cmd.InsertStringIntoWord("baz")
AssertTableEquals({"\24foo", "bar", "baz"}, Document[1])

