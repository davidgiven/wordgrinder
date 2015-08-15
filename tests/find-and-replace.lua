require("tests/testsuite")

local function assert_sel(top, bot)
	AssertEquals(not not Document.mp, true)
	AssertTableEquals(top, {Document.mp, Document.mw, Document.mo})
	AssertTableEquals(bot, {Document.cp, Document.cw, Document.co})
end

Cmd.InsertStringIntoParagraph("WordOne WordTwo")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("WordThree")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("WordFour WordFive WordSix")
Cmd.SplitCurrentParagraph()

Cmd.GotoBeginningOfDocument()
Cmd.Find("WordTwo")
assert_sel({1, 2, 1}, {1, 2, 8})

Cmd.GotoBeginningOfDocument()
Cmd.Find("One Word")
assert_sel({1, 1, 5}, {1, 2, 5})

Cmd.GotoBeginningOfDocument()
Cmd.Find("Two Word")
assert_sel({1, 2, 5}, {2, 1, 5})

Cmd.GotoBeginningOfDocument()
Cmd.Find("One Word", "One Two Three")
Cmd.ReplaceThenFind()
AssertTableEquals({"WordOne", "Two", "ThreeTwo"}, Document[1])

Cmd.GotoBeginningOfDocument()
Cmd.Find("two", "TWO")
Cmd.ReplaceThenFind()
AssertTableEquals({"WordOne", "TWO", "ThreeTwo"}, Document[1])

Cmd.GotoBeginningOfDocument()
Cmd.Find("WordOne", "boris")
Cmd.ReplaceThenFind()
AssertTableEquals({"boris", "TWO", "ThreeTwo"}, Document[1])

Cmd.GotoBeginningOfDocument()
Cmd.Find("Two Word", "fred")
Cmd.ReplaceThenFind()
AssertTableEquals({"boris", "TWO", "ThreefredThree"}, Document[1])

Cmd.GotoBeginningOfDocument()
Cmd.Find("fred", " ")
Cmd.ReplaceThenFind()
AssertTableEquals({"boris", "TWO", "Three", "Three"}, Document[1])

