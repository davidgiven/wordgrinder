-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local min = min
local max = max
local int = math.floor
local string_rep = string.rep
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

function FileBrowser(title, message, saving, default)
	-- Prevent the first item being selected if no default is supplied; as
	-- it's always .., it's never helpful.
	default = default or ""

	-- If the default has a slash in it, it's a subdirectory, so go there.
	do
		local _, _, dir, leaf = default:find("(.*)/([^/]*)$")
		if dir then
			ChDir(dir)
			default = leaf
		end
	end

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
	local defaultn = 1
	for _, attr in ipairs(files) do
		local dmarker = "  "
		if (attr.mode == "directory") then
			dmarker = "◇ "
		end
		labels[#labels+1] = {
			data = attr.name,
			label = dmarker..attr.name
		}
		if (attr.name == default) then
			defaultn = #labels
		end
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

	local f = Browser(title, GetCwd(), message, labels,
		default, defaultn)
	if not f then
		return nil
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
		return FileBrowser(title, message, saving, default)
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
	
	return GetCwd().."/"..f
end

function Browser(title, topmessage, bottommessage, data, default, defaultn)
	local browser = Form.Browser {
		focusable = false,
		type = Form.Browser,
		x1 = 1, y1 = 2,
		x2 = -1, y2 = -5,
		data = data,
		cursor = defaultn or 1
	}
	
	local textfield = Form.TextField {
		x1 = GetStringWidth(bottommessage) + 3, y1 = -3,
		x2 = -1, y2 = -2,
		value = default or data[1].data,
	}
		
	local function navigate(self, key)
		local action = browser[key](browser)
		textfield.value = data[browser.cursor].data
		textfield.cursor = textfield.value:len() + 1
		textfield.offset = 1
		textfield:draw()
		return action
	end

	local function go_to_parent(self, key)
		textfield.value = ".."
		return "confirm"
	end

	local helptext
	if (ARCH == "windows") then
		helptext = "enter an absolute path or drive letter ('c:') to go there"
	else
		helptext = "enter an absolute path to go there"
	end

	local dialogue =
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
