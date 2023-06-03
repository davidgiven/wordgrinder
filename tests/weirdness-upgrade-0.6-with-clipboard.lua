--!nonstrict
loadfile("tests/testsuite.lua")()

AssertEquals(Cmd.LoadDocumentSet("testdocs/0.6-with-clipboard.wg"), true)
local filename = wg.mkdtemp().."/tempfile"
AssertEquals(Cmd.SaveCurrentDocumentAs(filename), true)
