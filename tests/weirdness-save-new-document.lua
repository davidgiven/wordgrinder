require("tests/testsuite")

local function assert_class(t, c)
	AssertEquals(GetClass(t), c)
end

Cmd.InsertStringIntoParagraph("fnord")
assert_class(Document[1], ParagraphClass)
Cmd.AddBlankDocument("other")
Cmd.InsertStringIntoParagraph("blarg")
assert_class(Document[1], ParagraphClass)

local filename = os.tmpname()
AssertEquals(Cmd.SaveCurrentDocumentAs(filename), true)
AssertEquals(Cmd.LoadDocumentSet(filename), true)

Cmd.ChangeDocument("main")
AssertTableEquals({"fnord"}, Document[1])
assert_class(Document[1], ParagraphClass)
AssertNotNull(Document[1].getLineOfWord)
Cmd.ChangeDocument("other")
AssertTableEquals({"blarg"}, Document[1])
AssertNotNull(Document[1].getLineOfWord)
AssertNotNull(Document[1].style)

