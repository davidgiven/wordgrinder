-- © 2007 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local int = math.floor
local Write = wg.write
local Goto = wg.goto
local GetStringWidth = wg.getstringwidth
local GetBoundedString = wg.getboundedstring
local GetBytesOfCharacter = wg.getbytesofcharacter
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local string_rep = string.rep

Form = {}

-- Atoms.

Form.Left = {}
Form.Right = {}
Form.Centre = {}
Form.Center = Form.Centre

Form.Large = {}

local function min(a, b)
	if (a < b) then
		return a
	else
		return b
	end
end

local function max(a, b)
	if (a > b) then
		return a
	else
		return b
	end
end

local function makewidgetclass(class)
	return function(table)
		setmetatable(table, {__index = class})
		return table
	end
end

Form.Divider = makewidgetclass
{
	draw = function(self)
		Write(self.realx1, self.realy1, string_rep("─", self.realwidth))
	end
}

Form.WrappedLabel = makewidgetclass
{
	draw = function(self)
		local words = ParseStringIntoWords(self.value)
		local paragraph = CreateParagraph(nil, words)
		local lines = paragraph:wrap(self.realwidth)
		
		for i = 1, #lines do
			paragraph:renderLine(lines[i], self.realx1, self.realy1+i-1)
		end
	end,
	
	calculate_height = function(self)
		local words = ParseStringIntoWords(self.value)
		local paragraph = CreateParagraph(nil, words)
		local lines = paragraph:wrap(self.realwidth)
		return #lines
	end,
}

Form.Label = makewidgetclass {
	align = Form.Centre,
	
	draw = function(self)
		local xo
		if (self.align == Form.Centre) then
			xo = int((self.realwidth - GetStringWidth(self.value)) / 2)
		elseif (self.align == Form.Left) then
			xo = 0
		elseif (self.align == Form.Right) then
			xo = self.realwidth - GetStringWidth(self.value)
		end
		
		Write(self.realx1 + xo, self.realy1, self.value)
	end
}

local checkbox_toggle = function(self, key)
	self.value = not self.value
	self:draw()
end

Form.Checkbox = makewidgetclass {
	value = false,
	label = "Checkbox",
	focusable = true,
	
	draw = function(self)
		local s
		if self.value then
			s = "✔"
		else
			s = "✘"
		end
		
		Write(self.realx1, self.realy1, s)		
		if self.focus then
			Goto(self.realx1, self.realy1)
		end
		
		Write(self.realx1 + 2, self.realy1, GetBoundedString(self.label, self.realwidth - 2))
	end,
	
	["KEY_RETURN"] = checkbox_toggle,
	["KEY_ENTER"] = checkbox_toggle,
	[" "] = checkbox_toggle
}

Form.TextField = makewidgetclass {
	focusable = true,
	
	init = function(self)
		self.cursor = self.cursor or (self.value:len() + 1)
		self.offset = self.offset or 1
	end,
	
	draw = function(self)
		Write(self.realx1, self.realy1 + 1, string_rep("⎺", self.realwidth))
		Write(self.realx1, self.realy1, string_rep(" ", self.realwidth))
		
		-- If the cursor is to the left of the visible area, adjust.
		
		if (self.cursor < self.offset) then
			self.offset = self.cursor
		end

		-- If the cursor is to the right of the visible area, adjust. (This is
		-- very crude, but I'm not sure there's a more elegant way of doing
		-- it.)
		
		while true do
			local xo = GetStringWidth(self.value:sub(self.offset, self.cursor))
			if (xo <= self.realwidth) then
				break
			end
			
			local b = GetBytesOfCharacter(self.value:byte(self.offset))
			self.offset = self.offset + b
		end
		
		-- Draw the visible bit of the string.
			
		local s = GetBoundedString(self.value:sub(self.offset), self.realwidth)
		Write(self.realx1, self.realy1, s)
		
		if self.focus then
			Goto(self.realx1 + GetStringWidth(s:sub(1, self.cursor-self.offset)), self.realy1)
		end
	end,

	["KEY_LEFT"] = function(self, key)
		if (self.cursor > 1) then
			while true do
				self.cursor = self.cursor - 1
				if (GetBytesOfCharacter(self.value:byte(self.cursor)) ~= 0) then
					break
				end
			end
			self:draw()
		end
		
		return "nop"
	end,
	
	["KEY_RIGHT"] = function(self, key)
		if (self.cursor <= self.value:len()) then	
			self.cursor = self.cursor + GetBytesOfCharacter(self.value:byte(self.cursor))
			self:draw()
		end
		
		return "nop"
	end,

	["KEY_HOME"] = function(self, key)
		self.cursor = 1
		self:draw()
		
		return "nop"
	end,
			
	["KEY_END"] = function(self, key)
		self.cursor = self.value:len() + 1
		self:draw()
		
		return "nop"
	end,

	["KEY_BACKSPACE"] = function(self, key)
		if (self.cursor > 1) then	
			local w
			while true do
				self.cursor = self.cursor - 1
				w = GetBytesOfCharacter(self.value:byte(self.cursor))
				if (w ~= 0) then
					break
				end
			end

			self.value = self.value:sub(1, self.cursor - 1) ..
				self.value:sub(self.cursor + w)
			self:draw()
		end
		
		return "nop"
	end,
				
	["KEY_DC"] = function(self, key)
		local v = self.value:byte(self.cursor)
		if v then
			local w = GetBytesOfCharacter(self.value:byte(self.cursor))
			self.value = self.value:sub(1, self.cursor - 1) ..
				self.value:sub(self.cursor + w)
			self:draw()
		end
		
		return "nop"
	end,
	
	["KEY_^U"] = function(self, key)
		self.cursor = 1
		self.offset = 1
		self.value = ""
		self:draw()
		
		return "nop"
	end,
		
	key = function(self, key)
		if not key:match("^KEY_") then
			self.value = self.value:sub(1, self.cursor-1) .. key .. self.value:sub(self.cursor)
			self.cursor = self.cursor + GetBytesOfCharacter(key:byte(1))
			self:draw()
		
			return "nop"
		end
	end,
}

