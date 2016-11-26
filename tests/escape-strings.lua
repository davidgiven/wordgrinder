local escape = wg.escape
local unescape = wg.unescape

require("tests/testsuite")

AssertEquals("1234", escape("1234"))
AssertEquals("12\\n34", escape("12\n34"))
AssertEquals("12\\r34", escape("12\r34"))
AssertEquals("12💩34", escape("12💩34"))
AssertEquals('12\\"34', escape('12"34'))
AssertEquals('12\\\\34', escape('12\\34'))
AssertEquals("", escape(""))

AssertEquals("1234", unescape("1234"))
AssertEquals("12\n34", unescape("12\\n34"))
AssertEquals("12\r34", unescape("12\\r34"))
AssertEquals("12💩34", unescape("12💩34"))
AssertEquals('12\"34', unescape('12\\"34'))
AssertEquals('12\\34', unescape('12\\\\34'))
AssertEquals("", unescape(""))
