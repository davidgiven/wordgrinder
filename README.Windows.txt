                              WORDGRINDER V0.7.0
                              ==================

                           © 2007-2017 David Given
                                 2015-09-23

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
read it, as WordGrinder doesn't work like other Windows applications.

Press ESC to get the menu. Press ESC, F, O to open a file.


If you use WordGrinder, please join the mailing list. This will allow you
to ask questions, hopefully receive answers, and get news about any
new releases. You can subscribe or view the archives at the following page:

https://lists.sourceforge.net/lists/listinfo/wordgrinder-users



LICENSE
=======

WordGrinder is available under the MIT license. Please see the COPYING file
for the full text.

WordGrinder contains a copy of Lua 5.1. This is also MIT licensed and is
© 1994–2017 Lua.org, PUC-Rio. See http://lua.org for more information.

WordGrinder contains a copy of the LuaFileSystem code. This is also MIT
licensed and is © The Kepler Project. See
http://www.keplerproject.org/luafilesystem for more information.

WordGrinder contains a copy of the xpattern module. This is also MIT licensed
and is © David Manura. See http://lua-users.org/wiki/ExPattern for more
information.

WordGrinder contains a copy of the SCOWL wordlist for British and
American-Canadian English. This is © Kevin Atkinson and J. Ross Beresford.
Please see the README.Scowl file for the full license text.



REVISION HISTORY
================

WordGrinder 0.7: 2017-??-??: new plain text diffable file format; Lua 5.3
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
