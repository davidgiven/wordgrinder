--!nonstrict
loadfile("tests/testsuite.lua")()

GlobalSettings.lookandfeel.denseparagraphs = false
DocumentSet = CreateDocumentSet()
AssertEquals(documentStyles.P.above, 1)

GlobalSettings.lookandfeel.denseparagraphs = true
DocumentSet = CreateDocumentSet()
AssertEquals(documentStyles.P.above, 0)

