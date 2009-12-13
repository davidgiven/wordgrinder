-- © 2008 David Given.
-- WordGrinder is licensed under the MIT open source license. See the COPYING
-- file in this distribution for the full text.
--
-- $Id$
-- $URL$

-- Load the LFS module if needed (Windows has it built in).

if not lfs then
	require "lfs"
end

-- Global definitions that the various source files need.

Cmd = {}
