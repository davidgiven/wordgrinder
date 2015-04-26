require "tests/testsuite"

local p = CreateParagraph("P", {"one"})
AssertTableEquals({"one"}, p)

local p = CreateParagraph("P", {"one", "two"}, {"three"})
AssertTableEquals({"one", "two", "three"}, p)

AssertTableEquals({"one"}, p:sub(1, 1))
AssertTableEquals({"one", "two"}, p:sub(1, 2))
AssertTableEquals({"one", "two", "three"}, p:sub(1, 3))
AssertTableEquals({"one", "two", "three"}, p:sub(1, 4))
AssertTableEquals({"one", "two", "three"}, p:sub(1))
AssertTableEquals({"two", "three"}, p:sub(2, 2))
AssertTableEquals({"two", "three"}, p:sub(2, 3))
AssertTableEquals({"two", "three"}, p:sub(2))
