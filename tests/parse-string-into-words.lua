require("tests/testsuite")

local words = ParseStringIntoWords("The quick brown fox jumps over the lazy dog.")
AssertTableEquals({"The", "quick", "brown", "fox", "jumps", "over", "the",
	"lazy", "dog."}, words)

