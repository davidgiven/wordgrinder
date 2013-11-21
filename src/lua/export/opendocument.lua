-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local table_concat = table.concat
local writezip = wg.writezip

-----------------------------------------------------------------------------
-- The exporter itself.

local function unhtml(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	s = s:gsub("%s", "<text:s/>")
	return s
end

local style_tab =
{
	["H1"] = {false, '<text:h text:style-name="H1" text:outline-level="1">', '</text:h>'},
	["H2"] = {false, '<text:h text:style-name="H2" text:outline-level="2">', '</text:h>'},
	["H3"] = {false, '<text:h text:style-name="H3" text:outline-level="3">', '</text:h>'},
	["H4"] = {false, '<text:h text:style-name="H4" text:outline-level="4">', '</text:h>'},
	["P"] =  {false, '<text:p text:style-name="P">', '</text:p>'},
	["L"] =  {false, '<text:list text:style-name="L"><text:list-item><text:p text:style-name="P">',
		'</text:p></text:list-item></text:list>'},
	["LB"] = {false, '<text:list text:style-name="LB"><text:list-item><text:p text:style-name="P">',
		'</text:p></text:list-item></text:list>'},
	["Q"] =  {false, '<text:p text:style-name="Q">', '</text:p>'},
	["V"] =  {false, '<text:p text:style-name="V">', '</text:p>'},
	["RAW"] = {false, '', ''},
	["PRE"] = {false, '<text:p text:style-name="PRE">', '</text:p>'}
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
			writer(
				[[<?xml version="1.0" encoding="UTF-8"?>
					<office:document-content office:version="1.0"
					xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
					xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
					xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
					xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0">
					<office:body><office:text>
				]]
			)
			 
		end,
		
		epilogue = function()
			changepara(nil)
			writer('</office:text></office:body></office:document-content>\n')	
		end,
		
		rawtext = function(s)
			writer(s)
		end,
		
		text = function(s)
			writer(unhtml(s))
		end,
		
		notext = function(s)
		end,
		
		italic_on = function()
			writer('<text:span text:style-name="I">')
		end,
		
		italic_off = function()
			writer("</text:span>")
		end,
		
		bold_on = function()
			writer('<text:span text:style-name="B">')
		end,
		
		bold_off = function()
			writer("</text:span>")
		end,
		
		underline_on = function()
			writer('<text:span text:style-name="UL">')
		end,
		
		underline_off = function()
			writer("</text:span>")
		end,
		
		list_start = function()
		end,
		
		list_end = function()
		end,
		
		paragraph_start = function(style)
			changepara(style)
		end,		
		
		paragraph_end = function(style)
		end,
		
	})
end

