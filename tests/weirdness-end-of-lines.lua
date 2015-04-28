require "tests/testsuite"

ScreenWidth = 80
Document:wrap(ScreenWidth)

Cmd.InsertStringIntoParagraph("can change the font (the default one is pretty ugly; I recommend Consolas) and switch in and out of full-screen mode.")

AssertEquals(1, #Document)

--Cmd.GotoBeginningOfLine()
Cmd.GotoEndOfLine()
Cmd.InsertStringIntoParagraph("!")

AssertTableEquals({"can", "change", "the", "font", "(the", "default", "one", "is", "pretty", "ugly;", "I", "recommend", "Consolas)", "and", "switch", "in", "and", "out", "of", "full-screen", "mode.!"}, Document[1])

