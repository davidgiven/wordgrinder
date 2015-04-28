require("tests/testsuite")

Cmd.Checkpoint()
Cmd.InsertStringIntoParagraph("Hello,")
Cmd.SplitCurrentWord()
Cmd.Checkpoint()
Cmd.InsertStringIntoParagraph("world!")
Cmd.SplitCurrentParagraph()

AssertEquals(2, #Document)
AssertTableEquals({"Hello,", "world!"}, Document[1])
AssertTableEquals({"\016"}, Document[2])
AssertEquals(2, #Document.undostack)
AssertEquals(0, #Document.redostack)

Cmd.Undo()

AssertEquals(1, #Document)
AssertTableEquals({"Hello,", "\016"}, Document[1])
AssertEquals(1, #Document.undostack)
AssertEquals(1, #Document.redostack)

Cmd.Undo()

AssertEquals(1, #Document)
AssertTableEquals({""}, Document[1])
AssertEquals(0, #Document.undostack)
AssertEquals(2, #Document.redostack)

Cmd.Redo()

AssertEquals(1, #Document)
AssertTableEquals({"Hello,", "\016"}, Document[1])
AssertEquals(1, #Document.undostack)
AssertEquals(1, #Document.redostack)

Cmd.Checkpoint()

AssertEquals(2, #Document.undostack)
AssertEquals(0, #Document.redostack)

