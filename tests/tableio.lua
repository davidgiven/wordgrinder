loadfile("tests/testsuite.lua")()

local tmpfile = os.tmpname()

local t = {
	foo = {
		bar = {
			n = 1,
			s = "one"
		}
	},
	array = { "one", "two", "three" }
}

local r, e = SaveToFile(tmpfile, {data = t})
AssertEquals(nil, e)

local tt, e = LoadFromFile(tmpfile)
AssertEquals(nil, e)
AssertTableEquals(t, tt.data)

