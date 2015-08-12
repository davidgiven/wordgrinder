require("tests/testsuite")

AssertTableEquals({"one", "two", "three"}, SplitString("one two three", "%s"))

AssertEquals("foo", GetWordSimpleText("foo"))
AssertEquals("foo", GetWordSimpleText("foo."))
AssertEquals("foo", GetWordSimpleText("(foo)"))
AssertEquals("hello", GetWordSimpleText("‘Hello’"))
AssertEquals("hello", GetWordSimpleText("“Hello”"))
AssertEquals("there's", GetWordSimpleText("there's"))
AssertEquals("there's", GetWordSimpleText("there’s"))

AssertEquals("'Hello'", UnSmartquotify("‘Hello’"))
AssertEquals('"Hello"', UnSmartquotify("“Hello”"))

