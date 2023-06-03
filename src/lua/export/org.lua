--!nonstrict
local function unorg(s)
	s = s:gsub("#", "\\#")
	s = s:gsub("- ", "\\- ")
	s = s:gsub("<", "\\<")
	s = s:gsub(">", "\\>")
	s = s:gsub("`", "\\`")
	s = s:gsub("_", "\\_")
	s = s:gsub("*", "\\*")
	return s
end

local style_tab: {[string]: {any}} =
{
	["H1"] = {false, '* ', '\n'},
	["H2"] = {false, '** ', '\n'},
	["H3"] = {false, '*** ', '\n'},
	["H4"] = {false, '**** ', '\n'},
	["P"] =  {false, '', '\n'},
	["L"] =  {false, '- ', ''},
	["LB"] = {false, '- ', ''},
	["LN"] = {false, '1. ', ''},
	["Q"] =  {false, '#+begin_quote\n', '\n#+end_quote\n'},
	["V"] =  {false, '#+begin_quote\n', '\n#+end_quote\n'},
	["RAW"] = {false, '', ''},
	["PRE"] = {true, '#+begin_src\n', '\n#+end_src\n'}
}

local function callback(writer: (...string) -> (), document: Document)
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
			writer('#+TITLE: ', document.name, '\n')
		end,

		rawtext = function(s)
			writer(s)
		end,

		text = function(s)
			writer(unorg(s))
		end,

		notext = function()
		end,

		italic_on = function()
			writer("/")
		end,

		italic_off = function()
			writer("/")
		end,

		underline_on = function()
			writer("_")
		end,

		underline_off = function()
			writer("_")
		end,

		bold_on = function()
			writer("*")
		end,

		bold_off = function()
			writer("*")
		end,

		list_start = function()
			writer("\n")
		end,

		list_end = function()
			writer("\n")
		end,

		paragraph_start = function(para)
			changepara(para.style)
		end,

		paragraph_end = function(para)
		end,

		epilogue = function()
			changepara(nil)
		end,
	})
end

function Cmd.ExportOrgFile(filename)
	return ExportFileWithUI(filename, "Export Org File", ".org", callback)
end

function Cmd.ExportToOrgString()
	return ExportToString(currentDocument, callback)
end

