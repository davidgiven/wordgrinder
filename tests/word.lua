local GetBytesOfCharacter = wg.getbytesofcharacter
local GetStringWidth = wg.getstringwidth
local NextCharInWord = wg.nextcharinword
local PrevCharInWord = wg.prevcharinword
local InsertIntoWord = wg.insertintoword
local DeleteFromWord = wg.deletefromword
local ApplyStyleToWord = wg.applystyletoword
local GetStyleFromWord = wg.getstylefromword
local CreateStyleByte = wg.createstylebyte
local ReadU8 = wg.readu8
local WriteU8 = wg.writeu8

--!strict
loadfile("tests/testsuite.lua")()

AssertEquals(NextCharInWord("abcd", 1), 2)
AssertEquals(NextCharInWord("\016abcd", 2), 3)
AssertEquals(NextCharInWord("\016abcd", 1), 3)

AssertEquals(DeleteFromWord("abcd", 2, 4), "ad")
AssertEquals(DeleteFromWord("abcd", 1, 3), "cd")
AssertEquals(DeleteFromWord("abcd", 2, 4), "ad")

