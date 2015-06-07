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

-- This should delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("f", Document[1][1])

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

-- This should *not* delete the selection.
Cmd.TypeWhileSelected()

AssertEquals("foo", Document[1][1])

