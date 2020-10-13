require("tests/testsuite")

local longarg
local shortarg
local filename
local unknown

local argmap = {
	["long"] = function()          longarg = true end,
	["longparam"] = function(arg)  longarg = arg return 1 end,
	["s"] = function()             shortarg = true end,
	["p"] = function(arg)          shortarg = arg return 1 end,
	[UNKNOWN_ARG] = function()     unknown = true end,
	[FILENAME_ARG] = function(arg) filename = arg return 1 end,
}

local function reset()
	longarg = nil
	shortarg = nil
	filename = nil
	unknown = nil
end

reset()
ParseArguments({}, argmap)
AssertEquals(true, not longarg and not shortarg and not filename and not unknown)

reset()
ParseArguments({ "--long" }, argmap)
AssertEquals(true, longarg and not shortarg and not filename and not unknown)

reset()
ParseArguments({ "--long", "-s" }, argmap)
AssertEquals(true, longarg and shortarg and not filename and not unknown)

reset()
ParseArguments({ "--longparam", "7" }, argmap)
AssertEquals(true, (longarg == "7") and not shortarg and not filename and not unknown)

reset()
ParseArguments({ "--longparam", "7", "-s" }, argmap)
AssertEquals(true, (longarg == "7") and shortarg and not filename and not unknown)

reset()
ParseArguments({ "-s" }, argmap)
AssertEquals(true, not longarg and shortarg and not filename and not unknown)

reset()
ParseArguments({ "-s", "--long" }, argmap)
AssertEquals(true, longarg and shortarg and not filename and not unknown)

reset()
ParseArguments({ "-p", "7", "--long" }, argmap)
AssertEquals(true, longarg and (shortarg == "7") and not filename and not unknown)

reset()
ParseArguments({ "-p7", "--long" }, argmap)
AssertEquals(true, longarg and (shortarg == "7") and not filename and not unknown)

reset()
ParseArguments({ "fnord" }, argmap)
AssertEquals(true, not longarg and not shortarg and (filename == "fnord") and not unknown)

reset()
ParseArguments({ "-s", "fnord" }, argmap)
AssertEquals(true, not longarg and shortarg and (filename == "fnord") and not unknown)

reset()
ParseArguments({ "-s", "fnord", "--long" }, argmap)
AssertEquals(true, longarg and shortarg and (filename == "fnord") and not unknown)

reset()
ParseArguments({ "--blah" }, argmap)
AssertEquals(true, not longarg and not shortarg and not filename and unknown)

reset()
ParseArguments({ "-s", "--blah" }, argmap)
AssertEquals(true, not longarg and shortarg and not filename and unknown)

reset()
ParseArguments({ "-s", "--blah", "--long" }, argmap)
AssertEquals(true, not longarg and shortarg and not filename and unknown)


