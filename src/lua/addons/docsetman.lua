-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id: export.lua 58 2008-08-06 00:08:24Z dtrg $
-- $URL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/src/lua/export.lua $

function Cmd.AddBlankDocument(name)
	if not name then
		name = PromptForString("Name of new document?", "Please enter the new document name:")
		if not name or (name == "") then
			return false
		end
	end

	if DocumentSet.documents[name] then
		ModalMessage("Name in use", "Sorry! There's already a document with that name in this document set.")
		return false
	end

	DocumentSet:addDocument(CreateDocument(), name)
	DocumentSet:setCurrent(name)
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
	
	local dialogue =
	{
		title = "Document Manager",
		width = Form.Large,
		height = Form.Large,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "cancel",
		["KEY_ENTER"] = "cancel",
		
		["u"] = function()
			if (browser.cursor > 1) then
				local document = browser.data[browser.cursor].document
				DocumentSet:moveDocumentIndexTo(document.name, browser.cursor - 1)
				browser.cursor = browser.cursor - 1
				return "confirm"
			end
			return "nop"
		end,
		
		["d"] = function()
			if (browser.cursor < #browser.data) then
				DocumentSet:moveDocumentIndexTo(Document.name, browser.cursor + 1)
				browser.cursor = browser.cursor + 1
				return "confirm"
			end
			return "nop"
		end,
		
		["r"] = function()
			local name = PromptForString("Change name of current document", "Please enter the new document name:", Document.name)
			if not name or (name == Document.name) then
				return "confirm"
			end
			
			if not DocumentSet:renameDocument(Document.name, name) then
				ModalMessage("Name in use", "Sorry! There's already a document with that name in this document set.")
				return "confirm"
			end
		
			return "confirm"
		end,
		
		["x"] = function()
			if (#browser.data == 1) then
				ModalMessage("Unable to delete document", "You can't delete the last document from the document set.")
				return "confirm"
			end
			
			if not PromptForYesNo("Delete this document?", "Are you sure you want to delete the document '"
				.. Document.name .."'? It will be removed from the current document set, and will be gone forever.") then
				return false
			end
			
			if not DocumentSet:deleteDocument(Document.name) then
				ModalMessage("Unable to delete document", "You can't delete that document.")
				return "confirm"
			end
		
			return "confirm"
		end,
		
		["n"] = function()
			Cmd.AddBlankDocument()
			return "confirm"
		end,
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			value = "Select heading to jump to:"
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

	while true do
		local data = {}
		local current = nil
		for dn, d in ipairs(DocumentSet:getDocumentList()) do
			data[dn] =
			{
				document = d,
				label = d.name or "(unnamed)"
			}
			if (d == Document) then
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

