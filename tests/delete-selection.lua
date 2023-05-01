--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoWord("foo")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

-- This should delete the selection only.
Cmd.DeleteSelectionOrPreviousChar()

AssertTableEquals({"f"}, currentDocument[1])
AssertEquals(2, currentDocument.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrPreviousChar()

AssertTableEquals({""}, currentDocument[1])
AssertEquals(1, currentDocument.co)

ResetDocumentSet()
Cmd.InsertStringIntoWord("foo")
Cmd.GotoBeginningOfDocument()
Cmd.SetMark()
Cmd.GotoNextCharW()
Cmd.GotoNextCharW()

-- This should delete the selection only.
Cmd.DeleteSelectionOrNextChar()

AssertEquals("o", currentDocument[1][1])
AssertEquals(1, currentDocument.co)

-- Doing it again will delete the remaining char.

Cmd.DeleteSelectionOrNextChar()

AssertEquals("", currentDocument[1][1])
AssertEquals(1, currentDocument.co)


