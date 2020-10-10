-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		GlobalSettings.templates = MergeTables(GlobalSettings.templates,
			{
				templatedir = HOME.."/.wordgrinder"
			}
		)
	end

	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Save a new template.

function Cmd.SaveCurrentDocumentAsTemplate()
	local settings = GlobalSettings.templates;
	local oldcwd = lfs.currentdir()
	lfs.mkdir(settings.templatedir)

	lfs.chdir(settings.templatedir)
	local filename = FileBrowser("Save Document Set as template", "New template:", true)
	lfs.chdir(oldcwd)
	if not filename then
		return false
	end
	if filename:find("/[^.]*$") then
		filename = filename .. ".wg"
	end

	DocumentSet.name = nil

	ImmediateMessage("Saving...")
	DocumentSet:clean()
	local r, e = SaveDocumentSetRaw(filename)
	if not r then
			ModalMessage("Save failed", "The document could not be saved: "..e)
	else
			NonmodalMessage("Save succeeded.")
	end
	return r
end

-----------------------------------------------------------------------------
-- Create a new document set from a template.

function Cmd.CreateDocumentSetFromTemplate()
	if not ConfirmDocumentErasure() then
		return false
	end

	local settings = GlobalSettings.templates
	local oldcwd = lfs.currentdir()
	lfs.mkdir(settings.templatedir)

	lfs.chdir(settings.templatedir)
	local filename = FileBrowser("Create Document Set from template", "Select template:", false)
	lfs.chdir(oldcwd)
	if not filename then
		return false
	end

	local r = Cmd.LoadDocumentSet(filename)
	DocumentSet.name = nil
	return r
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureTemplates()
	local settings = GlobalSettings.templates

	local dir_textfield =
		Form.TextField {
			x1 = 21, y1 = 1,
			x2 = -1, y2 = 1,
			value = tostring(settings.templatedir)
		}
		
	local dialogue =
	{
		title = "Configure Templates",
		width = Form.Large,
		height = 3,
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
		dir_textfield,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local templatedir = dir_textfield.value
		
		if (templatedir:len() == 0) then
			ModalMessage("Parameter error", "The directory cannot be empty.")
		else
			settings.templatedir = templatedir
			SaveGlobalSettings()
			return true
		end
	end
		
	return false
end

