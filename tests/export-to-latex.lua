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
Cmd.SetStyle("b")
Cmd.SetMark()
Cmd.InsertStringIntoParagraph("underline")
Cmd.SetStyle("u")
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
%% This document automatically generated by WordGrinder 0.7.3.
\documentclass{article}
\usepackage{xunicode, setspace, xltxtra}
\sloppy
\onehalfspacing
\begin{document}
\title{main}
\author{(no author)}
\maketitle
one two three

four b\textbf{olditalic\underline{underline}}

\section{heading}
\begin{enumerate}
\item[\textbullet]{bullet}
\item[]{no bullet}
\item{numbered}
\end{enumerate}
normal text again

\end{document}
]]

local output = Cmd.ExportToLatexString(Document)
AssertEquals(expected, output)
