require("tests/testsuite")

local w = "\17→Edit→FnordFile→Edit→Fnord"
AssertEquals("\17→", wg.deletefromword(w, 5, #w+1))

Cmd.InsertStringIntoParagraph("Word File→Edit→Fnord Word")
Cmd.GotoPreviousWord()
Cmd.GotoPreviousWord()
Cmd.GotoBeginningOfWord()
Cmd.SetMark()
Cmd.GotoEndOfWord()
Cmd.SetStyle("i")
AssertTableEquals({"Word", "\17File→Edit→Fnord", "Word"}, Document[1])

Cmd.UnsetMark()
Cmd.GotoBeginningOfWord()
Cmd.SetMark()
Cmd.GotoEndOfWord()
Cmd.Copy()
AssertTableEquals({"\17File→Edit→Fnord"}, DocumentSet:getClipboard()[1])
Cmd.Paste()
AssertTableEquals({"Word", "\17File→Edit→FnordFile→Edit→Fnord", "Word"}, Document[1])

Cmd.UnsetMark()
Cmd.GotoBeginningOfWord()
Cmd.GotoNextChar()
Cmd.GotoNextChar()
Cmd.GotoNextChar()
Cmd.GotoNextChar()
Cmd.SetMark()
Cmd.GotoNextChar()
Cmd.Copy()
AssertTableEquals({"\17→"}, DocumentSet:getClipboard()[1])

