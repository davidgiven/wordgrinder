loadfile("tests/testsuite.lua")()

wg.clipboard_set("text data", "wg data");
local textData, wgData = wg.clipboard_get()
AssertEquals("text data", textData)
AssertEquals("wg data", wgData)

