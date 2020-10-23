                               WORDGRINDER V0.8
                               ================

                           © 2007-2020 David Given
                                 2020-10-23

                               Windows version


INTRODUCTION
============

WordGrinder is a simple, Unicode-aware word processor. It's designed to get
the hell out of your way and let you write; it does very little, but what it
does it does well.

It supports basic paragraph styles, basic character styles, basic screen
markup, a menu interface that means you don't have to remember complex
key sequences, HTML import and export, and some other useful features.

Note: WordGrinder originated as a Unix program and as such it does not behave
anything like a traditional Windows application. You Have Been Warned.



INSTALLATION
============

Run the supplied installer. It's done.

You can switch to use a different font with the drop-down menu from the
application icon in the top-left corner of the screen.

Important note! To quit, you'll have to use the menus inside WordGrinder
(because the application knows nothing about the Windows window close button).
Do CTRL+Q to quit.

You can toggle full-screen mode with ALT+ENTER.



USAGE
=====

Run WordGrinder from the start menu. There's an option for the menu. Please
read it, as WordGrinder doesn't work like other Windows applications. There's
also a command line version for scripting use, or running from a cmd shell; I
assume that if you want this, you know where to find it!

Press ESC to get the menu. Press ESC, F, O to open a file.


If you use WordGrinder, please join the mailing list. This will allow you
to ask questions, hopefully receive answers, and get news about any
new releases. You can subscribe or view the archives at the following page:

https://lists.sourceforge.net/lists/listinfo/wordgrinder-users



LICENSE
=======

WordGrinder contains a number of embedded libraries, described here. Not all of
them may be used by any given binary depending on your configuration. Please
look in the licenses directory for the full license text.

WordGrinder is © 2007-2020 David Given, and is available under the MIT license.

The distribution contains a copy of Lua 5.1. This is also MIT licensed and is ©
1994–2017 Lua.org, PUC-Rio. See http://lua.org for more information.

The distribution contains a copy of the Lpeg parser library. This is also MIT
licensed and is © 2007-2019 Lua.org, PUC-Rio. See
http://inf.puc-rio.br/~roberto/lpeg for more information.

The distribution contains a copy of LuaBitOp. This is also MIT licensed and is ©
2008-2012 Mike Pall. See http://bitop.luajit.org/ for more information.

The distribution contains a copy of the MiniZip library. This is © 1998-2010
Gilles Vollant and Mathis Svenson, and is available under the BSD license.

The distribution contains a copy of the SCOWL wordlist for British and
American-Canadian English. This is © Kevin Atkinson and J. Ross Beresford.
Please see the licenses/COPYING.Scowl file for the full license text.

The distribution contains a copy of the uthash and utlist libraries. This is ©
2003-2009 Troy D Hanson, and is available under a simplified BSD license.

The distribution contains a copy of the xpattern module. This is also MIT
licensed and is © 2008-2009 David Manura. See
http://lua-users.org/wiki/ExPattern for more information.

The distribution contains a (thoroughly hacked up) copy of the Lunamark
Markdown parser. This is also MIT licensed and is © 2009-2016 John MacFarlane.
See https://github.com/jgm/lunamark for more information.



REVISION HISTORY
================

WordGrinder 0.8: 2020-10-13: started out as a bugfix release but then I got
carried away. New features: a paragraph style for numbered bulletpoints; more
look-and-feel options; the caret now flashes; basic template support; word
count display of selected text; custom autosave directory; autocompletion in
file dialogues; Windows console version; recent documents list; Markdown
import. Bugfixes: lots of import and export fixes (and tests so that they stay
fixed); spellchecker fixes; selection position fixes; keyboard entry fixes on
Windows; graphics fixes on Windows; filesystem fixes on Windows; assorted other
minor tweaks.

WordGrinder 0.7.2: 2017-03-21: bugfix release. Pasting immediately after
loading a document no longer hard crashes. Don't buffer overrun if given
invalid unicode. Global settings are now updated correctly (in several
places). Fix a data loss situation when saving fails.

WordGrinder 0.7.1: 2017-11-02: correct and cleaner license reporting;
rearrange the source so that we can avoid shipping upstream dependencies
if we want. No actual code changes.

WordGrinder 0.7: 2017-10-30: new plain text diffable file format; Lua 5.3
support; better locale detection; dense paragraphs mode; lots of bugfixes.
Official OSX support. New (better, hopefully) build system.

WordGrinder 0.6: 2015-04-18: New X11 frontend (actual bold and italic on
Linux machines!); shift+cursor keys starts a selection; more HTML emission
fixes; non-document persistent settings; global key maps (currently via a
configurationfile); search works properly across words with markup; italic
display in a terminal (if you have a new enough version of ncurses); more
traditional charstyle selection (you can press ^B at the beginning of words
now!); more traditional selection model (shift+cursor keys works now!); fix
crash on loading very large .wg files; smart quote support; more efficient
files; undo and redo; spellchecker; colour configuration on X11 and Windows;
MarkDown export.

WordGrinder 0.5.2.1: 2015-02-18: Minor bugfixes: build system fixes; updated
minizip to a version which builds better on Ubuntu; OSX Homebrew build system;
delete word; subsection counts now correct; HTML PRE emission issue corrected.

WordGrinder 0.5.1: 2013-12-08: Major overhaul: fixed hideous file corruption
bug; much improved Windows text renderer; bold; page count; widescreen mode;
UI style overhaul; many other minor bugfixes. Many thanks to Connor Karatzas
for extensive Windows testing.

WordGrinder 0.4.1: 2013-04-14: Minor bugfixes and build optimisation in aid
of the Debian package.

WordGrinder 0.4: 2013-03-24: Major overhaul: OpenDocument import/export,
new much smaller file format, a proper Windows port, updated to Lua 5.2,
switched away from Prime Mover to make (sob), much bug fixage.

WordGrinder 0.3.3: 2009-12-13: Fixed a bug when searching for or replacing
strings containing multiple whitespace characters (that was triggering the
crash handler). Thanks to lostnbronx for the report. Added RAW and PRE
paragraph styles. Cleaned up HTML import. Add customisability to HTML export.
Relicensed to MIT.

WordGrinder 0.3.2: 2008-11-03: Fixed a very simple and very stupid typo that
caused a crash if you tried to turn autosave on. Added a simple exception
handler to try and prevent data loss on error in the future.

WordGrinder 0.3.1: 2008-09-08: Minor bugfix revision to correct a few minor
but really embarrassing crashes problems in 0.3: no crash on HTML import, no
crash on File->New. Also some minor cosmetic fixes I noticed while doing the
work.

WordGrinder 0.3: 2008-09-07: Lots more bug fixes. Added LaTeX export; troff
export; next/previous word/character; table of contents; autosave; scrapbook;
Windows console port. Fixed some issues with key binding. Lua bytecode is now
embedded in the executable, making it self contained. --lua option. General
overhaulage.

WordGrinder 0.2: 2008-01-13: Lots of bug fixes. Added word count. Added about
dialogue.

WordGrinder 0.1: 2007-10-14: Initial release.



THE AUTHOR
==========

WordGrinder was written by me, David Given. You may contact me at
dg@cowlark.com, or visit my website at http://www.cowlark.com. There may or
may not be anything interesting there.
