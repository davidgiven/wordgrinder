require("tests/testsuite")

GlobalSettings.lookandfeel.denseparagraphs = false
DocumentSet = CreateDocumentSet()
AssertEquals(DocumentSet.styles.P.above, 1)

GlobalSettings.lookandfeel.denseparagraphs = true
DocumentSet = CreateDocumentSet()
AssertEquals(DocumentSet.styles.P.above, 0)

