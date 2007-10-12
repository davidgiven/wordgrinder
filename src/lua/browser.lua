-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $Url: $

local min = min
local max = max
local int = math.floor
local string_rep = string.rep
local Write = wg.write
local Goto = wg.goto
local ClearToEOL = wg.cleartoeol
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local GetBytesOfCharacter = wg.getbytesofcharacter

function FileBrowser(title, message, saving, default)
	local files = {}
	for i in lfs.dir(".") do
		if (i ~= ".") and ((i == "..") or not i:match("^%.")) then
			local attr = lfs.attributes(i)
			if attr then
				attr.name = i
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
			label = dmarker..attr.name
		}
	end
	
	local f = Browser(title, lfs.currentdir(), message, labels, default)
	if not f then
		return nil
	end
	
	local attr, e = lfs.attributes(f)
	if not saving and e then
		ModalMessage("File not found", "The file '"..f.."' does not exist (or you do not have permission to access it).")
		return FileBrowser(title, message, saving)
	end

	if attr and (attr.mode == "directory") then
		lfs.chdir(f)
		return FileBrowser(title, message, saving)
	end
	
	if saving and not e then
		local r = PromptForYesNo("Overwrite file?", "The file '"..f.."' already exists. Do you want to overwrite it?")
		if (r == nil) then
			return nil
		elseif r then
			return f
		else
			return FileBrowser(title, message, saving)
		end
	end
	
	return f
end

function Browser(title, topmessage, bottommessage, data, default)
	local browser = Form.Browser {
		focusable = false,
		type = Form.Browser,
		x1 = 1, y1 = 2,
		x2 = -1, y2 = -4,
		data = data,
	}
	
	local textfield = Form.TextField {
		x1 = GetStringWidth(bottommessage) + 3, y1 = -2,
		x2 = -1, y2 = -1,
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
	
	local dialogue =
	{
		title = title,
		width = Form.Large,
		height = Form.Large,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		["KEY_UP"] = navigate,
		["KEY_DOWN"] = navigate,
		["KEY_NPAGE"] = navigate,
		["KEY_PPAGE"] = navigate,
			
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			value = topmessage
		},
		
		textfield,
		browser,
		
		Form.Label {
			x1 = 1, y1 = -2,
			x2 = GetStringWidth(bottommessage) + 1, y2 = -2,
			value = bottommessage
		},
	}
	
	local result = Form.Run(dialogue, RedrawScreen)
	QueueRedraw()
	if result then
		return textfield.value
	else
		return nil
	end
end
