--!nonstrict
loadfile("tests/testsuite.lua")()

ScreenWidth = 80
currentDocument:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("can change the font (the default one is pretty ugly; I recommend Consolas) and switch in and out of full-screen mode.")

AssertEquals(1, #currentDocument)

--Cmd.GotoBeginningOfLine()
Cmd.GotoEndOfLine()
Cmd.InsertStringIntoParagraph("!")

AssertTableEquals({"can", "change", "the", "font", "(the", "default", "one", "is", "pretty", "ugly;", "I", "recommend", "Consolas)", "and", "switch", "in", "and", "out", "of", "full-screen", "mode.!"}, currentDocument[1])

