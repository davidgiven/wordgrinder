--!nonstrict
loadfile("tests/testsuite.lua")()

documentSet.addons.smartquotes.singlequotes = true
documentSet.addons.smartquotes.doublequotes = true
documentSet.addons.smartquotes.notinraw = true

-- Fake typing on the keyboard.
local function typestring(s)
	for c in s:gmatch(".") do
		local payload = { value = c }
		FireEvent("KeyTyped", payload)

		local c = payload.value
		if (c == " ") then
			Cmd.SplitCurrentWord()
		else
			Cmd.InsertStringIntoWord(c)
		end
	end
end

typestring("'Hello, world!'")
AssertTableEquals({"‘Hello,", "world!’"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

typestring('"Hello, world!"')
AssertTableEquals({"“Hello,", "world!”"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

typestring("flob's")
AssertTableEquals({"flob’s"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("RAW")
typestring("not'd")
AssertTableEquals({"not'd"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

Cmd.ChangeParagraphStyle("P")
Cmd.SetStyle("b")
typestring("'fnord'")
AssertTableEquals({"\24‘fnord’"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

Cmd.SetStyle("o")
Cmd.SetStyle("i")
typestring("'")
Cmd.SetStyle("b")
typestring("fnord'")
AssertTableEquals({"\17‘\25fnord’"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

documentSet.addons.smartquotes.rightsingle = "%"
Cmd.ChangeParagraphStyle("P")
typestring("blorb's")
AssertTableEquals({"blorb%s"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

documentSet.addons.smartquotes.rightsingle = "’"
typestring([["Once upon a time," said K'trx'frn, "there was an aardvark called Albert."]])
AssertTableEquals({"“Once", "upon", "a", "time,”", "said", "K’trx’frn,",
	"“there", "was", "an", "aardvark", "called", "Albert.”"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

typestring("fnord")
Cmd.GotoBeginningOfWord()
typestring('"')
Cmd.GotoEndOfWord()
AssertTableEquals({"“fnord"}, currentDocument[currentDocument.cp])
Cmd.SplitCurrentParagraph()

typestring("\"'nested'\"")
AssertTableEquals({"“‘nested’”"}, currentDocument[currentDocument.cp])

