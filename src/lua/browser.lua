-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local min = min
local max = max
local int = math.floor
local string_rep = string.rep
local table_sort = table.sort
local Write = wg.write
local GotoXY = wg.gotoxy
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetCwd = wg.getcwd
local ChDir = wg.chdir
local ReadDir = wg.readdir
local Stat = wg.stat

local function compare_filenames(f1, f2)
	if (ARCH == "windows") then
		return f1:lower() == f2:lower()
	else
		return f1 == f2
	end
end

function FileBrowser(title, message, saving)
	local files = {}
	for _, filename in ipairs(ReadDir(".")) do
		if (filename ~= ".") and ((filename == "..") or not filename:match("^%.")) then
			local attr = Stat(filename)
			if attr then
				attr.name = filename
				files[#files+1] = attr
			end
		end
	end
	table.sort(files, function(a, b)
		if (a.mode == b.mode) then
			return a.name < b.name
		end
		if (a.mode == "directory") then
			return true
		end
		return false
	end)
	
	local labels = {}
	for _, attr in ipairs(files) do
		local dmarker = "  "
		if (attr.mode == "directory") then
			dmarker = "◇ "
		end
		labels[#labels+1] = {
			data = attr.name,
			key = attr.name,
			label = dmarker..attr.name
		}
	end
	
	-- Windows will sometimes give you a directory with no entries
	-- in it at all (e.g. Documents and Settings on Win7). This is
	-- annoying.

	if (#labels == 0) then
		labels[#labels+1] = {
			data = "..",
			label = "◇ .."
		}
	end

	local f = Browser(title, GetCwd(), message, labels)
	if not f then
		return nil
	end
	
	if f:match("[/\\]$") then
		-- Remove any trailing directory specifier (autocompletion
		-- tends to leave these).
		f = f:sub(1, -2)
	end
	if (ARCH == "windows") and f:match("^%a:$") then
		-- The user has typed a drive specifier; turn it into a path.
		f = f.."/"
	end

	local attr, e, errno = Stat(f)
	if not saving and e then
		ModalMessage("File inaccessible", "The file '"..f.."' could not be accessed: "..e)
		return FileBrowser(title, message, saving)
	end

	if attr and (attr.mode == "directory") then
		ChDir(f)
		return FileBrowser(title, message, saving)
	end
	
	if saving and not e then
		local r = PromptForYesNo("Overwrite file?", "The file '"..f.."' already exists. Do you want to overwrite it?")
		if (r == nil) then
			return nil
		elseif r then
			return GetCwd().."/"..f
		else
			return FileBrowser(title, message, saving)
		end
	end
	
	if not f:find("^[/\\]") then
		return GetCwd().."/"..f
	else
		return f
	end
end

function Autocomplete(filename, x1, x2, y)
	local dirname = Dirname(filename)
	local leafname = Leafname(filename)

	if (dirname ~= "/") then
		dirname = dirname.."/"
	end

	local files = ReadDir(dirname)
	if not files then
		return filename
	end

	if (dirname == "./") then
		dirname = ""
	end

	local candidates = {}
	for _, f in ipairs(files) do
		if (compare_filenames(f:sub(1, #leafname), leafname)) then
			local st = Stat(dirname.."/"..f)
			if st and (st.mode == "directory") then
				f = f.."/"
			end
			candidates[#candidates+1] = f
		end
	end

	-- Only one candidate --- match it.
	if (#candidates == 1) then
		return dirname..candidates[1]
	end

	-- Does the LCP advance the filename? If so, return it.
	local prefix = (ARCH == "windows")
		and LargestCommonPrefixCaseInsensitive(candidates)
		or LargestCommonPrefix(candidates)
	if (prefix == nil) then
		return filename
	elseif prefix ~= leafname then
		return dirname..prefix
	end

	-- Display the autocompletion list to the user.
	local boxw = x2 - x1
	local boxh = min(y-1, #candidates)
	local boxx = x1
	local boxy = y - 1 - boxh
	DrawBox(boxx, boxy, boxw, boxh)
	for i = 1, boxh do
		Write(x1+1, y-i, candidates[i])
	end
	return filename
end

function Browser(title, topmessage, bottommessage, data)
	local dialogue

	local browser = Form.Browser {
		focusable = false,
		type = Form.Browser,
		x1 = 1, y1 = 2,
		x2 = -1, y2 = -5,
		data = data,
		cursor = 1
	}
	
	local textfield = Form.TextField {
		x1 = GetStringWidth(bottommessage) + 3, y1 = -3,
		x2 = -1, y2 = -2,
		value = data[1].data,
		transient = true,

		-- Only fired if changed _by the text field_.
		changed = function(self)
			local value = self.value
			if (#value == 0) then
				return
			end
			for index, item in ipairs(data) do
				if item.key and compare_filenames(item.key:sub(1, #value), value) then
					browser.cursor = index
					browser:draw()
					return
				end
			end
		end,
	}
		
	local function navigate(self, key)
		local action = browser[key](browser)
		textfield.value = data[browser.cursor].data
		textfield.cursor = textfield.value:len() + 1
		textfield.offset = 1
		textfield.transient = true
		textfield:draw()
		return action
	end

	local function autocomplete(self)
		textfield.value = Autocomplete(textfield.value,
			textfield.realx1-1, textfield.realx2-1, textfield.realy1)
		textfield.cursor = textfield.value:len() + 1
		textfield.offset = 1
		textfield.transient = false
		textfield:draw()
		dialogue.transient = true
		return "nop"
	end

	local function go_to_parent(self, key)
		textfield.value = ".."
		return "confirm"
	end

	local helptext
	if (ARCH == "windows") then
		helptext = "enter an path or drive letter ('c:') to go there; TAB completes"
	else
		helptext = "enter an path to go there; TAB completes"
	end

	dialogue =
	{
		title = title,
		width = Form.Large,
		height = Form.Large,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_^P"] = go_to_parent,
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		["KEY_UP"] = navigate,
		["KEY_DOWN"] = navigate,
		["KEY_PGDN"] = navigate,
		["KEY_PGUP"] = navigate,
			
		["KEY_TAB"] = autocomplete,

		Form.Label {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			value = topmessage
		},
		
		textfield,
		browser,
		
		Form.Label {
			x1 = 1, y1 = -3,
			x2 = GetStringWidth(bottommessage) + 1, y2 = -3,
			value = bottommessage
		},

		Form.Label {
			x1 = 1, y1 = -1,
			x2 = -1, y2 = -1,
			value = helptext
		}
	}
	
	local result = Form.Run(dialogue, RedrawScreen,
		"RETURN to confirm, CTRL+C to cancel, CTRL+P to go to parent dir")
	QueueRedraw()
	if result then
		return textfield.value
	else
		return nil
	end
end
