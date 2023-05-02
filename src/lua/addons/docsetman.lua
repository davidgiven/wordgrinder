--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

function Cmd.AddBlankDocument(name)
	if not name then
		name = PromptForString("Name of new document?", "Please enter the new document name:")
		if not name or (name == "") then
			return false
		end
	end

	if documentSet.documents[name] then
		ModalMessage("Name in use", "Sorry! There's already a document with that name in this document set.")
		return false
	end

	documentSet:addDocument(CreateDocument(), name)
	documentSet:setCurrent(name)
	QueueRedraw()
	return true
end

function Cmd.ManageDocumentsUI()
	local browser = Form.Browser {
		focusable = true,
		type = Form.Browser,
		x1 = 1, y1 = 2,
		x2 = -1, y2 = -4,
		
		changed = function(self)
			Cmd.ChangeDocument(self.data[self.cursor].document.name)
			return "redraw"
		end
	}
	
	local function up_cb(self: Form): ActionResult
		if (browser.cursor > 1) then
			local document = browser.data[browser.cursor].document
			documentSet:moveDocumentIndexTo(document.name, browser.cursor - 1)
			browser.cursor = browser.cursor - 1
			return "confirm"
		end
		return "nop"
	end
		
	local function down_cb(self: Form): ActionResult
		if (browser.cursor < #browser.data) then
			documentSet:moveDocumentIndexTo(currentDocument.name, browser.cursor + 1)
			browser.cursor = browser.cursor + 1
			return "confirm"
		end
		return "nop"
	end
		
	local function rename_cb(self: Form): ActionResult
		local name = PromptForString("Change name of current document", "Please enter the new document name:", currentDocument.name)
		if not name or (name == currentDocument.name) then
			return "confirm"
		end
		
		if not documentSet:renameDocument(currentDocument.name, name) then
			ModalMessage("Name in use", "Sorry! There's already a document with that name in this document set.")
			return "confirm"
		end
	
		return "confirm"
	end
		
	local function delete_cb(self: Form): ActionResult
		if (#browser.data == 1) then
			ModalMessage("Unable to delete document", "You can't delete the last document from the document set.")
			return "confirm"
		end
		
		if not PromptForYesNo("Delete this document?", "Are you sure you want to delete the document '"
			.. currentDocument.name .."'? It will be removed from the current document set, and will be gone forever.") then
			return "cancel"
		end
		
		if not documentSet:deleteDocument(currentDocument.name) then
			ModalMessage("Unable to delete document", "You can't delete that document.")
			return "confirm"
		end
	
		return "confirm"
	end
		
	local function new_cb(self: Form): ActionResult
		Cmd.AddBlankDocument()
		return "confirm"
	end

	local dialogue: Form =
	{
		title = "Document Manager",
		width = Form.Large,
		height = Form.Large,
		stretchy = false,

		actions = {
			["KEY_RETURN"] = "cancel",
			["KEY_ENTER"] = "cancel",
			
			["u"] = up_cb,
			["U"] = up_cb,
			
			["d"] = down_cb,
			["D"] = down_cb,
			
			["r"] = rename_cb,
			["R"] = rename_cb,
			
			["x"] = delete_cb,
			["X"] = delete_cb,
			
			["n"] = new_cb,
			["N"] = new_cb,
		},
		
		widgets = {
			Form.Label {
				x1 = 1, y1 = 1,
				x2 = -1, y2 = 1,
				value = "Select document:"
			},
			
			Form.Label {
				x1 = 1, y1 = -3,
				x2 = -1, y2 = -3,
				value = "U: Move document up              R: Rename document"
			},
			
			Form.Label {
				x1 = 1, y1 = -2,
				x2 = -1, y2 = -2,
				value = "D: Move document down            X: Delete document"
			},
			
			Form.Label {
				x1 = 1, y1 = -1,
				x2 = -1, y2 = -1,
				value = "N: Create blank document     RETURN, ^C: Close dialogue"
			},
			
			browser,
		}
	}

	while true do
		local data = {}
		local current = nil
		for dn, d in ipairs(documentSet:getDocumentList()) do
			data[dn] =
			{
				document = d,
				label = d.name or "(unnamed)"
			}
			if (d == currentDocument) then
				current = dn
			end 
		end
		
		browser.data = data
		browser.cursor = current
		
		local result = Form.Run(dialogue, RedrawScreen)
		QueueRedraw()
	
		if not result then
			return true
		end
	end
end

