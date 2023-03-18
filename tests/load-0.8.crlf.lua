loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.8.crlf.wg")
AssertEquals(true, r)


