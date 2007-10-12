-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL: $

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local ParseWord = wg.parseword
local bitand = wg.bitand
local bitor = wg.bitor
local bitxor = wg.bitxor
local bit = wg.bit

local MAGIC = "WordGrinder dumpfile v1: this is not a text file!"

local function writetostream(object, fp)
	local type_lookup = {
		[DocumentSetClass] = "DS",
		[DocumentClass] = "D",
		[ParagraphClass] = "P",
		[WordClass] = "W",
		[MenuClass] = "M",
	}
	
	local cache = {}
	local cacheid = 1
	local function save(t)
		if cache[t] then
			fp:write(cache[t], "\n")
			return
		end
		cache[t] = cacheid
		cacheid = cacheid + 1
		
		if (type(t) == "table") then
			local m = getmetatable(t)
			if m then
				m = type_lookup[m.__index]
			else
				m = "T"
			end
			fp:write(m, "\n", #t, "\n")
			
			for _, i in ipairs(t) do
				save(i)
			end
			for k, v in pairs(t) do
				if not tonumber(k) then
					save(k)
					save(v)
				end
			end
			fp:write(".\n")
		elseif (type(t) == "boolean") then
			if t then
				fp:write("B\nT\n")
			else
				fp:write("B\nF\n")
			end
		elseif (type(t) == "string") then
			fp:write("S\n", t, "\n")
		elseif (type(t) == "number") then
			fp:write("N\n", t, "\n")
		else
			error("unsupported type "..type(t))
		end
	end
	
	save(object)
	
	return true
end

local function savedocument(filename)
	ImmediateMessage("Saving...")
	
	local fp = io.open(filename, "w")
	if not fp then
		return false
	end
	
	DocumentSet:purge()
	fp:write(MAGIC, "\n")
	local r = writetostream(DocumentSet, fp)
	fp:close()
	
	return r
end

function Cmd.SaveCurrentDocumentAs(filename)
	if not filename then
		filename = FileBrowser("Save Document Set", "Save as:", true)
		if not filename then
			return false
		end
		DocumentSet.name = filename
	end

	local r = savedocument(DocumentSet.name)
	if not r then
		ModalMessage("Save failed", "The document could not be saved for some reason.")
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
			local t = {}
			setmetatable(t, {__index = WordClass})
			cache[#cache + 1] = t
			return populate_table(t)
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

local function loaddocument(filename)
	local fp = io.open(filename)
	if not fp then
		return nil, "file not found"
	end
	if (fp:read("*l") ~= MAGIC) then
		fp:close()
		return nil, "this is not a WordGrinder document set"
	end
	
	local d = loadfromstream(fp)
	fp:close()
	d.name = filename
	-- FIXME
	d.menu = CreateMenu()
	
	return d
end

function Cmd.LoadDocumentSet(filename)
	if not filename then
		filename = FileBrowser("Load Document Set", "Load file:", false)
		if not filename then
			return false
		end
	end
	
	ImmediateMessage("Loading...")
	local d = loaddocument(filename)
	if not d then
		ModalMessage(nil, "The load failed, probably because the file could not be opened.")
		QueueRedraw()
		return false
	end
		
	DocumentSet = d
	Document = d.current
	
	RebuildParagraphStylesMenu(DocumentSet.styles)
	RebuildDocumentsMenu(DocumentSet.documents)
	QueueRedraw()
	return true
end
