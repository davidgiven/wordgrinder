--!strict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local GetBoundedString = wg.getboundedstring
local GetBytesOfCharacter = wg.getbytesofcharacter
local GetChar = wg.getchar
local GetStringWidth = wg.getstringwidth
local GotoXY = wg.gotoxy
local HideCursor = wg.hidecursor
local SetBold = wg.setbold
local SetBright = wg.setbright
local SetNormal = wg.setnormal
local SetReverse = wg.setreverse
local SetUnderline = wg.setunderline
local UseUnicode = wg.useunicode
local Write = wg.write
local int = math.floor
local string_rep = string.rep

ESCAPE_KEY = (FRONTEND == "ncurses") and "CTRL+C" or "ESCAPE"

type FormCommand = "nop" | "confirm" | "redraw" | "cancel"
type ActionResult = FormCommand | MenuCallback
type FormAction = FormCommand | ((Form, any) -> ActionResult)
type ActionTable = {[string]: FormAction}

type Form = {
	title: string,
	width: number | "large",
	height: number | "large",
	stretchy: boolean?,
	transient: boolean?,

	focus: number?,

	actions: ActionTable,
	widgets: {Widget}
}

Form = {}

type WidgetAlignment = "left" | "right" | "centre"

--- Widget ------------------------------------------------------------------

declare class Widget extends Object
	x1: number
	y1: number
	x2: number
	y2: number
	focusable: boolean?
	focus: boolean

	realx1: number
	realx2: number
	realy1: number
	realy2: number
	realwidth: number
	realheight: number

	init: (self: Widget) -> ()
	draw: (self: Widget) -> ()
	calculate_height: (self: Widget) -> number
	changed: (self: Widget) -> ()
	key: (self: Widget, key: KeyboardEvent) -> FormAction
	click: (self: Widget, event: MouseEvent) -> FormAction
	action: (self: Widget, event: InputEvent) -> ActionResult
end

Form.Widget = Object {
	changed = function(self: Widget)
	end,

	action = function(self: Widget, event: InputEvent)
		return "nop"
	end
}

--- DividerWidget -----------------------------------------------------------

declare class DividerWidget extends Widget
end

local Divider: DividerWidget = Form.Widget {
	draw = function(self: DividerWidget)
		Write(self.realx1, self.realy1, string_rep("─", self.realwidth))
	end
}
Form.Divider = Divider

--- WrapperLabelWidget ------------------------------------------------------

declare class WrappedLabelWidget extends Widget
	value: string
end

local WrappedLabel: WrappedLabelWidget = Form.Widget {
	draw = function(self: WrappedLabelWidget)
		local words = ParseStringIntoWords(self.value)
		local paragraph = CreateParagraph("P", words)
		local wd = paragraph:wrap(self.realwidth)

		local s = SpellcheckerOff()
		for i = 1, #wd.lines do
			paragraph:renderLine(wd.lines[i], self.realx1, self.realy1+i-1)
		end
		SpellcheckerRestore(s)
	end,

	calculate_height = function(self: WrappedLabelWidget)
		local words = ParseStringIntoWords(self.value)
		local paragraph = CreateParagraph("P", words)
		local wd = paragraph:wrap(self.realwidth)
		return #wd.lines
	end
}
Form.WrappedLabel = WrappedLabel

--- LabelWidget -------------------------------------------------------------

declare class LabelWidget extends Widget
	align: WidgetAlignment
	value: string
end

local Label: LabelWidget = Form.Widget {
	align = "centre",

	draw = function(self: LabelWidget)
		local xo
		if (self.align == "centre") then
			xo = int((self.realwidth - GetStringWidth(self.value)) / 2)
		elseif (self.align == "left") then
			xo = 0
		elseif (self.align == "right") then
			xo = self.realwidth - GetStringWidth(self.value)
		end

		Write(self.realx1, self.realy1, string_rep(" ", self.realwidth))
		Write(self.realx1 + xo, self.realy1, self.value)
	end
}
Form.Label = Label

--- CheckboxWidget ----------------------------------------------------------

declare class CheckboxWidget extends Widget
	value: boolean
	label: string
end

local checkbox_toggle = function(self: CheckboxWidget, key)
end

local Checkbox: CheckboxWidget = Form.Widget {
	value = false,
	label = "Checkbox",
	focusable = true,

	draw = function(self: CheckboxWidget)
		local s
		if self.value then
			s = "> YES"
		else
			s = "> NO "
		end

		Write(self.realx1, self.realy1, GetBoundedString(self.label, self.realwidth - 10))

		SetBright()
		Write(self.realx2-10, self.realy1, s)
		SetNormal()

		if self.focus then
			GotoXY(self.realx2-10, self.realy1)
		end
	end,
	
	[" "] = function(self: CheckboxWidget, key)
		self.value = not self.value
		self:changed()
		self:draw()
	end,
}
Form.Checkbox = Checkbox

