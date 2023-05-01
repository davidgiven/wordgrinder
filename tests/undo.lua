--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.Checkpoint()
Cmd.InsertStringIntoParagraph("Hello,")
Cmd.SplitCurrentWord()
Cmd.Checkpoint()
Cmd.InsertStringIntoParagraph("world!")
Cmd.SplitCurrentParagraph()

AssertEquals(2, #currentDocument)
AssertTableEquals({"Hello,", "world!"}, currentDocument[1])
AssertTableEquals({"\016"}, currentDocument[2])
AssertEquals(2, #currentDocument._undostack)
AssertEquals(0, #currentDocument._redostack)

Cmd.Undo()

AssertEquals(1, #currentDocument)
AssertTableEquals({"Hello,", "\016"}, currentDocument[1])
AssertEquals(1, #currentDocument._undostack)
AssertEquals(1, #currentDocument._redostack)

Cmd.Undo()

AssertEquals(1, #currentDocument)
AssertTableEquals({""}, currentDocument[1])
AssertEquals(0, #currentDocument._undostack)
AssertEquals(2, #currentDocument._redostack)

Cmd.Redo()

AssertEquals(1, #currentDocument)
AssertTableEquals({"Hello,", "\016"}, currentDocument[1])
AssertEquals(1, #currentDocument._undostack)
AssertEquals(1, #currentDocument._redostack)

Cmd.Checkpoint()

AssertEquals(2, #currentDocument._undostack)
AssertEquals(0, #currentDocument._redostack)

