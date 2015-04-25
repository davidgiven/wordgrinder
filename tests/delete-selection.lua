require("tests/testsuite")

Cmd.InsertStringIntoWord("foo")
FlushAsyncEvents()
Cmd.SetMark()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

-- This should delete the selection only.
Cmd.DeleteSelectionOrPreviousChar()
FlushAsyncEvents()

AssertEquals("f", Document[1][1].text)
AssertEquals(2, Document.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrPreviousChar()
FlushAsyncEvents()

AssertEquals("", Document[1][1].text)
AssertEquals(1, Document.co)

ResetDocumentSet()
Cmd.InsertStringIntoWord("foo")
FlushAsyncEvents()
Cmd.GotoBeginningOfDocument()
FlushAsyncEvents()
Cmd.SetMark()
Cmd.GotoNextCharW()
FlushAsyncEvents()
Cmd.GotoNextCharW()
FlushAsyncEvents()

-- This should delete the selection only.
Cmd.DeleteSelectionOrNextChar()
FlushAsyncEvents()

AssertEquals("o", Document[1][1].text)
AssertEquals(1, Document.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrNextChar()
FlushAsyncEvents()

AssertEquals("", Document[1][1].text)
AssertEquals(1, Document.co)


