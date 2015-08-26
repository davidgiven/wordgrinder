require("tests/testsuite")

DocumentSet.addons.smartquotes.singlequotes = true
DocumentSet.addons.smartquotes.doublequotes = true
DocumentSet.addons.smartquotes.notinraw = true

-- Fake typing on the keyboard.
local function typestring(s)
	for c in s:gmatch(".") do
		local payload = { value = c }
		FireEvent(Event.KeyTyped, payload)

		local c = payload.value
		if (c == " ") then
			Cmd.SplitCurrentWord()
		else
			Cmd.InsertStringIntoWord(c)
		end
	end
end

typestring("'Hello, world!'")
AssertTableEquals({"‘Hello,", "world!’"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

typestring('"Hello, world!"')
AssertTableEquals({"“Hello,", "world!”"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

typestring("flob's")
AssertTableEquals({"flob’s"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("RAW")
typestring("not'd")
AssertTableEquals({"not'd"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("P")
Cmd.SetStyle("b")
typestring("'fnord'")
AssertTableEquals({"\24‘fnord’"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

Cmd.SetStyle("o")
Cmd.SetStyle("i")
typestring("'")
Cmd.SetStyle("b")
typestring("fnord'")
AssertTableEquals({"\17‘\25fnord’"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

DocumentSet.addons.smartquotes.rightsingle = "%"
Cmd.ChangeParagraphStyle("P")
typestring("blorb's")
AssertTableEquals({"blorb%s"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

DocumentSet.addons.smartquotes.rightsingle = "’"
typestring([["Once upon a time," said K'trx'frn, "there was an aardvark called Albert."]])
AssertTableEquals({"“Once", "upon", "a", "time,”", "said", "K’trx’frn,",
	"“there", "was", "an", "aardvark", "called", "Albert.”"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

typestring("fnord")
Cmd.GotoBeginningOfWord()
typestring('"')
Cmd.GotoEndOfWord()
AssertTableEquals({"“fnord"}, Document[Document.cp])
Cmd.SplitCurrentParagraph()

typestring("\"'nested'\"")
AssertTableEquals({"“‘nested’”"}, Document[Document.cp])

