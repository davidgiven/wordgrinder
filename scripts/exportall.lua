-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-- This user script will export all subdocuments in a document set.
--
-- To use:
--
--     wordgrinder --lua exportall.lua "mynovel.wg output.html"
--
-- (Note the quoting.)
--
-- If mynovel.wg contains subdocuments called Foo, Bar and Baz, this will
-- create files output.1.Foo.html, output.2.Bar.html and output.3.Baz.html.

-- Main program

local function main(args)
    local inputfile, template = unpack(SplitString(args, " "))

	if not template then
		print("Syntax: wordgrinder --lua exportall.lua '<inputfile.wg> <outputfiletemplate>'")
		os.exit(1)
	end

    local export_table =
    {
        ["wg"] = Cmd.SaveCurrentDocumentAs,
        ["odt"] = Cmd.ExportODTFile,
        ["html"] = Cmd.ExportHTMLFile,
        ["tr"] = Cmd.ExportTroffFile,
        ["tex"] = Cmd.ExportLatexFile, 
        ["txt"] = Cmd.ExportTextFile,
    }
    local _, _, extension = template:find("%.(%w+)$")
    local exporter = export_table[extension or ""]
    if not exporter then
        print("Unknown output format")
        os.exit(1)
    end

    if not Cmd.LoadDocumentSet(inputfile) then
        print("failed to load document")
        os.exit(1)
    end

    for i, doc in ipairs(DocumentSet:getDocumentList()) do
        local outputfile = template:gsub("%.(%w+)$", "."..i.."."..doc.name..".%1")
        print(outputfile)
        Document = doc
        if not exporter(outputfile) then
            print("failed to write output file")
            os.exit(1)
        end
    end
end

main(...)
os.exit(0)


