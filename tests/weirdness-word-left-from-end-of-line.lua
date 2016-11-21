require "tests/testsuite"

ScreenWidth = 80
Document:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("foo bar baz")

AssertEquals(1, #Document)

Cmd.GotoEndOfLine()
Cmd.GotoPreviousWord()

AssertTableEquals({Document.cp, Document.cw, Document.co}, {1, 3, 1})
