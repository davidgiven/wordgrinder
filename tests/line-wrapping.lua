--!nonstrict
loadfile("tests/testsuite.lua")()

Cmd.InsertStringIntoParagraph("The quick brown fox jumps over the lazy dog.")

documentStyles["P"].indent = 0
documentStyles["P"].firstindent = nil

local para = currentDocument[1]
para._wrapdata = nil
local wd = para:wrap(20)
AssertEquals(3, #wd.lines)

AssertTableEquals({1, 2, 3}, wd.lines[1])
AssertTableEquals({4, 5, 6, 7}, wd.lines[2])
AssertTableEquals({8, 9}, wd.lines[3])

AssertTableEquals({0, 4, 10, 0, 4, 10, 15, 0, 5}, wd.xs)

documentStyles["P"].indent = 4
documentStyles["P"].firstindent = nil

local para = currentDocument[1]
para._wrapdata = nil
local wd = para:wrap(20)
AssertEquals(4, #wd.lines)

AssertTableEquals({1, 2}, wd.lines[1])
AssertTableEquals({3, 4}, wd.lines[2])
AssertTableEquals({5, 6, 7}, wd.lines[3])
AssertTableEquals({8, 9}, wd.lines[4])

AssertTableEquals({0, 4, 0, 6, 0, 6, 11, 0, 5}, wd.xs)

documentStyles["P"].indent = 0
documentStyles["P"].firstindent = 15

local para = currentDocument[1]
para._wrapdata = nil
local wd = para:wrap(20)
AssertEquals(4, #wd.lines)

AssertTableEquals({1}, wd.lines[1])
AssertTableEquals({2, 3, 4}, wd.lines[2])
AssertTableEquals({5, 6, 7}, wd.lines[3])
AssertTableEquals({8, 9}, wd.lines[4])

AssertTableEquals({0, 0, 6, 12, 0, 6, 11, 0, 5}, wd.xs)
