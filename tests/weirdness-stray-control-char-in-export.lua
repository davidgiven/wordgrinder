require("tests/testsuite")

-- Test the low level function that's actually got the bug in it.

local object, result = LoggingCallback()
wg.parseword("\16", 0, object)

AssertTableAndPropertiesEquals(
	{},
	result)

-- And now do an end-to-end test of the exporter framework which was
-- provoking it.

Cmd.InsertStringIntoParagraph("one")
Cmd.SplitCurrentParagraph()
Cmd.SplitCurrentParagraph()
Cmd.InsertStringIntoParagraph("two")

local object, result = LoggingObject()

local function callback(writer, document)
	return ExportFileUsingCallbacks(document, object)
end

-- This can actually happen by the right sequence of user operations,
-- but it's a bit brittle and I want to be absolutely sure it happens
-- for the test case.

Document[2][1] = "\16"
ExportToString(Document, callback)

AssertTableAndPropertiesEquals(
	{
		["paragraph_start"] = {
			{{"one", ["style"]="P"}},
			{{"\16", ["style"]="P"}},
			{{"two", ["style"]="P"}}
		},
		["paragraph_end"] = {
			{{"one", ["style"]="P"}},
			{{"\16", ["style"]="P"}},
			{{"two", ["style"]="P"}}
		},
		["prologue"] = {{}},
		["text"] = {
			{"one"},
			{""},
			{"two"}
		},
		["epilogue"] = {{}}
	}, 
	result)

