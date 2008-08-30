-- $Id: c.pm 55 2008-08-05 00:24:20Z dtrg $
-- $HeadURL: https://wordgrinder.svn.sourceforge.net/svnroot/wordgrinder/wordgrinder/c.pm $
-- $LastChangedDate: 2007-04-30 22:41:42 +0000 (Mon, 30 Apr 2007) $

-- pm includefile to compile *host* C programs.

-- Standard Lua boilerplate.

local io_open = io.open
local string_gsub = string.gsub
local string_gfind = string.gfind
local string_find = string.find
local table_insert = table.insert
local table_getn = table.getn
local filetime = pm.filetime

-- Define some variables.

CCOMPILER = "gcc"
CXXCOMPILER = "g++"
CC = "%CCOMPILER% %CBUILDFLAGS% %CDYNINCLUDES:cincludes% %CINCLUDES:cincludes% %CDEFINES:cdefines% %CEXTRAFLAGS% -c -o %out% %in%"
CXX = "%CXXCOMPILER% %CBUILDFLAGS% %CDYNINCLUDES:cincludes% %CINCLUDES:cincludes% %CDEFINES:cdefines% %CEXTRAFLAGS% -c -o %out% %in%"
CPROGRAM = "%CCOMPILER% %CBUILDFLAGS% %CLINKFLAGS% %CEXTRAFLAGS% -o %out% %in% %CLIBRARIES:clibraries%"
CXXPROGRAM = "%CXXCOMPILER% %CBUILDFLAGS% %CLINKFLAGS% %CEXTRAFLAGS% -o %out% %in% %CLIBRARIES:clibraries%"

CLIBRARY = "rm -f %out% && ar cr %out% %in% && ranlib %out%"

CBUILDFLAGS = {"-g"}
CINCLUDES = EMPTY
CDEFINES = EMPTY
CEXTRAFLAGS = EMPTY
CLINKFLAGS = EMPTY
CDYNINCLUDES = EMPTY
CLIBRARIES = EMPTY

--- Custom string modifiers -------------------------------------------------

local function prepend(rule, arg, prefix)
	if (arg == EMPTY) then
		return EMPTY
	end
	
	local t = {}
	for i, j in ipairs(arg) do
		t[i] = prefix..j
	end
	return t
end

function pm.stringmodifier.cincludes(rule, arg)
	return prepend(rule, arg, "-I")
end

function pm.stringmodifier.cdefines(rule, arg)
	return prepend(rule, arg, "-D")
end

function pm.stringmodifier.clibraries(rule, arg)
	if (arg == EMPTY) then
		return EMPTY
	end
	
	local t = {}
	for i, j in ipairs(arg) do
		if string_find(j, "%.a$") then
			t[i] = j
		else
			t[i] = "-l"..j
		end
	end
	return t
end

--- Manage C file dependencies ----------------------------------------------

local dependency_cache = {}
local function calculate_dependencies(filename, includes)
	-- Cache values, so we don't recalculate dependencies needlessly.
	
	local o = dependency_cache[filename]
	if o then
		return o
	end
	
	local deps = {}
	deps[filename] = true
	
	local calcdeps = 0
	calcdeps = function(filename, file)
		file = file or io_open(filename)
		if not file then
			return
		end
		
		local localincludes = string_gsub(filename, "/[^/]*$", "")
		if localincludes then
			localincludes = {localincludes, unpack(includes)}
		else
			localincludes = includes
		end
			
		for line in file:lines() do
			local _, _, f = string_find(line, '^[ \t]*#[ \t]*include[ \t]*["<]([^"]+)[">]')
			if f then
				for _, path in ipairs(localincludes) do
					local subfilename = path.."/"..f
					local subfile = io_open(subfilename)
					if subfile then
						if not deps[subfilename] then
							deps[subfilename] = true
							calcdeps(subfilename, subfile)
						end
						break
					end
				end
			end
		end
		
		-- Explicit close to avoid having to wait for the garbage collector
		-- to free up the underlying fd.
		
		file:close()
	end
	
	calcdeps(filename)
	o = {}
	for i, _ in pairs(deps) do
		table_insert(o, i)
	end
		
	dependency_cache[filename] = o
	return o
end

-- This clause specialises 'simple' to add support for smart dependencies of C
-- files.

simple_with_clike_dependencies = simple {
	class = "simple_with_clike_dependencies",
	makedepends = {"%CDEPENDS%"},

	__init = function(self, p)
 		simple.__init(self, p)
  		
		-- If we're a class, don't verify.
		
		if ((type(p) == "table") and p.class) then
			return
		end

		-- If dynamicheaders is an object, turn it into a singleton list.
		
		if self.dynamicheaders then
			if (type(self.dynamicheaders) ~= "table") then
				self:__error("doesn't know what to do with dynamicheaders, which ",
					"should be a list or an object but was a ", type(self.dynamicheaders))
			end
			if self.dynamicheaders.class then
				self.dynamicheaders = {self.dynamicheaders}
			end
		end
	end,
	
	__dependencies = function(self, inputs, outputs)		
		local cincludes = self:__index("CINCLUDES")
		if (type(cincludes) == "string") then
			cincludes = {cincludes}
		end
		
		local includes = {}
		for _, i in ipairs(cincludes) do
			table_insert(includes, self:__expand(i))
		end
		
		local input = self:__expand(inputs[1])
		local depends = calculate_dependencies(input, includes)
		if not depends then
			self:__error("could not determine the dependencies for ",
				pm.rendertable({input}))
		end
		if self.dynamicheaders then
			for _, i in ipairs(self.dynamicheaders) do
				local o = i:__build()
				if o[1] then
					table_insert(depends, o[1])
				end
			end
		end
		if pm.verbose then
			pm.message('"', input, '" appears to depend on ',
				pm.rendertable(depends))
		end
		return depends
	end,
	
	__buildadditionalchildren = function(self)
		self.CDYNINCLUDES = {}
		if self.dynamicheaders then
			for _, i in ipairs(self.dynamicheaders) do
				local o = i:__build()
				if o[1] then
					table_insert(self.CDYNINCLUDES, (string_gsub(o[1], "/[^/]*$", "")))
				end
			end
		end
		-- If no paths on the list, replace the list with EMPTY so it doesn't
		-- expand to anything.
		if (table_getn(self.CDYNINCLUDES) == 0) then
			self.CDYNINCLUDES = EMPTY
		end
	end
}

-- These are the publically useful clauses.

cfile = simple_with_clike_dependencies {
	class = "cfile",
	command = {"%CC%"},
	outputs = {"%U%-%I%.o"},
}

cxxfile = simple_with_clike_dependencies {
	class = "cxxfile",
	command = {"%CXX%"},
	outputs = {"%U%-%I%.o"},
}

cprogram = simple {
	class = "cprogram",
	command = {"%CPROGRAM%"},
	outputs = {"%U%-%I%"},
}

cxxprogram = simple {
	class = "cxxprogram",
	command = {"%CXXPROGRAM%"},
	outputs = {"%U%-%I%"},
}

clibrary = simple {
	class = "clibrary",
	command = {
		"%CLIBRARY%"
	},
	outputs = {"%U%-%I%.a"},
}
