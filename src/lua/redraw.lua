-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

local int = math.floor
local Write = wg.write
local Goto = wg.goto
local ClearToEOL = wg.cleartoeol
local SetNormal = wg.setnormal
local SetBold = wg.setbold
local SetUnderline = wg.setunderline
local SetReverse = wg.setreverse
local SetDim = wg.setdim
local GetStringWidth = wg.getstringwidth

local messages = {}

function NonmodalMessage(s)
	messages[#messages+1] = s
	QueueRedraw()
end

function ResizeScreen()
	ScreenWidth, ScreenHeight = wg.getscreensize()
	Document:wrap(ScreenWidth - Document.margin - 1)
end

local function drawmargin(y, pn, p)
	local controller = MarginControllers[Document.viewmode]
	if controller.getcontent then
		local s = controller:getcontent(pn, p)

		if s then
			SetDim()
			RAlignInField(0, y, Document.margin - 1, s)
			SetNormal()
		end
	end
	
	local bullet = p.style.bullet
	if bullet then
		local w = GetStringWidth(bullet) + 1
		local i = p.style.indent
		if (i >= w) then
			Write(Document.margin + i - w, y, bullet)
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
			DocumentSet.name or "(unnamed)",
			"[",
			Document.name or "",
			"] ",
			changed_tab[DocumentSet.changed] or "",
		}
		
		SetReverse()
		SetBold()	
		LAlignInField(0, ScreenHeight-1, ScreenWidth, table.concat(s, ""))
		ClearToEOL()
		
		local s = {
			string.format("│ P: %d/%d ", Document.cp, #Document),
			string.format("│ %d %s", Document.wordcount or 0,
				pluralise(Document.wordcount or 0, "word ", "words "))
		}
		
		RAlignInField(0, ScreenHeight-1, ScreenWidth, table.concat(s, ""))
		SetNormal()

		y = y - 1
	end

	if (#messages > 0) then
		SetReverse()

		for i = #messages, 1, -1 do
			Write(0, y, messages[i])
			ClearToEOL()
			y = y - 1
		end
		messages = {}

		SetNormal()
	end
end
		
local topmarker = {
	"     ╲╱          ╲╱          ╲╱          ╲╱          ╲╱     ",
	"▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔▔"
}
local topmarkerwidth = GetStringWidth(topmarker[1])

local function drawtopmarker(y)
	local x = int((ScreenWidth - topmarkerwidth)/2)
	
	SetBold()
	for i = #topmarker, 1, -1 do
		if (y >= 0) then
			Write(x, y, topmarker[i])
		end
		y = y - 1
	end
	SetNormal()
end

local bottommarker = {
	"▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁",
	"     ╱╲          ╱╲          ╱╲          ╱╲          ╱╲     ",
}
local bottommarkerwidth = GetStringWidth(bottommarker[1])

local function drawbottommarker(y)
	local x = int((ScreenWidth - bottommarkerwidth)/2)
	
	SetBold()
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
	cl, cw = paragraph:getLineOfWord(cw)
	if not cl then
		error("word "..ocw.." not in para of len "..#paragraph)
	end
	
	-- Position the cursor.

	do
		local word = paragraph[Document.cw]
		Goto(margin + word.x + word:getXOffsetOfChar(Document.co) +
			(paragraph.style.indent or 0), cy - 1)	
	end
	
	-- Cache values for mark drawing.
	
	local mp = Document.mp
	local mw = Document.mw
	local mo = Document.mo
	
	-- Draw backwards.
	
	local pn = cp - 1
	local y = cy - cl - 1 - Document:spaceAbove(cp)
	
	while (y >= 0) do
		local paragraph = Document[pn]
		if not paragraph then
			break
		end
	
		local lines = paragraph:wrap()
		local x = paragraph.style.indent or 0 -- FIXME
		for ln = #lines, 1, -1 do
			local l = lines[ln]
			
			if not mp then
				paragraph:renderLine(l, margin + x, y)
			else
				paragraph:renderMarkedLine(l, margin + x, y, nil, pn)
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
	
	if (y >= 0) then
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

		local x = paragraph.style.indent or 0 -- FIXME
		for ln, l in ipairs(paragraph:wrap()) do
			if not mp then
				paragraph:renderLine(l, margin + x, y)
			else
				paragraph:renderMarkedLine(l, margin + x, y, nil, pn)
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
	
	if (y <= ScreenHeight) then
		drawbottommarker(y)
	end
	
	redrawstatus()
	
	FireEvent(Event.Redraw)
end

-----------------------------------------------------------------------------
-- Maintains the word count field in the current document.

do
	local function cb(event, token)
		local wc = 0
		
		for _, p in ipairs(Document) do
			wc = wc + #p
		end
		
		Document.wordcount = wc
	end
	
	AddEventListener(Event.Changed, cb)
end
