-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local min = math.min
local max = math.max
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
	if Document.margin > 0 then
		papermargin = max(Document.margin + 2, math.floor(ScreenWidth/2 - w/2))
	else
		papermargin = math.floor(ScreenWidth/2 - w/2)
	end
	w = ScreenWidth - papermargin*2
	Document:wrap(w)
end

local function drawmargin(y, pn, p)
	local controller = MarginControllers[Document.viewmode]
	if controller.getcontent then
		local s = controller:getcontent(pn, p)

		if s then
			SetColour(Palette.StyleFG, Palette.Desktop)
			SetDim()
			RAlignInField(0, y, papermargin - 1, s)
		end
	end

	local style = DocumentStyles[p.style]
	local function drawbullet(n)
		local w = GetStringWidth(n) + 1
		local i = style.indent
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

	if DocumentSet.statusbar then
		local s = {
			Leafname(DocumentSet.name or "(unnamed)"),
			"[",
			Document.name or "",
			"] ",
			changed_tab[DocumentSet.changed] or "",
		}

		-- Reversed due to SetReverse later.
		SetColour(Palette.StatusbarBG, Palette.StatusbarFG)
		SetReverse()
		ClearArea(0, ScreenHeight-1, ScreenWidth-1, ScreenHeight-1)
		LAlignInField(0, ScreenHeight-1, ScreenWidth, table.concat(s, ""))

		local ss = {}
		FireEvent(Event.BuildStatusBar, ss)
		table.sort(ss, function(x, y) return x.priority < y.priority end)

		local s = {" "}
		for _, v in ipairs(ss) do
			s[#s+1] = v.value
		end
		s = table.concat(s, " │ ")
		if (string.sub(s, #s) == " ") then
			s = string.sub(s, 1, #s-1)
		end

		RAlignInField(0, ScreenHeight-1, ScreenWidth, s)
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
	if not Document.sp then
		Document.sp = Document.cp
		Document.sw = Document.cw
	end
	local sp, sw = Document.sp, Document.sw
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local tx = papermargin + 1

	-- Find out the offset of the paragraph at the middle of the screen.

	local paragraph = Document[sp]
	local osw = sw
	local sl
	sl, sw = paragraph:getLineOfWord(sw)
	if not sl then
		error("word "..osw.." not in para "..sp.." of len "..#paragraph)
	end

	-- So, line sl on sp is supposed to be in the middle. We now work up
	-- and down to find the real cursor position.

	local cy = int(ScreenHeight / 2) - sl
	if cp >= sp then
		local p = sp
		
		while p < cp do
			cy = cy + #Document[p]:wrap() + Document:spaceBelow(p)
			p = p + 1
		end
		cy = cy + Document[p]:getLineOfWord(cw) - 1
		if cy >= (ScreenHeight-5) then
			Document.sp = cp
			Document.sw = cw
			return RedrawScreen()
		end
	else
		local p = sp

		while p > cp do
			p = p - 1
			cy = cy - #Document[p]:wrap() - Document:spaceBelow(p)
		end
		cy = cy + Document[p]:getLineOfWord(cw) - 1
		if cy < 4 then
			Document.sp = cp
			Document.sw = cw
			return RedrawScreen()
		end
	end

	-- Position the cursor.

	do
		local paragraph = Document[cp]
		local word = paragraph[cw]
		GotoXY(tx + paragraph.xs[cw] +
			GetWidthFromOffset(word, Document.co) + paragraph:getIndentOfLine(cl),
			cy)
	end

	-- Cache values for mark drawing.

	local mp = Document.mp
	local mw = Document.mw
	local mo = Document.mo

	local lm = papermargin
	local rm = ScreenWidth - lm - 1

	local function setparacolour(paragraph)
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
	local sa = Document:spaceAbove(sp)
	local y = (ScreenHeight/2) - sl - 1 - sa
	local paragraph = Document[sp]
	if paragraph then
		SetColour(Palette.Paper, Palette.Paper)
		clear(y+1, y+sa)
	end

	Document.topp = nil
	Document.topw = nil
	while (y >= 0) do
		local paragraph = Document[pn]
		if not paragraph then
			break
		end

		local lines = paragraph:wrap()
		for ln = #lines, 1, -1 do
			local x = paragraph:getIndentOfLine(ln)
			local l = lines[ln]

			setparacolour(paragraph)
			clear(y, y)
			if not mp then
				paragraph:renderLine(l, tx + x, y)
			else
				paragraph:renderMarkedLine(l, tx + x, y, nil, pn)
			end

			if (ln == 1) then
				drawmargin(y, pn, paragraph)
			end

			Document.topp = pn
			Document.topw = l.wn
			y = y - 1

			if (y < 0) then
				break
			end
		end

		local sa = Document:spaceAbove(pn)
		y = y - sa
		SetColour(Palette.Paper, Palette.Paper)
		clear(y, y+sa)
		pn = pn - 1
	end

	if (y >= 0) and WantTerminators() then
		drawtopmarker(y)
	end

	-- Draw forwards.

	y = (ScreenHeight/2) - sl
	pn = sp
	while (y < ScreenHeight) do
		local paragraph = Document[pn]
		if not paragraph then
			break
		end

		drawmargin(y, pn, paragraph)

		for ln, l in ipairs(paragraph:wrap()) do
			local x = paragraph:getIndentOfLine(ln)
			setparacolour(paragraph)
			clear(y, y)
			if not mp then
				paragraph:renderLine(l, tx + x, y)
			else
				paragraph:renderMarkedLine(l, tx + x, y, nil, pn)
			end

			if (ln == 1) then
				drawmargin(y, pn, paragraph)
			end

			-- If the top of the page hasn't already been set, then the
			-- current paragraph extends off the top of the screen.

			if not Document.topp and (y == 0) then
				Document.topp = pn
				Document.topw = l.wn
			end

			Document.botp = pn
			Document.botw = l.wn
			y = y + 1

			if (y > ScreenHeight) then
				break
			end
		end
		local sb = Document:spaceBelow(pn)
		y = y + sb
		SetColour(Palette.Paper, Palette.Paper)
		clear(y-sb, y-1)
		pn = pn + 1
	end

	-- If the top of the page *still* hasn't been set, then we're on the
	-- first paragraph of the document.

	if not Document.topp then
		Document.topp = 1
		Document.topw = 1
	end

	if (y <= ScreenHeight) and WantTerminators() then
		drawbottommarker(y)
	end

	redrawstatus()

	FireEvent(Event.Redraw)
end

function GetCharWithBlinkingCursor(timeout)
	ShowCursor()

	timeout = timeout or 1E10
	local shown = true
	while timeout > 0 do
		local t = shown and BLINK_ON_TIME or BLINK_OFF_TIME
		t = min(t, timeout)
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
		Document:renumber()
	end

	AddEventListener(Event.Changed, cb)
end
