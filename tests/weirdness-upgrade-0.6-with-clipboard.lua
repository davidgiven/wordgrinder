require("tests/testsuite")

AssertEquals(Cmd.LoadDocumentSet("testdocs/0.6-with-clipboard.wg"), true)
local filename = os.tmpname()
AssertEquals(Cmd.SaveCurrentDocumentAs(filename), true)