--- ToggleWidget ------------------------------------------------------------

declare class ToggleWidget extends Widget
	values: {string}
	value: number
	label: string
end

local Toggle: ToggleWidget = Form.Widget {
	values = {"Default"},
	value = 1,
	label = "Toggle",
	focusable = true,

	draw = function(self: ToggleWidget)
		Write(self.realx1, self.realy1, string_rep(" ", self.realwidth))
		Write(self.realx1, self.realy1, GetBoundedString(self.label, self.realwidth - 2))

		local s = self.values[self.value]
		if self.value == 1 then
			s = "  "..s
		else
			s = "< "..s
		end
		if self.value == #self.values then
			s = s.."  "
		else
			s = s.." >"
		end

		SetBright()
		Write(self.realx2 - 12, self.realy1, s)
		SetNormal()

		if self.focus then
			GotoXY(self.realx2 - 10, self.realy1)
		end
	end,

	["KEY_LEFT"] = function(self: ToggleWidget, key)
		if self.value ~= 1 then
			self.value = self.value - 1
			self:draw()
		end
		return "nop"
	end,

	["KEY_RIGHT"] = function(self: ToggleWidget, key)
		if self.value ~= #self.values then
			self.value = self.value + 1
			self:draw()
		end
		return "nop"
	end,

	[" "] = function(self: ToggleWidget, key)
		self.value = self.value + 1
		if self.value > #self.values then
			self.value = 1
		end
		self:draw()
		return "nop"
	end
}
Form.Toggle = Toggle

--- Textfield ---------------------------------------------------------------

declare class TextFieldWidget extends Widget
	value: string
	cursor: number
	offset: number
	transient: boolean
end

local function keep_transient_textfield(self: TextFieldWidget)
	self.transient = false
end

local function discard_transient_textfield(self: TextFieldWidget)
	if self.transient then
		self.value = ""
		self.cursor = 1
		self.transient = false
	end
end

