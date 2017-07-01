-- © 2013 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

-----------------------------------------------------------------------------
-- The editor itself.

local function bounds(min, max, value)
    if not value then
        return value
    elseif value < min then
        return min
    elseif value > max then
        return max
    else
        return value
    end
end

local function styleeditor(style)
	local description_textfield =
		Form.TextField {
			x1 = 20, y1 = 1,
			x2 = -1, y2 = 1,
			value = tostring(style.desc)
		}

	local above_textfield =
		Form.TextField {
			x1 = 20, y1 = 3,
			x2 = 30, y2 = 3,
			value = tostring(style.above)
		}

	local below_textfield =
		Form.TextField {
			x1 = 20, y1 = 5,
			x2 = 30, y2 = 5,
			value = tostring(style.below)
		}

	local indent_textfield =
		Form.TextField {
			x1 = 20, y1 = 7,
			x2 = 30, y2 = 7,
			value = tostring(style.indent or 0)
		}

	local firstindent_textfield =
		Form.TextField {
			x1 = 20, y1 = 9,
			x2 = 30, y2 = 9,
			value = tostring(style.firstindent or "")
		}

	local bullet_textfield =
		Form.TextField {
			x1 = 20, y1 = 11,
			x2 = 30, y2 = 11,
			value = tostring(style.bullet or "")
		}

	local dialogue =
	{
		title = "Table of Contents",
		width = Form.Large,
		height = 13,
		stretchy = false,

		["KEY_^C"] = "cancel",
		["KEY_RETURN"] = "confirm",
		["KEY_ENTER"] = "confirm",

		Form.Label {
			x1 = 1, y1 = 1,
			x2 = 18, y2 = 1,
			align = Form.Left,
			value = "Description",
		},
        description_textfield,

		Form.Label {
			x1 = 1, y1 = 3,
			x2 = 18, y2 = 3,
			align = Form.Left,
			value = "Blank lines above",
		},
        above_textfield,

		Form.Label {
			x1 = 1, y1 = 5,
			x2 = 18, y2 = 5,
			align = Form.Left,
			value = "Blank lines below",
		},
        below_textfield,

		Form.Label {
			x1 = 1, y1 = 7,
			x2 = 18, y2 = 7,
			align = Form.Left,
			value = "Indent",
		},
        indent_textfield,

		Form.Label {
			x1 = 1, y1 = 9,
			x2 = 18, y2 = 9,
			align = Form.Left,
			value = "First line indent",
		},
        firstindent_textfield,
		Form.Label {
			x1 = 31, y1 = 9,
			x2 = -1, y2 = 9,
			align = Form.Left,
			value = "(leave blank for default)",
		},

		Form.Label {
			x1 = 1, y1 = 11,
			x2 = 18, y2 = 11,
			align = Form.Left,
			value = "Bullet text",
		},
        bullet_textfield,
	}

	local result = Form.Run(dialogue, RedrawScreen,
		"RETURN to select item, CTRL+C to cancel")
	QueueRedraw()
	if result then
        style.desc = description_textfield.value
        style.above = bounds(0, 10, tonumber(above_textfield.value)) or 0
        style.below = bounds(0, 10, tonumber(below_textfield.value)) or 0
        style.indent = bounds(0, 20, tonumber(indent_textfield.value)) or 0
        style.firstindent = bounds(0, 20, tonumber(firstindent_textfield.value))
        style.bullet = bullet_textfield.value
        DocumentSet:touch()
	end
end

function Cmd.EditParagraphStyles()
    local cursor = 1

    while true do
        local data = {}
        for _, style in ipairs(DocumentSet.styles) do
            data[#data+1] = {
                label = string.format("% 3s %s", style.name, style.desc),
                style = style
            }
        end

        local browser = Form.Browser {
            focusable = true,
            type = Form.Browser,
            x1 = 1, y1 = 2,
            x2 = -1, y2 = -1,
            data = data,
            cursor = cursor,
        }

        local dialogue =
        {
            title = "Paragraph Styles",
            width = Form.Large,
            height = Form.Large,
            stretchy = false,

            ["KEY_^C"] = "cancel",
            ["KEY_RETURN"] = "confirm",
            ["KEY_ENTER"] = "confirm",

            Form.Label {
                x1 = 1, y1 = 1,
                x2 = -1, y2 = 1,
                value = "Select style to edit:"
            },

            browser,
        }

        local result = Form.Run(dialogue, RedrawScreen,
            "RETURN to select item, CTRL+C to close")
        QueueRedraw()
        if result then
            cursor = browser.cursor
            styleeditor(browser.data[cursor].style)
        else
            RebuildParagraphStylesMenu(DocumentSet.styles)
            return
        end
    end
end
