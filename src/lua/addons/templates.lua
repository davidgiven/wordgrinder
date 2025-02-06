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

	local oldname = documentSet.name
	documentSet.name = nil

	ImmediateMessage("Saving...")
	documentSet:clean()
	local r, e = SaveDocumentSetRaw(filename)
	documentSet.name = oldname
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
	documentSet.name = nil
	return r, e
end

-----------------------------------------------------------------------------
-- Create a new document set from the default template. If there isn't one,
-- you get a vanilla blank document set.

function Cmd.LoadDefaultTemplate()
	if not ConfirmDocumentErasure() then
		return false
	end

	ResetDocumentSet()
	local templatename = GlobalSettings.directories.templates.."/default.wg"
	local r, e = wg.readfile(templatename)
	if r then
		local d, e = LoadFromString(templatename, r)
		if d then
			local fileformat = d.fileformat or 1
			if fileformat ~= FILEFORMAT then
				NonmodalMessage("Cannot load default template: please update it.")
			else
				Cmd.LoadDocumentSet(templatename)
			end
		else
			NonmodalMessage("Cannot load default template.")
		end
	end

	documentSet.name = nil
	return r, e
end

