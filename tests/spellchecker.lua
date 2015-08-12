require("tests/testsuite")

local function unset(s)
	local a = {}
	for k in pairs(s) do
		a[#a+1] = k
	end
	return a
end

Cmd.InsertStringIntoWord("fnord")
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

Cmd.DeleteWord()
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

DocumentSet.addons.spellchecker.enabled = false
local payload = { word="fnord", cstyle=0, ostyle=0 }
FireEvent(Event.DrawWord, payload)
AssertTableEquals({"fnord", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

DocumentSet.addons.spellchecker.enabled = true
DocumentSet.addons.spellchecker.useuserdictionary = true
local payload = { word="fnord", cstyle=0, ostyle=0 }
FireEvent(Event.DrawWord, payload)
AssertTableEquals({"fnord", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

local payload = { word="fnord.", cstyle=0, ostyle=0 }
FireEvent(Event.DrawWord, payload)
AssertTableEquals({"fnord.", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

local payload = { word="notfound", cstyle=0, ostyle=0 }
FireEvent(Event.DrawWord, payload)
AssertTableEquals({"notfound", wg.DIM, 0},
	{payload.word, payload.cstyle, payload.ostyle})

Cmd.InsertStringIntoParagraph("foo bar baz")
Cmd.GotoBeginningOfDocument()
Cmd.FindNextMisspeltWord()
AssertTableEquals({1, 1, 1}, {Document.mp, Document.mw, Document.mo})
AssertTableEquals({1, 1, 4}, {Document.cp, Document.cw, Document.co})

Cmd.FindNextMisspeltWord()
AssertTableEquals({1, 2, 1}, {Document.mp, Document.mw, Document.mo})
AssertTableEquals({1, 2, 4}, {Document.cp, Document.cw, Document.co})

