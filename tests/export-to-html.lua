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
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
<meta name="generator" content="WordGrinder 0.8"/>
<title>main</title>
</head><body>

<p>one two three</p>
<p>four <b>bold</b><i><b>italic</b></i><i><b><u>underline </u></b></i><i><b><u>stillunderline</u></b></i>plain</p>
<h1>heading</h1>
<ul>
<li>bullet</li>
<li style="list-style-type: none;">no bullet</li>
<li style="list-style-type: decimal;" value=1>numbered</li>
</ul>
<p>normal text again</p>
</body>
</html>
]]

local output = Cmd.ExportToHTMLString()
AssertEquals(expected, output)

