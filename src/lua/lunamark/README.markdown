# Lunamark

Lunamark is a lua library and command-line program for conversion of markdown
to other textual formats. Currently HTML, [dzslides] (HTML5 slides),
Docbook, ConTeXt, LaTeX, and Groff man are the supported output formats, but
it is easy to add new writers or modify existing ones. The markdown parser is
written using a PEG grammar and can also be modified by the user.

The library is as portable as lua and has very good performance.
It is roughly as fast as the author's own C library
[peg-markdown](http://github.com/jgm/peg-markdown),
two orders of magnitude faster than `Markdown.pl`,
and three orders of magnitude faster than `markdown.lua`.

# Links

+ [Source code repository]
+ [Issue tracker]
+ [Website]
+ [API documentation]
+ [lunamark(1)]
+ [lunadoc(1)]

[Source code repository]: https://github.com/jgm/lunamark
[Issue tracker]: https://github.com/jgm/lunamark/issues
[Website]: http://jgm.github.com/lunamark
[API documentation]: http://jgm.github.com/lunamark/doc/
[lunamark(1)]: http://jgm.github.com/lunamark/lunamark.1.html
[lunadoc(1)]: http://jgm.github.com/lunamark/lunadoc.1.html
[dzslides]: http://paulrouget.com/dzslides/ 

# Extensions

Lunamark's markdown parser currently supports a number of extensions
(which can be turned on or off individually), including:

  - Smart typography (fancy quotes, dashes, ellipses)
  - Significant start numbers in ordered lists
  - Footnotes (both regular and inline)
  - Definition lists
  - Pandoc-style title blocks
  - Pandoc-style citations
  - Fenced code blocks
  - Flexible metadata using lua declarations

See the [lunamark(1)] man page for a complete list.

It is very easy to extend the library by modifying the writers,
adding new writers, and even modifying the markdown parser. Some
simple examples are given in the [API documentation].

# Benchmarks

Generated with

    PROG=$program make bench

This converts the input files from the original markdown test suite
concatenated together 25 times.

         0.04s   sundown
         0.15s   discount
    ->   0.56s   lunamark + luajit
         0.80s   peg-markdown
    ->   0.97s   lunamark
         4.05s   PHP Markdown
         6.11s   pandoc
       113.13s   Markdown.pl
      2322.33s   markdown.lua

# Installing

If you want a standalone version of lunamark that doesn't
depend on lua or other lua modules being installed on
your system, just do

    make standalone

Your executable will be created in the `standalone`
directory.

If you are a lua user, you will probably prefer to install
lunamark using luarocks.  You can install the latest development
version this way:

    git clone http://github.com/jgm/lunamark.git
    cd lunamark
    luarocks make

Released versions will be uploaded to the luarocks
repository, so you should be able to install them using:

    luarocks install lunamark

There may be a short delay between the release and the
luarocks upload.

# Using the library

Simple usage example:

    local lunamark = require("lunamark")
    local opts = { }
    local writer = lunamark.writer.html.new(opts)
    local parse = lunamark.reader.markdown.new(writer, opts)
    print(parse("Here's my *text*"))

For more examples, see [API documentation].

# lunamark

The `lunamark` executable allows easy markdown conversion from the command
line.  For usage instructions, see the [lunamark(1)] man page.

# lunadoc

Lunamark comes with a simple lua library documentation tool, `lunadoc`.
For usage instructions, see the [lunadoc(1)] man page.
`lunadoc` reads source files and parses specially marked markdown
comment blocks.  [Here][API documentation] is an example of the result.

# Tests

The source directory contains a large test suite in `tests`.
This includes existing Markdown and PHP Markdown tests, plus more
tests for lunamark-specific features and additional corner cases.

To run the tests, use `bin/shtest`.

    bin/shtest --help            # get usage
    bin/shtest                   # run all tests
    bin/shtest indent            # run all tests matching "indent"
    bin/shtest -p Markdown.pl -t # run all tests using Markdown.pl, and normalize using 'tidy'

Lunamark currently fails four of the PHP Markdown tests:

  * `tests/PHP_Markdown/Quotes in attributes.test`: The HTML is
    semantically equivalent; using the `-t/--tidy` option to `bin/shtest` makes
    the test pass.

  * `tests/PHP_Markdown/Email auto links.test`: The HTML is
    semantically equivalent. PHP markdown does entity obfuscation, and
    lunamark does not. This feature could be added easily enough, but the test
    would still fail, because the obfuscation involves randomness. Again,
    using the `-t/--tidy` option makes the test pass.

  * `tests/PHP_Markdown/Ins & del.test`:  PHP markdown puts extra `<p>`
    tags around `<ins>hello</ins>`, while lunamark does not.  It's hard
    to tell from the markdown spec which behavior is correct.

  * `tests/PHP_Markdown/Emphasis.test`:  A bunch of corner cases with nested
    strong and emphasized text.  These corner cases are left undecided by
    the markdown spec, so in my view the PHP test suite is not normative here;
    I think lunamark's behavior is perfectly reasonable, and I see no reason
    to change.

The `make test` target only runs the Markdown and lunamark
tests, skipping the PHP Markdown tests.

# Authors

lunamark is released under the MIT license.

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added the
original ConTeXt writer.

The [dzslides] HTML, CSS, and javascript code is by Paul Rouget, released under
the DWTFYWT Public License.

