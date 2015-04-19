-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- This runs some basic tests of the UTF-8 encoder and decoder.

local writeu8 = wg.writeu8
local readu8 = wg.readu8

local values =
{
	0, 1, 0x10, 0x100, 0x1000, 0x10000, 0x100000, 0x1000000, 0x10000000, 0x70000000, 0x7fffffff,
}

local function main()
	for _, i in ipairs(values) do
		local v = writeu8(i)
		local s = {string.format("%08x", bit32.band(i, 0xffffffff)), ":"}
		for k = 1, #v do
			s[#s+1] = string.format(" %02x", string.byte(v, k))
		end
		s[#s+1] = ": "
		s[#s+1] = string.format("%08x", readu8(v))
		print(table.concat(s))
	end
end

main(...)
os.exit(0)

