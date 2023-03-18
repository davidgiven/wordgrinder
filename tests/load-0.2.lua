--!strict
loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.2.wg")
AssertEquals(true, r)

