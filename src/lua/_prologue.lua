-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- Load the LFS module if needed (Windows has it built in).

if not lfs then
	lfs = require "lfs"
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
