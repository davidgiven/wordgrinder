--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local string_rep = string.rep
local table_concat = table.concat

local function gotobrowser(data, index)
	local browser = Form.Browser {
		focusable = true,
		type = Form.Browser,
		x1 = 1, y1 = 2,
		x2 = -1, y2 = -1,
		data = data,
		cursor = index
	}

	local dialogue: Form =
	{
		title = "Table of Contents",
		width = "large",
		height = "large",
		stretchy = false,

		actions = {
			["KEY_RETURN"] = "confirm",
			["KEY_ENTER"] = "confirm",
		},

		widgets = {
			Form.Label {
				x1 = 1, y1 = 1,
				x2 = -1, y2 = 1,
				value = "Select heading to jump to:"
			},

			browser,
		}
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"RETURN to select item, "..ESCAPE_KEY.." to cancel")
	QueueRedraw()
	if result then
		return browser.cursor
	else
		return nil
	end
end

function Cmd.Goto()
	ImmediateMessage("Scanning document...")

	local data = {}
	local levelcount: {number} = {0, 0, 0, 0}
	local currentheading = 1
	for paran, para in ipairs(currentDocument) do
		local _, _, level = para.style:find("^H(%d)$")
		if level then
			local level = assert(tonumber(level))

			-- Update the array of section counts. Remember that subsections
			-- are local to their section, so make sure to zero out the
			-- level count for subsections contained within this section.
			levelcount[level] = levelcount[level] + 1
			for i = level+1, 4 do
				levelcount[i] = 0
			end

			local s = {}
			for i = 1, level do
				s[#s+1] = levelcount[i] .. "."
			end
			s[#s+1] = " "
			s[#s+1] = para:asString()

			data[#data+1] =
			{
				label = table_concat(s),
				paran = paran
			}

			if (paran <= currentDocument.cp) then
				currentheading = #data
			end
		end
	end

	if (#data == 0) then
		ModalMessage("No contents available", "You must have some heading paragraphs in your document to use the table of contents.")
		return false
	end

	local result = gotobrowser(data, currentheading)
	QueueRedraw()

	if result then
		currentDocument.cp = data[result].paran
		currentDocument.cw = 1
		currentDocument.co = 1
		return true
	end

	return false
end
