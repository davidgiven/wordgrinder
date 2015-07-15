local function unmarkdown(s)
	s = s:gsub("#", "\\#")
	s = s:gsub("- ", "\\- ")
	s = s:gsub("> ", "\\> ")
	s = s:gsub("`", "\\`")
	s = s:gsub("_", "\\_")
	s = s:gsub("*", "\\*")
	return s
end

local style_tab =
{
	["H1"] = {false, '# ', '\n'},
	["H2"] = {false, '## ', '\n'},
	["H3"] = {false, '### ', '\n'},
	["H4"] = {false, '#### ', '\n'},
	["P"] =  {false, '', '\n'},
	["L"] =  {false, '- ', ''},
	["LB"] = {false, '- ', ''},
	["Q"] =  {false, '> ', '\n'}, 
	["V"] =  {false, '> ', '\n'},
	["RAW"] = {false, '    ', ''},
	["PRE"] = {true, '`', '`'}
}

local function callback(writer, document)
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
		end,

		rawtext = function(s)
			writer(s)
		end,

		text = function(s)
			writer(unmarkdown(s))
		end,

		notext = function()
		end,

		italic_on = function()
			writer("_")
		end,

		italic_off = function()
			writer("_")
		end,

		underline_on = function()
		end,

		underline_off = function()
		end,

		bold_on = function()
			writer("**")
		end,

		bold_off = function()
			writer("**")
		end,

		list_start = function()
			writer("\n")
		end,

		list_end = function()
			writer("\n")
		end,

		paragraph_start = function(s)
			changepara(s)
		end,

		paragraph_end = function(s)
		end,

		epilogue = function()
			changepara(nil)
		end,
	})
end

function Cmd.ExportMarkdownFile(filename)
	return ExportFileWithUI(filename, "Export Markdown File", ".md", callback)
end
