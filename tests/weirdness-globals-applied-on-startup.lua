--!nonstrict
loadfile("tests/testsuite.lua")()

GlobalSettings.lookandfeel.denseparagraphs = false
DocumentSet = CreateDocumentSet()
AssertEquals(DocumentStyles.P.above, 1)

GlobalSettings.lookandfeel.denseparagraphs = true
DocumentSet = CreateDocumentSet()
AssertEquals(DocumentStyles.P.above, 0)

