require("tests/testsuite")

local fp, message, errno = io.open("/this/file/does/not/exist")
AssertEquals(errno, wg.ENOENT)
