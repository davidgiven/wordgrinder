require("tests/testsuite")

local writeu8 = wg.writeu8
local readu8 = wg.readu8

local values =
{
	[0] = "00",
	[1] = "01",
	[0x10] = "10",
	[0x100] = "c4 80",
	[0x1000] = "e1 80 80",
	[0x10000] = "f0 90 80 80",
	[0x100000] = "f4 80 80 80",
	[0x1000000] = "f9 80 80 80 80",
	[0x10000000] = "fc 90 80 80 80 80",
	[0x70000000] = "fd b0 80 80 80 80",
	[0x7fffffff] = "fd bf bf bf bf bf",
}

for i, bytes in ipairs(values) do
	local v = writeu8(i)
	local s = {}
	for k = 1, #v do
		s[#s+1] = string.format("%02x", string.byte(v, k))
	end
	AssertEquals(bytes, table.concat(s, " "))
	AssertEquals(i, readu8(v))
end

