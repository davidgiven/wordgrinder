-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local Write = wg.write
local GotoXY = wg.gotoxy
local ClearArea = wg.cleararea
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetBright = wg.setbright
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetBoundedString = wg.getboundedstring

function DrawStatusLine(s)
	SetReverse()
	ClearArea(0, ScreenHeight-1, ScreenWidth-1, ScreenHeight-1)
	Write(0, ScreenHeight-1, s)
	SetNormal()
end

function DrawBox(x, y, w, h)
	local border = string.rep("─", w)
	local space = string.rep(" ", w)
	Write(x-1,   y,     " ┌")
	Write(x+w+1, y,     "┐ ")
	Write(x-1,   y+h+1, " └")
	Write(x+w+1, y+h+1, "┘ ")

	Write(x+1,   y,     border)
	Write(x+1,   y+h+1, border)

	for i = y+1, y+h do
		Write(x-1, i, " │")
		Write(x+w+1, i, "│ ")
		Write(x+1, i, space)
	end
end

function CentreInField(x, y, w, s)
	s = GetBoundedString(s, w)
	local xo = int((w - GetStringWidth(s)) / 2)
	Write(x+xo, y, s)
end

function LAlignInField(x, y, w, s)
	s = GetBoundedString(s, w)
	Write(x, y, s)
end

function RAlignInField(x, y, w, s)
	s = GetBoundedString(s, w)
	local xo = w - GetStringWidth(s)
	Write(x+xo, y, s)
end

function DrawTitledBox(x, y, w, h, title, subtitle)
	SetBright()
	DrawBox(x, y, w, h)
	CentreInField(x+1, y, w, title)
	if subtitle then
		SetBold()
		CentreInField(x+1, y+h+1, w, subtitle)
	end
	SetNormal()
end

function ImmediateMessage(text)
	local w = GetStringWidth(text)
	local x = int((ScreenWidth - w) / 2)
	local y = int(ScreenHeight / 2)

	DrawBox(x-2, y-1, w+2, 1)
	Write(x, y, text)
	wg.sync()
end

function ModalMessage(title, message)
	local dialogue =
	{
		title = title or "Message",
		width = Form.Large,
		height = 2,
		stretchy = true,

		["KEY_^C"] = "cancel",
		[" "] = "confirm",

		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -3,
		},
	}

	Form.Run(dialogue, RedrawScreen,
		"press SPACE to continue")
	QueueRedraw()
end

function PromptForYesNo(title, message)
	local result = nil

	local function rtrue()
		result = true
		return "confirm"
	end

	local function rfalse()
		result = false
		return "confirm"
	end

	local dialogue =
	{
		title = title or "Message",
		width = Form.Large,
		height = 2,
		stretchy = true,

		["KEY_^C"] = "cancel",
		["n"] = rfalse,
		["N"] = rfalse,
		["y"] = rtrue,
		["Y"] = rtrue,

		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -3,
		},
	}

	Form.Run(dialogue, RedrawScreen,
		"Y for yes, N for no, or CTRL+C to cancel")
	QueueRedraw()
	return result
end

function PromptForString(title, message, default)
	if not default then
		default = ""
	end

	local textfield =
	Form.TextField {
		value = default,
		cursor = default:len() + 1,
		x1 = 1, y1 = -4, x2 = -1, y2 = -3,
	}

	local dialogue =
	{
		title = title,
		width = Form.Large,
		height = 4,
		stretchy = true,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -6,
		},

		textfield,
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"RETURN to confirm, CTRL+C to cancel")

	QueueRedraw()
	if result then
		return textfield.value
	else
		return nil
	end
end

function FindAndReplaceDialogue(defaultfind, defaultreplace)
	defaultfind = defaultfind or ""
	defaultreplace = defaultreplace or ""

	local findfield = Form.TextField {
		value = defaultfind,
		cursor = defaultfind:len() + 1,
		x1 = 11, y1 = 1, x2 = -1, y2 = 2,
	}

	local replacefield = Form.TextField {
		value = defaultreplace,
		cursor = defaultreplace:len() + 1,
		x1 = 11, y1 = 3, x2 = -1, y2 = 4,
	}

	local dialogue =
	{
		title = "Find and Replace",
		width = Form.Large,
		height = 5,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		Form.Label {
			value = "Find:",
			x1 = 1, y1 = 1, x2 = 10, y2 = 1,
			align = Form.Left,
		},

		Form.Label {
			value = "Replace:",
			x1 = 1, y1 = 3, x2 = 10, y2 = 3,
			align = Form.Left,
		},

		findfield,
		replacefield,
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"RETURN to confirm, CTRL+C to cancel")

	QueueRedraw()
	if result then
		return findfield.value, replacefield.value
	else
		return nil
	end
end

function AboutDialogue()
	local dialogue =
	{
		title = "About WordGrinder",
		width = Form.Large,
		height = 12,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		[" "] = "confirm",

		Form.Label {
			value = "WordGrinder "..VERSION,
			x1 = 1, y1 = 1, x2 = -1, y2 = 1,
			align = Form.Centre,
		},

		Form.Label {
			value = "© 2007-2020 David Given",
			x1 = 1, y1 = 2, x2 = -1, y2 = 2,
			align = Form.Centre,
		},

		Form.Label {
			value = "File format version "..FILEFORMAT,
			x1 = 1, y1 = 4, x2 = -1, y2 = 4,
			align = Form.Centre,
		},

		Form.Label {
			value = "Cat vacuuming (n): pointless or otherwise inefficient",
			x1 = 1, y1 = 6, x2 = -1, y2 = 6,
			align = Form.Centre,
		},

		Form.Label {
			value = "    displacement activity to avoid having to settle  ",
			x1 = 1, y1 = 7, x2 = -1, y2 = 7,
			align = Form.Centre,
		},

		Form.Label {
			value = "    down and do some real writing.                   ",
			x1 = 1, y1 = 8, x2 = -1, y2 = 8,
			align = Form.Centre,
		},

		Form.Label {
			value = "For more information, see http://cowlark.com/wordgrinder.",
			x1 = 1, y1 = 10, x2 = -1, y2 = 10,
			align = Form.Centre,
		},
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"press SPACE to continue")

	QueueRedraw()
	return nil
end

