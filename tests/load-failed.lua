--!nonstrict
loadfile("tests/testsuite.lua")()

AddAllowedMessage("Load failed")

local r = Cmd.LoadDocumentSet("testdocs/README-this file does not exist.wg")
AssertEquals(false, r)


