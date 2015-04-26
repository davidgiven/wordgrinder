require("tests/testsuite")

-- Make sure that toggling the style hint just before typing a space
-- works correctly.

Cmd.SetStyle("b")
Cmd.InsertStringIntoWord("foo")
FlushAsyncEvents()
Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
FlushAsyncEvents()
Cmd.InsertStringIntoWord("bar")
FlushAsyncEvents()
Cmd.SetStyle("b")
Cmd.SplitCurrentWord()
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()
Cmd.GotoNextCharW()
FlushAsyncEvents()
Cmd.InsertStringIntoWord("baz")

AssertEquals(3, #Document[1])
AssertEquals("\024foo", Document[1][1])
AssertEquals("bar", Document[1][2])
AssertEquals("baz", Document[1][3])

