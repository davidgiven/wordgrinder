-- © 2020 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.

local ITALIC = wg.ITALIC
local UNDERLINE = wg.UNDERLINE
local BOLD = wg.BOLD
local ParseWord = wg.parseword
local WriteU8 = wg.writeu8
local bitand = bit32.band
local bitor = bit32.bor
local bitxor = bit32.bxor
local bit = bit32.btest
local string_char = string.char
local string_find = string.find
local string_sub = string.sub
local table_concat = table.concat
local table_insert = table.insert

-----------------------------------------------------------------------------
-- The importer itself.

function Cmd.ImportMarkdownFileFromStream(fp)
	local document = CreateDocument()
	local importer = CreateImporter(document)

	-- The Lunamark parser model expects to produce a string, but what we want
	-- is a parse tree.  This means there's some degree of semantic mismatch.
	-- What we do instead is to have Lunamark return a tree of parse operations
	-- gets flattened after parsing is complete.
	
	local metadata = {}
    local current_style = "P"

    local function nop() return "" end
    local function style_on(s) return function() importer:style_on(s) end end
    local function style_off(s) return function() importer:style_off(s) end end
    local function flushparagraph(s) return function() importer:flushparagraph(s) end end

    local function list(items, kind)
        local flush = flushparagraph(kind)
        local oldstyle
        return {
            function() oldstyle = current_style current_style = kind end,
            InterleaveArray(items, flush),
            flush,
            function() current_style = oldstyle end,
        }
    end

    local htmltags = {
        ["<b>"] = style_on(BOLD),
        ["</b>"] = style_off(BOLD),
        ["<strong>"] = style_on(BOLD),
        ["</strong>"] = style_off(BOLD),
        ["<i>"] = style_on(ITALIC),
        ["</i>"] = style_off(ITALIC),
        ["<em>"] = style_on(ITALIC),
        ["</em>"] = style_off(ITALIC),
        ["<u>"] = style_on(UNDERLINE),
        ["</u>"] = style_off(UNDERLINE),
    }

	local writer = {
        --- Set metadata field `key` to `val`.
        set_metadata = function(key, val)
            metadata[key] = val
            return {}
        end,

        --- Add `val` to an array in metadata field `key`.
        add_metadata = function(key, val)
            local cur = metadata[key]
            if (type(cur) == "table") then
                table_insert(cur,val)
            elseif cur then
                metadata[key] = {cur, val}
            else
                metadata[key] = {val}
            end
        end,

        --- Return metadata table.
        get_metadata = function()
            return metadata
        end,

        --- A space (string).
        space = function()
            return function() importer:flushword() end
        end,

        --- Tasks at the beginning and end of the document.
        start_document = nop,
        stop_document = nop,

        --- Plain text block (not formatted as a pragraph).
        plain = function(s)
            return s
        end,

        --- A line break (string).
        linebreak = "",

        --- Line breaks to use between block elements.
        interblocksep = "",

        --- Line breaks to use between a container (like a `<div>`
        -- tag) and the adjacent block element.
        containersep = "",

        --- Ellipsis (string).
        ellipsis = "...",

        --- Em dash (string).
        mdash = "—",

        --- En dash (string).
        ndash = "–",

        --- Non-breaking space.
        nbsp = { function() importer:flushword() end },

        --- String in curly single quotes.
        singlequoted = function(s)
            return {"'", s, "'"}
        end,

        --- String in curly double quotes.
        doublequoted = function(s)
            return {'"', s, '"'}
        end,

        --- String, escaped as needed for the output format.
        string = function(s)
            return s
        end,

        --- Inline (verbatim) code.
        code = function(s)
            if s:find("[\n\r]") then
                -- Multiline.
                local lines = SplitString(s, "[\n\r]")
                local flush = flushparagraph("PRE")
                return { InterleaveArray(lines, flush), flush }
            else
                -- Inline.
                return {
                    style_on(UNDERLINE),
                    s,
                    style_off(UNDERLINE)
                }
            end
        end,

        --- A link with link text `label`, uri `uri`,
        -- and title `title`.
        link = function(label, uri, title)
            return label
        end,

        --- An image link with alt text `label`,
        -- source `src`, and title `title`.
        image = function(label, src, title)
            return label
        end,

        --- A paragraph.
        paragraph = function(s)
            return {
                s,
                function() importer:flushparagraph(current_style) end
            }
        end,

        --- A bullet list with contents `items` (an array).  If
        -- `tight` is true, returns a "tight" list (with
        -- minimal space between items).
        bulletlist = function(items, tight) return list(items, "LB") end,

        --- An ordered list with contents `items` (an array). If
        -- `tight` is true, returns a "tight" list (with
        -- minimal space between items). If optional
        -- number `startnum` is present, use it as the
        -- number of the first list item.
        orderedlist = function(items, tight, startnum) return list(items, "LN") end,

        --- Inline HTML.
        inline_html = function(s)
            return htmltags[s] or ""
        end,

        --- Display HTML (HTML block).
        display_html = function(s)
            return {
                s,
                flushparagraph("RAW")
            }
        end,

        --- Emphasized text.
        emphasis = function(s)
            return {
                style_on(ITALIC),
                s,
                style_off(ITALIC)
            }
        end,

        --- Strongly emphasized text.
        strong = function(s)
            return {
                style_on(BOLD),
                s,
                style_off(BOLD)
            }
        end,

        --- Block quotation.
        blockquote = function(s)
            return {
                function() current_style = "Q" end,
                s,
                function() current_style = "P" end,
            }
        end,

        --- Verbatim block.
        verbatim = function(s)
            local lines = SplitString(s, "[\n\r]")
            local flush = flushparagraph("PRE")
            return { InterleaveArray(lines, flush), flush }
        end,

        --- Fenced code block, with infostring `i`.
        fenced_code = function(s, i)
            return {}
        end,

        --- Header level `level`, with text `s`.
        header = function(s, level)
            if (level > 4) then
                level = 4
            end
            return {
                s,
                flushparagraph("H"..level)
            }
        end,

        --- Horizontal rule.
        hrule = function()
            importer:flushparagraph("P")
            importer:flushparagraph("P")
        end,

        definitionlist = nop,
        citation = nop,
        citations = nop,
        note = nop,
	}

	local metadata = {}
	local parser = lunamark.reader.new(writer,
	{
		smart = true,
		require_blank_before_blockquote = true,
		require_blank_before_header = true,
	})
	local data = fp:read("*a")
    local parsetree, metadata = parser(data)

    -- Now we have a parse tree, execute all the actions to generate the document.

    importer:reset()
    for _, v in ipairs(FlattenArray(parsetree)) do
        local t = type(v)
        if (t == "string") and (v ~= "") then
            importer:text(v)
        elseif (t == "function") then
            v()
        end
    end
    importer:flushparagraph(current_style)

	return document
end

function Cmd.ImportMarkdownFile(filename)
	return ImportFileWithUI(filename, "Import Markdown File", Cmd.ImportMarkdownFileFromStream)
end

-- vim: sw=4 ts=4 et

