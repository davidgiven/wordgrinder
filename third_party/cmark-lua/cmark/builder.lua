local c = require('cmark')

local builder = {}

-- returns 'inline', 'block', 'item', or 'unknown'
local node_get_class = function(node)
  local nt = c.node_get_type(node)
  if nt == c.NODE_ITEM then
    return 'item'
  elseif (nt >= c.NODE_FIRST_BLOCK and nt <= c.NODE_LAST_BLOCK) then
    return 'block'
  elseif (nt >= c.NODE_FIRST_INLINE and nt <= c.NODE_LAST_INLINE) then
    return 'inline'
  end
  return 'unknown'
end

local add_children
-- 'builder.add_children(node, {node1, node2})'
-- adds 'node1' and 'node2' as children of 'node'.
-- 'builder.add_children(node, {node1, {node2, node3}})'
-- adds 'node1', 'node2', and 'node3' as children of 'node'.
-- 'builder.add_children(node, "hello")'
-- adds a text node with "hello" as child of 'node'.
-- 'builder.add_children(node, node1)'
-- adds 'node1' as a child of 'node'.
-- THe parameter 'contains' is a table with boolean fields 'items',
-- 'blocks', 'inlines', and 'literal' that tells you what kind of
-- children the table can contain.
-- The function returns 'true' or 'nil, msg'.
add_children = function(node, v, contains)
  if type(v) == 'nil' then
    return true -- just skip a nil
  end
  if type(v) == 'table' then
    for _,x in ipairs(v) do
      local ok, msg = add_children(node, x, contains)
      if not ok then
        return nil, msg
      end
    end
    return true
  elseif type(v) == 'function' then
    -- e.g. hard_break -- we want hard_break()
    local ok, msg = add_children(node, v(), contains)
    return ok, msg
  end
  local child
  if type(v) == 'userdata' then
    child = v
  elseif contains.literal then
    if c.node_set_literal(node, tostring(v)) then
      return true
    else
      return nil, "Could not set literal"
    end
  else
    -- if v is not a node, make a text node:
    child = c.node_new(c.NODE_TEXT)
    if not child then
      return nil, "Could not create text node"
    end
    if not c.node_set_literal(child, tostring(v)) then
      return nil, "Could not set literal"
    end
  end
  local child_class = node_get_class(child)
  if (child_class == 'item' and contains.items) or
     (child_class == 'block' and contains.blocks) or
     (child_class == 'inline' and contains.inlines) then
    if not c.node_append_child(node, child) then
      return nil, "Could not append child"
    end
  elseif child_class == 'block' and contains.items then
    local item = c.node_new(c.NODE_ITEM)
    if not item then
      return nil, "Could not create item node"
    end
    if not c.node_append_child(item, child) then
      return nil, "Could not append child to item"
    end
    if not c.node_append_child(node, item) then
      return nil, "Could not append item to node"
    end
  elseif child_class == 'inline' and contains.blocks then
    local para = c.node_new(c.NODE_PARAGRAPH)
    if not c.node_append_child(para, child) then
      return nil, "Could not append child to para"
    end
    if not c.node_append_child(node, para) then
      return nil, "Could not append para to node"
    end
  elseif child_class == 'inline' and contains.items then
    local para = c.node_new(c.NODE_PARAGRAPH)
    local item = c.node_new(c.NODE_ITEM)
    if not c.node_append_child(para, child) then
      return nil, "Could not append child to para"
    end
    if not c.node_append_child(item, para) then
      return nil, "Could not append para to item"
    end
    if not c.node_append_child(node, item) then
      return nil, "Could not append item to node"
    end
  else
    return nil, 'Tried to add a node with class ' .. child_class ..
                ' to a node with class ' .. node_get_class(node)
  end
  return true
end

-- return children as a table
builder.get_children = function(node)
  local child = c.node_first_child(node)
  local result = {}
  while child do
    result[#result + 1] = child
    child = c.node_next(child)
  end
  return result
end

-- contains is a table, with boolean fields 'literal', 'blocks', 'inlines',
-- 'items'
local node = function(node_type, contains, fields)
  return function(contents)
    local node = c.node_new(node_type)
    if not node then
      return nil, 'Could not create node of type ' .. tostring(node_type)
    end
    if contents == nil then
      return node
    end
    -- set the attributes if defined
    if fields and type(contents) == 'table' then
      for field,func in pairs(fields) do
        if contents[field] then
          local ok, msg = func(node, contents[field])
          if not ok then
            return nil, msg
          end
        end
      end
    end
    -- treat rest as children
    local ok, msg = add_children(node, contents, contains)
    if not ok then
      return nil, msg
    end
    return node
  end
end

local function set_tight(n, tight)
  local t_int = tight and 1 or 0
  return c.node_set_list_tight(n, t_int)
end

local function set_delim(n, delim)
  local delimt
  if delim == c.PAREN_DELIM or delim == c.PERIOD_DELIM then
    delimt = delim
  elseif delim == ')' then
    delimt = c.PAREN_DELIM
  elseif delim == '.' then
    delimt = c.PERIOD_DELIM
  else
    return nil, 'Unknown delimiter ' .. delim
  end
  return c.node_set_list_delim(n, delimt)
end

builder.document = node(c.NODE_DOCUMENT, {blocks = true})

builder.block_quote = node(c.NODE_BLOCK_QUOTE, {blocks = true})

builder.ordered_list = function(contents)
  local n = node(c.NODE_LIST, {items = true},
                 {delim = set_delim,
                  start = c.node_set_list_start,
                  tight = set_tight,
                 })(contents)
  c.node_set_list_type(n, c.ORDERED_LIST)
  return n
end

builder.bullet_list = function(contents)
  local n = node(c.NODE_LIST, {items = true},
                 {tight = set_tight,
                 })(contents)
  c.node_set_list_type(n, c.BULLET_LIST)
  return n
end

builder.item = node(c.NODE_ITEM, {blocks = true})

builder.code_block = node(c.NODE_CODE_BLOCK, {literal = true},
   { info = c.node_set_fence_info })

builder.html_block = node(c.NODE_HTML_BLOCK, {literal = true})

builder.custom_block = node(c.NODE_CUSTOM_BLOCK,
   {inlines = true, blocks = true, items = true},
   { on_enter = c.node_set_on_enter, on_exit = c.node_set_on_exit })

builder.thematic_break = node(c.NODE_THEMATIC_BREAK)

builder.heading = node(c.NODE_HEADING, {inlines = true},
  { level = c.node_set_heading_level })

builder.paragraph = node(c.NODE_PARAGRAPH, {inlines = true})

builder.text = node(c.NODE_TEXT, {literal = true})

builder.emph = node(c.NODE_EMPH, {inlines = true})

builder.strong = node(c.NODE_STRONG, {inlines = true})

builder.link = node(c.NODE_LINK, {inlines = true},
                 {title = c.node_set_title, url = c.node_set_url})

builder.image = node(c.NODE_IMAGE, {inlines = true},
                 {title = c.node_set_title, url = c.node_set_url})

builder.linebreak = node(c.NODE_LINEBREAK)

builder.softbreak = node(c.NODE_SOFTBREAK)

builder.code = node(c.NODE_CODE, {literal = true})

builder.html_inline = node(c.NODE_HTML_INLINE, {literal = true})

builder.custom_inline = node(c.NODE_CUSTOM_INLINE, {inlines = true},
   { on_enter = c.node_set_on_enter, on_exit = c.node_set_on_exit })

return builder
