-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL: $

local int = math.floor
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

function DrawStatusLine(s)
	SetReverse()
	SetBold()	
	Write(0, ScreenHeight-1, s)
	ClearToEOL()
	SetNormal()
end

function DrawBox(x, y, w, h)
	local border = string.rep("─", w)
	local space = string.rep(" ", w)
	Write(x-1,   y,     " ╭")
	Write(x+w+1, y,     "╮ ")
	Write(x-1,   y+h+1, " ╰")
	Write(x+w+1, y+h+1, "╯ ")
	
	Write(x+1,   y,     border)
	Write(x+1,   y+h+1, border)
	
	for i = y+1, y+h do
		Write(x-1, i, " │")
		Write(x+w+1, i, "│ ")
		Write(x+1, i, space)
	end
end

function CentreInField(x, y, w, s)
	local xo = int((w - GetStringWidth(s)) / 2)
	Write(x+xo, y, s)
end

function RAlignInField(x, y, w, s)
	local xo = w - GetStringWidth(s)
	Write(x+xo, y, s)
end

function DrawTitledBox(x, y, w, h, title)
	DrawBox(x, y, w, h)
	CentreInField(x+1, y, w, title)
end

function ImmediateMessage(text)
	local w = GetStringWidth(text)
	local x = int((ScreenWidth - w) / 2)
	local y = int(ScreenHeight / 2)
	
	SetBold()
	DrawBox(x-2, y-1, w+2, 1)
	SetNormal()
	Write(x, y, text)
	wg.sync()
end

function ModalMessage(title, message)
	local dialogue = 
	{
		title = title or "Message",
		width = Form.Large,
		height = 3,
		stretchy = true,

		["KEY_^C"] = "cancel",
		[" "] = "confirm",
		
		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -3,
		},

		Form.Label {
		    value = "<press SPACE to continue>",
		    x1 = 1, y1 = -1, x2 = -1, y2 = -1
		},
	}

	Form.Run(dialogue, RedrawScreen)		
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
		height = 3,
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

		Form.Label {
		    value = "<Y for yes, N for no, or CTRL+C to cancel>",
		    x1 = 1, y1 = -1, x2 = -1, y2 = -1
		},
	}

	Form.Run(dialogue, RedrawScreen)		
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
		height = 6,
		stretchy = true,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		Form.WrappedLabel {
			value = message,
			x1 = 1, y1 = 1, x2 = -1, y2 = -6,
		},

		textfield,			
		
		Form.Label {
		    value = "<enter string, or CTRL+C to cancel>",
		    x1 = 1, y1 = -1, x2 = -1, y2 = -1
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

function FindAndReplaceDialogue(defaultfind, defaultreplace)
	defaultfind = defaultfind or ""
	defaultreplace = defaultreplace or ""
	
	local findfield = Form.TextField {
		value = defaultfind,
		cursor = defaultfind:len() + 1,
		x1 = 11, y1 = -6, x2 = -1, y2 = -5,
	}

	local replacefield = Form.TextField {
		value = defaultreplace,
		cursor = defaultreplace:len() + 1,
		x1 = 11, y1 = -4, x2 = -1, y2 = -3,
	}

	local dialogue = 
	{
		title = "Find and Replace",
		width = Form.Large,
		height = 7,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		Form.Label {
			value = "Find:",
			x1 = 1, y1 = -6, x2 = 10, y2 = -6,
			align = Form.Left,
		},
		 		
		Form.Label {
			value = "Replace:",
			x1 = 1, y1 = -4, x2 = 10, y2 = -4,
			align = Form.Left,
		},
		 		
		findfield,
		replacefield,			
		
		Form.Label {
		    value = "<enter string, or CTRL+C to cancel>",
		    x1 = 1, y1 = -1, x2 = -1, y2 = -1
		},
	}

	local result = Form.Run(dialogue, RedrawScreen)		
	
	QueueRedraw()
	if result then
		return findfield.value, replacefield.value
	else
		return nil
	end
end

