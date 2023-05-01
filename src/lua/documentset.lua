-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_remove = table.remove
local table_insert = table.insert
local table_concat = table.concat
local Write = wg.write
local WriteStyled = wg.writestyled
local ClearToEOL = wg.cleartoeol
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetWordText = wg.getwordtext
local BOLD = wg.BOLD
local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local REVERSE = wg.REVERSE
local BRIGHT = wg.BRIGHT
local DIM = wg.DIM

local DocumentSet = {}
DocumentSet.__index = DocumentSet
_G.DocumentSet = DocumentSet

type DocumentSet = {
	menu: Menu,
	changed: boolean,
	justchanged: boolean,
	documents: {Document},

	purge: (self: DocumentSet) -> (),
	touch: (self: DocumentSet) -> (),
	clean: (self: DocumentSet) -> (),
	getDocumentList: (self: DocumentSet) -> {Document},
	_findDocument: (self: DocumentSet, name: string) -> Document?,
	findDocument: (self: DocumentSet, name: string) -> Document?,
	addDocument: (self: DocumentSet, name: string, index: number)
		-> currentDocument,
}

function CreateDocumentSet(): DocumentSet
	UpdateDocumentStyles()
	local ds =
	{
		fileformat = FILEFORMAT,
		statusbar = true,
		documents = {},
		addons = {},
	}

	return setmetatable(ds, DocumentSet)
end

-- remove any cached data prior to saving
DocumentSet.purge = function(self)
	for _, l in ipairs(self.documents) do
		l:purge()
	end
end

DocumentSet.touch = function(self)
	self.changed = true
	self.justchanged = true
	currentDocument:touch()
end

DocumentSet.clean = function(self)
	self.changed = nil
	self.justchanged = nil
end

DocumentSet.getDocumentList = function(self)
	return self.documents
end

DocumentSet._findDocument = function(self, name)
	for i, d in ipairs(self.documents) do
		if (d.name == name) then
			return i
		end
	end
	return nil
end

DocumentSet.findDocument = function(self, name)
	local document = self.documents[name]
	if not document then
		document = self.documents[self:_findDocument(name)]
		if document then
			ModalMessage("Document index inconsistency corrected",
				"Something freaky happened to '"..name.."'.")
			self.documents[name] = document
		end
	end
	return document
end

DocumentSet.addDocument = function(self, document, name, index)
	document.name = name

	local n = self:_findDocument(name) or (#self.documents + 1)
	self.documents[n] = document
	self.documents[name] = document
	if not self.current or (self.current.name == name) then
		self:setCurrent(name)
	end

	self:touch()
	RebuildDocumentsMenu(self.documents)
	return document
end

DocumentSet.moveDocumentIndexTo = function(self, name, targetIndex)
	local n = self:_findDocument(name)
	if not n then
		return
	end
	local document = self.documents[n]

	table_remove(self.documents, n)
	table_insert(self.documents, targetIndex, document)
	self:touch()
	RebuildDocumentsMenu(self.documents)
end

DocumentSet.deleteDocument = function(self, name)
	if (#self.documents == 1) then
		return false
	end

	local n = self:_findDocument(name)
	if not n then
		return
	end
	local document = self.documents[n]

	table_remove(self.documents, n)
	self.documents[name] = nil

	self:touch()
	RebuildDocumentsMenu(self.documents)

	if (currentDocument == document) then
		document = self.documents[n]
		if not document then
			document = self.documents[#self.documents]
		end

		self:setCurrent(document.name)
	end

	return true
end

DocumentSet.setCurrent = function(self, name)
	-- Ensure any housekeeping on the current document gets done.

	if currentDocument.changed then
		FireEvent(Event.Changed)
	end

	currentDocument = self.documents[name]
	if not currentDocument then
		currentDocument = self.documents[1]
	end

	self.current = currentDocument
	currentDocument:renumber()
	ResizeScreen()
end

DocumentSet.renameDocument = function(self, oldname, newname)
	if self.documents[newname] then
		return false
	end

	local d = self.documents[oldname]
	self.documents[oldname] = nil
	self.documents[newname] = d
	d.name = newname

	self:touch()
	RebuildDocumentsMenu(self.documents)
	return true
end

DocumentSet.setClipboard = function(self, clipboard)
	self.clipboard = clipboard
end

DocumentSet.getClipboard = function(self)
	return self.clipboard
end

