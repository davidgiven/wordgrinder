require("tests/testsuite")

local GetStyleFromWord = wg.getstylefromword

AssertEquals(0, GetStyleFromWord("foo", 1))
AssertEquals(1, GetStyleFromWord("\017foo", 2))
AssertEquals(0, GetStyleFromWord("\017f\016oo", 4))
AssertEquals(0, GetStyleFromWord("f\017oo", 1))
AssertEquals(0, GetStyleFromWord("f\017oo", 2))
AssertEquals(1, GetStyleFromWord("f\017oo", 3))

