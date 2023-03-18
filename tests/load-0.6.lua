--!strict
loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.6.wg")
AssertEquals(true, r)


