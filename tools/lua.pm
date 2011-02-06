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
