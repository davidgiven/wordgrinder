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

-- This should delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("f", Document[1][1])

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

-- This should *not* delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("foo", Document[1][1])

