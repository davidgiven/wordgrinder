-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local string_find = string.find
local table_concat = table.concat
local stderr = io.stderr

local import_table =
{
	["wg"] = Cmd.LoadDocumentSet,
	["odt"] = Cmd.ImportODTFile,
	["html"] = Cmd.ImportHTMLFile,
	["txt"] = Cmd.ImportTextFile 
}

local export_table =
{
	["wg"] = Cmd.SaveCurrentDocumentAs,
	["odt"] = Cmd.ExportODTFile,
	["html"] = Cmd.ExportHTMLFile,
	["tr"] = Cmd.ExportTroffFile,
	["tex"] = Cmd.ExportLatexFile, 
	["txt"] = Cmd.ExportTextFile,
	["md"] = Cmd.ExportMarkdownFile,
}

function CLIMessage(...)
	stderr:write("wordgrinder: ", ...)
	stderr:write("\n")
	stderr:flush()
end

function CLIError(...)
	CLIMessage(...)
	os.exit(1)
end
		
--- Engages CLI mode.

function EngageCLI()
	function ImmediateMessage(s)
		if s then
			CLIMessage(s)
		end
	end
	
	function ModalMessage(s1, s2)
		if s2 then
			CLIMessage(s2)
		end
	end
end

--- Converts between two files.
--
-- @param file1                 Source filename
-- @param file2                 Destination filename

function CliConvert(file1, file2)
	EngageCLI()
	
	local function decode_filename(f)
		local _, _, root, extension, hassubdoc, subdoc = string_find(f,
			"^(.*)%.(%w*)(:?)(.*)$")
		
		if not root or not extension then
			CLIError("unable to parse filename '", f, "'")
		end
			
		return root, extension, hassubdoc, subdoc
	end
	
	local f1r, f1e, f1hs, f1s = decode_filename(file1)
	local f1 = f1r.."."..f1e
	local f2r, f2e, f2hs, f2s = decode_filename(file2)
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
			
			local dl = DocumentSet:getDocumentList()
			if not dl[f1s] then
				CLIError("no such document '", f1s, "'")
			end
			DocumentSet:setCurrent(f1s)
		else
			-- Otherwise, rename the document we just imported to the name
			-- that the user specified.
			
			local name = Document.name
			DocumentSet:renameDocument(name, f1s)
		end
	end
	
	if not exporter(f2) then
		CLIError("failed")
	end
	
	os.exit(0)
end

