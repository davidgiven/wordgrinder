-- $Id: c.pm 55 2008-08-05 00:24:20Z dtrg $
-- $HeadURL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/c.pm $
-- $LastChangedDate: 2007-04-30 22:41:42 +0000 (Mon, 30 Apr 2007) $

-- pm includefile to compile Lua programs.

-- Define some variables.

LUACOMPILER = "luac"
LUAC = "%LUACOMPILER% %LUABUILDFLAGS% %LUAEXTRAFLAGS% -o %out% %in%"

LUABUILDFLAGS = EMPTY
LUAEXTRAFLAGS = EMPTY

-- These are the publically useful clauses.

luafile = simple {
	class = "luafile",
	command = {"%LUAC%"},
	outputs = {"%U%-%I%.luac"},
}
