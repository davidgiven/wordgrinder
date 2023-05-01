--!nonstrict
-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local string_format = string.format
local floor = math.floor

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local settings = GlobalSettings.debug
		if settings.memory then
			local mem = floor(gcinfo())
			terms[#terms+1] = 
				{
					priority=50,
					value=string_format("%dkB", mem)
				}
		end
		if settings.location then
			terms[#terms+1] = 
				{
					priority=50,
					value=string_format("%d.%d.%d",
						Document.cp, Document.cw, Document.co)
				}
		end
		if settings.currentword then
			terms[#terms+1] = 
				{
					priority=50,
					value=Format(Document[Document.cp][Document.cw])
				}
		end
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the documentSet.

do
	local function cb()
		GlobalSettings.debug = GlobalSettings.debug or {
			memory = false,
			location = false,
			currentword = false
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureDebug()
	local settings = GlobalSettings.debug

	local memory_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 3,
			x2 = -1, y2 = 3,
			label = "Show memory usage on status bar",
			value = settings.memory
		}
	local location_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 5,
			x2 = -1, y2 = 5,
			label = "Show detailed location on status bar",
			value = settings.location
		}

	local currentword_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 7,
			x2 = -1, y2 = 8,
			label = "Show word representation on status bar",
			value = settings.currentword
		}

	local dialogue =
	{
		title = "Configure Debugging Options",
		width = Form.Large,
		height = 9,
		stretchy = false,

		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		memory_checkbox,
		location_checkbox,
		currentword_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			align = Form.Centre,
			value = "None of these options are of any interest to normal users."
		},
	}
	
	local result = Form.Run(dialogue, RedrawScreen,
		"SPACE to toggle, RETURN to confirm, "..ESCAPE_KEY.." to cancel")
	if not result then
		return false
	end
	
	settings.memory = memory_checkbox.value
	settings.location = location_checkbox.value
	settings.currentword = currentword_checkbox.value
	SaveGlobalSettings()

	return true
end

