-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ParseWord = wg.parseword
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

local function writetostream(object, write, writeo)
	local function save(key, t, force)
		if (type(t) == "table") then
			local m = GetClass(t)
			if (m ~= ParagraphClass) and (key ~= ".current") then
				for k, i in ipairs(t) do
					save(key.."."..k, i)
				end

				if (t ~= DocumentSet.documents) then
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
			end
		elseif (type(t) == "boolean") then
			writeo(key, tostring(t))
		elseif (type(t) == "string") then
			writeo(key, '"'..escape(t)..'"')
		elseif (type(t) == "number") then
			writeo(key, tostring(t))
		else
			error("unsupported type "..type(t))
		end
	end

	save("", object)

	if (GetClass(object) == DocumentSetClass) then
		save(".current", object:_findDocument(object.current.name))

		for i, d in ipairs(object.documents) do
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
	end

	return true
end

function SaveToStream(filename, object)
	-- Ensure the destination file is writeable.

	local fp, e = io.open(filename, "wb")
	if not fp then
		return nil, e
	end
	fp:close()

	-- However, write the file to a *different* filename
	-- (so that crashes during writing doesn't corrupt the file).

	fp, e = io.open(filename..".new", "wb")
	if not fp then
		return nil, e
	end

	local fpw = fp.write

	local ss = {}
	local write = function(s)
		ss[#ss+1] = s
	end

	local writeo = function(k, v)
		write(k)
		write(": ")
		write(v)
		write("\n")
	end

	local r = writetostream(object, write, writeo)
	local s = table.concat(ss)

	local e
	if r then
		r, e = fp:write(TMAGIC, "\n", s)
	end
	if r then
		r, e = fp:close()
	end

	-- Once done, do a complicated series of renames so that we
	-- don't remove the old file until we're sure the new one has
	-- been written correctly. Note that accurs�d Windows doesn't
	-- support clobbering renames...

	if r then
		r, e = os.rename(filename, filename..".old")
		if not e then
			r, e = os.rename(filename..".new", filename)
		end
		if not e then
			os.remove(filename..".old")
		end
	end

	return r, e
end

function SaveDocumentSetRaw(filename)
	DocumentSet:purge()
	return SaveToStream(filename, DocumentSet)
end

function Cmd.SaveCurrentDocumentAs(filename)
	if not filename then
		filename = FileBrowser("Save Document Set", "Save as:", true)
		if not filename then
			return false
		end
		if filename:find("/[^.]*$") then
			filename = filename .. ".wg"
		end
	end
	DocumentSet.name = filename

	ImmediateMessage("Saving...")
	DocumentSet:clean()
	local r, e = SaveDocumentSetRaw(DocumentSet.name)
	if not r then
		ModalMessage("Save failed", "The document could not be saved: "..e)
	else
		NonmodalMessage("Save succeeded.")
	end
	return r
end

function Cmd.SaveCurrentDocument()
	local name = DocumentSet.name
	if not name then
		name = FileBrowser("Save Document Set", "Save as:", true)
		if not name then
			return false
		end
		if name:find("/[^.]*$") then
			name = name .. ".wg"
		end
		DocumentSet.name = name
	end

	return Cmd.SaveCurrentDocumentAs(name)
end

local function loadfromstream(fp)
	local cache = {}
	local load

	local function populate_table(t)
		local n = tonumber(fp:read("*l"))
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
			local t = {}
			setmetatable(t, {__index = DocumentSetClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["D"] = function()
			local t = {}
			setmetatable(t, {__index = DocumentClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["P"] = function()
			local t = {}
			setmetatable(t, {__index = ParagraphClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["W"] = function()
			-- Words used to be objects of their own; they've been replaced
			-- with simple strings.
			local t = {}

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
			local t = {}
			setmetatable(t, {__index = MenuClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		["T"] = function()
			local t = {}
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

function loadfromstreamz(fp)
	local cache = {}
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
			local t = {}
			setmetatable(t, {__index = DocumentSetClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[DOCUMENTCLASS] = function()
			local t = {}
			setmetatable(t, {__index = DocumentClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[PARAGRAPHCLASS] = function()
			local t = {}
			setmetatable(t, {__index = ParagraphClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[WORDCLASS] = function()
			-- Words used to be objects of their own; they've been replaced
			-- with simple strings.
			local t = {}

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

			local t = load()
			cache[#cache+1] = t
			return t
		end,

		[MENUCLASS] = function()
			local t = {}
			setmetatable(t, {__index = MenuClass})
			cache[#cache + 1] = t
			return populate_table(t)
		end,

		[TABLE] = function()
			local t = {}
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

function loadfromstreamt(fp)
	local data = CreateDocumentSet()
	data.menu = CreateMenu()
	data.documents = {}

	while true do
		local line = fp:read("*l")
		if not line then
			break
		end

		if line:find("^%.") then
			local _, _, k, p, v = line:find("^(.*)%.([^.:]+): (.*)$")

			-- This is setting a property value.
			local o = data
			for e in k:gmatch("[^.]+") do
				if e:find('^[0-9]+') then
					e = tonumber(e)
				end
				if not o[e] then
					if (o == data.documents) then
						o[e] = CreateDocument()
					else
						o[e] = {}
					end
				end
				o = o[e]
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
			local id = tonumber(line:sub(2))
			local doc = data.documents[id]

			local index = 1
			while true do
				line = fp:read("*l")
				if not line or (line == ".") then
					break
				end

				local words = SplitString(line, " ")
				local para = CreateParagraph(unpack(words))

				doc[index] = para
				index = index + 1
			end
		else
			error(
				string.format("malformed line when reading file: %s", line))
		end
	end

	-- Patch up document names.
	for i, d in ipairs(data.documents) do
		data.documents[d.name] = d
	end
	data.current = data.documents[data.current]

	return data
end

function LoadFromStream(filename)
	local fp, e = io.open(filename, "rb")
	if not fp then
		return nil, ("'"..filename.."' could not be opened: "..e)
	end
	local loader = nil
	local magic = fp:read("*l")
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

	local d, e = loader(fp)
	fp:close()

	return d, e
end

local function loaddocument(filename)
	local d, e = LoadFromStream(filename)
	if e then
		return nil, e
	end

	-- Even if the changed flag was set in the document on disk, remove it.

	d:clean()

	d.name = filename
	return d
end

function Cmd.LoadDocumentSet(filename)
	if not ConfirmDocumentErasure() then
		return false
	end

	if not filename then
		filename = FileBrowser("Load Document Set", "Load file:", false)
		if not filename then
			return false
		end
	end

	ImmediateMessage("Loading...")
	local d, e = loaddocument(filename)
	if not d then
		if not e then
			e = "The load failed, probably because the file could not be opened."
		end
		ModalMessage("Load failed", e)
		QueueRedraw()
		return false
	end

	-- Downgrading documents is not supported.
	local fileformat = d.fileformat or 1
	if (fileformat > FILEFORMAT) then
		ModalMessage("Cannot load document", "This document belongs to a newer version of " ..
			"WordGrinder and cannot be loaded. Sorry.")
		QueueRedraw()
		return false
	end

	DocumentSet = d
	Document = d.current

	if (fileformat < FILEFORMAT) then
		UpgradeDocument(fileformat)
		FireEvent(Event.DocumentUpgrade, fileformat, FILEFORMAT)

		DocumentSet.fileformat = FILEFORMAT
		DocumentSet.menu = CreateMenu()
	end
	FireEvent(Event.RegisterAddons)
	DocumentSet:touch()

	ResizeScreen()
	FireEvent(Event.DocumentLoaded)

	UpdateDocumentStyles()
	RebuildDocumentsMenu(DocumentSet.documents)
	QueueRedraw()

	if (fileformat < FILEFORMAT) then
		ModalMessage("Document upgraded",
			"You are trying to open a file belonging to an earlier "..
			"version of WordGrinder. That's not a problem, but if you "..
			"save the file again it may not work on the old version. "..
			"Also, all keybindings defined in this file will get reset "..
			"to their default values.")
	end
	return true
end

function UpgradeDocument(oldversion)
	DocumentSet.addons = DocumentSet.addons or {}

	-- Upgrade version 1 to 2.

	if (oldversion < 2) then
		-- Update wordcount.

		for _, document in ipairs(DocumentSet.documents) do
			local wc = 0

			for _, p in ipairs(document) do
				wc = wc + #p
			end

			document.wordcount = wc
		end

		-- Status bar defaults to on.

		DocumentSet.statusbar = true
	end

	-- Upgrade version 2 to 3.

	if (oldversion < 3) then
		-- Idle time defaults to 3.

		DocumentSet.idletime = 3
	end

	-- Upgrade version 5 to 6.

	if (oldversion < 6) then
		-- This is the version which made WordClass disappear. The
		-- conversion's actually done as part of the stream loader
		-- (where WORDCLASS and BRIEFWORD are parsed).
	end

	-- Upgrade version 6 to 7.

	if (oldversion < 7) then
		-- This is the version where DocumentSet.styles vanished. Each paragraph.style
		-- is now a string containing the name of the style; styles are looked up on
		-- demand.

		for _, document in ipairs(DocumentSet.documents) do
			for _, p in ipairs(document) do
				if (type(p.style) ~= "string") then
					p.style = p.style.name
				end
			end
		end
		DocumentSet.styles = nil
	end
end
