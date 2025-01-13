--!nonstrict
loadfile("tests/testsuite.lua")()

local function unset(s)
	local a = {}
	for k in pairs(s) do
		a[#a+1] = k
	end
	return a
end

SetSystemDictionaryForTesting({"lower", "UPPER", "there's"})

Cmd.InsertStringIntoWord("fnord")
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

Cmd.DeleteWord()
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

documentSet.addons.spellchecker.enabled = false
local payload = { word="fnord", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"fnord", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

documentSet.addons.spellchecker.enabled = true
documentSet.addons.spellchecker.useuserdictionary = true
documentSet.addons.spellchecker.usesystemdictionary = false
local payload = { word="fnord", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"fnord", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

local payload = { word="fnord.", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"fnord.", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

local payload = { word="There’s", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"There’s", wg.DIM, 0},
	{payload.word, payload.cstyle, payload.ostyle})

local payload = { word="notfound", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"notfound", wg.DIM, 0},
	{payload.word, payload.cstyle, payload.ostyle})

documentSet.addons.spellchecker.enabled = true
documentSet.addons.spellchecker.useuserdictionary = true
documentSet.addons.spellchecker.usesystemdictionary = true
AssertEquals(false, IsWordMisspelt("lower", true))
AssertEquals(false, IsWordMisspelt("Lower", true))
AssertEquals(false, IsWordMisspelt("lower", false))
AssertEquals(true, IsWordMisspelt("Lower", false))

AssertEquals(true, IsWordMisspelt("LOWER", true))
AssertEquals(true, IsWordMisspelt("LOWER", false))

AssertEquals(true, IsWordMisspelt("upper", true))
AssertEquals(true, IsWordMisspelt("Upper", true))
AssertEquals(true, IsWordMisspelt("upper", false))
AssertEquals(true, IsWordMisspelt("Upper", false))

AssertEquals(false, IsWordMisspelt("UPPER", true))
AssertEquals(false, IsWordMisspelt("UPPER", false))

AssertEquals(false, IsWordMisspelt("there’s", false))
AssertEquals(true, IsWordMisspelt("There’s", false))
AssertEquals(false, IsWordMisspelt("there’s", true))
AssertEquals(false, IsWordMisspelt("There’s", true))

documentSet.addons.spellchecker.useuserdictionary = true
documentSet.addons.spellchecker.usesystemdictionary = true
local payload = { word="fnord", cstyle=0, ostyle=0 }
FireEvent("DrawWord", payload)
AssertTableEquals({"fnord", 0, 0},
	{payload.word, payload.cstyle, payload.ostyle})

-- FindNextMisspeltWord

SetSystemDictionaryForTesting({"bar", "exclamation", "correct"})

Cmd.InsertStringIntoParagraph("foo bar baz exclamation! Correct. incorroct")
Cmd.GotoBeginningOfDocument()
Cmd.FindNextMisspeltWord()
AssertTableEquals({1, 1, 1}, {currentDocument.mp, currentDocument.mw, currentDocument.mo})
AssertTableEquals({1, 1, 4}, {currentDocument.cp, currentDocument.cw, currentDocument.co})

Cmd.FindNextMisspeltWord()
AssertTableEquals({1, 3, 1}, {currentDocument.mp, currentDocument.mw, currentDocument.mo})
AssertTableEquals({1, 3, 4}, {currentDocument.cp, currentDocument.cw, currentDocument.co})

Cmd.FindNextMisspeltWord()
AssertTableEquals({1, 6, 1}, {currentDocument.mp, currentDocument.mw, currentDocument.mo})
AssertTableEquals({1, 6, 10}, {currentDocument.cp, currentDocument.cw, currentDocument.co})

