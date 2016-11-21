require "tests/testsuite"

ScreenWidth = 80
Document:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("foo bar baz")

AssertEquals(1, #Document)

Cmd.GotoBeginningOfLine()
Cmd.GotoNextWord()
Cmd.GotoNextWord()
Cmd.GotoNextWord()

AssertTableEquals({1, 3, 4}, {Document.cp, Document.cw, Document.co})
