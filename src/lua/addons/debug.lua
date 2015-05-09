-- © 2015 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local string_format = string.format

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local settings = GlobalSettings.debug
		if settings.memory then
			local mem = collectgarbage("count")
			terms[#terms+1] = 
				{
					priority=50,
					value=string_format("%dkB", mem)
				}
		end
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		GlobalSettings.debug = GlobalSettings.debug or {
			memory = false
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
			x2 = 40, y2 = 3,
			label = "Show memory usage on status bar",
			value = settings.memory
		}

	local dialogue =
	{
		title = "Configure Debugging Options",
		width = Form.Large,
		height = 5,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		memory_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			align = Form.Centre,
			value = "None of these options are of any interest to normal users."
		},
	}
	
	local result = Form.Run(dialogue, RedrawScreen,
		"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
	if not result then
		return false
	end
	
	settings.memory = memory_checkbox.value
	SaveGlobalSettings()

	return true
end

