--!nonstrict
loadfile("tests/testsuite.lua")()

local filename = wg.mkdtemp().."/testfile"

GlobalSettings = {
	intValue = 1,
	stringValue = "one",
	floatValue = 1.0,
	tableValue = { 1, 2, 3, foo="bar" }
}
FireEvent("RegisterAddons")

SaveGlobalSettings(filename)

local want = GlobalSettings
GlobalSettings = {}

LoadGlobalSettings(filename)

AssertTableAndPropertiesEquals(want, GlobalSettings)
