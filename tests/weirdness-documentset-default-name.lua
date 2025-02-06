--!nonstrict
loadfile("tests/testsuite.lua")()

AssertEquals(documentSet.name, nil)

ResetDocumentSet()
AssertEquals(documentSet.name, nil)

Cmd.LoadDefaultTemplate()
AssertEquals(documentSet.name, nil)
