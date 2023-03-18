loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.3.3.wg")
AssertEquals(true, r)


