--!nonstrict
-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local PrintErr = wg.printerr
local string_find = string.find
local table_concat = table.concat

local import_table =
{
	["html"] = Cmd.ImportHTMLFile,
	["md"] = Cmd.ImportMarkdownFile,
	["odt"] = Cmd.ImportODTFile,
	["txt"] = Cmd.ImportTextFile,
	["wg"] = Cmd.LoadDocumentSet,
}

local export_table =
{
	["html"] = Cmd.ExportHTMLFile,
	["md"] = Cmd.ExportMarkdownFile,
	["odt"] = Cmd.ExportODTFile,
	["org"] = Cmd.ExportOrgFile,
	["tex"] = Cmd.ExportLatexFile, 
	["tr"] = Cmd.ExportTroffFile,
	["txt"] = Cmd.ExportTextFile,
	["wg"] = Cmd.SaveCurrentDocumentAs,
--	["rtf"] = Cmd.ExportRTFFile,
}

function CLIMessage(...: string)
	PrintErr("wordgrinder: ", ...)
	PrintErr("\n")
end

function CLIError(...: string)
	CLIMessage(...)
	wg.exit(1)
end
		
--- Engages CLI mode.

function EngageCLI()
	function ImmediateMessage(s: string)
		if s then
			CLIMessage(s)
		end
	end
	
	function ModalMessage(s1: string, s2: string)
		if s2 then
			CLIMessage(s2)
		end
	end
end

--- Converts between two files.
--
-- @param file1                 Source filename
-- @param file2                 Destination filename

function CliConvert(file1: string, file2: string)
	EngageCLI()
	
	local function decode_filename(f: string): (string, string, string, string)
		local _, _, root, extension, hassubdoc, subdoc = string_find(f,
			"^(.*)%.(%w*)(:?)(.*)$")
		
		if not root or not extension then
			CLIError("unable to parse filename '", f, "'")
		end

		assert(root)
		assert(extension)
		assert(hassubdoc)
		assert(subdoc)
		return root, extension, hassubdoc, subdoc
	end
	
	local f1r, f1e, f1hs, f1s = decode_filename(file1)
	local f1 = f1r.."."..f1e
	local f2r, f2e, f2hs, _f2s = decode_filename(file2)
	local f2 = f2r.."."..f2e
	
	if (f2hs ~= "") then
		CLIError("you cannot specify a document name for the output file")
	end
	
	local function supported_extensions(t)
		local s = {}
		for k, v in pairs(t) do
			s[#s+1] = k
		end
		return table_concat(s, " ")
	end
	
	local importer = import_table[f1e]
	if not importer then
		CLIError("don't know how to import extension '", f1e, "' ",
			"(supported extensions are: ",
			supported_extensions(import_table), ")")
	end
	
	local exporter = export_table[f2e]
	if not exporter then
		CLIError("don't know how to export extension '", f2e, "' ",
			"(supported extensions are: ",
			supported_extensions(export_table), ")")
	end
	
	if not importer(f1) then
		CLIError("failed")
	end
	
	if (f1hs ~= "") then
		if (f1e == "wg") then
			-- If the user specified a document name, and we loaded a wg file,
			-- then select the specified document.
			
			local dl = documentSet:getDocumentList()
			if not documentSet:_findDocument(f1s) then
				CLIError("no such document '", f1s, "'")
			end
			documentSet:setCurrent(f1s)
		else
			-- Otherwise, rename the document we just imported to the name
			-- that the user specified.
			
			local name = currentDocument.name
			documentSet:renameDocument(name, f1s)
		end
	end
	
	if not exporter(f2) then
		CLIError("failed")
	end
	
	wg.exit(0)
end

