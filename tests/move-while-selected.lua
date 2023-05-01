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

-- This should remove the selection.
Cmd.MoveWhileSelected()

AssertEquals(nil, currentDocument.mp)

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

-- This should *not* remove the selection.
Cmd.MoveWhileSelected()

AssertEquals(1, currentDocument.mp)

-- Ensure that setting a mark at the beginning of a word works.

ResetDocumentSet()
Cmd.InsertStringIntoWord("foo")
Cmd.SplitCurrentWord()
Cmd.SetMark()
AssertEquals(false, currentDocument.sticky_selection)
AssertEquals(1, currentDocument.mp)
AssertEquals(2, currentDocument.mw)
AssertEquals(1, currentDocument.mo)

