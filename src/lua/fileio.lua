--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ParseWord = wg.parseword
local WriteFile = wg.writefile
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local time = wg.time
local compress = wg.compress
local decompress = wg.decompress
local writeu8 = wg.writeu8
local readu8 = wg.readu8
local escape = wg.escape
local unescape = wg.unescape
local string_format = string.format
local unpack = rawget(_G, "unpack") or table.unpack

local MAGIC = "WordGrinder dumpfile v1: this is not a text file!"
local ZMAGIC = "WordGrinder dumpfile v2: this is not a text file!"
local TMAGIC = "WordGrinder dumpfile v3: this is a text file; diff me!"

local STOP = 0
local TABLE = 1
local BOOLEANTRUE = 2
local BOOLEANFALSE = 3
local STRING = 4
local NUMBER = 5
local CACHE = 6
local NEGNUMBER = 7
local BRIEFWORD = 8

local DOCUMENTSETCLASS = 100
local DOCUMENTCLASS = 101
local PARAGRAPHCLASS = 102
local WORDCLASS = 103
local MENUCLASS = 104

local function writetostreamt(object, write)
	local writeo = function(k, v)
		write(k)
		write(": ")
		write(v)
		write("\n")
	end

	local function save(key: string, t: any)
		if (type(t) == "table") then
			local m = GetClass(t)
			if (m ~= Paragraph) and (key ~= ".current") then
				for k, i in ipairs(t) do
					save(key.."."..k, i)
				end

				-- Save the keys in alphabetical order, so we get repeatable
				-- files.
				local keys = {}
				for k in pairs(t) do
					if (type(k) ~= "number") then
						if not k:find("^_") then
							keys[#keys+1] = k
						end
					end
				end
				table.sort(keys)

				for _, k in ipairs(keys) do
					save(key.."."..k, t[k])
				end
			end
		elseif (type(t) == "boolean") then
			writeo(key, tostring(t))
		elseif (type(t) == "string") then
			writeo(key, '"'..escape(t)..'"')
		elseif (type(t) == "number") then
			writeo(key, tostring(t))
		else
			error(string.format("unsupported type %s for key %s", type(t), key))
		end
	end

	local function save_document(i, d)
		write("#")
		write(tostring(i))
		write("\n")

		for _, p in ipairs(d) do
			write(p.style)

			for _, s in ipairs(p) do
				write(" ")
				write(s)
			end

			write("\n")
		end

		write(".")
		write("\n")
	end

	save("", object)

	local class = GetClass(object)
	if class == DocumentSet then
		if object.current then
			save(".current", object:_findDocument(object.current.name))
		end

		for i, d in ipairs(object.documents) do
			save_document(i, d)
		end
	end

	return true
end

function SaveToHeaderlessString(object)
	local ss = {}
	local write = function(s)
		ss[#ss+1] = s
	end

	writetostreamt(object, write)
	return table.concat(ss)
end

function SaveToFile(filename: string, object: any): (boolean, string?)
	-- Write the file to a *different* filename (so that crashes during
	-- writing doesn't corrupt the file).

	local s = TMAGIC .. "\n" .. SaveToHeaderlessString(object)

	local new_filename = filename..".new"
	local _, e = WriteFile(new_filename, s)
	if e then
		return false, e
	end

	-- At this point, we know the new file has been written correctly.
	-- We can remove the old one and rename the new one to be the old
	-- one. On proper operating systems we could do this in a single
	-- os.rename, but Windows doesn't support clobbering renames.

	wg.remove(filename)
	local r, e = wg.rename(new_filename, filename)
	if e then
		-- Yikes! The old file has gone, but we couldn't rename the new
		-- one...
		return r, e..": the filename of your document has changed"
	end
	return r, e
end

function SaveDocumentSetRaw(filename): (boolean?, string?)
	return SaveToFile(filename, documentSet)
end

function Cmd.SaveCurrentDocumentAs(filename: string?): boolean
	if not filename then
		filename = FileBrowser("Save Document Set", "Save as:", true)
		if not filename then
			return false
		end
		assert(filename)
		if filename:find("/[^.]*$") then
			filename = filename .. ".wg"
		end
	end
	assert(filename)
	documentSet.name = filename

	ImmediateMessage("Saving...")
	documentSet:clean()
	local r, e = SaveDocumentSetRaw(documentSet.name)
	if not r then
		assert(e)
		ModalMessage("Save failed", "The document could not be saved: "..e)
	else
		NonmodalMessage("Save succeeded.")
	end
	return assert(r)
end

function Cmd.SaveCurrentDocument()
	local name: string? = documentSet.name
	if not name then
		name = FileBrowser("Save Document Set", "Save as:", true)
		if not name then
			return false
		end
		assert(name)
		if name:find("/[^.]*$") then
			name = name .. ".wg"
		end
		documentSet.name = name
	end
	assert(name)

	return Cmd.SaveCurrentDocumentAs(name)
end

local function loadfromstream(fp): DocumentSet
	type Value = {[number]: any, text: string?}
	local cache: {any} = {}
	local load

	local function populate_table(t)
		local n = assert(tonumber(fp:read("*l")))
		for i = 1, n do
			t[i] = load()
		end

		while true do
			local k = load()
			if not k then
				break
			end

			t[k] = load()
		end

		return t
	end

	local load_cb = {
		["DS"] = function()
			local t: any = {}
			setmetatable(t, DocumentSet)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["D"] = function()
			local t: any = {}
			setmetatable(t, Document)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["P"] = function()
			local t: any = {}
			setmetatable(t, Paragraph)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["W"] = function()
			-- Words used to be objects of their own; they've been replaced
			-- with simple strings.
			local t: any = {}

			-- Ensure we allocate a cache entry *before* calling
			-- populate_table(), or else the numbers will go all wrong; the
			-- original implementation put t here.
			local cn = #cache + 1
			cache[cn] = {}

			populate_table(t)

			cache[cn] = t.text
			return t.text
		end,

		["M"] = function()
			local t: any = {}
			setmetatable(t, MenuTree)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["T"] = function()
			local t: any = {}
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["S"] = function()
			local s = fp:read("*l")
			cache[#cache + 1] = s
			return s
		end,

		["N"] = function()
			local n = tonumber(fp:read("*l"))
			cache[#cache + 1] = n
			return n
		end,

		["B"] = function()
			local s = fp:read("*l")
			s = (s == "T")
			cache[#cache + 1] = s
			return s
		end,

		["."] = function()
			return nil
		end
	}

	load = function()
		local s = fp:read("*l")
		if not s then
			error("unexpected EOF when reading file")
		end

		local n = tonumber(s)
		if n then
			return cache[n]
		end

		local f = load_cb[s]
		if not f then
			error("can't load type "..s)
		end
		return f()
	end

	return load()
end

local function loadfromstreamz(fp): DocumentSet
	local cache: {any} = {}
	local load
	local data = decompress(fp:read("*a"))
	local offset = 1

	local function populate_table(t)
		local n
		n, offset = readu8(data, offset)
		for i = 1, n do
			t[i] = load()
		end

		while true do
			local k = load()
			if not k then
				break
			end

			t[k] = load()
		end

		return t
	end

	local load_cb = {
		[CACHE] = function()
			local n
			n, offset = readu8(data, offset)
			return cache[n]
		end,

		[DOCUMENTSETCLASS] = function()
			local t: any = {}
			setmetatable(t, DocumentSet)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[DOCUMENTCLASS] = function()
			local t: any = {}
			setmetatable(t, Document)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[PARAGRAPHCLASS] = function()
			local t: any = {}
			setmetatable(t, Paragraph)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[WORDCLASS] = function()
			-- Words used to be objects of their own; they've been replaced
			-- with simple strings.
			local t: any = {}

			-- Ensure we allocate a cache slot *before* calling populate_table,
			-- or else the numbers all go wrong.
			local cn = #cache + 1
			cache[cn] = {}

			populate_table(t)

			cache[cn] = t.text
			return t.text
		end,

		[BRIEFWORD] = function()
			-- Words used to be objects of their own; they've been replaced
			-- with simple strings.

			local t: any = load()
			cache[#cache+1] = t
			return t
		end,

		[MENUCLASS] = function()
			local t: any = {}
			setmetatable(t, MenuTree)
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[TABLE] = function()
			local t: any = {}
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[STRING] = function()
			local n
			n, offset = readu8(data, offset)
			local s = data:sub(offset, offset+n-1)
			offset = offset + n

			cache[#cache + 1] = s
			return s
		end,

		[NUMBER] = function()
			local n
			n, offset = readu8(data, offset)
			cache[#cache + 1] = n
			return n
		end,

		[NEGNUMBER] = function()
			local n
			n, offset = readu8(data, offset)
			n = -n
			cache[#cache + 1] = n
			return n
		end,

		[BOOLEANTRUE] = function()
			cache[#cache + 1] = true
			return true
		end,

		[BOOLEANFALSE] = function()
			cache[#cache + 1] = false
			return false
		end,

		[STOP] = function()
			return nil
		end
	}

	load = function()
		local n
		n, offset = readu8(data, offset)

		local f = load_cb[n]
		if not f then
			error("can't load type "..n.." at offset "..offset)
		end
		return f()
	end

	return load()
end

local function loadfromstreamt(fp): DocumentSet
	local data = CreateDocumentSet()
	data.menu = CreateMenuTree()
	data.documents = {}

	local function readl(): string?
		local s = fp:read("*l")
		if s then
			return s:gsub("\r", "")
		end
		return nil
	end

	while true do
		local line = readl()
		if not line then
			break
		end
		assert(line)

		if line:find("^%.") then
			local s, _, k: any, p: any, v: any
				= line:find("^(.*)%.([^.:]+): (.*)$")
			if not s then
				error(
					string.format("malformed line when reading file: '%s'", line))
			end

			-- This is setting a property value.
			local o: any = data
			for e in k:gmatch("[^.]+") do
				local en: any = e
				if e:find('^[0-9]+$') then
					en = assert(tonumber(e))
				end
				if not o[en] then
					if (o == data.documents) then
						o[en] = CreateDocument()
					else
						o[en] = {}
					end
				end
				o = o[en]
			end

			if v:find('^-?[0-9][0-9.e+-]*$') then
				v = tonumber(v)
			elseif (v == "true") then
				v = true
			elseif (v == "false") then
				v = false
			elseif v:find('^".*"$') then
				v = v:sub(2, -2)
				v = unescape(v)
			else
				error(
					string.format("malformed property %s.%s: %s", k, p, v))
			end

			if p:find('^[0-9]+$') then
				p = tonumber(p)
			end

			o[p] = v
		elseif line:find("^#") then
			local id = line:sub(2)
			local doc: Document
			if id == "clipboard" then
				doc = assert(data.clipboard)
			else
				local n = assert(tonumber(id))
				doc = data.documents[n]
			end

			local index = 1
			while true do
				line = readl()
				if not line or (line == ".") then
					break
				end

				local words = SplitString(line, " ")
				local para = CreateParagraph(unpack(words))

				doc[index] = para
				index = index + 1
			end
		elseif line == "" then
			-- Just ignore these.
		else
			error(
				string.format("malformed line when reading file: '%s'", line))
		end
	end

	-- Bugfix: previously, the document metadata was written twice to the file,
	-- once using the numeric document index as key and once using the name
	-- (because the same table was used for both indices). This was wrong. So
	-- we need to go through and remove the stub documents created erroneously
	-- for the string keys. The actual data is added to the documents with
	-- numeric keys, via the # line above.
	
	for i: any, d in data.documents do
		if typeof(i) == "string" then
			data.documents[i::any] = nil
		end
	end

	-- Create the index by name.
	--
	data._documentIndex = {}
	for i, d in data.documents do
		data._documentIndex[d.name] = d
	end
	data.current = data.documents[data.current :: any]

	-- Remove any clipboard (unused).
	data.clipboard = nil

	return data
end

function LoadFromHeaderlessString(s)
	return loadfromstreamt(CreateIStream(s))
end

function LoadFromString(data: string): (DocumentSet?, string?)
	local fp = CreateIStream(data)

	local loader = nil
	local magic = fp:read("*l"):gsub("\r", "")
	if (magic == MAGIC) then
		loader = loadfromstream
	elseif (magic == ZMAGIC) then
		loader = loadfromstreamz
	elseif (magic == TMAGIC) then
		loader = loadfromstreamt
	else
		fp:close()
		return nil, ("'"..filename.."' is not a valid WordGrinder file.")
	end

	return loader(fp)
end

function LoadFromFile(filename): (DocumentSet?, string?)
	local data, _, e = wg.readfile(filename);
	if not data then
		assert(e)
		return nil, ("'"..filename.."' could not be opened: "..e)
	end
	assert(data)
	return LoadFromString(data)
end

local function loaddocument(filename): (DocumentSet?, string?)
	local d: DocumentSet?, e = LoadFromFile(filename)
	if e then
		return nil, e
	end

	-- Even if the changed flag was set in the document on disk, remove it.

	assert(d)
	d:clean()

	d.name = filename
	return d
end

function Cmd.LoadDocumentSet(filename): (boolean, string?)
	if not ConfirmDocumentErasure() then
		return false, "Cancelled"
	end

	if not filename then
		filename = FileBrowser("Load Document Set", "Load file:", false)
		if not filename then
			return false, "Cancelled"
		end
	end

	assert(filename)
	ImmediateMessage("Loading "..filename.."...")
	local d, e = loaddocument(filename)
	if not d then
		if not e then
			e = "The load failed, probably because the file could not be opened."
		end
		assert(e)
		ModalMessage("Load failed", e)
		QueueRedraw()
		return false, e
	end
	assert(d)

	-- Downgrading documents is not supported.
	local fileformat = d.fileformat or 1
	if (fileformat > FILEFORMAT) then
		ModalMessage("Cannot load document", "This document belongs to a newer version of " ..
			"WordGrinder and cannot be loaded. Sorry.")
		QueueRedraw()
		return false, "Incompatible version"
	end

	documentSet = d
	currentDocument = d.current

	if (fileformat < FILEFORMAT) then
		UpgradeDocument(fileformat)
		FireEvent("DocumentUpgrade", fileformat, FILEFORMAT)

		documentSet.fileformat = FILEFORMAT
		documentSet.menu = CreateMenuTree()
	end
	FireEvent("RegisterAddons")
	documentSet:touch()

	ResizeScreen()
	FireEvent("DocumentLoaded")

	UpdateDocumentStyles()
	RebuildDocumentsMenu(documentSet.documents)
	QueueRedraw()

	if (fileformat < FILEFORMAT) then
		ModalMessage("Document upgraded",
			"You are trying to open a file belonging to an earlier "..
			"version of WordGrinder. That's not a problem, but if you "..
			"save the file again it may not work on the old version. "..
			"Also, all keybindings defined in this file will get reset "..
			"to their default values.")
	end

	-- The document is NOT dirty immediately after a load.
	
	documentSet._changed = false

	return true
end

function UpgradeDocument(oldversion)
	documentSet.addons = documentSet.addons or {}

	-- Upgrade version 1 to 2.

	if (oldversion < 2) then
		-- Update wordcount.

		for _, document in ipairs(documentSet.documents) do
			local wc = 0

			for _, p in ipairs(document) do
				wc = wc + #p
			end

			document.wordcount = wc
		end

		-- Status bar defaults to on.

		documentSet.statusbar = true
	end

	-- Upgrade version 2 to 3.

	if (oldversion < 3) then
		-- Idle time defaults to 3.

		(documentSet::any).idletime = 3
	end

	-- Upgrade version 5 to 6.

	if (oldversion < 6) then
		-- This is the version which made WordClass disappear. The
		-- conversion's actually done as part of the stream loader
		-- (where WORDCLASS and BRIEFWORD are parsed).
	end

	-- Upgrade version 6 to 7.

	if (oldversion < 7) then
		-- This is the version where documentSet.styles vanished. Each paragraph.style
		-- is now a string containing the name of the style; styles are looked up on
		-- demand.

        local function convertStyles(document: Document)
            for _, p in ipairs(document) do
                if (type(p.style) ~= "string") then
                    p.style = (p.style::any).name
                end
            end
        end

		for _, document in ipairs(documentSet.documents) do
            convertStyles(document)
        end
		(documentSet::any).styles = nil
	end

	-- Upgrade version 7 to 8.
	
	if (oldversion < 8) then
		-- This version added the LN paragraph style type; documents are forwards
		-- compatible but not backward compatible.
		
		-- A bug on 0.7.2 meant that the styles were still exported in
		-- WordGrinder files, even though they were never used.

		(documentSet::any).styles = nil
		(documentSet::any).idletime = nil
	end
end

function GetClipboard()
	local text, wgdata = wg.clipboard_get()
	if wgdata then
		return LoadFromHeaderlessString(wgdata).documents[1]
	end
	if text then
		return Cmd.ImportTextString(text)
	end
	return CreateDocument()
end

function SetClipboard(document)
	local text = Cmd.ExportToTextString(document)

	local documentSet = CreateDocumentSet()
	document.name = "clipboard"
	documentSet.documents = { document }

	local wgdata = SaveToHeaderlessString(documentSet)
	wg.clipboard_set(text, wgdata)
end

