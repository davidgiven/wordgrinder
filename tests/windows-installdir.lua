require("tests/testsuite")

if (ARCH == "windows") then
	AssertNotNull(WINDOWS_INSTALL_DIR)
	AssertNotNull(WINDOWS_INSTALL_DIR:find("^[A-Z]:\\"))
end