local TextField: TextFieldWidget = Form.Widget {
	focusable = true,
	transient = false,

	init = function(self: TextFieldWidget)
		self.cursor = self.cursor or (self.value:len() + 1)
		self.offset = self.offset or 1
	end,

	draw = function(self: TextFieldWidget)
		SetBright()
		Write(self.realx1, self.realy1 + 1, string_rep(
			UseUnicode() and "▔" or " ", self.realwidth))
		Write(self.realx1, self.realy1, string_rep(" ", self.realwidth))
		SetNormal()

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
		SetBright()
		if self.transient then
			SetReverse()
		end
		Write(self.realx1, self.realy1, s)
		SetNormal()

		if self.focus then
			GotoXY(self.realx1 + GetStringWidth(s:sub(1, self.cursor-self.offset)), self.realy1)
		end
	end,

	["KEY_LEFT"] = function(self: TextFieldWidget, key)
		keep_transient_textfield(self)
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

	["KEY_RIGHT"] = function(self: TextFieldWidget, key)
		keep_transient_textfield(self)
		if (self.cursor <= self.value:len()) then
			self.cursor = self.cursor + GetBytesOfCharacter(self.value:byte(self.cursor))
			self:draw()
		end

		return "nop"
	end,

	["KEY_HOME"] = function(self: TextFieldWidget, key)
		keep_transient_textfield(self)
		self.cursor = 1
		self:draw()

		return "nop"
	end,

	["KEY_END"] = function(self: TextFieldWidget, key)
		keep_transient_textfield(self)
		self.cursor = self.value:len() + 1
		self:draw()

		return "nop"
	end,

	["KEY_BACKSPACE"] = function(self: TextFieldWidget, key)
		discard_transient_textfield(self)
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
			self:changed()
			self:draw()
		end

		return "nop"
	end,

	["KEY_DELETE"] = function(self: TextFieldWidget, key)
		discard_transient_textfield(self)
		local v = self.value:byte(self.cursor)
		if v then
			local w = GetBytesOfCharacter(self.value:byte(self.cursor))
			self.value = self.value:sub(1, self.cursor - 1) ..
				self.value:sub(self.cursor + w)
			self:changed()
			self:draw()
		end

		return "nop"
	end,

	["KEY_^U"] = function(self: TextFieldWidget, key)
		discard_transient_textfield(self)
		self.cursor = 1
		self.offset = 1
		self.value = ""
			self:changed()
		self:draw()

		return "nop"
	end,

	click = function(self: TextFieldWidget, m: MouseEvent)
		local c = m.x - self.realx1 + self.offset
		if (c >= 1) and (c <= #self.value) then
			self.cursor = c
			return "redraw"
		end
		return "nop"
	end,

	key = function(self: TextFieldWidget, key: KeyboardEvent): ActionResult
		if not key:match("^KEY_") then
			discard_transient_textfield(self)
			self.value = self.value:sub(1, self.cursor-1) .. key .. self.value:sub(self.cursor)
			self.cursor = self.cursor + GetBytesOfCharacter(key:byte(1))
			self:changed()
			self:draw()
		end
		return "nop"
	end,
}

Form.TextField = TextField

--- Browser --------------------------------------------------------------

type BrowserItem = {
	data: string,
	label: string,
	key: string?
}

declare class BrowserWidget extends Widget
	cursor: number
	offset: number
	data: {BrowserItem}
	label: string

	_adjustOffset: (self: BrowserWidget) -> ()
end

local Browser: BrowserWidget = Form.Widget {
	focusable = true,
	data = {},

	init = function(self: BrowserWidget)
		self.cursor = self.cursor or 1
		self.offset = self.offset or 0
	end,

	_adjustOffset = function(self: BrowserWidget)
		local h = self.realheight

		if (self.offset == 0) then
			self.offset = self.cursor - int(h/2)
		end

		self.offset = math.min(self.offset, self.cursor)
		self.offset = math.max(self.offset, self.cursor - (h-2))
		self.offset = math.min(self.offset, #self.data - (h-2))
		self.offset = math.max(self.offset, 1)
	end,

	changed = function(self: BrowserWidget)
		return "nop"
	end,

	draw = function(self: BrowserWidget)
		local x = self.realx1
		local y = self.realy1
		local w = self.realwidth
		local h = self.realheight

		-- Draw the box.

		do
			local border = string_rep(UseUnicode() and "─" or "-", w - 2)
			SetBright()
			Write(x, y, UseUnicode() and "┌" or "+")
			Write(x+1, y, border)
			Write(x+w-1, y, UseUnicode() and "┐" or "+")
			for i = 1, h-1 do
				Write(x, y+i, UseUnicode() and "│" or "|")
				Write(x+w-1, y+i, UseUnicode() and "│" or "|")
			end
			Write(x, y+h, UseUnicode() and "└" or "+")
			Write(x+1, y+h, border)
			Write(x+w-1, y+h, UseUnicode() and "┘" or "+")
			SetNormal()
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
				SetBright()
				s = "│"
				local yf = (i+1) * #self.data / (h-1)
				if (yf >= self.offset) and (yf <= (self.offset + h-2)) then
					s = "║"
				end
				Write(x+w-1, y+1+i, s)
			end
			SetNormal()
		end
		SetNormal()
	end,

	["KEY_UP"] = function(self: BrowserWidget, key)
		if (self.cursor > 1) then
			self.cursor = self.cursor - 1
			self:draw()
			return self:changed()
		end

		return "nop"
	end,

	["KEY_DOWN"] = function(self: BrowserWidget, key)
		if (self.cursor < #self.data) then
			self.cursor = self.cursor + 1
			self:draw()
			return self:changed()
		end

		return "nop"
	end,

	["KEY_PGUP"] = function(self: BrowserWidget, key)
		local oldcursor = self.cursor
		self.cursor = oldcursor - int(self.realheight/2)
		if (self.cursor < 1) then
			self.cursor = 1
		end

		if (self.cursor ~= oldcursor) then
			self:draw()
			return self:changed()
		end
		return "nop"
	end,

	["KEY_PGDN"] = function(self: BrowserWidget, key)
		local oldcursor = self.cursor
		self.cursor = oldcursor + int(self.realheight/2)
		if (self.cursor > #self.data) then
			self.cursor = #self.data
		end

		if (self.cursor ~= oldcursor) then
			self:draw()
			return self:changed()
		end
		return "nop"
	end,
}

local standard_actions: {[string]: FormAction} =
{
	["KEY_UP"] = function(form: Form, key)
		if form.focus then
			local f = form.focus - 1
			while (f ~= form.focus) do
				if (f == 0) then
					f = #form.widgets
				end

				local widget = form.widgets[f]
				if widget.focusable then
					form.focus = f
					return "redraw"
				end

				f = f - 1
			end
		end

		return "nop"
	end,

	["KEY_DOWN"] = function(form: Form, key)
		if form.focus then
			local f = form.focus + 1
			while (f ~= form.focus) do
				if (f > #form.widgets) then
					f = 1
				end

				local widget = form.widgets[f]
				if widget.focusable then
					form.focus = f
					return "redraw"
				end

				f = f + 1
			end
		end

		return "nop"
	end
}
Form.Browser = Browser

local function resolvesize(size: number, bound: number): number
	if (size < 0) then
		return size + bound
	else
		return size
	end
end

local function findaction(table: ActionTable, focus: any, key: string): ActionResult?
	local action = table[key]
	if action then
		if type(action) == "function"  then
			return action(focus, key)
		elseif type(action) == "string" then
			return action::FormCommand
		end
	end
	return nil
end

local function findmouseaction(form, m)
	local x = m.x
	local y = m.y
	for i, widget in form.widgets do
		if (x >= widget.realx1) and (x <= widget.realx2)
			and (y >= widget.realy1) and (y <= widget.realy2)
		then
			local action = nil
			if m.b and widget.focusable then
				form.focus = i
				if widget.click then
					action = widget:click(m)
				end
			end
			if not action and widget.mouse then
				action = widget:mouse(m)
			end
			return action or "redraw"
		end
	end
	return nil
end

function Form.Run(form: Form, redraw: (() -> ())?, helptext: string?)
	local function redraw_form()
		-- Ensure the screen is properly sized.

		ResizeScreen()

		-- Find a widget to give the focus to.

		if not form.focus then
			for i, widget in form.widgets do
				if widget.focusable then
					form.focus = i
					break
				end
			end
		end

		-- Initialise any widgets that need it.

		for _, widget in form.widgets do
			if widget.init then
				widget:init()
			end
		end

		-- Redraw the backdrop.

		if redraw then
			redraw()
		end

		-- Size the form.

		local realwidth = 0
		local realheight = 0

		if (form.width == "large") then
			realwidth = int(ScreenWidth * 6/7)
		else
			realwidth = form.width
		end

		if (form.height == "large") then
			realheight = int(ScreenHeight * 5/6)
		else
			realheight = form.height
		end

		-- Is this a stretchy form?

		if form.stretchy then
			-- Automatically scale the height depending on a 'stretchy' widget.

			for _, widget in form.widgets do
				if (widget.y1 > 0) and (widget.y2 < 0) then
					widget.realx1 = resolvesize(widget.x1, realwidth)
					widget.realx2 = resolvesize(widget.x2, realwidth)
					widget.realwidth = widget.realx2 - widget.realx1

					local h = 1
					if widget.calculate_height then
						h = widget:calculate_height()
					end

					realheight = realheight + h
					break
				end
			end
		end

		-- Place the form.

		local realx = int(ScreenWidth/2 - realwidth/2)
		local realy = int(ScreenHeight/2 - realheight/2)

		-- Place all widgets in the form.

		for _, widget in form.widgets do
			widget.realx1 = resolvesize(widget.x1, realwidth) + realx
			widget.realy1 = resolvesize(widget.y1, realheight) + realy
			widget.realx2 = resolvesize(widget.x2, realwidth) + realx
			widget.realy2 = resolvesize(widget.y2, realheight) + realy
			widget.realwidth = widget.realx2 - widget.realx1
			widget.realheight = widget.realy2 - widget.realy1
		end

		-- Draw the form itself.

		SetColour(Palette.ControlFG, Palette.ControlBG)
		do
			local sizeadjust = 0
			if helptext then
				sizeadjust = 1
			end
			DrawTitledBox(realx - 1, realy - 1,
				realwidth, realheight + sizeadjust,
				form.title)

			if helptext then
				CentreInField(realx, realy + realheight,
					realwidth, "<"..helptext..">")
			end
		end

		-- Draw the widgets.

		GotoXY(ScreenWidth-1, ScreenHeight-1)
		for i, widget in form.widgets do
			widget.focus = (i == form.focus)
			widget:draw()
		end

		form.transient = false
	end

	-- Process keys.

	redraw_form()
	while not Quitting do
		HideCursor()
		local key = if form.focus then
			GetCharWithBlinkingCursor() else GetChar()

		if form.transient then
			redraw_form()
		end

		if (key == "KEY_RESIZE") then
			ResizeScreen()
			redraw_form()
		end
		if (key == "KEY_QUIT") then
			QuitForcedBySystem()
		end

		local action = nil
		if type(key) == "table" then
			action = findmouseaction(form, key)
		else
			if form.focus then
				local w = form.widgets[form.focus]
				action = findaction(w::any, w, key)
			end

			if not action then
				if key == "KEY_^C" then
					action = "cancel"
				elseif key == "KEY_ESCAPE" then
					action = "cancel"
				else
					action = findaction(form.actions, form, key) or
						findaction(standard_actions, form, key)
				end
			end

			if not action and form.focus then
				local w = form.widgets[form.focus]
				action = w:key(key)
			end
		end

		if (action == "cancel") then
			return false
		elseif (action == "confirm") then
			return true
		elseif (action == "redraw") then
			redraw_form()
		end
	end
	return false
end
