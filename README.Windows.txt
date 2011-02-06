                              WORDGRINDER V0.3.3
                              ==================

                           © 2007-2009 David Given
                                 2009-12-13

                               Windows version


INTRODUCTION
============

WordGrinder is a simple, Unicode-aware word processor that runs in a Win32
console. It's designed to get the hell out of your way and let you write;
it does very little, but what it does it does well.

It supports basic paragraph styles, basic character styles, basic screen
markup, a menu interface that means you don't have to remember complex
key sequences, HTML import and export, and some other useful features.

Note: WordGrinder originated as a Unix program and as such it does not behave
anything like a traditional Windows application. You Have Been Warned.



INSTALLATION
============

No installation is needed. Simply uncompress the zipfile somewhere, run
wordgrinder.exe and it will start.

However:

WordGrinder makes heavy use of Unicode for drawing things like menus.
Unfortunately, the Windows console has rather poor Unicode support. While
WordGrinder will still *work*, and be useful, a lot of the graphical
elements will be drawn as strings of ????... characters. This may lead to
a degraded user experience.

As a workaround, supplied in this package are a proper Unicode console font
and a registry hack to enable it. This will make WordGrinder considerably
nicer to use. To install:

- Copy DejaVuSansMono.ttf into the Fonts folder in your Control Panel.
- Double-click on DejaVuSansMono.reg to install the registry hack.
- Reboot.

Once done, start WordGrinder, and then click on the window icon on the top
left of the console and select 'Properties'. You can change the font there.
Windows will remember the font so that you don't have to set it every time.

This does not work in full-screen mode, unfortunately (press ALT+ENTER to
toggle); you are restricted to the system bitmap font for that. That's not
my fault.

If you want to use a different font, I recommend the following site which
explains how:

http://www.hanselman.com/blog/UsingConsolasAsTheWindowsConsoleFont.aspx



USAGE
=====

Simply double-click on the .exe to run WordGrinder.

Press ESC to get the menu. Press ESC, F, O to open a file. You'll see
README.wg in there; that's the manual. Please read it.

WARNING: if you close the window, Windows will immediately terminate
WordGrinder without prompting you to save your document. I recommend
investigating WordGrinder's autosave feature. 


If you use WordGrinder, please join the mailing list. This will allow you
to ask questions, hopefully receive answers, and get news about any
new releases. You can subscribe or view the archives at the following page:

https://lists.sourceforge.net/lists/listinfo/wordgrinder-users



LICENSE
=======

WordGrinder is available under the MIT license. Please see the COPYING file
for the full text.



REVISION HISTORY
================

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
