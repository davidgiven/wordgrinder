-- © 2008 David Given.
-- WordGrinder is licensed under the BSD open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id: browser.lua 68 2008-08-07 16:26:32Z dtrg $
-- $URL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/src/lua/browser.lua $

-- Load the LFS module if needed (Windows has it built in).

if not lfs then
	require "lfs"
end

-- Global definitions that the various source files need.

Cmd = {}
