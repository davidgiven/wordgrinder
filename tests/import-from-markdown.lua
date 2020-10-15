require("tests/testsuite")

local tempfile = io.tmpfile()
tempfile:write([[
# Header 1
## Header 2
### Header 3
#### Header 4

Header 1
========

Header 2
--------

This is normal paragraph text.

This is normal paragraph text with **bold** and _italic_. And <b>bold</b> and
<i>italic</i> and <u>underline</u>. And <u>_**all three!**_</u>

Some of this is `code`.

- bullet point one
- bullet point two
 - bullet point with leading spaces
- bullet point with
  text continuation

Spacing text.

* bullet one before whitespace

* bullet two after whitespace
  
  bullet two text continuation

Spacing text.

1. ordered list one
2. ordered list two
 1. ordered list with leading spaces

<div></div>

> More text, but this is in a block quotation.

Spacing normal text.

> Block text paragraph 1.
>
> Block text paragraph 2.

	This is a verbatim paragraph.

Spacing normal text.

	This is verbatim paragraph 1.

	This is verbatim paragraph 2.

More spacing normal text.

```
This is in backticks.
Line 2

Stuff here.
```
]])

tempfile:seek("set", 0)
tempfile:flush()
local document = Cmd.ImportMarkdownFileFromStream(tempfile)

local expected = [[
<html xmlns="http://www.w3.org/1999/xhtml"><head>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
<meta name="generator" content="WordGrinder 0.8"/>
<title>imported</title>
</head><body>

<p><br/></p>
<h1>Header 1</h1>
<h2>Header 2</h2>
<h3>Header 3</h3>
<h4>Header 4</h4>
<h1>Header 1</h1>
<h2>Header 2</h2>
<p>This is normal paragraph text.</p>
<p>This is normal paragraph text with <b>bold </b>and <i>italic</i>. And <b>bold </b>and <i>italic </i>and <u>underline</u>. And <i><b><u>all </u></b></i><i><b><u>three!</u></b></i></p>
<p>Some of this is <u>code</u>.</p>
<ul>
<li>bullet point one</li>
<li>bullet point two</li>
<li>bullet point with leading spaces</li>
<li>bullet point with text continuation</li>
</ul>
<p>Spacing text.</p>
<ul>
<li>bullet one before whitespace</li>
<li>bullet two after whitespace</li>
<li>bullet two text continuation</li>
</ul>
<p>Spacing text.</p>
<ul>
<li style="list-style-type: decimal;" value=1>ordered list one</li>
<li style="list-style-type: decimal;" value=2>ordered list two</li>
<li style="list-style-type: decimal;" value=3>ordered list with leading spaces</li>
</ul>
<div></div>
<blockquote>More text, but this is in a block quotation.</blockquote>
<p>Spacing normal text.</p>
<blockquote>Block text paragraph 1.</blockquote>
<blockquote>Block text paragraph 2.</blockquote>
<pre>This is a verbatim paragraph.</pre>
<p>Spacing normal text.</p>
<pre>This is verbatim paragraph 1.
This is verbatim paragraph 2.</pre>
<p>More spacing normal text.</p>
<pre>This is in backticks.
Line 2
Stuff here.</pre>
</body>
</html>
]]

DocumentSet:addDocument(document, "imported")
DocumentSet:setCurrent("imported")
local output = Cmd.ExportToHTMLString()
AssertEquals(expected, output)



