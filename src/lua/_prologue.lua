-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- Lua 5.3 moved unpack into table.unpack.

unpack = unpack or table.unpack

-- Urrgh, luajit's path defaults to all the wrong places. This is painfully
-- evil but does at least work.

if jit then
	package.path = package.path ..
		";/usr/share/lua/5.1/?.lua;/usr/share/lua/5.1/?/init.lua"
	package.cpath = package.cpath ..
		";/usr/lib/x86_64-linux-gnu/lua/5.1/?.so;/usr/lib/lua/5.1/?.so;/usr/local/lib/lua/5.1/loadall.so"
end

-- Bit library fallbacks. (LuaJIT vs Lua 5.2 incompatibilities.)

if not bit32 then
	bit32 =
	{
		bxor = bit.bxor,
		band = bit.band,
		bor = bit.bor,
		btest = function(a, b)
			return bit.band(a, b) ~= 0
		end
	}
end

-- Make sure that reads of undefined global variables fail. Note: this will
-- prevent us from storing nil in a global.

if DEBUG then
	local allowed = 
	{
		X11_BLACK_COLOUR = true,
		X11_BOLD_MODIFIER = true,
		X11_BRIGHT_COLOUR = true,
		X11_DIM_COLOUR = true,
		X11_FONT = true,
		X11_ITALIC_MODIFIER = true,
		X11_NORMAL_COLOUR = true,
	}

	setmetatable(_G,
		{
			__index = function(self, k)
				if not allowed[k] then
					error("read from undefined local '"..k.."'")
				end
				return rawget(_G, k)
			end
		}
	)
end

-- Global definitions that the various source files need.

Cmd = {}
lunamark = {}

BLINK_ON_TIME = 0.8
BLINK_OFF_TIME = 0.53
IDLE_TIME = (BLINK_ON_TIME + BLINK_OFF_TIME) * 5

