require("tests/testsuite")

AssertTableEquals({"one", "two", "three"}, SplitString("one two three", "%s"))

AssertEquals("foo",     GetWordSimpleText("foo"))
AssertEquals("foo",		GetWordSimpleText("foo."))
AssertEquals("foo",		GetWordSimpleText("(foo)"))
AssertEquals("foo-bar", GetWordSimpleText("foo-bar"))
AssertEquals("foo+bar", GetWordSimpleText("foo+bar"))
AssertEquals("e.g",     GetWordSimpleText("e.g."))
AssertEquals("hello",   GetWordSimpleText("‘Hello’"))
AssertEquals("hello",   GetWordSimpleText("“Hello”"))
AssertEquals("there's", GetWordSimpleText("there's"))
AssertEquals("there's", GetWordSimpleText("there’s"))
AssertEquals("there",   GetWordSimpleText("there;"))

AssertEquals("'Hello'", UnSmartquotify("‘Hello’"))
AssertEquals('"Hello"', UnSmartquotify("“Hello”"))

AssertTableEquals({}, Intersperse({}, 0))
AssertTableEquals({1}, Intersperse({1}, 0))
AssertTableEquals({1, 0, 2}, Intersperse({1, 2}, 0))
AssertTableEquals({1, 0, 2, 0, 3}, Intersperse({1, 2, 3}, 0))

AssertEquals('""',            Format(""))
AssertEquals('"foo"',         Format("foo"))
AssertEquals('"fo\\"o"',      Format('fo"o'))
AssertEquals('"\\17foo"',     Format("\17foo"))
AssertEquals('"\\17foo\\17"', Format("\17foo\17"))

