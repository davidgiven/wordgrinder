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
		Document.margin = 0
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

		Document.margin = m + 1
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
			Document.margin = int(math.log10(#Document)) + 3
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
		Document.margin = 5
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
	local controller = MarginControllers[Document.viewmode]
	if controller.detach then
		controller:detach()
	end

	Document.viewmode = mode
	controller = MarginControllers[Document.viewmode]
	if controller.attach then
		controller:attach()
	end

	DocumentSet:touch()
	ResizeScreen()
end

function Cmd.SetViewMode(mode)
	SetMarginMode(mode)
	QueueRedraw()
	return true
end

