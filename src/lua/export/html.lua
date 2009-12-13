-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

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

local function callback(fp, document)
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
				fp:write(currentstyle[3])
			end
			fp:write("\n")
			if newstyle then
				fp:write(newstyle[2])
			end
			currentpara = newpara
		else
			fp:write("\n")
		end
	end
		
	return ExportFileUsingCallbacks(document,
	{
		prologue = function()
			fp:write('<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">\n')
			fp:write('<html><head>\n')
			fp:write('<meta http-equiv="Content-Type" content="text/html;charset=utf-8">\n')
			fp:write('<meta name="generator" content="WordGrinder '..VERSION..'">\n')
			fp:write('<title>', unhtml(document.name), '</title>\n')
			fp:write('</head><body>\n')
		end,
		
		rawtext = function(s)
			fp:write(s)
		end,
		
		text = function(s)
			fp:write(unhtml(s))
		end,
		
		notext = function(s)
			fp:write('<br/>')
		end,
		
		italic_on = function()
			fp:write(settings.italic_on)
		end,
		
		italic_off = function()
			fp:write(settings.italic_off)
		end,
		
		underline_on = function()
			fp:write(settings.underline_on)
		end,
		
		underline_off = function()
			fp:write(settings.underline_off)
		end,
		
		list_start = function()
			fp:write('<ul>')
		end,
		
		list_end = function()
			fp:write('</ul>')
		end,
		
		paragraph_start = function(style)
			changepara(style)
		end,		
		
		paragraph_end = function(style)
		end,
		
		epilogue = function()
			changepara(nil)
			fp:write('</body>\n')	
			fp:write('</html>\n')
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

	local dialogue =
	{
		title = "Configure HTML Export",
		width = Form.Large,
		height = 11,
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
			x1 = 1, y1 = -2,
			x2 = -1, y2 = -2,
			value = "<SPACE to toggle, RETURN to confirm, CTRL+C to cancel>"
		}
	}
	
	while true do
		local result = Form.Run(dialogue, RedrawScreen)
		if not result then
			return false
		end
		
		settings.underline_on = underline_on_textfield.value
		settings.underline_off = underline_off_textfield.value
		settings.italic_on = italic_on_textfield.value
		settings.italic_off = italic_off_textfield.value
		return true
	end
		
	return false
end
