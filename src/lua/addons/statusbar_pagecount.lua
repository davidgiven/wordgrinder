--!nonstrict
-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- Build the status bar.

do
	local function cb(event, token, terms)
		local settings = documentSet.addons.pagecount or {}
		if settings.enabled then
			local pages = math.floor((currentDocument.wordcount or 0) / settings.wordsperpage)
			terms[#terms+1] = {
				priority=80,
				value=string.format("%d %s", pages,
					Pluralise(pages, "page", "pages"))
			}
		end
	end
	
	AddEventListener("BuildStatusBar", cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the documentSet.

do
	local function cb()
		documentSet.addons.pagecount = documentSet.addons.pagecount or {
			enabled = false,
			wordsperpage = 250,
		}
	end
	
	AddEventListener("RegisterAddons", cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigurePageCount()
	local settings = documentSet.addons.pagecount

	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = -1, y2 = 1,
			label = "Show approximate page count",
			value = settings.enabled
		}

	local count_textfield =
		Form.TextField {
			x1 = -11, y1 = 3,
			x2 = -1, y2 = 3,
			value = tostring(settings.wordsperpage)
		}
		
	local dialogue: Form =
	{
		title = "Configure Page Count",
		width = "large",
		height = 5,
		stretchy = false,

		actions = {
			["KEY_RETURN"] = "confirm",
			["KEY_ENTER"] = "confirm",
		},
		
		widgets = {
			enabled_checkbox,
			
			Form.Label {
				x1 = 1, y1 = 3,
				x2 = 32, y2 = 3,
				align = "left",
				value = "Number of words per page:"
			},
			count_textfield,
		}
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, "..ESCAPE_KEY.." to cancel")
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
			documentSet:touch()

			return true
		end
	end
		
	return false
end
