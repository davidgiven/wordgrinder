--!nonstrict
loadfile("tests/testsuite.lua")()

local dir = wg.mkdtemp()

local t, _, errno = wg.mkdirs(dir.."/foo/bar/baz")
AssertEquals(nil, errno)

local t, _, errno = wg.readdir(dir.."/foo/bar")
AssertEquals(nil, errno)
table.sort(t)
AssertTableEquals({ ".", "..", "baz" }, t)

t, _, errno = wg.stat(dir.."/foo/bar/baz")
AssertEquals(nil, errno)
AssertEquals("directory", t.mode)

t, _, errno = wg.stat(dir.."/foo/bar/bloo")
AssertEquals(wg.ENOENT, errno)

