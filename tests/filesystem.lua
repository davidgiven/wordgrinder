require("tests/testsuite")

local tmpfile = os.tmpname()
local dir = tmpfile..".dir"

AssertEquals(true, Mkdirs(dir.."/foo/bar/baz"))

local t, _, errno = wg.readdir(dir.."/foo/bar")
AssertEquals(nil, errno)
AssertTableEquals({ ".", "..", "baz" }, t)

t, _, errno = wg.stat(dir.."/foo/bar/baz")
AssertEquals(nil, errno)
AssertEquals("directory", t.mode)

t, _, errno = wg.stat(dir.."/foo/bar/bloo")
AssertEquals(wg.ENOENT, errno)

