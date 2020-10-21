-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local string_format = string.format

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		terms[#terms+1] = 
			{
				priority=100,
				value=string_format("%s: %d/%d",
					Document[Document.cp].style,
					Document.cp,
					#Document)
			}
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end

