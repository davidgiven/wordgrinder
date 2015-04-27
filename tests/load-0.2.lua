require("tests/testsuite")

local r = Cmd.LoadDocumentSet("testdocs/README-v0.2.wg")
AssertEquals(true, r)

