--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local GetStringWidth = wg.getstringwidth

-- This code defines the various controllers that work the margin displays.
-- It's all a little overengineered, but is really intended to test some
-- modularisation concepts.

local no_margin_controller =
{
	attach = function(self)
		currentDocument.margin = 0
		NonmodalMessage("Hiding margin.")
	end,

	getcontent = function(self, pn, paragraph)
		return nil
	end
}

local style_name_controller =
{
	attach = function(self)
		local m = 0

		for _, style in pairs(DocumentStyles) do
			local mm = GetStringWidth(style.name)
			if (mm > m) then
				m = mm
			end
		end

		currentDocument.margin = m
		NonmodalMessage("Margin now displays paragraph styles.")
	end,

	getcontent = function(self, pn, paragraph)
		return paragraph.style
	end
}

local paragraph_number_controller =
{
	attach = function(self)
		local cb = function()
			local nm = int(math.log10(#currentDocument)) + 1
			if nm ~= currentDocument.margin then
				currentDocument.margin = nm
				ResizeScreen()
			end
		end

		self.token = AddEventListener(Event.Changed, cb)
		cb()
		NonmodalMessage("Margin now displays paragraph numbers.")
	end,

	detach = function(self)
		RemoveEventListener(self.token)
		self.token = nil
	end,

	getcontent = function(self, pn, paragraph)
		return tostring(pn)
	end
}

local word_count_controller =
{
	attach = function(self)
		currentDocument.margin = 3
		NonmodalMessage("Margin now displays word counts.")
	end,

	getcontent = function(self, pn, paragraph)
		return tostring(#paragraph)
	end
}

MarginControllers =
{
	[1] = no_margin_controller,
	[2] = style_name_controller,
	[3] = paragraph_number_controller,
	[4] = word_count_controller
}

--- Sets a specific margin mode for the current document.
--
-- @param mode               the new margin mode

function SetMarginMode(mode)
	local controller = MarginControllers[currentDocument.viewmode]
	if controller.detach then
		controller:detach()
	end

	currentDocument.viewmode = mode
	controller = MarginControllers[currentDocument.viewmode]
	if controller.attach then
		controller:attach()
	end

	documentSet:touch()
	ResizeScreen()
end

function Cmd.SetViewMode(mode)
	SetMarginMode(mode)
	QueueRedraw()
	return true
end

