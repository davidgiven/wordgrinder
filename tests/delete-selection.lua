require("tests/testsuite")

Cmd.InsertStringIntoWord("foo")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

-- This should delete the selection only.
Cmd.DeleteSelectionOrPreviousChar()

AssertTableEquals({"f"}, Document[1])
AssertEquals(2, Document.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrPreviousChar()

AssertTableEquals({""}, Document[1])
AssertEquals(1, Document.co)

ResetDocumentSet()
Cmd.InsertStringIntoWord("foo")
Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()

-- This should delete the selection only.
Cmd.DeleteSelectionOrNextChar()

AssertEquals("o", Document[1][1])
AssertEquals(1, Document.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrNextChar()

AssertEquals("", Document[1][1])
AssertEquals(1, Document.co)


