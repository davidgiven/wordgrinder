require("tests/testsuite")

AssertTableEquals({"one", "two", "three"}, SplitString("one two three", "%s"))

AssertEquals("foo",     GetWordSimpleText("foo"))
AssertEquals("foo",		GetWordSimpleText("foo."))
AssertEquals("foo",		GetWordSimpleText("(foo)"))
AssertEquals("foo-bar", GetWordSimpleText("foo-bar"))
AssertEquals("foo+bar", GetWordSimpleText("foo+bar"))
AssertEquals("e.g",     GetWordSimpleText("e.g."))
AssertEquals("Hello",   GetWordSimpleText("‘Hello’"))
AssertEquals("Hello",   GetWordSimpleText("“Hello”"))
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

AssertEquals("/foo/bar",      Dirname("/foo/bar/baz"))
AssertEquals("/foo/bar",      Dirname("/foo/bar/"))
AssertEquals("/foo",          Dirname("/foo/bar"))
AssertEquals("/foo",          Dirname("/foo/"))
AssertEquals("/",             Dirname("/foo"))
AssertEquals("/",             Dirname("/"))
AssertEquals(".",             Dirname("foo"))

AssertEquals("baz",           Leafname("/foo/bar/baz"))
AssertEquals("",              Leafname("/foo/bar/"))
AssertEquals("bar",           Leafname("/foo/bar"))
AssertEquals("",              Leafname("/foo/"))
AssertEquals("foo",           Leafname("/foo"))
AssertEquals("",              Leafname("/"))
AssertEquals("foo",           Leafname("foo"))

AssertEquals("foo", LargestCommonPrefix({ "foo", "foobar" }))
AssertEquals("foo", LargestCommonPrefix({ "foof", "foobar" }))
AssertEquals("foo", LargestCommonPrefix({ "foonly", "foobar", "footle" }))
AssertEquals("foo", LargestCommonPrefix({ "foo" }))
AssertEquals(nil,   LargestCommonPrefix({ }))

local fp = CreateIStream("foo\nbar\nbaz\n\nbib")
local t = {}
for s in fp:lines() do
	t[#t+1] = s
end
AssertTableEquals({"foo", "bar", "baz", "", "bib"}, t)

