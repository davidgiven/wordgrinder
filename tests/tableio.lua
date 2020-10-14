require("tests/testsuite")

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

local r, e = SaveToStream(tmpfile, {data = t})
AssertEquals(nil, e)

local tt, e = LoadFromStream(tmpfile)
AssertEquals(nil, e)
AssertTableEquals(t, tt.data)

