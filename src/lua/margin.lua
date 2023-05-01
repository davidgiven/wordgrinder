--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local GetStringWidth = wg.getstringwidth

type MarginController = {
	token: any?,

	attach: (self: MarginController) -> (),
	detach: ((self: MarginController) -> ())?,
	getcontent: (self: MarginController, pn: number, paragraph: Paragraph) -> ()
}

-- This code defines the various controllers that work the margin displays.
-- It's all a little overengineered, but is really intended to test some
-- modularisation concepts.

local no_margin_controller =
{
	attach = function(self: MarginController)
		currentDocument.margin = 0
		NonmodalMessage("Hiding margin.")
	end,

	getcontent = function(self: MarginController, pn: number, paragraph: Paragraph)
		return nil
	end
}

local style_name_controller =
{
	attach = function(self: MarginController)
		local m = 0

		for _, style in pairs(documentStyles) do
			local mm = GetStringWidth(style.name)
			if (mm > m) then
				m = mm
			end
		end

		currentDocument.margin = m
		NonmodalMessage("Margin now displays paragraph styles.")
	end,

	getcontent = function(self: MarginController, pn: number, paragraph: Paragraph)
		return paragraph.style
	end
}

local paragraph_number_controller =
{
	attach = function(self: MarginController)
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

	detach = function(self: MarginController)
		RemoveEventListener(self.token)
		self.token = nil
	end,

	getcontent = function(self: MarginController, pn: number, paragraph: Paragraph)
		return tostring(pn)
	end
}

local word_count_controller =
{
	attach = function(self: MarginController)
		currentDocument.margin = 3
		NonmodalMessage("Margin now displays word counts.")
	end,

	getcontent = function(self: MarginController,
			pn: number, paragraph: Paragraph)
		return tostring(#paragraph)
	end
}

marginControllers =
{
	[1] = no_margin_controller,
	[2] = style_name_controller,
	[3] = paragraph_number_controller,
	[4] = word_count_controller
} :: {MarginController}

--- Sets a specific margin mode for the current document.
--
-- @param mode               the new margin mode

function SetMarginMode(mode)
	local controller = marginControllers[currentDocument.viewmode]
	if controller.detach then
		assert(controller.detach)(controller)
	end

	currentDocument.viewmode = mode
	controller = marginControllers[currentDocument.viewmode]
	if controller.attach then
		assert(controller.attach)(controller)
	end

	documentSet:touch()
	ResizeScreen()
end

function Cmd.SetViewMode(mode)
	SetMarginMode(mode)
	QueueRedraw()
	return true
end

