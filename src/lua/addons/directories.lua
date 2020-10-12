-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Chdir = wg.chdir
local GetCwd = wg.getcwd
local Stat = wg.stat
local Access = wg.access
local string_format = string.format
local ENOENT = wg.ENOENT
local W_OK = wg.W_OK

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		GlobalSettings.directories = MergeTables(GlobalSettings.directories,
			{
				templates = CONFIGDIR.."/templates",
				autosaves = nil,
			}
		)
	end

	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

local function check_dir(dir)
	local st, e, errno = Access(dir, W_OK)
	if (errno == ENOENT) then
		if PromptForYesNo("Directory does not exist",
				string_format("'%s' does not exist. Try to create it now?", dir)) then
			_, e, errno = Mkdirs(dir)
			if e then
				ModalMessage("File system error",
					string_format("Could not create '%s': %s", dir, e))
				return false
			end
		else
			return false
		end
	end
	if e then
		ModalMessage("File system error",
			string_format("'%s' is not accessible: %s", dir, e))
		return false
	end

	st, e, errno = Stat(dir)
	if st and (st.mode ~= "directory") then
		ModalMessage("File system error",
			string_format("'%s' exists but is not a directory", dir))
		return false
	end
	return true
end

function Cmd.ConfigureDirectories()
	local settings = GlobalSettings.directories

	local templates_textfield =
		Form.TextField {
			x1 = 27, y1 = 1,
			x2 = -1, y2 = 1,
			value = tostring(settings.templates)
		}
		
	local autosaves_textfield =
		Form.TextField {
			x1 = 27, y1 = 3,
			x2 = -1, y2 = 3,
			value = settings.autosaves or "",
		}

	local dialogue =
	{
		title = "Configure Templates",
		width = Form.Large,
		height = 6,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 20, y2 = 1,
			align = Form.Left,
			value = "Template directory:"
		},
		templates_textfield,

		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 20, y2 = 3,
			align = Form.Left,
			value = "Autosave directory:"
		},
		Form.Label {
			x1 = 1, y1 = 4,
			x2 = 20, y2 = 4,
			align = Form.Left,
			value = "(leave blank for default)"
		},
		autosaves_textfield,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local templates = templates_textfield.value
		local autosaves = autosaves_textfield.value
		if (autosaves == "") then
			autosaves = nil
		end
		
		if (templates:len() == 0) then
			ModalMessage("Parameter error", "The templates directory cannot be empty.")
		else
			if check_dir(templates) and (not autosaves or check_dir(autosaves)) then
				settings.templates = templates
				settings.autosaves = autosaves
				SaveGlobalSettings()
				return true
			end
		end
	end
		
	return false
end


