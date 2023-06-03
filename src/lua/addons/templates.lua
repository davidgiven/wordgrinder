--!nonstrict
-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Chdir = wg.chdir
local GetCwd = wg.getcwd

-----------------------------------------------------------------------------
-- Save a new template.

function Cmd.SaveCurrentDocumentAsTemplate(): (boolean, string?)
	local templatedir = GlobalSettings.directories.templates
	local oldcwd = GetCwd()

	Chdir(templatedir)
	local filename = FileBrowser("Save Document Set as template", "New template:", true)
	Chdir(oldcwd)
	if not filename then
		return false
	end
	assert(filename)
	if filename:find("/[^.]*$") then
		filename = filename .. ".wg"
	end

	documentSet.name = ""

	ImmediateMessage("Saving...")
	documentSet:clean()
	local r, e = SaveDocumentSetRaw(filename)
	if not r then
		assert(e)
		ModalMessage("Save failed", "The document could not be saved: "..e)
		return false, e
	else
		NonmodalMessage("Save succeeded.")
		return true
	end
end

-----------------------------------------------------------------------------
-- Create a new document set from a template.

function Cmd.CreateDocumentSetFromTemplate(): (boolean, string?)
	if not ConfirmDocumentErasure() then
		return false
	end

	local templatedir = GlobalSettings.directories.templates
	local oldcwd = GetCwd()

	Chdir(templatedir)
	local filename = FileBrowser("Create Document Set from template", "Select template:", false)
	Chdir(oldcwd)
	if not filename then
		return false
	end

	local r, e = Cmd.LoadDocumentSet(filename)
	documentSet.name = ""
	return r, e
end

