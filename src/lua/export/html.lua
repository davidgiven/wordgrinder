-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- The exporter itself.

local function unhtml(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local style_tab =
{
	["H1"] = {false, '<h1>', '</h1>'},
	["H2"] = {false, '<h2>', '</h2>'},
	["H3"] = {false, '<h3>', '</h3>'},
	["H4"] = {false, '<h4>', '</h4>'},
	["P"] =  {false, '<p>', '</p>'},
	["L"] =  {false, '<li style="list-style-type: none;">', '</li>'},
	["LB"] = {false, '<li>', '</li>'},
	["Q"] =  {false, '<blockquote>', '</blockquote>'},
	["V"] =  {false, '<blockquote>', '</blockquote>'},
	["RAW"] = {false, '', ''},
	["PRE"] = {true, '<pre>', '</pre>'}
}

local function callback(writer, document)
	local settings = DocumentSet.addons.htmlexport
	local currentpara = nil
	
	function changepara(newpara)
		local currentstyle = style_tab[currentpara]
		local newstyle = style_tab[newpara]
		
		if (newpara ~= currentpara) or
			not newpara or
			not currentstyle[1] or
			not newstyle[1] 
		then
			if currentstyle then
				writer(currentstyle[3])
			end
			writer("\n")
			if newstyle then
				writer(newstyle[2])
			end
			currentpara = newpara
		else
			writer("\n")
		end
	end
		
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			writer('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n')
			writer('<html><head>\n')
			writer('<meta http-equiv="Content-Type" content="text/html;charset=utf-8">\n')
			writer('<meta name="generator" content="WordGrinder '..VERSION..'">\n')
			writer('<title>', unhtml(document.name), '</title>\n')
			writer('</head><body>\n')
		end,
		
		rawtext = function(s)
			writer(s)
		end,
		
		text = function(s)
			writer(unhtml(s))
		end,
		
		notext = function(s)
			if (currentpara ~= "PRE") then
				writer('<br/>')
			end
		end,
		
		italic_on = function()
			writer(settings.italic_on)
		end,
		
		italic_off = function()
			writer(settings.italic_off)
		end,
		
		underline_on = function()
			writer(settings.underline_on)
		end,
		
		underline_off = function()
			writer(settings.underline_off)
		end,
		
		bold_on = function()
			writer(settings.bold_on)
		end,
		
		bold_off = function()
			writer(settings.bold_off)
		end,
		
		list_start = function()
			writer('<ul>')
		end,
		
		list_end = function()
			writer('</ul>')
		end,
		
		paragraph_start = function(style)
			changepara(style)
		end,		
		
		paragraph_end = function(style)
		end,
		
		epilogue = function()
			changepara(nil)
			writer('</body>\n')	
			writer('</html>\n')
		end
	})
end

function Cmd.ExportHTMLFile(filename)
	return ExportFileWithUI(filename, "Export HTML File", ".html",
		callback)
end

-----------------------------------------------------------------------------
-- Addon registration. Set the HTML export settings.

do
	local function cb()
		DocumentSet.addons.htmlexport = DocumentSet.addons.htmlexport or {
			underline_on = "<u>",
			underline_off = "</u>",
			italic_on = "<i>",
			italic_off = "</i>"
		}

		local s = DocumentSet.addons.htmlexport
		s.bold_on = s.bold_on or "<b>"
		s.bold_off = s.bold_off or "</b>"
	end
	
	AddEventListener(Event.RegisterAddons, cb)
end

-----------------------------------------------------------------------------
-- Configuration user interface.

function Cmd.ConfigureHTMLExport()
	local settings = DocumentSet.addons.htmlexport

	local underline_on_textfield =
		Form.TextField {
			x1 = 16, y1 = 1,
			x2 = -1, y2 = 1,
			value = settings.underline_on
		}

	local underline_off_textfield =
		Form.TextField {
			x1 = 16, y1 = 3,
			x2 = -1, y2 = 3,
			value = settings.underline_off
		}

	local italic_on_textfield =
		Form.TextField {
			x1 = 16, y1 = 5,
			x2 = -1, y2 = 5,
			value = settings.italic_on
		}

	local italic_off_textfield =
		Form.TextField {
			x1 = 16, y1 = 7,
			x2 = -1, y2 = 7,
			value = settings.italic_off
		}

	local bold_on_textfield =
		Form.TextField {
			x1 = 16, y1 = 9,
			x2 = -1, y2 = 9,
			value = settings.bold_on
		}

	local bold_off_textfield =
		Form.TextField {
			x1 = 16, y1 = 11,
			x2 = -1, y2 = 11,
			value = settings.bold_off
		}

	local dialogue =
	{
		title = "Configure HTML Export",
		width = Form.Large,
		height = 13,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 32, y2 = 1,
			align = Form.Left,
			value = "Underline on:"
		},
		underline_on_textfield,
		
		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 32, y2 = 3,
			align = Form.Left,
			value = "Underline off:"
		},
		underline_off_textfield,
		
		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 32, y2 = 5,
			align = Form.Left,
			value = "Italics on:"
		},
		italic_on_textfield,
		
		Form.Label {
			x1 = 1, y1 = 7,
			x2 = 32, y2 = 7,
			align = Form.Left,
			value = "Italics off:"
		},
		italic_off_textfield,
		
		Form.Label {
			x1 = 1, y1 = 9,
			x2 = 32, y2 = 9,
			align = Form.Left,
			value = "Bold on:"
		},
		bold_on_textfield,
		
		Form.Label {
			x1 = 1, y1 = 11,
			x2 = 32, y2 = 11,
			align = Form.Left,
			value = "Bold off:"
		},
		bold_off_textfield,
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen,
			"SPACE to toggle, RETURN to confirm, CTRL+C to cancel")
		if not result then
			return false
		end
		
		settings.underline_on = underline_on_textfield.value
		settings.underline_off = underline_off_textfield.value
		settings.italic_on = italic_on_textfield.value
		settings.italic_off = italic_off_textfield.value
		settings.bold_on = bold_on_textfield.value
		settings.bold_off = bold_off_textfield.value
		return true
	end
		
	return false
end
