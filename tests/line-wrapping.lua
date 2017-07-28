require("tests/testsuite")

Cmd.InsertStringIntoParagraph("The quick brown fox jumps over the lazy dog.")

DocumentStyles["P"].indent = 0
DocumentStyles["P"].firstindent = nil

local para = Document[1]
local lines = para:wrap(20)
AssertEquals(3, #lines)

AssertTableEquals({1, 2, 3}, lines[1])
AssertTableEquals({4, 5, 6, 7}, lines[2])
AssertTableEquals({8, 9}, lines[3])

AssertTableEquals({0, 4, 10, 0, 4, 10, 15, 0, 5}, para.xs)

DocumentStyles["P"].indent = 4
DocumentStyles["P"].firstindent = nil

local para = Document[1]
local lines = para:wrap(20)
AssertEquals(4, #lines)

AssertTableEquals({1, 2}, lines[1])
AssertTableEquals({3, 4}, lines[2])
AssertTableEquals({5, 6, 7}, lines[3])
AssertTableEquals({8, 9}, lines[4])

AssertTableEquals({0, 4, 0, 6, 0, 6, 11, 0, 5}, para.xs)

DocumentStyles["P"].indent = 0
DocumentStyles["P"].firstindent = 15

local para = Document[1]
local lines = para:wrap(20)
AssertEquals(4, #lines)

AssertTableEquals({1}, lines[1])
AssertTableEquals({2, 3, 4}, lines[2])
AssertTableEquals({5, 6, 7}, lines[3])
AssertTableEquals({8, 9}, lines[4])

AssertTableEquals({0, 0, 6, 12, 0, 6, 11, 0, 5}, para.xs)
