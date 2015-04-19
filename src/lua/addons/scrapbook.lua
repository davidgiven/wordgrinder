-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local function maketimestamp(pattern, name)
	name = name or Document.name
	name = name:gsub("%%", "%%%%")
	
	local timestamp = os.date("%Y-%m-%d.%H%M")
	timestamp = timestamp:gsub("%%", "%%%%")
	
	pattern = pattern:gsub("%%[nN]", name)
	pattern = pattern:gsub("%%[tT]", timestamp)
	pattern = pattern:gsub("%%%%", "%%")
	return pattern
end

function Cmd.CutToScrapbook()
	if not Document.mp then
		NonmodalMessage("There's nothing selected.")
		return false
	end
	
	if not Cmd.Cut() then
		return false
	end
	return Cmd.PasteToScrapbook()
end

function Cmd.CopyToScrapbook()
	if not Document.mp then
		NonmodalMessage("There's nothing selected.")
		return false
	end
	
	if not Cmd.Copy() then
		return false
	end
	return Cmd.PasteToScrapbook()
end

function Cmd.PasteToScrapbook()
	local buffer = DocumentSet:getClipboard()
	if not buffer then
		NonmodalMessage("There's nothing on the clipboard.")
		return false
	end
	
	local settings = DocumentSet.addons.scrapbook
	
	local currentdocument = Document.name
	
	if not DocumentSet:findDocument(settings.document) then
		DocumentSet:addDocument(CreateDocument(), settings.document)
		NonmodalMessage("Creating scrapbook in document '"..settings.document.."'.")
	end
	DocumentSet:setCurrent(settings.document)

	Cmd.GotoEndOfDocument()
	Cmd.UnsetMark()
	Cmd.SplitCurrentParagraph()
	if settings.timestamp then
		Cmd.InsertStringIntoParagraph(maketimestamp(settings.pattern, currentdocument))
		Cmd.ChangeParagraphStyle("H1")
		Cmd.SplitCurrentParagraph()
	end
	Cmd.ChangeParagraphStyle("P")
	Cmd.Paste()
	
	DocumentSet:setCurrent(currentdocument)
	NonmodalMessage("Fragment added to scrapbook.")
	
	return false
end

-----------------------------------------------------------------------------
-- Addon registration. Create the default settings in the DocumentSet.

do
	local function cb()
		DocumentSet.addons.scrapbook = DocumentSet.addons.scrapbook or {
			document = "Scrapbook",
			timestamp = true,
			pattern = "Item from '%N' at %T:" 
		}
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureScrapbook()
	local settings = DocumentSet.addons.scrapbook

	local document_textfield =
		Form.TextField {
			x1 = 33, y1 = 1,
			x2 = -1, y2 = 1,
			value = tostring(settings.document)
		}
		
	local timestamp_checkbox =
		Form.Checkbox {
			x1 = 1, y1 = 3,
			x2 = 33, y2 = 3,
			label = "Enable timestamp",
			value = settings.timestamp
		}

	local example_label =
		Form.Label {
			x1 = 1, y1 = 7,
			x2 = -1, y2 = 7,
		}
		
	local pattern_textfield =
		Form.TextField {
			x1 = 33, y1 = 5,
			x2 = -1, y2 = 5,
			value = settings.pattern,
			
			draw = function(self)
				self.class.draw(self)
				
				example_label.value = "(Example timestamp: "..maketimestamp(self.value)..")"
				example_label:draw()
			end
		}
	
	local dialogue =
	{
		title = "Configure Timestamp",
		width = Form.Large,
		height = 9,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",
		
		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 32, y2 = 1,
			align = Form.Left,
			value = "Name of scrapbook document:"
		},
		document_textfield,
		
		timestamp_checkbox,
		
		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Timestamp pattern:"
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
		
		local document = document_textfield.value
		local timestamp = timestamp_checkbox.value
		local pattern = pattern_textfield.value
		
		if (document:len() == 0) then
			ModalMessage("Parameter error", "The document name cannot be empty.")
		elseif (pattern:len() == 0) then
			ModalMessage("Parameter error", "The timestamp pattern cannot be empty.")
		elseif pattern:find("%%[^%%ntNT]") then
			ModalMessage("Parameter error", "The filename pattern can only contain "..
				"%%, %N or %T fields.")
		else
			settings.document = document
			settings.timestamp = timestamp
			settings.pattern = pattern
			DocumentSet:touch()

			return true
		end
	end
		
	return false
end
