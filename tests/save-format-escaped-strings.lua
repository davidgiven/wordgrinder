require("tests/testsuite")

local filename = os.tmpname()

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
FireEvent(Event.RegisterAddons)

SaveGlobalSettings(filename)

local want = GlobalSettings
GlobalSettings = {}

LoadGlobalSettings(filename)

AssertTableAndPropertiesEquals(want, GlobalSettings)
