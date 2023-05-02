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
	fileformat: number,
	name: string,
	menu: MenuTree,
	current: Document,
	documents: {[number]: Document},
	clipboard: Document?,
	statusbar: boolean,

	_documentIndex: {[string]: Document},
	_changed: boolean,
	_justchanged: boolean,

	touch: (self: DocumentSet) -> (),
	clean: (self: DocumentSet) -> (),
	getDocumentList: (self: DocumentSet) -> {Document},
	_findDocument: (self: DocumentSet, name: string) -> number?,
	findDocument: (self: DocumentSet, name: string) -> Document?,
	addDocument: (self: DocumentSet, name: string, index: number)
		-> Document,
	moveDocumentIndexTo: (self: DocumentSet, name: string, targetIndex: number)
		-> (),
	deleteDocument: (self: DocumentSet, name: string) -> boolean,
	setCurrent: (self: DocumentSet, name: string) -> (),
	renameDocument: (self: DocumentSet, oldname: string, newname: string) -> (),
	setClipboard: (self: DocumentSet, clipboard: Document) -> (),
	getClipboard: (self: DocumentSet) -> Document?,
}

function CreateDocumentSet(): DocumentSet
	UpdateDocumentStyles()
	local ds =
	{
		fileformat = FILEFORMAT,
		statusbar = true,
		documents = {},
		_documentIndex = {},
		addons = {},
	}

	return (setmetatable(ds, DocumentSet)::any)::DocumentSet
end

DocumentSet.touch = function(self: DocumentSet)
	self._changed = true
	self._justchanged = true
end

DocumentSet.clean = function(self: DocumentSet)
	self._changed = false
	self._justchanged = false
end

DocumentSet.getDocumentList = function(self: DocumentSet)
	return self.documents
end

DocumentSet._findDocument = function(self: DocumentSet, name): number?
	for i, d in self.documents do
		if (d.name == name) then
			return i
		end
	end
	return nil
end

DocumentSet.findDocument = function(self: DocumentSet, name: string)
	local document = self._documentIndex[name]
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
	self._documentIndex[name] = document
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
		return false
	end
	local document = self.documents[n]

	table.remove(self.documents, n)
	self._documentIndex[name] = nil

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

	if currentDocument._changed then
		FireEvent("Changed")
	end

	currentDocument = self._documentIndex[name]
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

