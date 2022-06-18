-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local int = math.floor
local min = math.min
local Write = wg.write
local GotoXY = wg.gotoxy
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

local UNICODE = wg.useunicode()
local BLINK_TIME = 0.8

local messages = {}
local leftpadding = 0

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
	local rw = w - Document.margin - 1
	leftpadding = math.floor(ScreenWidth/2 - rw/2)
	Document:wrap(w - Document.margin - 1)
end

local function drawmargin(y, pn, p)
	local controller = MarginControllers[Document.viewmode]
	if controller.getcontent then
		local s = controller:getcontent(pn, p)

		if s then
			SetDim()
			RAlignInField(leftpadding, y, Document.margin - 1, s)
			SetNormal()
		end
	end

	local style = DocumentStyles[p.style]
	local function drawbullet(n)
		local w = GetStringWidth(n) + 1
		local i = style.indent
		if (i >= w) then
			Write(leftpadding + Document.margin + i - w, y, n)
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
		SetReverse()

		for i = #messages, 1, -1 do
			ClearArea(0, y, ScreenWidth-1, y)
			Write(0, y, messages[i])
			y = y - 1
		end

		SetNormal()
	end
end

local topmarker = UNICODE and {
	"     ┃          ┃          ┃          ┃          ┃     ",
	"───────────────────────────────────────────────────────"
} or {
	"     |          |          |          |          |     ",
	"-------------------------------------------------------"
}
local topmarkerwidth = GetStringWidth(topmarker[1])

local function drawtopmarker(y)
	local x = int((ScreenWidth - topmarkerwidth)/2)

	SetBright()
	for i = #topmarker, 1, -1 do
		if (y >= 0) then
			Write(x, y, topmarker[i])
		end
		y = y - 1
	end
	SetNormal()
end

local bottommarker = UNICODE and {
	"───────────────────────────────────────────────────────",
	"     ┃          ┃          ┃          ┃          ┃     ",
} or {
	"-------------------------------------------------------",
	"     |          |          |          |          |     ",
}
local bottommarkerwidth = GetStringWidth(bottommarker[1])

local function drawbottommarker(y)
	local x = int((ScreenWidth - bottommarkerwidth)/2)

	SetBright()
	for i = 1, #bottommarker do
		if (y <= ScreenHeight) then
			Write(x, y, bottommarker[i])
		end
		y = y + 1
	end
	SetNormal()
end

function RedrawScreen()
	wg.clearscreen()
	local cp, cw, co = Document.cp, Document.cw, Document.co
	local cy = int(ScreenHeight / 2)
	local margin = Document.margin

	-- Find out the offset of the current paragraph.

	local paragraph = Document[cp]
	local ocw = cw
	local cl
	cl, cw = paragraph:getLineOfWord(cw)
	if not cl then
		error("word "..ocw.." not in para "..cp.." of len "..#paragraph)
	end

	-- Position the cursor.

	do
		local cw = Document.cw
		local word = paragraph[cw]
		GotoXY(leftpadding + margin + paragraph.xs[cw] +
			GetWidthFromOffset(word, Document.co) + paragraph:getIndentOfLine(cl),
			cy - 1)
	end

	-- Cache values for mark drawing.

	local mp = Document.mp
	local mw = Document.mw
	local mo = Document.mo

	-- Draw backwards.

	local pn = cp - 1
	local y = cy - cl - 1 - Document:spaceAbove(cp)

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

			if not mp then
				paragraph:renderLine(l,
					leftpadding + margin + x, y)
			else
				paragraph:renderMarkedLine(l,
					leftpadding + margin + x, y, nil, pn)
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

		y = y - Document:spaceAbove(pn)
		pn = pn - 1
	end

	if (y >= 0) and WantTerminators() then
		drawtopmarker(y)
	end

	-- Draw forwards.

	y = cy - cl
	pn = cp
	while (y < ScreenHeight) do
		local paragraph = Document[pn]
		if not paragraph then
			break
		end

		drawmargin(y, pn, paragraph)

		for ln, l in ipairs(paragraph:wrap()) do
			local x = paragraph:getIndentOfLine(ln)
			if not mp then
				paragraph:renderLine(l,
					leftpadding + margin + x, y)
			else
				paragraph:renderMarkedLine(l,
					leftpadding + margin + x, y, nil, pn)
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
		y = y + Document:spaceBelow(pn)
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
