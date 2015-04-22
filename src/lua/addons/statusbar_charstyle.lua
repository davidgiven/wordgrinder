-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local is_italic = false
local is_bold = false
local is_underline = false

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local s =
		{
			is_italic and "I" or ".",
			is_bold and "B" or ".",
			is_underline and "U" or "."
		}

		terms[#terms+1] =
			{
				priority=110,
				value=table.concat(s)
			}
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end

-----------------------------------------------------------------------------
-- Update the style whenever the cursor moves.

do
	local function cb(event, token)
		local style = GetStyleToLeftOfCursor()
		
		is_italic = bit32.btest(style, wg.ITALIC)
		is_bold = bit32.btest(style, wg.BOLD)
		is_underline = bit32.btest(style, wg.UNDERLINE)
	end

	AddEventListener(Event.Moved, cb)
end

