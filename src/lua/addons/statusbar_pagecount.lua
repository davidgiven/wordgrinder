-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local settings = DocumentSet.addons.pagecount or {}
		if settings.enabled then
			if settings.pagesbylines then
				local pages = math.ceil((Document.linecount or 0) / settings.linesperpage)
				terms[#terms+1] = {
					priority=80,
					value=string.format("%d %s", pages,
						Pluralise(pages, "page", "pages"))
				}
			else
				local pages = math.ceil((Document.linecount or 0) / settings.wordsperpage)
				terms[#terms+1] = {
					priority=80,
					value=string.format("%d %s", pages,
						Pluralise(pages, "page", "pages"))
				}
			end
		end
	end
	
	AddEventListener(Event.BuildStatusBar, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.pagecount = DocumentSet.addons.pagecount or {
			enabled = false,
			pagesbylines = true,
			wordsperpage = 251,
			linesperpage = 22,
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigurePageCount()
	local settings = DocumentSet.addons.pagecount

	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 40, y2 = 1,
			label = "Show approximate page count",
			value = settings.enabled
		}
	local mode_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 3,
			x2 = 40, y2 = 3,
			label = "estimate pagecount by lines, not words",
			value = settings.pagesbylines
		}
	local count_textfield =
		Form.TextField {
			x1 = 40, y1 = 5,
			x2 = 50, y2 = 5,
			value = tostring(settings.wordsperpage)
		}

	local count_lpptextfield =
		Form.TextField {
			x1 = 40, y1 = 7,
			x2 = 50, y2 = 7,
			value = tostring(settings.linesperpage)
		}
		
	local dialogue =
	{
		title = "Configure Page Count",
		width = Form.Large,
		height = 11,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		mode_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 39, y2 = 5,
			align = Form.Left,
			value = "Number of words per page:"
		},
		count_textfield,

		Form.Label {
			x1 = 1, y1 = 7,
			x2 = 39, y2 = 7,
			align = Form.Left,
			value = "Number of lines per page:"
		},
		count_lpptextfield
	}
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local enabled = enabled_checkbox.value
		local pagesbylines = mode_checkbox.value
		local wordsperpage = tonumber(count_textfield.value)
		local linesperpage = tonumber(count_lpptextfield.value)

		if not wordsperpage then
			ModalMessage("Parameter error", "The number of words per page must be a valid number.")

		elseif not linesperpage then
			ModalMessage("Parameter error", "The number of lines per page must be a valid number.")

		else
			settings.enabled = enabled
			settings.pagesbylines = pagesbylines
			settings.wordsperpage = wordsperpage
			settings.linesperpage = linesperpage
			DocumentSet:touch()

			return true
		end
	end
		
	return false
end
