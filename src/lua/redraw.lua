--!nonstrict
-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local Write = wg.write
local GotoXY = wg.gotoxy
local ClearScreen = wg.clearscreen
local ClearArea = wg.cleararea
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetBright = wg.setbright
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth
local ShowCursor = wg.showcursor
local HideCursor = wg.hidecursor
local Sync = wg.sync

local UseUnicode = wg.useunicode
local BLINK_TIME = 0.8

local messages = {}
local lineindex = {}
local papermargin = 0

local SYMBOLS = {
	[0] = { "₀", "0" },
	[1] = { "₁", "1" },
	[2] = { "₂", "2" },
	[3] = { "₃", "3" },
	[4] = { "₄", "4" },
	[5] = { "₅", "5" },
	[6] = { "₆", "6" },
	[7] = { "₇", "7" },
	[8] = { "₈", "8" },
	[9] = { "₉", "9" },
	dl =  { "◥", "\\" },
	dm =  { "▼", "+" },
	dms = { "▾", "." },
	dr =  { "◤", "/" },
	ul =  { "◿", "/" },
	um =  { "△", "+" },
	ur =  { "◺", "\\" },
	lb =  { "▁", "-" },
	lt =  { "▔", "-" },
}

function NonmodalMessage(s)
	messages[#messages+1] = s
	QueueRedraw()
end

function ResetNonmodalMessages()
	messages = {}
end

function ResizeScreen()
	ScreenWidth, ScreenHeight = wg.getscreensize()
	local w = GetMaximumAllowedWidth(ScreenWidth)
	if currentDocument.margin > 0 then
		papermargin = math.max(currentDocument.margin + 2, math.floor(ScreenWidth/2 - w/2))
	else
		papermargin = math.floor(ScreenWidth/2 - w/2)
	end
	w = ScreenWidth - papermargin*2
	currentDocument:wrap(w)
	return true
end

local function drawmargin(y: number, pn: number, p: Paragraph)
	local controller = marginControllers[currentDocument.viewmode]
	if controller.getcontent then
		local s: string? = assert(controller.getcontent)(controller, pn, p)

		if s then
			SetColour(Palette.StyleFG, Palette.Desktop)
			SetDim()
			RAlignInField(0, y, papermargin - 1, s)
		end
	end

	local style = documentStyles[p.style]
	local function drawbullet(n)
		local w = GetStringWidth(n) + 1
		local i = (style.indent or 0)
		if (i >= w) then
			SetNormal()
			SetColour(Palette.LB_FG, Palette.LB_BG)
			Write(papermargin + i - w, y, n)
		end
	end

	local bullet = style.bullet
	if bullet then
		drawbullet(bullet)
	else
		local numbered = style.numbered
		if numbered then
			local n = tostring(p.number or 0).."."
			drawbullet(n)
		end
	end
end

local changed_tab =
{
	[true] = "CHANGED"
}

local function redrawstatus()
	local y = ScreenHeight - 1

	if documentSet.statusbar then
		local s = {
			Leafname(documentSet.name or "(unnamed)"),
			"[",
			currentDocument.name or "",
			"] ",
			changed_tab[documentSet._changed] or "",
		}

		-- Reversed due to SetReverse later.
		SetColour(Palette.StatusbarBG, Palette.StatusbarFG)
		SetReverse()
		ClearArea(0, ScreenHeight-1, ScreenWidth-1, ScreenHeight-1)
		LAlignInField(0, ScreenHeight-1, ScreenWidth, table.concat(s, ""))

		local ss: {StatusbarField} = {}
		FireEvent("BuildStatusBar", ss)
		table.sort(ss, function(x, y) return x.priority < y.priority end)

		local s = {" "}
		for _, v in ipairs(ss) do
			s[#s+1] = v.value
		end
		local ss = table.concat(s, " │ ")
		if (string.sub(ss, #ss) == " ") then
			ss = string.sub(ss, 1, #ss-1)
		end

		RAlignInField(0, ScreenHeight-1, ScreenWidth, ss)
		SetNormal()

		y = y - 1
	end

	if (#messages > 0) then
		-- Reversed due to SetReverse later.
		SetColour(Palette.MessageFG, Palette.MessageBG)
		SetReverse()

		for i = #messages, 1, -1 do
			ClearArea(0, y, ScreenWidth-1, y)
			Write(0, y, messages[i])
			y = y - 1
		end

		SetNormal()
	end
end

local function drawtopmarker(y)
	local lm = papermargin
	local rm = ScreenWidth - lm - 1
	local w = rm - lm + 1
	local u = UseUnicode() and 1 or 2

	SetNormal()
	SetColour(Palette.MarkerFG, Palette.Desktop)
	if y > 2 then
		local n = 0
		for i = lm, rm, 10 do
			Write(i, y-2, SYMBOLS[n][u])
			n = n + 1
			if n == 10 then
				n = 0
			end
		end
	end
	if y > 1 then
		Write(lm, y-1, SYMBOLS.dl[u])
		for i = lm+5, rm, 10 do
			Write(i, y-1, SYMBOLS.dms[u])
		end
		for i = lm+10, rm, 10 do
			Write(i, y-1, SYMBOLS.dm[u])
		end
		Write(rm, y-1, SYMBOLS.dr[u])
	end

	SetColour(Palette.MarkerFG, Palette.Paper)
	ClearArea(lm, y, rm, y)
	for i = lm+1, rm-1 do
		Write(i, y, SYMBOLS.lt[u])
	end
end

local function drawbottommarker(y)
	local lm = papermargin
	local rm = ScreenWidth - lm - 1
	local w = rm - lm + 1
	local u = UseUnicode() and 1 or 2

	SetNormal()
	SetColour(Palette.MarkerFG, Palette.Paper)
	ClearArea(lm, y, rm, y)
	for i = lm+1, rm-1 do
		Write(i, y, SYMBOLS.lb[u])
	end
	y = y + 1
	if y < ScreenHeight then
		SetColour(Palette.MarkerFG, Palette.Desktop)
		Write(lm, y, SYMBOLS.ul[u])
		for i = lm+10, rm, 10 do
			Write(i, y, SYMBOLS.um[u])
		end
		Write(rm, y, SYMBOLS.ur[u])
	end
end

function RedrawScreen()
	-- We can't actual draw until the first resize event has been processed.
	if ScreenHeight == 0 then
		return
	end

	SetColour(nil, Palette.Desktop)
	ClearScreen()
	if not currentDocument._sp then
		currentDocument._sp = currentDocument.cp
		currentDocument._sw = currentDocument.cw
	end
	local sp, sw = assert(currentDocument._sp), assert(currentDocument._sw)
	local cp, cw, co = currentDocument.cp, currentDocument.cw, currentDocument.co
	local tx = papermargin + 1

	if GetScrollMode() == "Fixed" then
		sp = currentDocument.cp
		sw = currentDocument.cw
	else
		if sp > #currentDocument then
			sp = #currentDocument
		elseif sp < 1 then
			sp = 1
		end
	end

	-- Find out the offset of the paragraph at the middle of the screen.

	local paragraph = currentDocument[sp]
	if sw > #paragraph then
		sw = #paragraph
	end
	local osw = sw
	local sl, sw = paragraph:getLineOfWord(sw)
	if not sl then
		sl = #paragraph:wrap().lines
	end
	assert(sl)

	-- So, line sl on sp is supposed to be in the middle. We now work up
	-- and down to find the real cursor position.

	local cy = math.floor(ScreenHeight / 2) - sl
	if cp >= sp then
		local p = sp
		
		while p < cp do
			local wd = currentDocument[p]:wrap()
			cy = cy + #wd.lines + currentDocument:spaceBelow(p)
			p = p + 1
		end
		cy = cy + currentDocument[p]:getLineOfWord(cw) - 1
		if cy >= (ScreenHeight-5) then
			currentDocument._sp = cp
			currentDocument._sw = cw
			return RedrawScreen()
		end
	else
		local p = sp

		while p > cp do
			p = p - 1
			local wd = currentDocument[p]:wrap()
			cy = cy - #wd.lines - currentDocument:spaceBelow(p)
		end
		cy = cy + currentDocument[p]:getLineOfWord(cw) - 1
		if cy < 4 then
			currentDocument._sp = cp
			currentDocument._sw = cw
			return RedrawScreen()
		end
	end

	-- Position the cursor.

	do
		local paragraph = currentDocument[cp]
		local wd = paragraph:wrap()
		local word = paragraph[cw]
		local cl = paragraph:getLineOfWord(cw)
		GotoXY(tx + wd.xs[cw] +
			GetWidthFromOffset(word, currentDocument.co) +
			paragraph:getIndentOfLine(cl),
			cy)
	end

	-- Cache values for mark drawing.

	local mp = currentDocument.mp
	local mw = currentDocument.mw
	local mo = currentDocument.mo

	local lm = papermargin
	local rm = ScreenWidth - lm - 1

	local function setparacolour(paragraph: Paragraph)
		SetColour(
			Palette[paragraph.style.."_FG"],
			Palette[paragraph.style.."_BG"])
	end

	local function clear(y1, y2)
		SetNormal()
		ClearArea(lm, y1, rm, y2)
	end

	-- Draw backwards.

	local pn = sp - 1
	local sa = currentDocument:spaceAbove(sp)
	local y = math.floor(ScreenHeight/2) - sl - 1 - sa
	local paragraph = currentDocument[sp]
	if paragraph then
		SetColour(Palette.Paper, Palette.Paper)
		clear(y+1, y+sa)
	end
	lineindex = {}

	local function drawline(paragraph: Paragraph, line: Line, ln: number)
		local x = paragraph:getIndentOfLine(ln)

		setparacolour(paragraph)
		clear(y, y)
		if not mp then
			paragraph:renderLine(line, tx + x, y)
		else
			paragraph:renderMarkedLine(line, tx + x, y, nil, pn)
		end

		if (ln == 1) then
			drawmargin(y, pn, paragraph)
		end

		lineindex[y] = {
			p = pn,
			w = paragraph:getWordOfLine(ln),
			x = tx
		}
	end

	currentDocument._topp = nil
	currentDocument._topw = nil
	while (y >= 0) do
		local paragraph = currentDocument[pn]
		if not paragraph then
			break
		end

		local wd = paragraph:wrap()
		for ln = #wd.lines, 1, -1 do
			local l = wd.lines[ln]
			drawline(paragraph, l, ln)

			currentDocument._topp = pn
			currentDocument._topw = l.wn
			y = y - 1

			if (y < 0) then
				break
			end
		end

		local sa = currentDocument:spaceAbove(pn)
		y = y - sa
		SetColour(Palette.Paper, Palette.Paper)
		clear(y, y+sa)
		pn = pn - 1
	end

	if (y >= 0) and WantTerminators() then
		drawtopmarker(y)
	end

	-- Draw forwards.

	y = math.floor(ScreenHeight/2) - sl
	pn = sp
	while (y < ScreenHeight) do
		local paragraph = currentDocument[pn]
		if not paragraph then
			break
		end

		drawmargin(y, pn, paragraph)

		local wd = paragraph:wrap()
		for ln, l in wd.lines do
			drawline(paragraph, l, ln)

			-- If the top of the page hasn't already been set, then the
			-- current paragraph extends off the top of the screen.

			if not currentDocument._topp and (y == 0) then
				currentDocument._topp = pn
				currentDocument._topw = l.wn
			end

			currentDocument._botp = pn
			currentDocument._botw = l.wn
			y = y + 1

			if (y > ScreenHeight) then
				break
			end
		end
		local sb = currentDocument:spaceBelow(pn)
		y = y + sb
		SetColour(Palette.Paper, Palette.Paper)
		clear(y-sb, y-1)
		pn = pn + 1
	end

	-- If the top of the page *still* hasn't been set, then we're on the
	-- first paragraph of the document.

	if not currentDocument._topp then
		currentDocument._topp = 1
		currentDocument._topw = 1
	end

	if (y <= ScreenHeight) and WantTerminators() then
		drawbottommarker(y)
	end

	redrawstatus()

	FireEvent("Redraw")
end

function GetPositionOfLine(y)
	local r = nil
	for yy = 1, y do
		r = lineindex[yy] or r
	end
	return r
end

function GetCharWithBlinkingCursor(timeout: number?)
	ShowCursor()

	timeout = timeout or 1E10
	assert(timeout)

	local shown = true
	while timeout > 0 do
		local t = shown and BLINK_ON_TIME or BLINK_OFF_TIME
		t = math.min(t, timeout)
		local c = wg.getchar(t)
		if (c ~= "KEY_TIMEOUT") then
			ShowCursor();
			return c
		end

		shown = not shown
		local cb = shown and ShowCursor or HideCursor
		cb()

		timeout = timeout - t
	end
	
	return "KEY_TIMEOUT"
end

-----------------------------------------------------------------------------
-- Does assorted fast updates in the current document on changes:
--   - word count
--   - numbered paragraph styles

do
	local function cb(event, token)
		currentDocument:renumber()
	end

	AddEventListener("Changed", cb)
end
