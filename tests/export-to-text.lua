require("tests/testsuite")

Cmd.InsertStringIntoParagraph("one two three")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("four")
Cmd.SplitCurrentWord()
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("bold")
Cmd.SetStyle("b")
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("italic")
Cmd.SetStyle("i")
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("underline")
Cmd.SetStyle("u")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("heading")
Cmd.ChangeParagraphStyle("H1")

local expected = [[
one two three
four bolditalicunderline
heading
]]

local output = Cmd.ExportToTextString()
AssertEquals(expected, output)
