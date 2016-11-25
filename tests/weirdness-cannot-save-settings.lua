require("tests/testsuite")

local filename = os.tmpname()

GlobalSettings = {
	intValue = 1,
	stringValue = "one",
	floatValue = 1.0,
	tableValue = { 1, 2, 3, foo="bar" }
}
FireEvent(Event.RegisterAddons)

SaveGlobalSettings(filename)

local want = GlobalSettings
GlobalSettings = {}

LoadGlobalSettings(filename)

AssertTableAndPropertiesEquals(want, GlobalSettings)
