-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Stat = wg.stat

local function announce()
	local settings = DocumentSet.addons.autosave

	if settings.enabled then
		NonmodalMessage("Autosave is enabled. Next save in "..settings.period..
			" minute"..Pluralise(settings.period, "", "s")..
			".")
	else
		NonmodalMessage("Autosave is disabled.")
	end	
end

local function makefilename(pattern)
	local leafname = Leafname(DocumentSet.name)
	local dirname = GlobalSettings.directories.autosaves or Dirname(DocumentSet.name)
	leafname = leafname:gsub("%.wg$", "")
	leafname = leafname:gsub("%%", "%%%%")
	
	local timestamp = os.date("%Y-%m-%d.%H%M")
	timestamp = timestamp:gsub("%%", "%%%%")
	
	pattern = pattern:gsub("%%[fF]", leafname)
	pattern = pattern:gsub("%%[tT]", timestamp)
	pattern = pattern:gsub("%%%%", "%%")
	return dirname.."/"..pattern
end

-----------------------------------------------------------------------------
-- Idle handler. This actually does the work of autosaving.

do
	local function cb()
		local settings = DocumentSet.addons.autosave
		if not settings.enabled or not DocumentSet.changed then
			return
		end
		
		if not settings.lastsaved then
			settings.lastsaved = os.time()
		end
		
		if ((os.time() - settings.lastsaved) > (settings.period * 60)) then
			ImmediateMessage("Autosaving...")
			
			local filename = makefilename(settings.pattern)
			local r, e = SaveDocumentSetRaw(filename)
			
			if not r then
				ModalMessage("Autosave failed", "The document could not be autosaved: "..e)
			else
				NonmodalMessage("Autosaved as "..filename) 
				QueueRedraw()
			end
			
			settings.lastsaved = os.time()
		end
	end
	
	AddEventListener(Event.Idle, cb)
end

-----------------------------------------------------------------------------
-- Load document. Nukes the 'last autosave' field 

do
	local function cb()
		DocumentSet.addons.autosave = DocumentSet.addons.autosave or {}
		DocumentSet.addons.autosave.lastsaved = nil
		announce()
	end
	
	AddEventListener(Event.DocumentLoaded, cb)
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.autosave = DocumentSet.addons.autosave or {
			enabled = false,
			period = 10,
			pattern = "%F.autosave.%T.wg",
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureAutosave()
	local settings = DocumentSet.addons.autosave

	if not DocumentSet.name then
		ModalMessage("Autosave not available", "You cannot use autosave "..
			"until you have manually saved your document at least once, "..
			"so that Autosave knows what base filename to use.")
		return false
	end
		
	local enabled_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 1,
			x2 = 33, y2 = 1,
			label = "Enable autosaving",
			value = settings.enabled
		}

	local period_textfield =
		Form.TextField {
			x1 = 33, y1 = 3,
			x2 = 43, y2 = 3,
			value = tostring(settings.period)
		}
		
	local example_label =
		Form.Label {
			x1 = 1, y1 = 7,
			x2 = -1, y2 = 7,
			value = ""
		}
		
	local pattern_textfield =
		Form.TextField {
			x1 = 33, y1 = 5,
			x2 = -1, y2 = 5,
			value = settings.pattern,
			
			draw = function(self)
				self.class.draw(self)

				local f = makefilename(self.value)
				if (#f > example_label.realwidth) then
					example_label.value = "..."..f:sub(-(example_label.realwidth-3))
				else
					example_label.value = f
				end
				example_label:draw()
			end
		}
	
	local dialogue =
	{
		title = "Configure Autosave",
		width = Form.Large,
		height = 9,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		enabled_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Period between saves (minutes):"
		},
		period_textfield,
		
		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Autosave filename pattern:"
		},
		pattern_textfield,

		example_label,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		local enabled = enabled_checkbox.value
		local period = tonumber(period_textfield.value)
		local pattern = pattern_textfield.value
		
		if not period then
			ModalMessage("Parameter error", "The period field must be a valid number.")
		elseif (pattern:len() == 0) then
			ModalMessage("Parameter error", "The filename pattern cannot be empty.")
		elseif pattern:find("%%[^%%ftFT]") then
			ModalMessage("Parameter error", "The filename pattern can only contain "..
				"%%, %F or %T fields.")
		else
			settings.enabled = enabled
			settings.period = period
			settings.pattern = pattern
			settings.lastsaved = nil
			DocumentSet:touch()

			announce()			
			return true
		end
	end
		
	return false
end
