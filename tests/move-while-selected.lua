require("tests/testsuite")

-- Non-sticky

Cmd.InsertStringIntoWord("foo")
Cmd.SetMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

AssertEquals(false, Document.sticky_selection)
AssertEquals(1, Document.mp)
AssertEquals(1, Document.mw)
AssertEquals(4, Document.mo)

-- This should remove the selection.
Cmd.MoveWhileSelected()

AssertEquals(nil, Document.mp)

-- Sticky

ResetDocumentSet()

Cmd.InsertStringIntoWord("foo")
Cmd.ToggleMark()
Cmd.GotoPreviousCharW()
Cmd.GotoPreviousCharW()

AssertEquals(true, Document.sticky_selection)
AssertEquals(1, Document.mp)
AssertEquals(1, Document.mw)
AssertEquals(4, Document.mo)

-- This should *not* remove the selection.
Cmd.MoveWhileSelected()

AssertEquals(1, Document.mp)

-- Ensure that setting a mark at the beginning of a word works.

ResetDocumentSet()
Cmd.InsertStringIntoWord("foo")
Cmd.SplitCurrentWord()
Cmd.SetMark()
AssertEquals(false, Document.sticky_selection)
AssertEquals(1, Document.mp)
AssertEquals(2, Document.mw)
AssertEquals(1, Document.mo)

