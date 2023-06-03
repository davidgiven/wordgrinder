--!nonstrict
loadfile("tests/testsuite.lua")()

if (ARCH == "windows") then
	AssertNotNull(WINDOWS_INSTALL_DIR)
	AssertNotNull(WINDOWS_INSTALL_DIR:find("^[A-Z]:\\"))
end