Form.Browser = makewidgetclass {
	focusable = true,
	
	init = function(self)
		self.cursor = self.cursor or 1
		self.offset = self.offset or 0
	end,
	
	_adjustOffset = function(self)
		local h = self.realheight
		
		if (self.offset == 0) then
			self.offset = self.cursor - int(h/2)
		end

		self.offset = min(self.offset, self.cursor)		
		self.offset = max(self.offset, self.cursor - (h-2))
		self.offset = min(self.offset, #self.data - (h-2)) 
		self.offset = max(self.offset, 1)
	end,
	
	draw = function(self)
		local x = self.realx1
		local y = self.realy1
		local w = self.realwidth
		local h = self.realheight
			
		-- Draw the box.
		
		do	
			local border = string_rep("─", w - 2)
			Write(x, y, "┌")
			Write(x+1, y, border)
			Write(x+w-1, y, "┐")
			for i = 1, h-1 do
				Write(x, y+i, "│")
				Write(x+w-1, y+i, "│")
			end
			Write(x, y+h, "└")
			Write(x+1, y+h, border)
			Write(x+w-1, y+h, "┘")
		end

		self:_adjustOffset()		
		
		-- Draw the data.
		
		local space = string_rep(" ", w - 2)
		for i = 0, h-2 do
			local index = self.offset + i
			local item = self.data[index]
			if not item then
				break
			end
			
			if (index == self.cursor) then
				SetReverse()
			else
				SetNormal()
			end
			
			Write(x+1, y+1+i, space)			
			local s = GetBoundedString(item.label, w-4)
			Write(x+2, y+1+i, s)

			if (#self.data > (h-2)) then
				SetNormal()
				s = "│"
				local yf = (i+1) * #self.data / (h-1)
				if (yf >= self.offset) and (yf <= (self.offset + h-2)) then
					SetBold()
					s = "║"
				end
				Write(x+w-1, y+1+i, s)
			end
			SetNormal()
		end
		SetNormal()
	end,
	
	["KEY_UP"] = function(self, key)
		if (self.cursor > 1) then
			self.cursor = self.cursor - 1
			self:draw()
		end
		
		return "nop"
	end,
	
	["KEY_DOWN"] = function(self, key)
		if (self.cursor < #self.data) then
			self.cursor = self.cursor + 1
			self:draw()
		end
		
		return "nop"
	end,
	
	["KEY_PPAGE"] = function(self, key)
		self.cursor = self.cursor - int(self.realheight/2)
		if (self.cursor < 1) then
			self.cursor = 1
		end
		
		self:draw()
	end,
	
	["KEY_NPAGE"] = function(self, key)
		self.cursor = self.cursor + int(self.realheight/2)
		if (self.cursor > #self.data) then
			self.cursor = #self.data
		end
		
		self:draw()
	end,
}

local standard_actions =
{
	["KEY_UP"] = function(dialogue, key)
		local f = dialogue.focus - 1
		while (f ~= dialogue.focus) do
			if (f == 0) then
				f = #dialogue
			end

			local widget = dialogue[f]
			if widget.focusable then
				dialogue.focus = f
				return "redraw"
			end
		
			f = f - 1
		end
		
		return "nop"
	end,
	
	["KEY_DOWN"] = function(dialogue, key)
		local f = dialogue.focus + 1
		while (f ~= dialogue.focus) do
			if (f > #dialogue) then
				f = 1
			end

			local widget = dialogue[f]
			if widget.focusable then
				dialogue.focus = f
				return "redraw"
			end
		
			f = f + 1
		end
		
		return "nop"
	end
}

local function resolvesize(size, bound)
	if (size < 0) then
		return size + bound
	else
		return size
	end
end

local function findaction(table, object, key)
	local action = table[key]
	if action and (type(action) == "function") then
		action = action(object, key)
	end
	if not action and table.key then
		action = table.key(object, key)
	end
	return action
end

function Form.Run(dialogue, redraw)
	-- Find a widget to give the focus to.
	
	if not dialogue.focus then
		for i, widget in ipairs(dialogue) do
			if widget.focusable then
				dialogue.focus = i
				break
			end
		end
	end
	
	-- Initialise any widgets that need it.
	
	for _, widget in ipairs(dialogue) do
		if widget.init then
			widget:init()
		end
	end
	
	-- Redraw the backdrop.
	
	if redraw then
		redraw()
	end
	
	-- Size the dialogue.
	
	if (dialogue.width == Form.Large) then
		dialogue.realwidth = int(ScreenWidth * 4/5)
	else
		dialogue.realwidth = dialogue.width
	end
	
	if (dialogue.height == Form.Large) then
		dialogue.realheight = int(ScreenHeight * 4/5)
	else
		dialogue.realheight = dialogue.height
	end

	-- Is this a stretchy dialogue?
			
	if dialogue.stretchy then
		-- Automatically scale the height depending on a 'stretchy' widget.
		
		for _, widget in ipairs(dialogue) do
			if (widget.y1 > 0) and (widget.y2 < 0) then
				widget.realx1 = resolvesize(widget.x1, dialogue.realwidth)
				widget.realx2 = resolvesize(widget.x2, dialogue.realwidth)
				widget.realwidth = widget.realx2 - widget.realx1 
			
				local h = 1
				if widget.calculate_height then
					h = widget:calculate_height()
				end
				
				dialogue.realheight = dialogue.height + h
				break
			end
		end
	end
	
	-- Place the dialogue.
	
	dialogue.realx = int(ScreenWidth/2 - dialogue.realwidth/2)
	dialogue.realy = int(ScreenHeight/2 - dialogue.realheight/2)
	
	-- Place all widgets in the dialogue.
	
	for _, widget in ipairs(dialogue) do
		widget.realx1 = resolvesize(widget.x1, dialogue.realwidth) + dialogue.realx
		widget.realy1 = resolvesize(widget.y1, dialogue.realheight) + dialogue.realy
		widget.realx2 = resolvesize(widget.x2, dialogue.realwidth) + dialogue.realx
		widget.realy2 = resolvesize(widget.y2, dialogue.realheight) + dialogue.realy
		widget.realwidth = widget.realx2 - widget.realx1 
		widget.realheight = widget.realy2 - widget.realy1 
	end
	
	-- Draw the dialogue itself.
	
	SetBold()
	DrawTitledBox(dialogue.realx - 1, dialogue.realy - 1,
		dialogue.realwidth, dialogue.realheight,
		dialogue.title)
	SetNormal()
		
	-- Draw the widgets.
	
	Goto(ScreenWidth-1, ScreenHeight-1)
	for i, widget in ipairs(dialogue) do
		widget.focus = (i == dialogue.focus)
		widget:draw()
	end
	
	-- Process keys.

	while true do
		local key = wg.getchar()
		
		if (key == "KEY_RESIZE") then
			ResizeScreen()
			return Form.Run(dialogue, redraw)
		end
		
		local action = nil
		if dialogue.focus then
			local w = dialogue[dialogue.focus]
			action = findaction(w, w, key)
		end
		
		if not action then
			action = findaction(dialogue, dialogue, key) or
				findaction(standard_actions, dialogue, key)
		end
			
		if (action == "redraw") then
			return Form.Run(dialogue, redraw)
		elseif (action == "cancel") then
			return false
		elseif (action == "confirm") then
			return true
		end
	end
end

-- Test code

function Form.Test()
	FileBrowser("Title", "Load file:", false)
end
