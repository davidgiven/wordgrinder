require "tests/testsuite"

Cmd.InsertStringIntoParagraph("The quick brown fox jumps")
Cmd.SplitCurrentParagraph()
Cmd.ChangeParagraphStyle("RAW")
Cmd.InsertStringIntoParagraph("over the lazy")
Cmd.SplitCurrentParagraph()
Cmd.ChangeParagraphStyle("P")
Cmd.InsertStringIntoParagraph("dog.")

Cmd.GotoBeginningOfDocument()
Cmd.GotoNextCharW()
Cmd.SetMark()
Cmd.GotoEndOfDocument()
Cmd.GotoPreviousCharW()
Cmd.Copy()
Cmd.UnsetMark()

AssertEquals(3, #DocumentSet.clipboard)

local filename = os.tmpname()
AssertEquals(Cmd.SaveCurrentDocumentAs(filename), true)
AssertEquals(Cmd.LoadDocumentSet(filename), true)

AssertEquals(3, #DocumentSet.clipboard)
