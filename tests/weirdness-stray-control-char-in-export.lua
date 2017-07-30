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
		prologue = {{}},
		paragraph_start = {{"P"}, {"P"}, {"P"}},
		text = {{"one"}, {""}, {"two"}},
		paragraph_end = {{"P"}, {"P"}, {"P"}},
		epilogue = {{}}
	},
	result)

