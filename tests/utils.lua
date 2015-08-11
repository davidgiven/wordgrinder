require("tests/testsuite")

AssertTableEquals({"one", "two", "three"}, SplitString("one two three", "%s"))

