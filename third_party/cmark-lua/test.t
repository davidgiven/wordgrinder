#!/usr/bin/env lua
require 'Test.More'

package.path = "./?.lua;" .. package.path
package.cpath = "./?.so;" .. package.cpath

local cmark = require 'cmark'
local builder = require 'cmark.builder'
local tests = require 'spec-tests'

subtest("spec tests (cmark)", function()
  for _,test in ipairs(tests) do
    local doc  = cmark.parse_string(test.markdown, cmark.OPT_DEFAULT)
    local html = cmark.render_html(doc, cmark.OPT_DEFAULT + cmark.OPT_UNSAFE)
    is(html, test.html, "example " .. tostring(test.example) ..
           " (lines " .. tostring(test.start_line) .. " - " ..
           tostring(test.end_line) .. ")")
  end
end)

local b = builder

local builds = function(node, expected, description)
  local rendered = cmark.render_html(node, cmark.OPT_DEFAULT + cmark.OPT_UNSAFE)
  return is(rendered, expected, description)
end

local returns_error = function(f, arg, expected_msg, description)
  local ok, msg = f(arg)
  is(ok, nil, description .. ' returns error status')
  is(msg, expected_msg, description .. ' error message')
end

builds(b.document { b.paragraph {"Hello ", b.emph { "world"  }, "."} },
    '<p>Hello <em>world</em>.</p>\n', "basic builder example")

builds(b.document "hi", '<p>hi</p>\n', "promotion of string to block")

builds(b.document(b.text "hi"), '<p>hi</p>\n', "promotion of inline to block")

builds(b.paragraph(77), '<p>77</p>\n', "promotion of number to inline")

builds(b.block_quote { b.paragraph "hi", b.paragraph "lo" },
    '<blockquote>\n<p>hi</p>\n<p>lo</p>\n</blockquote>\n', "blockquote")

builds(b.text("hello"), "hello", "b.text")

builds(b.link{url = "url", "hello"},
    '<a href="url">hello</a>', "b.link with string")
builds(b.link{url = "url", b.text("hello")},
    '<a href="url">hello</a>', "b.link with node")

builds(b.bullet_list { tight = true,
     b.item(b.paragraph "hi"),
     b.item(b.paragraph "lo") },
    '<ul>\n<li>hi</li>\n<li>lo</li>\n</ul>\n', "list turns table elts to items")

builds(b.bullet_list { tight = true, "hi", "lo" },
    '<ul>\n<li>hi</li>\n<li>lo</li>\n</ul>\n', "list turns table elts to items")

builds(b.ordered_list { tight = false, start = 2, delim = ')', "hi", "lo" },
    '<ol start="2">\n<li>\n<p>hi</p>\n</li>\n<li>\n<p>lo</p>\n</li>\n</ol>\n',
    "ordered list")

builds(b.bullet_list{ b.item
         { b.paragraph "one", b.paragraph "two", tight = false }},
    '<ul>\n<li>\n<p>one</p>\n<p>two</p>\n</li>\n</ul>\n',
    "bullet list with two paragraphs in an item")

builds(b.code_block "some code\n  ok",
  '<pre><code>some code\n  ok</code></pre>\n', "basic code block")

builds(b.code_block({info = "ruby", "some code\n  ok"}),
  '<pre><code class="language-ruby">some code\n  ok</code></pre>\n',
  "code block with info")

builds(b.html_block '<section id="foo">bar</section>',
  '<section id="foo">bar</section>\n', "html block")

builds(b.custom_block{ on_enter = "{{", on_exit = "}}", "foo\n  bar"},
  '{{\nfoo\n  bar\n}}\n', "custom block")

builds(b.thematic_break(), '<hr />\n', "thematic break")

builds(b.heading{level = 2, b.emph 'Foo', ' bar'},
  '<h2><em>Foo</em> bar</h2>\n', "heading")

local link = b.link{url = "url",
   b.text("hello"), b.text("there")}

is(#(b.get_children(link)), 2, "get_children has right length")

builds(link,
    '<a href="url">hellothere</a>', "b.link with list of nodes")

builds(b.link{url = "url", title = "tit", "hello"},
    '<a href="url" title="tit">hello</a>', "b.link with title")

builds(b.image{url = "url", title = "tit", "hello"},
    '<img src="url" alt="hello" title="tit" />', "b.image with title")

builds(b.emph "hi", '<em>hi</em>', "emph")

builds(b.strong(b.emph "hi"), '<strong><em>hi</em></strong>', "strong emph")

returns_error(b.emph, b.paragraph "text",
   "Tried to add a node with class block to a node with class inline",
   "paragraph inside emph")

builds(b.paragraph{"hi", b.linebreak(), "lo"}, '<p>hi<br />\nlo</p>\n',
  "linebreak")

builds(b.paragraph{"hi", b.linebreak(), "lo"}, '<p>hi<br />\nlo</p>\n',
  "linebreak, levaing off ()")

builds(b.paragraph{"hi", b.softbreak, "lo"}, '<p>hi\nlo</p>\n',
  "softbreak")

builds(b.code "some code", '<code>some code</code>', "code")

builds(b.html_inline "<a>&amp;</a>", '<a>&amp;</a>', "raw html inline")

builds(b.custom_inline{ on_enter = "{", on_exit = ".", "&" },
  '{&amp;.', "custom inline")


done_testing()
