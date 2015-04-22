-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local style = 0

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local s =
		{
			bit32.btest(style, wg.ITALIC) and "I" or ".",
			bit32.btest(style, wg.BOLD) and "B" or ".",
			bit32.btest(style, wg.UNDERLINE) and "U" or "."
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
		style = GetStyleToLeftOfCursor()
	end

	AddEventListener(Event.Moved, cb)
end

-----------------------------------------------------------------------------
-- Allow the current style to be overridden and fetched.

function SetCurrentStyleHint(sxor, sand)
	style = bit32.bxor(style, sxor)
	style = bit32.band(style, sand)
end

function GetCurrentStyleHint()
	return style
end

