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

	local settings = GlobalSettings.templates;
	local oldcwd = lfs.currentdir()
	lfs.mkdir(settings.templatedir)

	lfs.chdir(settings.templatedir)
	filename = FileBrowser("Create Document Set from template", "Select template:", false)
	lfs.chdir(oldcwd)
	if not filename then
		return false
	end

	local r = Cmd.LoadDocumentSet(filename)
	DocumentSet.name = nil
	return r
end

