-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local settings = DocumentSet.addons.pagecount or {}
		if settings.enabled then
			local pages = math.floor((Document.wordcount or 0) / settings.wordsperpage)
			terms[#terms+1] = {
				priority=80,
				value=string.format("%d %s", pages,
					Pluralise(pages, "page", "pages"))
			}
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
			wordsperpage = 250,
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
			x2 = 33, y2 = 1,
			label = "Show approximate page count",
			value = settings.enabled
		}

	local count_textfield =
		Form.TextField {
			x1 = 33, y1 = 3,
			x2 = 43, y2 = 3,
			value = tostring(settings.wordsperpage)
		}
		
	local dialogue =
	{
		title = "Configure Page Count",
		width = Form.Large,
		height = 5,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Number of words per page:"
		},
		count_textfield,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local enabled = enabled_checkbox.value
		local wordsperpage = tonumber(count_textfield.value)
		
		if not wordsperpage then
			ModalMessage("Parameter error", "The number of words per page must be a valid number.")
		else
			settings.enabled = enabled
			settings.wordsperpage = wordsperpage
			DocumentSet:touch()

			return true
		end
	end
		
	return false
end
