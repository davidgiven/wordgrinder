--!nonstrict
loadfile("tests/testsuite.lua")()

local r = Cmd.LoadDocumentSet("testdocs/README-v0.1.wg")
AssertEquals(true, r)

