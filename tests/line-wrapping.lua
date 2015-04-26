require("tests/testsuite")

Cmd.InsertStringIntoParagraph("The quick brown fox jumps over the lazy dog.")

local para = Document[1]
local lines = para:wrap(20)
AssertEquals(3, #lines)

AssertTableEquals({1, 2, 3}, lines[1])
AssertTableEquals({4, 5, 6, 7}, lines[2])
AssertTableEquals({8, 9}, lines[3])

AssertTableEquals({0, 4, 10, 0, 4, 10, 15, 0, 5}, para.xs)
