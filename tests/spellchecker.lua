require("tests/testsuite")

local function unset(s)
	local a = {}
	for k in pairs(s) do
		a[#a+1] = k
	end
	return a
end

Cmd.InsertStringIntoWord("fnord")
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

Cmd.DeleteWord()
Cmd.AddToUserDictionary()
AssertTableEquals({"fnord"}, unset(GetUserDictionary()))

