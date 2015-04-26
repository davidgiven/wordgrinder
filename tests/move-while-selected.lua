require("tests/testsuite")

-- Non-sticky

Cmd.InsertStringIntoWord("foo")
FlushAsyncEvents()
Cmd.SetMark()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

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
FlushAsyncEvents()
Cmd.ToggleMark()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()
Cmd.GotoPreviousCharW()
FlushAsyncEvents()

AssertEquals(true, Document.sticky_selection)
AssertEquals(1, Document.mp)
AssertEquals(1, Document.mw)
AssertEquals(4, Document.mo)

-- This should *not* remove the selection.
Cmd.MoveWhileSelected()

AssertEquals(1, Document.mp)

