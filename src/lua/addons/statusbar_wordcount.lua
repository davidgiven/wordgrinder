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
				priority=90,
				value=string_format("%d %s", Document.wordcount or 0,
					Pluralise(Document.wordcount or 0, "word", "words"))
			}
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end


