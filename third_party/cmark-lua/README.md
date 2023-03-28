cmark-lua
=========

Lua wrapper for [libcmark](https://github.com/jgm/cmark),
CommonMark parsing and rendering library

To install:  `luarocks install cmark`.

cmark
-----

`cmark` exposes the entire API of libcmark, as documented in
the `cmark(3)` man page.  Basic usage:

``` lua
local cmark = require("cmark")

local doc = cmark.parse_document(input, string.len(input), cmark.OPT_DEFAULT)
local html = cmark.render_html(doc, cmark.OPT_DEFAULT)
```

For convenience, constants and functions are renamed so that
an initial `cmark_` or `CMARK_` is omitted:  for example,
`CMARK_NODE_PARAGRAPH` is exposed as `cmark.NODE_PARAGRAPH` and
`cmark_parse_document` as `cmark.parse_document`.

Two additional functions are provided:

`cmark.parse_string(s, opts)` is like `parse_document`, but
does not require you to specify the length of the input
string.

`cmark.walk(node)` wraps `cmark`'s iterator interface in a
format that is more lua-esque.  Usage example:

``` lua
local links = 0
for cur, entering, node_type in cmark.walk(doc) do
   if node_type == cmark.NODE_LINK and not entering then
       links = links + 1
       -- insert " (link #n)" after the link:
       local t = cmark.node_new(NODE_TEXT)
       cmark.node_set_literal(t, string.format(" (link #%d)", links))
       cmark.node_insert_after(cur, t)
   end
end
```

The memory allocated by libcmark for `node` objects must be
freed by the calling program by calling `cmark.node_free` on the
document node.  (This will automatically free all children as
well.)

In addition, a C function

``` C
void push_cmark_node(lua_State *L, cmark_node *node)
```

is exported to make it easier to use these functions
from the C API.

For a higher-level interface, see
[lcmark](https://github.com/jgm/lcmark).

cmark.builder
-------------

A special module, `cmark.builder`, is provided to make it easier
to construct cmark nodes.

Usage examples:

```lua
local b = require 'cmark.builder'
local mydoc = b.document{
                b.paragraph{
                  b.text "Hello ",
                  b.emph{
                    b.text "world" },
                  b.link{
                    url = "http://example.com",
                    b.text "!" } } }
```

The arguments to builder functions are generally
tables.  Key-value pairs are used to set attributes,
and the other values are used as children or literal
string content, as appropriate.

The library will interpret values as the appropriate
types, when possible.  So, you can supply a single
value instead of an array.  And you can supply a string
instead of an inline node, or a node instead of a list
item.  The following is equivalent to the example above:

```lua
local mydoc = b.document{
                b.paragraph{
                  "Hello ", b.emph "world",
                  b.link{ url="http://example.com", "!"} }}
```

The builder functions are

```lua
builder.document{block1, block2, ...}
builder.block_quote{block1, block2, ...}
builder.ordered_list{delim = cmark.PAREN_DELIM, item1, item2, ...}
-- attributes: delim, start, tight
builder.bullet_list  -- attributes: tight
builder.item
builder.code_block  -- attributes: info
builder.html_block
builder.custom_block --  attributes: on_enter, on_exit
builder.thematic_break
builder.heading  -- attributes: level
builder.paragraph
builder.text
builder.emph
builder.strong
builder.link   -- attributes: title, url
builder.image  -- attributes: title, url
builder.linebreak
builder.softbreak
builder.code
builder.html_inline
builder.custom_inline  -- attributes: on_enter, on_exit
builder.get_children(node) -- returns children of a node as a table
```

For developers
--------------

`make` builds the rock and installs it locally.

`make test` runs some tests.  These are in `test.t`.
You'll need the `prove` executable and the `lua-TestMore` rock.

`make update` will update the C sources and spec test from the
`../cmark` directory.