local function export_odt_with_ui(filename, title, extension)
	if not filename then
		filename = Document.name
		if filename then
			if not filename:find("%..-$") then
				filename = filename .. extension
			else
				filename = filename:gsub("%..-$", extension)
			end
		else
			filename = "(unnamed)"
		end
			
		filename = FileBrowser(title, "Export as:", true,
			filename)
		if not filename then
			return false
		end
		if filename:find("/[^.]*$") then
			filename = filename .. extension
		end
	end
	
	ImmediateMessage("Exporting...")
	
	local content = {}
	local writer = function(s)
		content[#content+1] = s
	end
	callback(writer, Document)
	content = table_concat(content)
	
	local xml =
	{
		["mimetype"] = "application/vnd.oasis.opendocument.text",

		["META-INF/manifest.xml"] = [[<?xml version="1.0" encoding="UTF-8"?>
			<manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0"> 
				<manifest:file-entry
					manifest:media-type="application/vnd.oasis.opendocument.text"
					manifest:full-path="/"/> 
				<manifest:file-entry
					manifest:media-type="text/xml"
					manifest:full-path="content.xml"/> 
				<manifest:file-entry
					manifest:media-type="text/xml"
					manifest:full-path="meta.xml"/> 
				<manifest:file-entry
					manifest:media-type="text/xml"
					manifest:full-path="settings.xml"/> 
				<manifest:file-entry
					manifest:media-type="text/xml"
					manifest:full-path="styles.xml"/> 
			</manifest:manifest>
		]],
		
		["styles.xml"] = [[<?xml version="1.0" encoding="UTF-8"?>
			<office:document-styles office:version="1.0"
				xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
				xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
				xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
				xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
				xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0">
				
				<office:font-face-decls>
				  <style:font-face style:name="monospace" svg:font-family="monospace" style:font-family-generic="modern" style:font-pitch="fixed"/>
				  <style:font-face style:name="serif" svg:font-family="serif" style:font-family-generic="roman" style:font-pitch="variable"/>
				</office:font-face-decls>
				 
				<office:styles>
					<style:style style:name="B" style:family="text">
	              		<style:text-properties fo:font-weight="bold"
	              			style:font-weight-complex="bold"
	                		style:font-weight-asian="bold"/>
	            	</style:style>
	            	
					<style:style style:name="I" style:family="text">
	              		<style:text-properties fo:font-style="italic"
	              			style:font-style-asian="italic"
	                		style:font-style-complex="italic"/>
	            	</style:style>
	            	
					<style:style style:name="UL" style:family="text">
						<style:text-properties style:text-underline-style="solid"
							style:text-underline-width="auto"
							style:text-underline-color="font-color"/>
	            	</style:style>
                	
                	<style:style style:name="H1"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="5mm"
                			fo:margin-bottom="2mm"/>
                		<style:text-properties
                			fo:font-size="150%"
                			style:font-name="serif"
                			fo:font-weight="bold"/>
                	</style:style>
                	
                	<style:style style:name="H2"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="5mm"
                			fo:margin-bottom="2mm"/>
                		<style:text-properties
                			fo:font-size="130%"
                			style:font-name="serif"
                			fo:font-weight="bold"/>
                	</style:style>
                	
                	<style:style style:name="H3"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="5mm"
                			fo:margin-bottom="2mm"/>
                		<style:text-properties
                			fo:font-size="110%"
                			style:font-name="serif"
                			fo:font-weight="bold"/>
                	</style:style>
                	
                	<style:style style:name="H4"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="5mm"
                			fo:margin-bottom="2mm"/>
                		<style:text-properties
                			style:font-name="serif"
                			fo:font-weight="bold"/>
                	</style:style>
                	
                	<style:style style:name="P"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="1.5mm"
                			fo:margin-bottom="1.5mm"/>
                		<style:text-properties style:font-name="serif"/>
                	</style:style>
                	
                	<style:style style:name="Q"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
							fo:margin-top="1.5mm"
                			fo:margin-bottom="1.5mm"
                			fo:margin-left="10mm"/>
                		<style:text-properties style:font-name="serif"/>
                	</style:style>
                	
                	<style:style style:name="V"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-left="10mm"
                			fo:margin-top="0mm"
                			fo:margin-bottom="0mm"/>
                		<style:text-properties style:font-name="serif"/>
                	</style:style>
                	
                	<style:style style:name="PRE"
                		style:family="paragraph" style:class="text">
                		<style:paragraph-properties
                			fo:margin-top="0mm"
                			fo:margin-bottom="0mm"/>
                		<style:text-properties style:font-name="monospace"/>
                	</style:style>
                	
                	<text:list-style style:name="LB">
                		<text:list-level-style-bullet text:level="1" text:bullet-char="•">
							<style:list-level-properties
								text:space-before="5mm"
								text:min-label-width="5mm"/>
						</text:list-level-style-bullet>
                	</text:list-style>
                	
                	<text:list-style style:name="L">
                		<text:list-level-style-bullet text:level="1" text:bullet-char=" ">
							<style:list-level-properties
								text:space-before="5mm"
								text:min-label-width="5mm"/>
						</text:list-level-style-bullet>
                	</text:list-style>
				</office:styles>
			</office:document-styles>
		]],
		
		["settings.xml"] = [[<?xml version="1.0" encoding="UTF-8"?>
			<office:document-settings office:version="1.0"
				xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"/>
		]],
		
		["meta.xml"] = [[<?xml version="1.0" encoding="UTF-8"?>
			<office:document-meta office:version="1.0"
				xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"/>
		]],
		
		["content.xml"] = content
	}
	
	if not writezip(filename, xml) then
		ModalMessage(nil, "Unable to open the output file "..e..".")
		QueueRedraw()
		return false
	end
		
	QueueRedraw()
	return true
end

function Cmd.ExportODTFile(filename)
	return export_odt_with_ui(filename, "Export ODT File", ".odt")
end
