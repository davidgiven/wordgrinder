--!nonstrict
loadfile("tests/testsuite.lua")()

-- Non-sticky

Cmd.InsertStringIntoWord("foo")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

AssertEquals(false, currentDocument.sticky_selection)
AssertEquals(1, currentDocument.mp)
AssertEquals(1, currentDocument.mw)
AssertEquals(4, currentDocument.mo)

-- This should delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("f", currentDocument[1][1])

-- Sticky

ResetDocumentSet()

Cmd.InsertStringIntoWord("foo")
Cmd.ToggleMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

AssertEquals(true, currentDocument.sticky_selection)
AssertEquals(1, currentDocument.mp)
AssertEquals(1, currentDocument.mw)
AssertEquals(4, currentDocument.mo)

-- This should *not* delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("foo", currentDocument[1][1])

