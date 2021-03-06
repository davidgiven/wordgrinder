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

-- Make sure that reads of undefined global variables fail. Note: this will
-- prevent us from storing nil in a global.

if DEBUG then
	local allowed = 
	{
		FONT_REGULAR = true,
		FONT_BOLD = true,
		FONT_ITALIC = true,
		FONT_BOLDITALIC = true,
		FONT_SIZE = true,
		WINDOW_WIDTH = true,
		WINDOW_HEIGHT = true,
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

