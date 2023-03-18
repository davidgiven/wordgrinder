--!strict
loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.7.2.wg")
AssertEquals(true, r)


