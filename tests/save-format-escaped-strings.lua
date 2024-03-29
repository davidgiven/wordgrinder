--!nonstrict
loadfile("tests/testsuite.lua")()

local filename = wg.mkdtemp().."/temp.wg"

GlobalSettings = {
	boolValue = true,
	intValue = 1,
	stringValue = "one",
	floatValue = 1.0,
	tableValue = { 1, 2, 3, foo="bar" },
	escapedString = "one\ntwo\\three",
	stringWithQuotationMarks = 'one"two"three',
	stringWithSpecialBytes = "one\001two\002three",
}
FireEvent("RegisterAddons")

SaveGlobalSettings(filename)

local want = GlobalSettings
GlobalSettings = {}

LoadGlobalSettings(filename)

AssertTableAndPropertiesEquals(want, GlobalSettings)
