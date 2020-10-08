require("tests/testsuite")

Cmd.InsertStringIntoParagraph("one two three")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("four")
Cmd.SplitCurrentWord()
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("bold")
Cmd.SetStyle("b")
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("italic")
Cmd.SetStyle("i")
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("underline")
Cmd.SplitCurrentWord()
Cmd.InsertStringIntoParagraph("stillunderline")
Cmd.SetStyle("u")
Cmd.SetStyle("o")
Cmd.InsertStringIntoParagraph("plain")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("heading")
Cmd.ChangeParagraphStyle("H1")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("bullet")
Cmd.ChangeParagraphStyle("LB")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("no bullet")
Cmd.ChangeParagraphStyle("L")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("numbered")
Cmd.ChangeParagraphStyle("LN")
Cmd.SplitCurrentParagraph()

Cmd.InsertStringIntoParagraph("normal text again")
Cmd.ChangeParagraphStyle("P")

local expected = [[
<?xml version="1.0" encoding="UTF-8"?>
					<office:document-content office:version="1.0"
					xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
					xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
					xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
					xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0">
					<office:body><office:text>
				
<text:p text:style-name="P">one<text:s/>two<text:s/>three</text:p>
<text:p text:style-name="P">four<text:s/><text:span text:style-name="B">bold</text:span><text:span text:style-name="I"><text:span text:style-name="B">italic</text:span></text:span><text:span text:style-name="I"><text:span text:style-name="B"><text:span text:style-name="UL">underline<text:s/></text:span></text:span></text:span><text:span text:style-name="I"><text:span text:style-name="B"><text:span text:style-name="UL">stillunderline</text:span></text:span></text:span>plain</text:p>
<text:h text:style-name="H1" text:outline-level="1">heading</text:h>
<text:list text:style-name="LB"><text:list-item><text:p text:style-name="P">bullet</text:p></text:list-item></text:list>
<text:list text:style-name="L"><text:list-item><text:p text:style-name="P">no<text:s/>bullet</text:p></text:list-item></text:list>
<text:list text:style-name="LN"><text:list-item text:start-value="1"><text:p text:style-name="P">numbered</text:p></text:list-item></text:list>
<text:p text:style-name="P">normal<text:s/>text<text:s/>again</text:p>
</office:text></office:body></office:document-content>
]]

local output = Cmd.ExportToODTString()
AssertEquals(expected, output)

