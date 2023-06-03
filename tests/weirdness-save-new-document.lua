--!nonstrict
loadfile("tests/testsuite.lua")()

local function assert_class(t, c)
	AssertEquals(GetClass(t), c)
end

Cmd.InsertStringIntoParagraph("fnord")
assert_class(currentDocument[1], Paragraph)
Cmd.AddBlankDocument("other")
Cmd.InsertStringIntoParagraph("blarg")
assert_class(currentDocument[1], Paragraph)

local filename = wg.mkdtemp().."/tempfile"
AssertEquals(Cmd.SaveCurrentDocumentAs(filename), true)
AssertEquals(Cmd.LoadDocumentSet(filename), true)

Cmd.ChangeDocument("main")
AssertTableEquals({"fnord"}, currentDocument[1])
assert_class(currentDocument[1], Paragraph)
AssertNotNull(currentDocument[1].getLineOfWord)
Cmd.ChangeDocument("other")
AssertTableEquals({"blarg"}, currentDocument[1])
AssertNotNull(currentDocument[1].getLineOfWord)
AssertNotNull(currentDocument[1].style)

