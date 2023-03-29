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

type Markdown = any

-----------------------------------------------------------------------------
-- The importer itself.

function Cmd.ImportMarkdownString(data: string)
	local document = CreateDocument()
	local importer = CreateImporter(document)

	-- The Lunamark parser model expects to produce a string, but what we want
	-- is a parse tree.  This means there's some degree of semantic mismatch.
	-- What we do instead is to have Lunamark return a tree of parse operations
	-- gets flattened after parsing is complete.
	
	local metadata = {}
    local current_style = "P"

    local function nop(s) end
    local function style_on(s) return function() importer:style_on(s) end end
    local function style_off(s) return function() importer:style_off(s) end end
    local function flushparagraph(s) return function() importer:flushparagraph(s) end end

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

	local enter: {[number]: (string, Markdown) -> never} = {
        [CMARK_NODE_DOCUMENT] = nop,
        [CMARK_NODE_BLOCK_QUOTE] = function() current_style = "Q" end,
        [CMARK_NODE_LIST] = function(s, node)
            local listtype = CMarkGetList(node)
            if listtype == CMARK_BULLET_LIST then
                current_style = "LB"
            elseif listtype == CMARK_ORDERED_LIST then
                current_style = "LN"
            end
        end,
        [CMARK_NODE_ITEM] = nop,
        [CMARK_NODE_CODE_BLOCK] = function(s)
            s = s:gsub("[\n\r]+$", "")
            local lines = SplitString(s, "[\n\r]")
            for _, line in lines do
                importer:text(line)
                importer:flushparagraph("PRE")
            end
        end,
        [CMARK_NODE_HTML_BLOCK] = function(s)
            importer:text(s)
            importer:flushparagraph("RAW")
        end,
        [CMARK_NODE_CUSTOM_BLOCK] = nop,
        [CMARK_NODE_PARAGRAPH] = nop,
        [CMARK_NODE_HEADING] = nop,
        [CMARK_NODE_THEMATIC_BREAK] = function()
            importer:flushparagraph("P")
            importer:text("")
            importer:flushparagraph("P")
        end,
        [CMARK_NODE_TEXT] = function(s) importer:text(s) end,
        [CMARK_NODE_SOFTBREAK] = function() importer:flushword() end,
        [CMARK_NODE_LINEBREAK] = nop,
        [CMARK_NODE_CODE] = function(s)
            importer:style_on(UNDERLINE)
            importer:text(s)
            importer:style_off(UNDERLINE)
        end,
        [CMARK_NODE_HTML_INLINE] = function(s)
            local fn = htmltags[s:lower()]
            if fn then
                fn()
            end
        end,
        [CMARK_NODE_CUSTOM_INLINE] = nop,
        [CMARK_NODE_EMPH] = style_on(ITALIC),
        [CMARK_NODE_STRONG] = style_on(BOLD),
        [CMARK_NODE_LINK] = nop,
        [CMARK_NODE_IMAGE] = nop,
    }

    local exit: {[number]: (string, Markdown) -> never} = {
        [CMARK_NODE_DOCUMENT] = nop,
        [CMARK_NODE_BLOCK_QUOTE] = function(s) current_style = "P" end,
        [CMARK_NODE_LIST] = function() current_style = "P" end,
        [CMARK_NODE_ITEM] = nop,
        [CMARK_NODE_CUSTOM_BLOCK] = nop,
        [CMARK_NODE_PARAGRAPH] = function(s) importer:flushparagraph(current_style) end,
        [CMARK_NODE_HEADING] = function(s, node)
            local heading = CMarkGetHeading(node)
            if heading > 4 then
                heading = 4
            end
            local style = string.format("H%d", heading)
            importer:flushparagraph(style)
        end,
        [CMARK_NODE_CUSTOM_INLINE] = nop,
        [CMARK_NODE_EMPH] = style_off(ITALIC),
        [CMARK_NODE_STRONG] = style_off(BOLD),
        [CMARK_NODE_LINK] = nop,
        [CMARK_NODE_IMAGE] = nop,
    }

    local w = {
        --- Horizontal rule.
        hrule = function()
            importer:flushparagraph("P")
            importer:flushparagraph("P")
        end,
	}

    local markdown = CMarkParse(data)

    -- Now we have a parse tree, execute all the actions to generate the document.

    importer:reset()
    local iter = CMarkIterate(markdown)
    while true do
        local event, nodeType, node, text = CMarkNext(iter)
        if event == CMARK_EVENT_DONE then
            break
        elseif event == CMARK_EVENT_ENTER then
            enter[nodeType](text, node)
        elseif event == CMARK_EVENT_EXIT then
            exit[nodeType](text, node)
        end
    end
    importer:flushparagraph(current_style)

	return document
end

function Cmd.ImportMarkdownFile(filename)
	return ImportFileWithUI(filename, "Import Markdown File", Cmd.ImportMarkdownString)
end

-- vim: sw=4 ts=4 et

