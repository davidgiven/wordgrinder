#!/bin/sh
# Prime Mover
#
# (C) 2006 David Given.
# Prime Mover is licensed under the MIT open source license. To get the full
# license text, run this file with the '--license' option.
#
# $Id:shell.sh 115 2008-01-13 05:59:54Z dtrg $

if [ -x "$(which arch 2>/dev/null)" ]; then
	ARCH="$(arch)"
elif [ -x "$(which machine 2>/dev/null)" ]; then
	ARCH="$(machine)"
elif [ -x "$(which uname 2>/dev/null)" ]; then
	ARCH="$(uname -m)"
else
	echo "pm: unable to determine target type, proceeding anyway"
	ARCH=unknown
fi
	
THISFILE="$0"
PMEXEC="./.pm-exec-$ARCH"
set -e

GZFILE=/tmp/pm-$$.gz
CFILE=/tmp/pm-$$.c
trap "rm -f $GZFILE $CFILE" EXIT

extract_section() {
	sed -e "1,/^XXXXSTART$1/d" "$THISFILE" | (
		read size
		dd bs=1 count=$size 2> /dev/null
	) > $GZFILE
	cat $GZFILE | cat
}

# If the bootstrap's built, run it.

if [ "$PMEXEC" -nt $0 ]; then
	extract_section script | "$PMEXEC" /dev/stdin "$@"
	exit $?
fi

# Otherwise, compile it and restart.

echo "pm: bootstrapping..."

if [ -x "$(which gcc 2>/dev/null)" ]; then
	CC="gcc -O -s"
else
	CC="cc"
fi

extract_section interpreter > /tmp/pm-$$.c
$CC $CFILE -o "$PMEXEC" && exec "$THISFILE" "$@"

echo "pm: bootstrap failed."
exit 1

XXXXSTARTscript
38825
#!/usr/bin/lua
-- Prime Mover
--
-- © 2006-2007 David Given.
-- Prime Mover is licensed under the MIT open source license. Search
-- for 'MIT' in this file to find the full license text.
--
-- $Id: pm.lua 115 2008-01-13 05:59:54Z dtrg $

-- ======================================================================= --
--                                GLOBALS                                  --
-- ======================================================================= --

local VERSION = "0.1.2.1"

-- Fast versions of useful system variables.

local stdin = io.stdin
local stdout = io.stdout
local stderr = io.stderr

local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local string_byte = string.byte

local table_insert = table.insert
local table_getn = table.getn
local table_concat = table.concat

local posix_stat = posix.stat
local posix_readlink = posix.readlink
local posix_unlink = posix.unlink
local posix_rmdir = posix.rmdir

local os_time = os.time

local _G = _G
local _

-- Option settings.

local delete_output_files_on_error = true
local purge_intermediate_cache = false
local no_execute = false
local input_files = {}
local targets = {}
intermediate_cache_dir = ".pm-cache/"
verbose = false
quiet = false

-- Application globals.

local sandbox = {}
local scope = {object=sandbox, next=nil}
local intermediate_cache = {}
local intermediate_cache_count = 0
local buildstages = 0

-- Atoms.

local PARENT = {}
local EMPTY = {}
local REDIRECT = {}

-- Exported symbols (set to dummy values).

message = 0
filetime = 0
filetouch = 0
install = 0
rendertable = 0
stringmodifier = {}

setmetatable(_G, {__newindex = function(t, key, value)
	error("Attempt to write to new global "..key)
end})

-- ======================================================================= --
--                               UTILITIES                                 --
-- ======================================================================= --

local function message(...)
	stderr:write("pm: ")
	stderr:write(unpack(arg))
	stderr:write("\n")
end
_G.message = message

local function usererror(...)
	stderr:write("pm: ")
	stderr:write(unpack(arg))
	stderr:write("\n")
	os.exit(1)
end

local function traceoutput(...)
	stdout:write(unpack(arg))
	stdout:write("\n")
end

local function assert(message, result, e)
	if result then
		return result
	end
	
	if (type(message) == "string") then
		message = {message}
	end
	
	table.insert(message, ": ")
	table.insert(message, e)
	usererror(unpack(message))
end

-- Concatenates the contents of its arguments to the specified table.
-- (Numeric indices only.)

local function table_append(t, ...)
	for _, i in ipairs(arg) do
		if (type(i) == "table") then
			for _, j in ipairs(i) do
				table_insert(t, j)
			end
		else
			table_insert(t, i)
		end
	end
end

-- Merge the contents of its arguments to the specified table.
-- (Name indices. Will break on numeric indices.)

local function table_merge(t, ...)
	for _, i in ipairs(arg) do
		for j, k in pairs(i) do
			t[j] = k
		end
	end
end

-- Turn a list of strings into a single quoted string.

function rendertable(i, tolerant)
	if (type(i) == "string") or (type(i) == "number") then
		return i
	end
	
	if (i == nil) or (i == EMPTY) then
		return ""
	end
	
	local t = {}
	for _, j in ipairs(i) do
		if (type(j) ~= "string") and (type(j) ~= "number") then
			if tolerant then
				j = "[object]"
			else
				error("attempt to expand a list containing an object")
			end
		end
		
		local r = string_gsub(j, "\\", "\\\\")
		r = string_gsub(r, '"', '\\"')
		table_insert(t, r)
	end
	return '"'..table_concat(t, '" "')..'"'
end
local rendertable = rendertable

-- Returns just the directory part of a path.

local function dirname(f)
	local f, n = string_gsub(f, "/[^/]*$", "")
	if (n == 0) then
		return "."
	end
	return f
end
posix.dirname = dirname

-- Makes an absolute path.

local function absname(f)
	if string.find(f, "^/") then
		return f
	end
	
	return posix.getcwd().."/"..f
end
posix.absname = absname

-- Copies a file.

local function copy(src, dest)
	local s = string_gsub(src, "'", "'\"'\"'")
	local d = string_gsub(dest, "'", "'\"'\"'")
	local r = os.execute("cp '"..s.."' '"..d.."'")
	if (r ~= 0) then
		return nil, "unable to copy file"
	end
	return 0, nil
end
posix.copy = copy
	
-- Makes all directories that contain f

local function mkcontainerdir(f)
	f = dirname(f)
	if not posix_stat(f, "type") then
		mkcontainerdir(f)
		local r = posix.mkdir(f)
		if not r then
			usererror("unable to create directory '"..f.."'")
		end
	end
end

-- Install a file (suitable as a command list entry).

local function do_install(self, src, dest)
	src = absname(self:__expand(src))
	dest = absname(self:__expand(dest))
	if verbose then
		message("installing '", src, "' --> '", dest, "'")
	end
	
	mkcontainerdir(dest)
	local f, e = posix.symlink(src, dest)
	if f then
		return
	end

	if (e ~= nil) then
		f, e = posix.unlink(dest)
		if f then
			f, e = posix.symlink(src, dest)
			if f then
				return
			end
		end
	end
	
	self:__error("couldn't install '", src, "' to '", dest,
			"': ", e)
end

function install(src, dest)
	return function(self, inputs, outputs)
		local src = src
		local dest = dest
		
		if (dest == nil) then
			dest = src
			src = outputs[1]
		end
		if (type(src) ~= "string") then
			self:__error("pm.install needs a string or an object for an input")
		end
		if (type(dest) ~= "string") then
			self:__error("pm.install needs a string for a destination")
		end
		return do_install(self, src, dest)
	end
end

-- Perform an error traceback.

local function traceback(e)
	local i = 1
	while true do
		local t = debug.getinfo(i)
		if not t then
			break
		end
		if (t.short_src ~= "stdin") and (t.short_src ~= "[C]") then
			if (t.currentline == -1) then
				t.currentline = ""
			end
			message("  ", t.short_src, ":", t.currentline)
		end
		i = i + 1
	end
	
	e = string_gsub(e, "^stdin:[0-9]*: ", "")
	usererror("error: ", e)
end

-- ======================================================================= --
--                            CACHE MANAGEMENT                             --
-- ======================================================================= --

local statted_files = {}
local function clear_stat_cache()
	statted_files = {}
end

-- Returns the timestamp of a file, or 0 if it doesn't exist.

local statted_files = {}
local function filetime(f)
	local t = statted_files[f]
	if t then
		return t
	end
	
	-- Stupid BeOS doesn't dereference symlinks on stat().
	
	local realf = f
	while true do
		local newf, e = posix_readlink(realf)
		if e then
			break
		end
		realf = newf
	end
	
	t = posix_stat(realf, "mtime") or 0
	statted_files[f] = t
	return t
end
_G.filetime = filetime

-- Pretends to touch a file by manipulating the stat cache.

local function filetouch(f)
	if (type(f) == "string") then
		f = {f}
	end
	
	local t = os_time()
	for _, i in ipairs(f) do
		statted_files[i] = t
	end
end
_G.filetouch = filetouch

local function create_intermediate_cache()
	local d = dirname(intermediate_cache_dir)
	if not quiet then
		message("creating new intermediate file cache in '"..d.."'")
	end
	
	-- Attempt to wipe the old cache directory.
	
	local f = posix.files(d)
	if not f then
		-- The directory doesn't exist, so create it.
		
		mkcontainerdir(d)
		f = posix.mkdir(d)
		if not f then
			usererror("unable to create intermediate file cache directory")
		end
	else
		-- The directory exists. Delete all files in it recursively.
		
		local function rmdir(root)
			local f = posix.files(root)
			if not f then
				return
			end
			
			for i in f do
				if ((i ~= ".") and (i ~= "..")) then
					local fn = root.."/"..i
					local t = posix_stat(fn, "type")
					if (t == "regular") then
						if not posix_unlink(fn) then
							usererror("unable to purge intermediate file cache directory")
						end
					elseif (t == "directory") then
						rmdir(fn)
						posix_rmdir(fn)
					end
				end
			end
		end
		
		rmdir(d)
	end
end

local function save_intermediate_cache()
	local fn = intermediate_cache_dir.."index"
	local f = io.open(fn, "w")
	if not f then
		usererror("unable to save intermediate cache index file '", fn, "'")
	end
	
	f:write(intermediate_cache_count, "\n")
	for i, j in pairs(intermediate_cache) do
		f:write(i, "\n")
		f:write(j, "\n")
	end
	
	f:close()
end

local function load_intermediate_cache()
	local fn = intermediate_cache_dir.."index"
	local f = io.open(fn, "r")
	if not f then
		create_intermediate_cache()
		return
	end
	
	intermediate_cache_count = f:read("*l")
	while true do
		local l1 = f:read("*l")
		local l2 = f:read("*l")
		
		if (l1 == nil) or (l2 == nil) then
			break
		end
		
		intermediate_cache[l1] = l2
	end
	
	f:close()
end

local function create_intermediate_cache_key(key)
	local u = intermediate_cache[key]
	if not u then
		intermediate_cache_count = intermediate_cache_count + 1	
		u = intermediate_cache_count
		intermediate_cache[key] = u
		save_intermediate_cache()
	end
	
	return u
end

-- ======================================================================= --
--                            STRING MODIFIERS                             --
-- ======================================================================= --

function stringmodifier.dirname(self, s)
	if (type(s) == "table") then
		if (table_getn(s) == 1) then
			s = s[1]
		else
			self:__error("tried to use string modifier 'dirname' on a table with more than one entry")
		end
	end
	
	return dirname(s)
end

-- ======================================================================= --
--                              CLASS SYSTEM                               --
-- ======================================================================= --

--- Base class --------------------------------------------------------------

local metaclass = {
	class = "metaclass",
	
	-- Creates a new instance of a class by creating a new object and cloning
	-- all properties of the called class onto it.
	
	__call = function (self, ...)
		local o = {}
		for i, j in pairs(self) do
			o[i] = j
		end
		setmetatable(o, o)
		
		-- Determine where this object was defined.
		
		local i = 1
		while true do
			local s = debug.getinfo(i, "Sl")
			if s then
				if (string_byte(s.source) == 64) then
					o.definedat = string_sub(s.source, 2)..":"..s.currentline
				end
			else
				break
			end
			i = i + 1
		end

		-- Call the object's constructor and return it.
				
		o:__init(unpack(arg))
		return o
	end,
	
	-- Dummy constructor.
	
	__init = function (self, ...)
	end,
}
setmetatable(metaclass, metaclass)

--- Top-level build node ----------------------------------------------------

local node = metaclass()
node.class = "node"

-- When constructed, nodes initialise themselves from a supplied table of
-- properties. All node children take exactly one argument, allowing the
-- "constructor {properties}" construction pattern.

function node:__init(t)
	metaclass.__init(self)
	
	if (type(t) == "string") then
		t = {t}
	end
	if (type(t) ~= "table") then
		self:__error("can't be constructed with a ", type(t), "; try a table or a string")
	end
	
	-- Copy over non-numeric parameters.
	
	for i, j in pairs(t) do
		if (tonumber(i) == nil) then
			self[i] = j
		end
	end

	-- Copy any numeric parameters.
	
	for _, i in ipairs(t) do
		table_insert(self, i)
	end
	
	-- If we're a class, don't verify.
	
	if t.class then
		return
	end

	-- ensure_n_children
	-- When true, ensures that the node has exactly the number of children
	-- specified.
	
	if self.ensure_n_children then
		local n = self.ensure_n_children
		if (table.getn(self) ~= n) then
			local one
			if (n == 1) then
				one = "one child"
			else
				one = n.." children"
			end
			self:_error("must have exactly ", one)
		end
	end
	
	-- ensure_at_least_one_child
	-- When true, ensures the the node has at least one child.
		
	if self.ensure_at_least_one_child then	
		if (table_getn(self) < 1) then
			self:__error("must have at least one child")
		end
	end
			
	-- construct_string_children_with
	-- If set, any string children are automatically converted using the
	-- specified constructor.
	
	if self.construct_string_children_with then
		local constructor = self.construct_string_children_with
		for i, j in ipairs(self) do
			if (type(j) == "string") then
				self[i] = constructor {j}
			end
		end
	end
			
	-- all_children_are_objects
	-- When true, verifies that all children are objects and not something
	-- else (such as strings).

	if self.all_children_are_objects then			
		for i, j in ipairs(self) do
			if (type(j) ~= "table") then
				self:__error("doesn't know what to do with child ", i,
					", which is a ", type(j))
			end
		end
	end
	
	-- Ensure that self.install is valid.
	
	if self.install then
		local t = type(self.install)
		if (t == "string") or
		   (t == "function") then
			self.install = {self.install}
		end
		
		if (type(self.install) ~= "table") then
			self:__error("doesn't know what to do with its installation command, ",
				"which is a ", type(self.install), " but should be a table, function ",
				"or string")
		end
	end
end

-- If an attempt is made to access a variable on a node that doesn't exist,
-- and the variable starts with a capital letter, it's looked up in the
-- property scope.

function node:__index(key)
	local i = string_byte(key, 1)
	if (i >= 65) and (i <= 90) then
		-- Scan up the class hierarchy.
		
		local recurse
		recurse = function(s, key)
			if not s then
				return nil
			end
			local o = rawget(s.object, key)
			if o then
				if (type(o) == "table") then

					-- Handle lists of the form {PARENT, "foo", "bar"...}					
					if (o[1] == PARENT) then
						local parent = recurse(s.next, key)
						local newo = {}
						
						if parent then
							if (type(parent) ~= "table") then
								parent = {parent}
							end
							for _, j in ipairs(parent) do
								table_insert(newo, j)
							end
						end
						for _, j in ipairs(o) do
							if (j ~= PARENT) then
								table_insert(newo, j)
							end
						end
						return newo

					-- Handle lists of the form {REDIRECT, "newkey"}
					elseif (o[1] == REDIRECT) then
						return self:__index(o[2])
					end
				end
				return o
			end
			-- Tail recursion.
			return recurse(s.next, key)
		end
		
		-- We want this node looked at first, so fake up a scope entry for it.
		local fakescope = {
			next = scope,
			object = self
		}
		
		-- Tail recursion.
		return recurse(fakescope, key)
	end
	
	-- For local properties, just return what's here.
	return rawget(self, key)
end

-- Little utility that emits an error message.

function node:__error(...)
	usererror("object '", self.class, "', defined at ",
		self.definedat, ", ", unpack(arg))
end

-- Causes a node to return its outputs; that is, the files the node will
-- produce when built. The parameter contains a list of input filenames; the
-- outputs of the node's children.

function node:__outputs(inputs)
	self:__error("didn't implement __outputs when it should have")
end

-- Causes a node to return its dependencies; that is, a list of *filenames*
-- whose timestamps need to be considered when checking whether a node needs
-- to be rebuilt. This is usually, but not always, the same as the inputs.

function node:__dependencies(inputs, outputs)
	return inputs
end

-- Returns the node's timestamp. It will only get built if this is older than its
-- children's timestamps.

function node:__timestamp(inputs, outputs)
	local t = 0
	for _, i in ipairs(outputs) do
		local tt = filetime(i)
		if (tt > t) then
			t = tt
		end
	end
	return t
end

-- Unconditionally builds the nodes' children, collating their outputs. We
-- push a new scope while we do so, to make this object's definitions visible
-- to the children. (Almost never overridden. Only file() will want to do
-- this, most likely.)

function node:__buildchildren()
	local inputs = {}
	scope = {object=self, next=scope}
	
	for _, i in ipairs(self) do
		table_append(inputs, i:__build())
	end
	self:__buildadditionalchildren()
	scope = scope.next
	return inputs
end

-- Provides a hook for building any additional children that aren't actually
-- in the child list.

function node:__buildadditionalchildren()
end

-- Cause the node's children to be built, collating their outputs, and if
-- any output is newer than the node itself, causes the node to be built.

function node:__build()
	-- Build children and collate their outputs. These will become this node's
	-- inputs. 
	
	local inputs = self:__buildchildren()
 	self["in"] = inputs
	
	-- Determine the node's outputs. This will usually be automatically
	-- generated, in which case the name will depend on the overall environment ---
	-- including the inputs.
	
	local outputs = self:__outputs(inputs)
	self.out = outputs
	
	-- Get the current node's timestamp. If anything this node depends on is
	-- newer than that, the node needs rebuilding.
	
	local t = self:__timestamp(inputs, outputs)
	local depends = self:__dependencies(inputs, outputs)
	local rebuild = false

	if (t == 0) then
		rebuild = true
	end
		
	if (not rebuild and depends) then
		for _, i in ipairs(depends) do
			local tt = filetime(i)
--			message("comparing ", t, " with ", tt, " (", rendertable({i}), ")")
			if (tt > t) then
				if verbose then
					message("rebuilding ", self.class, " because ", i, " (", tt, ") newer than ",
						rendertable(outputs), " (", t, ")")
				end
				rebuild = true
				break
			end
		end
	end

	if rebuild then
		self:__dobuild(inputs, outputs)
		filetouch(outputs)
	end
	
	-- If an installation command was specified, execute it now.
	
	if self.install then
		self:__invoke(self.install, inputs, outputs)
	end
	
	-- And return this nodes' outputs.
	
	return outputs
end

-- Builds this node from the specified input files (the node's childrens'
-- outputs).

function node:__dobuild(inputs, outputs)
	self:__error("didn't implement __dobuild when it should have")
end

-- Recursively expands any variables in a string.

function node:__expand(s)
	local searching = true
	while searching do
		searching = false
		
		-- Expand %{expressions}%
		
		s = string_gsub(s, "%%{(.-)}%%", function (expr)
			searching = true

			local f, e = loadstring(expr, "expression")
			if not f then
				self:__error("couldn't compile the expression '", expr, "': ", e)
			end
			
			local env = {self=self}
			setmetatable(env, {
				__index = function(_, key)
					return sandbox[key]
				end
			})
			setfenv(f, env)
			
			f, e = pcall(f, self)
			if not f then
				self:__error("couldn't evaluate the expression '", expr, "': ", e)
			end

			return rendertable(e)			
		end)

		-- Expand %varnames%
		
		s = string_gsub(s, "%%(.-)%%", function (varname)
			searching = true

			-- Parse the string reference.
			
			local _, _, leftcolon, rightcolon = string_find(varname, "([^:]*):?(.*)$")
			local _, _, varname, selectfrom, hyphen, selectto = string_find(leftcolon, "^([^[]*)%[?([^-%]]*)(%-?)([^%]]*)]?$")
			
			-- Get the basic value that the rest of the reference is going to
			-- depend on.
			
			local result = self:__index(varname)
			if not result then
				self:__error("doesn't understand variable '", varname, "'")
			end

			-- Process any selector, if specified.
			
			if (selectfrom ~= "") or (hyphen ~= "") or (selectto ~= "") then
				if (type(result) ~= "table") then
					self:__error("tried to use a [] selector on variable '", varname,
						"', which doesn't contain a table")
				end
				local n = table_getn(result)

				selectfrom = tonumber(selectfrom)
				selectto = tonumber(selectto)
								
				if (hyphen ~= "") then
					if not selectfrom then
						selectfrom = 1
					end
					if not selectto then
						selectto = n
					end
				else
					if not selectto then
						selectto = selectfrom
					end
					if not selectfrom then
						self:__error("tried to use an empty selector on variable '", varname, "'")
					end
				end
				
				if (selectfrom < 1) or (selectto < 1) or
				   (selectfrom > n) or (selectto > n) or
				   (selectto < selectfrom) then
					self:__error("tried to use an invalid selector [",
						selectfrom, "-", selectto, "] on variable '", varname,
						"'; only [1-", n, "] is valid")
				end
				
				local newresult = {}
				for i = selectfrom, selectto do
					table_insert(newresult, result[i])
				end
				result = newresult
			end
			
			-- Process any string modifier, if supplied.
			
			if (rightcolon ~= "") then
				local f = stringmodifier[rightcolon]
				if not f then
					self:__error("tried to use an unknown string modifier '",
						rightcolon, "' on variable '", varname, "'")
				end
				
				result = f(self, result)
			end
				
			return rendertable(result)
		end)
	end
	
	-- Any remaining %% sequences must be empty, and so convert them into
	-- single % sequences.
	
	s = string_gsub(s, "%%%%", "%")
	return s
end

-- Expands any variables in a command table, and executes it.

function node:__invoke(command, inputs, outputs)
	if (type(command) ~= "table") then
		command = {command}
	end
	
	for _, s in ipairs(command) do
		if (type(s) == "string") then
			s = self:__expand(s)
			if not quiet then
				traceoutput(s)
			end
			if not no_execute then
				local r = os.execute(s)
				if (r ~= 0) then
					return r
				end
			end
		elseif (type(s) == "function") then
			local r = s(self, inputs, outputs)
			if r then
				return r
			end
		end
	end
	return false
end

-- ======================================================================= --
--                                PROLOGUE                                 --
-- ======================================================================= --

-- The prologue contains the standard library that all pmfiles can refer to.
-- For simplicity, it's implemented by code running inside the sandbox,
-- which means that it's basically identical to user code (and could, in
-- fact, be kept in a seperate file).

-- Here we set up the sandbox.

table_merge(sandbox, {
	VERSION = VERSION,
	
	assert = assert,
	collectgarbage = collectgarbage,
	dofile = dofile,
	error = error,
	getfenv = getfenv,
	getmetatable = getmetatable,
	gcinfo = gcinfo,
	ipairs = ipairs,
	loadfile = loadfile,
	loadlib = loadlib,
	loadstring = loadstring,
	next = next,
	pairs = pairs,
	pcall = pcall,
	print = print,
	rawequal = rawequal,
	rawget = rawget,
	rawset = rawset,
	require = require,
	setfenv = setfenv,
	setmetatable = setmetatable,
	tonumber = tonumber,
	tostring = tostring,
	type = type,
	unpack = unpack,
	_VERSION = _VERSION,
	xpcall = xpcall,
	
	table = table,
	io = io,
	os = os,
	posix = posix,
	string = string,
	debug = debug,
	loadlib = loadlib,
	
	pm = _G,
	node = node,
	
	PARENT = PARENT,
	EMPTY = EMPTY,
	REDIRECT = REDIRECT,
})

-- Cause any reads from undefined keys in the sandbox to fail with an error.
-- This helps debugging pmfiles somewhat.

setmetatable(sandbox, {
	__index = function(self, key)
		local value = rawget(self, key)
		if (value == nil) then
			error(key.." could not be found in any applicable scope")
		end
		return value
	end
})

-- Switch into sandbox mode.

setfenv(1, sandbox)

--- Assorted utilities ------------------------------------------------------

-- Includes a file.

function include(f, ...)
	local c, e = loadfile(f)
	if not c then
		usererror("script compilation error: ", e)
	end
	
	setfenv(c, sandbox)
	local arguments = arg
	xpcall(
		function()
			c(unpack(arguments))
		end,
		function(e)
			message("script execution error --- traceback follows:")
			traceback(e)
		end
	)
end

--- file --------------------------------------------------------------------

-- file() is pretty much the simplest clause. It takes a list of filenames,
-- and outputs them.
--
--  * Building does nothing.
--  * Its outputs are its inputs.
--
-- Note: this clause only takes *strings* as its children. If a reference is
-- made to a file that doesn't exist, an error occurs.

file = node {
	class = "file",
 	ensure_at_least_one_child = true,
  	
  __init = function(self, p)
 		node.__init(self, p)
  		
		-- If we're a class, don't verify.
		
		if ((type(p) == "table") and p.class) then
			return
		end
		
 		-- Ensure that the file's children are strings.
  		
		for i, j in ipairs(self) do
			if (type(j) ~= "string") then
				self:__error("doesn't know what to do with child ", i,
					", which is a ", type(j))
			end
		end
 	end,

	-- File's timestamp is special and will bail if it meets a nonexistant file.
	
	__timestamp = function(self, inputs, outputs) 	
		local t = 0
		for _, i in ipairs(outputs) do
			i = self:__expand(i)
			local tt = filetime(i)
			if (tt == 0) then
				self:__error("is referring to the file '", i, "' which does not exist")
			end
			if (tt > t) then
				t = tt
			end
		end
		return t
	end,

 	-- Outputs are inputs.
 	
 	__outputs = function(self, inputs)
		local o = {}
		local n
 		if self.only_n_children_are_outputs then
 			n = self.only_n_children_are_outputs
 		else
 			n = table_getn(inputs)
 		end
 		
 		for i = 1, n do
 			o[i] = self:__expand(inputs[i])
 		end
 		
 		return o
 	end,
 	
 	-- Building children does nothing; outputs are inputs.
 	
 	__buildchildren = function(self)
 		local outputs = {}
 		table_append(outputs, self)
 		return outputs
 	end,
 	
 	-- Building does nothing.
 	
 	__dobuild = function(self, inputs, outputs)
 	end,
}
 
--- group -------------------------------------------------------------------

-- group() is also the simplest clause. It does nothing, existing only to
-- group together its children.

group = node {
	class = "group",
  	
 	-- Outputs are inputs.
 	
 	__outputs = function(self, inputs)
 		return inputs
 	end,
 	
 	-- Building does nothing.
 	
 	__dobuild = function(self, inputs, outputs)
 	end,
}

--- deponly -----------------------------------------------------------------

-- deponly() is the one-and-a-halfth most simplest clause. It acts like
-- group {}, but returns no outputs. It's useful for ensuring that building
-- one node causes another node to be built without actually using the
-- second node's outputs.

deponly = node {
	class = "deponly",
 	ensure_at_least_one_child = true,
	
 	-- Emits no outputs
 	
 	__outputs = function(self, inputs)
		return {}
 	end,
 	
 	-- Building does nothing.
 	
 	__dobuild = function(self, inputs, outputs)
 	end,
}

--- ith ---------------------------------------------------------------------

-- ith() is the second simplest clause. It acts like group {}, but returns
-- only some of the specified output. It is suitable for extracting, say,
-- one output from a clause to pass to cfile {}.

ith = node {
	class = "ith",
 	ensure_at_least_one_child = true,
  	
	__init = function(self, p)
 		node.__init(self, p)
  		
		-- If we're a class, don't verify.
		
		if ((type(p) == "table") and p.class) then
			return
		end

		-- If we have an i property, ensure we don't have a from or
		-- to property.
		
		if self.i then
			if self.from or self.to then
				self:__error("can't have both an i property and a from or to property")
			end
			
			if (type(self.i) ~= "number") then
				self:__error("doesn't know what to do with its i property, ",
					"which is a ", type(self.i), " where a number was expected")
			end

			self.from = self.i
			self.to = self.i
		end
		
		-- Ensure the from and to properties are numbers, if they exist.
		
		if self.from then
			if (type(self.from) ~= "number") then
				self:__error("doesn't know what to do with its from property, ",
					"which is a ", type(self.from), " where a number was expected")
			end
		end
		
		if self.to then
			if (type(self.to) ~= "number") then
				self:__error("doesn't know what to do with its to property, ",
					"which is a ", type(self.to), " where a number was expected")
			end
		end
 	end,

 	-- Emits one output, which is one of the inputs.
 	
 	__outputs = function(self, inputs)
 		local n = table_getn(inputs)
 		local from = self.from or 1
 		local to = self.to or n
 		
 		if (from < 1) or (to > n) then
 			self:__error("tried to select range ", from, " to ", to,
 				" from only ", n, " inputs")
 		end
 		
 		local range = {}
 		for i = from, to do
 			table_append(range, inputs[i])
 		end
 		return range
 	end,
 	
 	-- Building does nothing.
 	
 	__dobuild = function(self, inputs, outputs)
 	end,
}


--- foreach -----------------------------------------------------------------

-- foreach {} is the counterpart to ith {}. It applies a particular rule to
-- all of its children.

foreach = node {
	class = "foreach",
  	
	__init = function(self, p)
 		node.__init(self, p)
  		
		-- If we're a class, don't verify.
		
		if ((type(p) == "table") and p.class) then
			return
		end

		-- Ensure we have a rule property which is a table.
		
		if not self.rule then
			self:__error("must have a rule property")
		end
		if (type(self.rule) ~= "table") then
			self:__error("doesn't know what to do with its rule property, ",
				"which is a ", type(self.rule), " where a table was expected")
		end
 	end,

	-- Build all our children via the rule.
	--
	-- This is pretty much a copy of node.__buildchildren().
	
	__buildchildren = function(self)
		scope = {object=self, next=scope}

		local intermediate = {}
		for _, i in ipairs(self) do
			table_append(intermediate, i:__build())
		end
		
		local inputs = {}
		for _, i in ipairs(intermediate) do
			local r = self.rule { i }
			table_append(inputs, r:__build())
		end
		
		self:__buildadditionalchildren()
		scope = scope.next
		return inputs
	end,

 	-- Inputs are outputs --- because __buildchildren has already done the
 	-- necessary work.
 	
 	__outputs = function(self, inputs)
 		return inputs
 	end,

 	-- Building does nothing.
 	
 	__dobuild = function(self, inputs, outputs)
 	end,
}

--- Simple ---------------------------------------------------------------

-- simple is the most common clause, and implements make-like behaviour:
-- the named command is executed in order to rebuild the node.
--
--  * The timestamp is the newest timestamp of its outputs.
--  * Building executes the command.
--  * Its outputs are automatically generated by expanding the templates
--    in the 'outputs' variable.

simple = node {
	class = "file",
 	construct_string_children_with = file,
 	all_children_are_objects = true,
 	
 	__init = function(self, p)
 		node.__init(self, p)
  		
		-- If we're a class, don't verify.
		
		if ((type(p) == "table") and p.class) then
			return
		end

		-- outputs must exist, and must be a table.
		
		if not self.outputs then
			self:__error("must have an outputs template set")
		end
		
		if (type(self.outputs) ~= "table") then
			self:__error("doesn't know what to do with its outputs, which is a ",
				type(self.outputs), " but should be a table")
		end
					
		-- There must be a command which must be a string or table.
		
		if not self.command then
			self:__error("must have a command specified")
		end
		if (type(self.command) == "string") then
			self.command = {self.command}
		end
		if (type(self.command) ~= "table") then
			self:__error("doesn't know what to do with its command, which is a ",
				type(self.command), " but should be a string or a table")
		end
	end,
	
 	-- Outputs are specified manually.
 	
 	__outputs = function(self, inputs)
 		local input
 		if inputs then
 			input = inputs[1]
 		end
 		if not input then
 			input = ""
 		end
 
		self.I = string_gsub(input, "^.*/", "")
		self.I = string_gsub(self.I, "%..-$", "")

		-- Construct an outputs array for use in the cache key. This mirrors
		-- what the final array will be, but the unique ID is going to be 0.
		-- Note that we're overriding %out% here; this is safe, because it
		-- hasn't been set yet when __outputs is called, and is going to be
		-- set to the correct value when this function exits.
		
		self.out = {}
		self.U = 0
		for _, i in ipairs(self.outputs) do
			i = self:__expand(i)
			table_append(self.out, i)
		end
		
		-- Determine the cache key we're going to use.
		
		local cachekey = table_concat(self.command, " && ")
		cachekey = self:__expand(cachekey)
		cachekey = create_intermediate_cache_key(cachekey)

		-- Work out the unique ID.
		--
		-- Note: we're running in the sandbox, so we need to fully qualify
		-- pm.intermediate_cache_dir.
		
		self.U = pm.intermediate_cache_dir..cachekey
		
		-- Construct the real outputs array.
				
 		self.out = {}
 		for _, i in ipairs(self.outputs) do
 			i = self:__expand(i)
			mkcontainerdir(i)
 			table_append(self.out, i)
		end

 		return self.out
 	end,
 	
 	-- Building causes the command to be expanded and invoked. The 'children'
 	-- variable is set to the input files.
 	
 	__dobuild = function(self, inputs, outputs)
		local r = self:__invoke(self.command, inputs, outputs)
		if r then
			if delete_output_files_on_error then
				self:__invoke({"%RM% %out%"})
			end			
			self:__error("failed to build with return code ", r)
		end
 	end,
}

--- End of prologue ---------------------------------------------------------

-- Set a few useful global variables.

RM = "rm -f"
INSTALL = "ln -f"

-- Now we're done, switch out of sandbox mode again. This only works
-- because we made _G local at the top of the file, which makes it
-- lexically scoped rather than looked up via the environment.

setfenv(1, _G)

-- ======================================================================= --
--                          APPLICATION DRIVER                             --
-- ======================================================================= --

-- Parse and process the command line options.

do
	local function do_help(opt)
		message("Prime Mover version ", VERSION, " © 2006-2007 David Given")
		stdout:write([[
Syntax: pm [<options...>] [<targets>]
Options:
   -h    --help        Displays this message.
         --license     List Prime Mover's redistribution license.
   -cX   --cachedir X  Sets the object file cache to directory X.
   -p    --purge       Purges the cache before execution.
                       WARNING: will remove *everything* in the cache dir!
   -fX   --file X      Reads in the pmfile X. May be specified multiple times.
   -DX=Y --define X=Y  Defines variable X to value Y (or true if Y omitted)
   -n    --no-execute  Don't actually execute anything
   -v    --verbose     Be more verbose
   -q    --quiet       Be more quiet
   
If no pmfiles are explicitly specified, 'pmfile' is read.
If no targets are explicitly specified, 'default' is built.
Options and targets may be specified in any order.
]])
		os.exit(0)
	end
	
	local function do_license(opt)
		message("Prime Mover version ", VERSION, " © 2006 David Given")
		stdout:write([[
		
Prime Mover is licensed under the MIT open source license.

Copyright © 2006-2007 David Given

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]])
		os.exit(0)
	end

	local function needarg(opt)
		if not opt then
			usererror("missing option parameter")
		end
	end
	
	local function do_cachedir(opt)
		needarg(opt)
		intermediate_cache_dir = opt
		return 1
	end
	
	local function do_inputfile(opt)
		needarg(opt)
		table_append(input_files, opt)
		return 1
	end
	
	local function do_purgecache(opt)
		purge_intermediate_cache = true
		return 0
	end
	
	local function do_define(opt)
		needarg(opt)
		
		local s, e, key, value = string_find(opt, "^([^=]*)=(.*)$")
		if not key then
			key = opt
			value = true
		end
		
		sandbox[key] = value
		return 1
	end
	
	local function do_no_execute(opt)
		no_execute = true
		return 0
	end
	
	local function do_verbose(opt)
		verbose = true
		return 0
	end
	
	local function do_quiet(opt)
		quiet = true
		return 0
	end
	
	local argmap = {
		["h"]           = do_help,
		["help"]        = do_help,
		["c"]           = do_cachedir,
		["cachedir"]    = do_cachedir,
		["p"]           = do_purgecache,
		["purge"]       = do_purgecache,
		["f"]           = do_inputfile,
		["file"]        = do_inputfile,
		["D"]           = do_define,
		["define"]      = do_define,
		["n"]           = do_no_execute,
		["no-execute"]  = do_no_execute,
		["v"]           = do_verbose,
		["verbose"]     = do_verbose,
		["q"]           = do_quiet,
		["quiet"]       = do_quiet,
		["license"]     = do_license,
	}
	
	-- Called on an unrecognised option.
	
	local function unrecognisedarg(arg)
		usererror("unrecognised option '", arg, "' --- try --help for help")
	end
	
	-- Do the actual argument parsing.
	
	for i = 1, table_getn(arg) do
		local o = arg[i]
		local op
		
		if (string_byte(o, 1) == 45) then
			-- This is an option.
			if (string_byte(o, 2) == 45) then
				-- ...with a -- prefix.
				o = string_sub(o, 3)
				local fn = argmap[o]
				if not fn then
					unrecognisedarg("--"..o)
				end
				local op = arg[i+1]
				i = i + fn(op)
			else
				-- ...without a -- prefix.
				local od = string_sub(o, 2, 2)
				local fn = argmap[od]
				if not fn then
					unrecognisedarg("-"..od)
				end
				op = string_sub(o, 3)
				if (op == "") then
					op = arg[i+1]
					i = i + fn(op)
				else
					fn(op)
				end
			end
		else
			-- This is a target name.
			table_append(targets, o)
		end	
	end
	
	-- Option fallbacks.
	
	if (table_getn(input_files) == 0) then
		input_files = {"pmfile"}
	end
	
	if (table_getn(targets) == 0) then
		targets = {"default"}
	end
end

-- Load any input files.

for _, i in ipairs(input_files) do
	sandbox.include(i, unpack(arg))
end

-- Set up the intermediate cache.

if purge_intermediate_cache then
	create_intermediate_cache()
else
	load_intermediate_cache()
end

-- Build any targets.

for _, i in ipairs(targets) do
	local o = sandbox[i]
	if not o then
		usererror("don't know how to build '", i, "'")
	end
	if ((type(o) ~= "table") and not o.class) then
		usererror("'", i, "' doesn't seem to be a valid target")
	end

	xpcall(
		function()
			o:__build()
		end,
		function(e)
			message("rule engine execution error --- traceback follows:")
			traceback(e)
		end
	)
end

XXXXSTARTinterpreter
253583
#include <signal.h>
#include <sys/wait.h>
#include <stdarg.h>
#include <errno.h>
#include <stdio.h>
#include <locale.h>
#include <sys/types.h>
#include <sys/utsname.h>
#include <stddef.h>
#include <grp.h>
#include <time.h>
#include <assert.h>
#include <sys/stat.h>
#include <ctype.h>
#include <utime.h>
#include <setjmp.h>
#include <dirent.h>
#include <sys/times.h>
#include <pwd.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <fcntl.h>
#include <stdlib.h>
#line 1 "lapi.c"
#define lapi_c
#line 1 "lua.h"
#ifndef lua_h
#define lua_h
#define LUA_NUMBER int
#define LUA_NUMBER_SCAN "%d"
#define LUA_NUMBER_FMT "%d"
#define LUA_VERSION "Lua 5.0.2 (patched for Prime Mover)"
#define LUA_COPYRIGHT "Copyright (C) 1994-2004 Tecgraf, PUC-Rio"
#define LUA_AUTHORS "R. Ierusalimschy, L. H. de Figueiredo & W. Celes"
#define LUA_MULTRET (-1)
#define LUA_REGISTRYINDEX (-10000)
#define LUA_GLOBALSINDEX (-10001)
#define lua_upvalueindex(i) (LUA_GLOBALSINDEX-(i))
#define LUA_ERRRUN 1
#define LUA_ERRFILE 2
#define LUA_ERRSYNTAX 3
#define LUA_ERRMEM 4
#define LUA_ERRERR 5
typedef struct lua_State lua_State;typedef int(*lua_CFunction)(lua_State*L);
typedef const char*(*lua_Chunkreader)(lua_State*L,void*ud,size_t*sz);typedef 
int(*lua_Chunkwriter)(lua_State*L,const void*p,size_t sz,void*ud);
#define LUA_TNONE (-1)
#define LUA_TNIL 0
#define LUA_TBOOLEAN 1
#define LUA_TLIGHTUSERDATA 2
#define LUA_TNUMBER 3
#define LUA_TSTRING 4
#define LUA_TTABLE 5
#define LUA_TFUNCTION 6
#define LUA_TUSERDATA 7
#define LUA_TTHREAD 8
#define LUA_MINSTACK 20
#ifdef LUA_USER_H
#include LUA_USER_H
#endif
#ifndef LUA_NUMBER
typedef double lua_Number;
#else
typedef LUA_NUMBER lua_Number;
#endif
#ifndef LUA_API
#define LUA_API extern
#endif
LUA_API lua_State*lua_open(void);LUA_API void lua_close(lua_State*L);LUA_API 
lua_State*lua_newthread(lua_State*L);LUA_API lua_CFunction lua_atpanic(
lua_State*L,lua_CFunction panicf);LUA_API int lua_gettop(lua_State*L);LUA_API 
void lua_settop(lua_State*L,int idx);LUA_API void lua_pushvalue(lua_State*L,
int idx);LUA_API void lua_remove(lua_State*L,int idx);LUA_API void lua_insert(
lua_State*L,int idx);LUA_API void lua_replace(lua_State*L,int idx);LUA_API int
 lua_checkstack(lua_State*L,int sz);LUA_API void lua_xmove(lua_State*from,
lua_State*to,int n);LUA_API int lua_isnumber(lua_State*L,int idx);LUA_API int 
lua_isstring(lua_State*L,int idx);LUA_API int lua_iscfunction(lua_State*L,int 
idx);LUA_API int lua_isuserdata(lua_State*L,int idx);LUA_API int lua_type(
lua_State*L,int idx);LUA_API const char*lua_typename(lua_State*L,int tp);
LUA_API int lua_equal(lua_State*L,int idx1,int idx2);LUA_API int lua_rawequal(
lua_State*L,int idx1,int idx2);LUA_API int lua_lessthan(lua_State*L,int idx1,
int idx2);LUA_API lua_Number lua_tonumber(lua_State*L,int idx);LUA_API int 
lua_toboolean(lua_State*L,int idx);LUA_API const char*lua_tostring(lua_State*L
,int idx);LUA_API size_t lua_strlen(lua_State*L,int idx);LUA_API lua_CFunction
 lua_tocfunction(lua_State*L,int idx);LUA_API void*lua_touserdata(lua_State*L,
int idx);LUA_API lua_State*lua_tothread(lua_State*L,int idx);LUA_API const 
void*lua_topointer(lua_State*L,int idx);LUA_API void lua_pushnil(lua_State*L);
LUA_API void lua_pushnumber(lua_State*L,lua_Number n);LUA_API void 
lua_pushlstring(lua_State*L,const char*s,size_t l);LUA_API void lua_pushstring
(lua_State*L,const char*s);LUA_API const char*lua_pushvfstring(lua_State*L,
const char*fmt,va_list argp);LUA_API const char*lua_pushfstring(lua_State*L,
const char*fmt,...);LUA_API void lua_pushcclosure(lua_State*L,lua_CFunction fn
,int n);LUA_API void lua_pushboolean(lua_State*L,int b);LUA_API void 
lua_pushlightuserdata(lua_State*L,void*p);LUA_API void lua_gettable(lua_State*
L,int idx);LUA_API void lua_rawget(lua_State*L,int idx);LUA_API void 
lua_rawgeti(lua_State*L,int idx,int n);LUA_API void lua_newtable(lua_State*L);
LUA_API void*lua_newuserdata(lua_State*L,size_t sz);LUA_API int 
lua_getmetatable(lua_State*L,int objindex);LUA_API void lua_getfenv(lua_State*
L,int idx);LUA_API void lua_settable(lua_State*L,int idx);LUA_API void 
lua_rawset(lua_State*L,int idx);LUA_API void lua_rawseti(lua_State*L,int idx,
int n);LUA_API int lua_setmetatable(lua_State*L,int objindex);LUA_API int 
lua_setfenv(lua_State*L,int idx);LUA_API void lua_call(lua_State*L,int nargs,
int nresults);LUA_API int lua_pcall(lua_State*L,int nargs,int nresults,int 
errfunc);LUA_API int lua_cpcall(lua_State*L,lua_CFunction func,void*ud);
LUA_API int lua_load(lua_State*L,lua_Chunkreader reader,void*dt,const char*
chunkname);LUA_API int lua_dump(lua_State*L,lua_Chunkwriter writer,void*data);
LUA_API int lua_yield(lua_State*L,int nresults);LUA_API int lua_resume(
lua_State*L,int narg);LUA_API int lua_getgcthreshold(lua_State*L);LUA_API int 
lua_getgccount(lua_State*L);LUA_API void lua_setgcthreshold(lua_State*L,int 
newthreshold);LUA_API const char*lua_version(void);LUA_API int lua_error(
lua_State*L);LUA_API int lua_next(lua_State*L,int idx);LUA_API void lua_concat
(lua_State*L,int n);
#define lua_boxpointer(L,u) (*(void**)(lua_newuserdata(L,sizeof(void*)))=(u))
#define lua_unboxpointer(L,i) (*(void**)(lua_touserdata(L,i)))
#define lua_pop(L,n) lua_settop(L,-(n)-1)
#define lua_register(L,n,f) (lua_pushstring(L,n),lua_pushcfunction(L,f),\
lua_settable(L,LUA_GLOBALSINDEX))
#define lua_pushcfunction(L,f) lua_pushcclosure(L,f,0)
#define lua_isfunction(L,n) (lua_type(L,n)==LUA_TFUNCTION)
#define lua_istable(L,n) (lua_type(L,n)==LUA_TTABLE)
#define lua_islightuserdata(L,n) (lua_type(L,n)==LUA_TLIGHTUSERDATA)
#define lua_isnil(L,n) (lua_type(L,n)==LUA_TNIL)
#define lua_isboolean(L,n) (lua_type(L,n)==LUA_TBOOLEAN)
#define lua_isnone(L,n) (lua_type(L,n)==LUA_TNONE)
#define lua_isnoneornil(L, n)(lua_type(L,n)<=0)
#define lua_pushliteral(L, s)lua_pushlstring(L,""s,(sizeof(s)/sizeof(char))-1)
LUA_API int lua_pushupvalues(lua_State*L);
#define lua_getregistry(L) lua_pushvalue(L,LUA_REGISTRYINDEX)
#define lua_setglobal(L,s) (lua_pushstring(L,s),lua_insert(L,-2),lua_settable(\
L,LUA_GLOBALSINDEX))
#define lua_getglobal(L,s) (lua_pushstring(L,s),lua_gettable(L,\
LUA_GLOBALSINDEX))
#define LUA_NOREF (-2)
#define LUA_REFNIL (-1)
#define lua_ref(L,lock) ((lock)?luaL_ref(L,LUA_REGISTRYINDEX):(lua_pushstring(\
L,"unlocked references are obsolete"),lua_error(L),0))
#define lua_unref(L,ref) luaL_unref(L,LUA_REGISTRYINDEX,(ref))
#define lua_getref(L,ref) lua_rawgeti(L,LUA_REGISTRYINDEX,ref)
#ifndef LUA_NUMBER_SCAN
#define LUA_NUMBER_SCAN "%lf"
#endif
#ifndef LUA_NUMBER_FMT
#define LUA_NUMBER_FMT "%.14g"
#endif
#define LUA_HOOKCALL 0
#define LUA_HOOKRET 1
#define LUA_HOOKLINE 2
#define LUA_HOOKCOUNT 3
#define LUA_HOOKTAILRET 4
#define LUA_MASKCALL (1<<LUA_HOOKCALL)
#define LUA_MASKRET (1<<LUA_HOOKRET)
#define LUA_MASKLINE (1<<LUA_HOOKLINE)
#define LUA_MASKCOUNT (1<<LUA_HOOKCOUNT)
typedef struct lua_Debug lua_Debug;typedef void(*lua_Hook)(lua_State*L,
lua_Debug*ar);LUA_API int lua_getstack(lua_State*L,int level,lua_Debug*ar);
LUA_API int lua_getinfo(lua_State*L,const char*what,lua_Debug*ar);LUA_API 
const char*lua_getlocal(lua_State*L,const lua_Debug*ar,int n);LUA_API const 
char*lua_setlocal(lua_State*L,const lua_Debug*ar,int n);LUA_API const char*
lua_getupvalue(lua_State*L,int funcindex,int n);LUA_API const char*
lua_setupvalue(lua_State*L,int funcindex,int n);LUA_API int lua_sethook(
lua_State*L,lua_Hook func,int mask,int count);LUA_API lua_Hook lua_gethook(
lua_State*L);LUA_API int lua_gethookmask(lua_State*L);LUA_API int 
lua_gethookcount(lua_State*L);
#define LUA_IDSIZE 60
struct lua_Debug{int event;const char*name;const char*namewhat;const char*what
;const char*source;int currentline;int nups;int linedefined;char short_src[
LUA_IDSIZE];int i_ci;};
#endif
#line 14 "lapi.c"
#line 1 "lapi.h"
#ifndef lapi_h
#define lapi_h
#line 1 "lobject.h"
#ifndef lobject_h
#define lobject_h
#line 1 "llimits.h"
#ifndef llimits_h
#define llimits_h
#ifndef BITS_INT
#if INT_MAX-20 <32760
#define BITS_INT 16
#else
#if INT_MAX >2147483640L
#define BITS_INT 32
#else
#error "you must define BITS_INT with number of bits in an integer"
#endif
#endif
#endif
typedef unsigned int lu_hash;typedef int ls_hash;typedef unsigned long lu_mem;
#define MAX_LUMEM ULONG_MAX
typedef long ls_nstr;typedef unsigned char lu_byte;
#define MAX_SIZET ((size_t)(~(size_t)0)-2)
#define MAX_INT (INT_MAX-2)
#define IntPoint(p) ((lu_hash)(p))
#ifndef LUSER_ALIGNMENT_T
typedef union{double u;void*s;long l;}L_Umaxalign;
#else
typedef LUSER_ALIGNMENT_T L_Umaxalign;
#endif
#ifndef LUA_UACNUMBER
typedef double l_uacNumber;
#else
typedef LUA_UACNUMBER l_uacNumber;
#endif
#ifndef lua_assert
#define lua_assert(c) 
#endif
#ifndef check_exp
#define check_exp(c,e) (e)
#endif
#ifndef UNUSED
#define UNUSED(x) ((void)(x))
#endif
#ifndef cast
#define cast(t, exp)((t)(exp))
#endif
typedef unsigned long Instruction;
#ifndef LUA_MAXCALLS
#define LUA_MAXCALLS 4096
#endif
#ifndef LUA_MAXCCALLS
#define LUA_MAXCCALLS 200
#endif
#ifndef LUA_MAXCSTACK
#define LUA_MAXCSTACK 2048
#endif
#define MAXSTACK 250
#ifndef MAXVARS
#define MAXVARS 200
#endif
#ifndef MAXUPVALUES
#define MAXUPVALUES 32
#endif
#ifndef MAXPARAMS
#define MAXPARAMS 100
#endif
#ifndef MINSTRTABSIZE
#define MINSTRTABSIZE 32
#endif
#ifndef LUA_MINBUFFER
#define LUA_MINBUFFER 32
#endif
#ifndef LUA_MAXPARSERLEVEL
#define LUA_MAXPARSERLEVEL 200
#endif
#endif
#line 12 "lobject.h"
#define NUM_TAGS LUA_TTHREAD
#define LUA_TPROTO (NUM_TAGS+1)
#define LUA_TUPVAL (NUM_TAGS+2)
typedef union GCObject GCObject;
#define CommonHeader GCObject*next;lu_byte tt;lu_byte marked
typedef struct GCheader{CommonHeader;}GCheader;typedef union{GCObject*gc;void*
p;lua_Number n;int b;}Value;typedef struct lua_TObject{int tt;Value value;}
TObject;
#define ttisnil(o) (ttype(o)==LUA_TNIL)
#define ttisnumber(o) (ttype(o)==LUA_TNUMBER)
#define ttisstring(o) (ttype(o)==LUA_TSTRING)
#define ttistable(o) (ttype(o)==LUA_TTABLE)
#define ttisfunction(o) (ttype(o)==LUA_TFUNCTION)
#define ttisboolean(o) (ttype(o)==LUA_TBOOLEAN)
#define ttisuserdata(o) (ttype(o)==LUA_TUSERDATA)
#define ttisthread(o) (ttype(o)==LUA_TTHREAD)
#define ttislightuserdata(o) (ttype(o)==LUA_TLIGHTUSERDATA)
#define ttype(o) ((o)->tt)
#define gcvalue(o) check_exp(iscollectable(o),(o)->value.gc)
#define pvalue(o) check_exp(ttislightuserdata(o),(o)->value.p)
#define nvalue(o) check_exp(ttisnumber(o),(o)->value.n)
#define tsvalue(o) check_exp(ttisstring(o),&(o)->value.gc->ts)
#define uvalue(o) check_exp(ttisuserdata(o),&(o)->value.gc->u)
#define clvalue(o) check_exp(ttisfunction(o),&(o)->value.gc->cl)
#define hvalue(o) check_exp(ttistable(o),&(o)->value.gc->h)
#define bvalue(o) check_exp(ttisboolean(o),(o)->value.b)
#define thvalue(o) check_exp(ttisthread(o),&(o)->value.gc->th)
#define l_isfalse(o) (ttisnil(o)||(ttisboolean(o)&&bvalue(o)==0))
#define setnvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TNUMBER;i_o->value.n=(\
x);}
#define chgnvalue(obj,x) check_exp(ttype(obj)==LUA_TNUMBER,(obj)->value.n=(x))
#define setpvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TLIGHTUSERDATA;i_o->\
value.p=(x);}
#define setbvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TBOOLEAN;i_o->value.b=\
(x);}
#define setsvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TSTRING;i_o->value.gc=\
cast(GCObject*,(x));lua_assert(i_o->value.gc->gch.tt==LUA_TSTRING);}
#define setuvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TUSERDATA;i_o->value.\
gc=cast(GCObject*,(x));lua_assert(i_o->value.gc->gch.tt==LUA_TUSERDATA);}
#define setthvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TTHREAD;i_o->value.gc\
=cast(GCObject*,(x));lua_assert(i_o->value.gc->gch.tt==LUA_TTHREAD);}
#define setclvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TFUNCTION;i_o->value.\
gc=cast(GCObject*,(x));lua_assert(i_o->value.gc->gch.tt==LUA_TFUNCTION);}
#define sethvalue(obj,x) {TObject*i_o=(obj);i_o->tt=LUA_TTABLE;i_o->value.gc=\
cast(GCObject*,(x));lua_assert(i_o->value.gc->gch.tt==LUA_TTABLE);}
#define setnilvalue(obj) ((obj)->tt=LUA_TNIL)
#define checkconsistency(obj) lua_assert(!iscollectable(obj)||(ttype(obj)==(\
obj)->value.gc->gch.tt))
#define setobj(obj1,obj2) {const TObject*o2=(obj2);TObject*o1=(obj1);\
checkconsistency(o2);o1->tt=o2->tt;o1->value=o2->value;}
#define setobjs2s setobj
#define setobj2s setobj
#define setsvalue2s setsvalue
#define setobjt2t setobj
#define setobj2t setobj
#define setobj2n setobj
#define setsvalue2n setsvalue
#define setttype(obj, tt)(ttype(obj)=(tt))
#define iscollectable(o) (ttype(o)>=LUA_TSTRING)
typedef TObject*StkId;typedef union TString{L_Umaxalign dummy;struct{
CommonHeader;lu_byte reserved;lu_hash hash;size_t len;}tsv;}TString;
#define getstr(ts) cast(const char*,(ts)+1)
#define svalue(o) getstr(tsvalue(o))
typedef union Udata{L_Umaxalign dummy;struct{CommonHeader;struct Table*
metatable;size_t len;}uv;}Udata;typedef struct Proto{CommonHeader;TObject*k;
Instruction*code;struct Proto**p;int*lineinfo;struct LocVar*locvars;TString**
upvalues;TString*source;int sizeupvalues;int sizek;int sizecode;int 
sizelineinfo;int sizep;int sizelocvars;int lineDefined;GCObject*gclist;lu_byte
 nups;lu_byte numparams;lu_byte is_vararg;lu_byte maxstacksize;}Proto;typedef 
struct LocVar{TString*varname;int startpc;int endpc;}LocVar;typedef struct 
UpVal{CommonHeader;TObject*v;TObject value;}UpVal;
#define ClosureHeader CommonHeader;lu_byte isC;lu_byte nupvalues;GCObject*\
gclist
typedef struct CClosure{ClosureHeader;lua_CFunction f;TObject upvalue[1];}
CClosure;typedef struct LClosure{ClosureHeader;struct Proto*p;TObject g;UpVal*
upvals[1];}LClosure;typedef union Closure{CClosure c;LClosure l;}Closure;
#define iscfunction(o) (ttype(o)==LUA_TFUNCTION&&clvalue(o)->c.isC)
#define isLfunction(o) (ttype(o)==LUA_TFUNCTION&&!clvalue(o)->c.isC)
typedef struct Node{TObject i_key;TObject i_val;struct Node*next;}Node;typedef
 struct Table{CommonHeader;lu_byte flags;lu_byte lsizenode;struct Table*
metatable;TObject*array;Node*node;Node*firstfree;GCObject*gclist;int sizearray
;}Table;
#define lmod(s,size) check_exp((size&(size-1))==0,(cast(int,(s)&((size)-1))))
#define twoto(x) (1<<(x))
#define sizenode(t) (twoto((t)->lsizenode))
extern const TObject luaO_nilobject;int luaO_log2(unsigned int x);int 
luaO_int2fb(unsigned int x);
#define fb2int(x) (((x)&7)<<((x)>>3))
int luaO_rawequalObj(const TObject*t1,const TObject*t2);int luaO_str2d(const 
char*s,lua_Number*result);const char*luaO_pushvfstring(lua_State*L,const char*
fmt,va_list argp);const char*luaO_pushfstring(lua_State*L,const char*fmt,...);
void luaO_chunkid(char*out,const char*source,int len);
#endif
#line 12 "lapi.h"
void luaA_pushobject(lua_State*L,const TObject*o);
#endif
#line 16 "lapi.c"
#line 1 "ldebug.h"
#ifndef ldebug_h
#define ldebug_h
#line 1 "lstate.h"
#ifndef lstate_h
#define lstate_h
#line 1 "ltm.h"
#ifndef ltm_h
#define ltm_h
typedef enum{TM_INDEX,TM_NEWINDEX,TM_GC,TM_MODE,TM_EQ,TM_ADD,TM_SUB,TM_MUL,
TM_DIV,TM_POW,TM_UNM,TM_LT,TM_LE,TM_CONCAT,TM_CALL,TM_N}TMS;
#define gfasttm(g,et,e) (((et)->flags&(1u<<(e)))?NULL:luaT_gettm(et,e,(g)->\
tmname[e]))
#define fasttm(l,et,e) gfasttm(G(l),et,e)
const TObject*luaT_gettm(Table*events,TMS event,TString*ename);const TObject*
luaT_gettmbyobj(lua_State*L,const TObject*o,TMS event);void luaT_init(
lua_State*L);extern const char*const luaT_typenames[];
#endif
#line 14 "lstate.h"
#line 1 "lzio.h"
#ifndef lzio_h
#define lzio_h
#define EOZ (-1)
typedef struct Zio ZIO;
#define char2int(c) cast(int,cast(unsigned char,(c)))
#define zgetc(z) (((z)->n--)>0?char2int(*(z)->p++):luaZ_fill(z))
#define zname(z) ((z)->name)
void luaZ_init(ZIO*z,lua_Chunkreader reader,void*data,const char*name);size_t 
luaZ_read(ZIO*z,void*b,size_t n);int luaZ_lookahead(ZIO*z);typedef struct 
Mbuffer{char*buffer;size_t buffsize;}Mbuffer;char*luaZ_openspace(lua_State*L,
Mbuffer*buff,size_t n);
#define luaZ_initbuffer(L, buff)((buff)->buffer=NULL,(buff)->buffsize=0)
#define luaZ_sizebuffer(buff) ((buff)->buffsize)
#define luaZ_buffer(buff) ((buff)->buffer)
#define luaZ_resizebuffer(L, buff,size)(luaM_reallocvector(L,(buff)->buffer,(\
buff)->buffsize,size,char),(buff)->buffsize=size)
#define luaZ_freebuffer(L, buff)luaZ_resizebuffer(L,buff,0)
struct Zio{size_t n;const char*p;lua_Chunkreader reader;void*data;const char*
name;};int luaZ_fill(ZIO*z);
#endif
#line 15 "lstate.h"
#ifndef lua_lock
#define lua_lock(L) ((void)0)
#endif
#ifndef lua_unlock
#define lua_unlock(L) ((void)0)
#endif
#ifndef lua_userstateopen
#define lua_userstateopen(l)
#endif
struct lua_longjmp;
#define defaultmeta(L) (&G(L)->_defaultmeta)
#define gt(L) (&L->_gt)
#define registry(L) (&G(L)->_registry)
#define EXTRA_STACK 5
#define BASIC_CI_SIZE 8
#define BASIC_STACK_SIZE (2*LUA_MINSTACK)
typedef struct stringtable{GCObject**hash;ls_nstr nuse;int size;}stringtable;
typedef struct CallInfo{StkId base;StkId top;int state;union{struct{const 
Instruction*savedpc;const Instruction**pc;int tailcalls;}l;struct{int dummy;}c
;}u;}CallInfo;
#define CI_C (1<<0)
#define CI_HASFRAME (1<<1)
#define CI_CALLING (1<<2)
#define CI_SAVEDPC (1<<3)
#define CI_YIELD (1<<4)
#define ci_func(ci) (clvalue((ci)->base-1))
typedef struct global_State{stringtable strt;GCObject*rootgc;GCObject*
rootudata;GCObject*tmudata;Mbuffer buff;lu_mem GCthreshold;lu_mem nblocks;
lua_CFunction panic;TObject _registry;TObject _defaultmeta;struct lua_State*
mainthread;Node dummynode[1];TString*tmname[TM_N];}global_State;struct 
lua_State{CommonHeader;StkId top;StkId base;global_State*l_G;CallInfo*ci;StkId
 stack_last;StkId stack;int stacksize;CallInfo*end_ci;CallInfo*base_ci;
unsigned short size_ci;unsigned short nCcalls;lu_byte hookmask;lu_byte 
allowhook;lu_byte hookinit;int basehookcount;int hookcount;lua_Hook hook;
TObject _gt;GCObject*openupval;GCObject*gclist;struct lua_longjmp*errorJmp;
ptrdiff_t errfunc;};
#define G(L) (L->l_G)
union GCObject{GCheader gch;union TString ts;union Udata u;union Closure cl;
struct Table h;struct Proto p;struct UpVal uv;struct lua_State th;};
#define gcotots(o) check_exp((o)->gch.tt==LUA_TSTRING,&((o)->ts))
#define gcotou(o) check_exp((o)->gch.tt==LUA_TUSERDATA,&((o)->u))
#define gcotocl(o) check_exp((o)->gch.tt==LUA_TFUNCTION,&((o)->cl))
#define gcotoh(o) check_exp((o)->gch.tt==LUA_TTABLE,&((o)->h))
#define gcotop(o) check_exp((o)->gch.tt==LUA_TPROTO,&((o)->p))
#define gcotouv(o) check_exp((o)->gch.tt==LUA_TUPVAL,&((o)->uv))
#define ngcotouv(o) check_exp((o)==NULL||(o)->gch.tt==LUA_TUPVAL,&((o)->uv))
#define gcototh(o) check_exp((o)->gch.tt==LUA_TTHREAD,&((o)->th))
#define valtogco(v) (cast(GCObject*,(v)))
lua_State*luaE_newthread(lua_State*L);void luaE_freethread(lua_State*L,
lua_State*L1);
#endif
#line 12 "ldebug.h"
#define pcRel(pc, p)(cast(int,(pc)-(p)->code)-1)
#define getline(f,pc) (((f)->lineinfo)?(f)->lineinfo[pc]:0)
#define resethookcount(L) (L->hookcount=L->basehookcount)
void luaG_inithooks(lua_State*L);void luaG_typeerror(lua_State*L,const TObject
*o,const char*opname);void luaG_concaterror(lua_State*L,StkId p1,StkId p2);
void luaG_aritherror(lua_State*L,const TObject*p1,const TObject*p2);int 
luaG_ordererror(lua_State*L,const TObject*p1,const TObject*p2);void 
luaG_runerror(lua_State*L,const char*fmt,...);void luaG_errormsg(lua_State*L);
int luaG_checkcode(const Proto*pt);
#endif
#line 17 "lapi.c"
#line 1 "ldo.h"
#ifndef ldo_h
#define ldo_h
#ifndef HARDSTACKTESTS
#define condhardstacktests(x) {}
#else
#define condhardstacktests(x) x
#endif
#define luaD_checkstack(L,n) if((char*)L->stack_last-(char*)L->top<=(n)*(int)\
sizeof(TObject))luaD_growstack(L,n);else condhardstacktests(luaD_reallocstack(\
L,L->stacksize));
#define incr_top(L) {luaD_checkstack(L,1);L->top++;}
#define savestack(L,p) ((char*)(p)-(char*)L->stack)
#define restorestack(L,n) ((TObject*)((char*)L->stack+(n)))
#define saveci(L,p) ((char*)(p)-(char*)L->base_ci)
#define restoreci(L,n) ((CallInfo*)((char*)L->base_ci+(n)))
typedef void(*Pfunc)(lua_State*L,void*ud);void luaD_resetprotection(lua_State*
L);int luaD_protectedparser(lua_State*L,ZIO*z,int bin);void luaD_callhook(
lua_State*L,int event,int line);StkId luaD_precall(lua_State*L,StkId func);
void luaD_call(lua_State*L,StkId func,int nResults);int luaD_pcall(lua_State*L
,Pfunc func,void*u,ptrdiff_t oldtop,ptrdiff_t ef);void luaD_poscall(lua_State*
L,int wanted,StkId firstResult);void luaD_reallocCI(lua_State*L,int newsize);
void luaD_reallocstack(lua_State*L,int newsize);void luaD_growstack(lua_State*
L,int n);void luaD_throw(lua_State*L,int errcode);int luaD_rawrunprotected(
lua_State*L,Pfunc f,void*ud);
#endif
#line 18 "lapi.c"
#line 1 "lfunc.h"
#ifndef lfunc_h
#define lfunc_h
Proto*luaF_newproto(lua_State*L);Closure*luaF_newCclosure(lua_State*L,int 
nelems);Closure*luaF_newLclosure(lua_State*L,int nelems,TObject*e);UpVal*
luaF_findupval(lua_State*L,StkId level);void luaF_close(lua_State*L,StkId 
level);void luaF_freeproto(lua_State*L,Proto*f);void luaF_freeclosure(
lua_State*L,Closure*c);const char*luaF_getlocalname(const Proto*func,int 
local_number,int pc);
#endif
#line 19 "lapi.c"
#line 1 "lgc.h"
#ifndef lgc_h
#define lgc_h
#define luaC_checkGC(L) {lua_assert(!(L->ci->state&CI_CALLING));if(G(L)->\
nblocks>=G(L)->GCthreshold)luaC_collectgarbage(L);}
size_t luaC_separateudata(lua_State*L);void luaC_callGCTM(lua_State*L);void 
luaC_sweep(lua_State*L,int all);void luaC_collectgarbage(lua_State*L);void 
luaC_link(lua_State*L,GCObject*o,lu_byte tt);
#endif
#line 20 "lapi.c"
#line 1 "lmem.h"
#ifndef lmem_h
#define lmem_h
#define MEMERRMSG "not enough memory"
void*luaM_realloc(lua_State*L,void*oldblock,lu_mem oldsize,lu_mem size);void*
luaM_growaux(lua_State*L,void*block,int*size,int size_elem,int limit,const 
char*errormsg);
#define luaM_free(L, b,s)luaM_realloc(L,(b),(s),0)
#define luaM_freelem(L, b)luaM_realloc(L,(b),sizeof(*(b)),0)
#define luaM_freearray(L, b,n,t)luaM_realloc(L,(b),cast(lu_mem,n)*cast(lu_mem,\
sizeof(t)),0)
#define luaM_malloc(L, t)luaM_realloc(L,NULL,0,(t))
#define luaM_new(L, t)cast(t*,luaM_malloc(L,sizeof(t)))
#define luaM_newvector(L, n,t)cast(t*,luaM_malloc(L,cast(lu_mem,n)*cast(lu_mem\
,sizeof(t))))
#define luaM_growvector(L,v,nelems,size,t,limit,e) if(((nelems)+1)>(size))((v)\
=cast(t*,luaM_growaux(L,v,&(size),sizeof(t),limit,e)))
#define luaM_reallocvector(L, v,oldn,n,t)((v)=cast(t*,luaM_realloc(L,v,cast(\
lu_mem,oldn)*cast(lu_mem,sizeof(t)),cast(lu_mem,n)*cast(lu_mem,sizeof(t)))))
#endif
#line 21 "lapi.c"
#line 1 "lstring.h"
#ifndef lstring_h
#define lstring_h
#define sizestring(l) (cast(lu_mem,sizeof(union TString))+(cast(lu_mem,l)+1)*\
sizeof(char))
#define sizeudata(l) (cast(lu_mem,sizeof(union Udata))+(l))
#define luaS_new(L, s)(luaS_newlstr(L,s,strlen(s)))
#define luaS_newliteral(L, s)(luaS_newlstr(L,""s,(sizeof(s)/sizeof(char))-1))
#define luaS_fix(s) ((s)->tsv.marked|=(1<<4))
void luaS_resize(lua_State*L,int newsize);Udata*luaS_newudata(lua_State*L,
size_t s);void luaS_freeall(lua_State*L);TString*luaS_newlstr(lua_State*L,
const char*str,size_t l);
#endif
#line 24 "lapi.c"
#line 1 "ltable.h"
#ifndef ltable_h
#define ltable_h
#define gnode(t,i) (&(t)->node[i])
#define gkey(n) (&(n)->i_key)
#define gval(n) (&(n)->i_val)
const TObject*luaH_getnum(Table*t,int key);TObject*luaH_setnum(lua_State*L,
Table*t,int key);const TObject*luaH_getstr(Table*t,TString*key);const TObject*
luaH_get(Table*t,const TObject*key);TObject*luaH_set(lua_State*L,Table*t,const
 TObject*key);Table*luaH_new(lua_State*L,int narray,int lnhash);void luaH_free
(lua_State*L,Table*t);int luaH_next(lua_State*L,Table*t,StkId key);Node*
luaH_mainposition(const Table*t,const TObject*key);
#endif
#line 25 "lapi.c"
#line 1 "lundump.h"
#ifndef lundump_h
#define lundump_h
Proto*luaU_undump(lua_State*L,ZIO*Z,Mbuffer*buff);int luaU_endianness(void);
void luaU_dump(lua_State*L,const Proto*Main,lua_Chunkwriter w,void*data);void 
luaU_print(const Proto*Main);
#define LUA_SIGNATURE "\033Lua"
#define VERSION 0x50
#define VERSION0 0x50
#define TEST_NUMBER ((lua_Number)3.14159265358979323846E7)
#endif
#line 27 "lapi.c"
#line 1 "lvm.h"
#ifndef lvm_h
#define lvm_h
#define tostring(L,o) ((ttype(o)==LUA_TSTRING)||(luaV_tostring(L,o)))
#define tonumber(o,n) (ttype(o)==LUA_TNUMBER||(((o)=luaV_tonumber(o,n))!=NULL)\
)
#define equalobj(L,o1,o2) (ttype(o1)==ttype(o2)&&luaV_equalval(L,o1,o2))
int luaV_lessthan(lua_State*L,const TObject*l,const TObject*r);int 
luaV_equalval(lua_State*L,const TObject*t1,const TObject*t2);const TObject*
luaV_tonumber(const TObject*obj,TObject*n);int luaV_tostring(lua_State*L,StkId
 obj);const TObject*luaV_gettable(lua_State*L,const TObject*t,TObject*key,int 
loop);void luaV_settable(lua_State*L,const TObject*t,TObject*key,StkId val);
StkId luaV_execute(lua_State*L);void luaV_concat(lua_State*L,int total,int 
last);
#endif
#line 28 "lapi.c"
const char lua_ident[]="$Lua: "LUA_VERSION" "LUA_COPYRIGHT" $\n""$Authors: "
LUA_AUTHORS" $\n""$URL: www.lua.org $\n";
#ifndef api_check
#define api_check(L, o)
#endif
#define api_checknelems(L, n)api_check(L,(n)<=(L->top-L->base))
#define api_incr_top(L) {api_check(L,L->top<L->ci->top);L->top++;}
static TObject*negindex(lua_State*L,int idx){if(idx>LUA_REGISTRYINDEX){
api_check(L,idx!=0&&-idx<=L->top-L->base);return L->top+idx;}else switch(idx){
case LUA_REGISTRYINDEX:return registry(L);case LUA_GLOBALSINDEX:return gt(L);
default:{TObject*func=(L->base-1);idx=LUA_GLOBALSINDEX-idx;lua_assert(
iscfunction(func));return(idx<=clvalue(func)->c.nupvalues)?&clvalue(func)->c.
upvalue[idx-1]:NULL;}}}static TObject*luaA_index(lua_State*L,int idx){if(idx>0
){api_check(L,idx<=L->top-L->base);return L->base+idx-1;}else{TObject*o=
negindex(L,idx);api_check(L,o!=NULL);return o;}}static TObject*
luaA_indexAcceptable(lua_State*L,int idx){if(idx>0){TObject*o=L->base+(idx-1);
api_check(L,idx<=L->stack_last-L->base);if(o>=L->top)return NULL;else return o
;}else return negindex(L,idx);}void luaA_pushobject(lua_State*L,const TObject*
o){setobj2s(L->top,o);incr_top(L);}LUA_API int lua_checkstack(lua_State*L,int 
size){int res;lua_lock(L);if((L->top-L->base+size)>LUA_MAXCSTACK)res=0;else{
luaD_checkstack(L,size);if(L->ci->top<L->top+size)L->ci->top=L->top+size;res=1
;}lua_unlock(L);return res;}LUA_API void lua_xmove(lua_State*from,lua_State*to
,int n){int i;lua_lock(to);api_checknelems(from,n);from->top-=n;for(i=0;i<n;i
++){setobj2s(to->top,from->top+i);api_incr_top(to);}lua_unlock(to);}LUA_API 
lua_CFunction lua_atpanic(lua_State*L,lua_CFunction panicf){lua_CFunction old;
lua_lock(L);old=G(L)->panic;G(L)->panic=panicf;lua_unlock(L);return old;}
LUA_API lua_State*lua_newthread(lua_State*L){lua_State*L1;lua_lock(L);
luaC_checkGC(L);L1=luaE_newthread(L);setthvalue(L->top,L1);api_incr_top(L);
lua_unlock(L);lua_userstateopen(L1);return L1;}LUA_API int lua_gettop(
lua_State*L){return(L->top-L->base);}LUA_API void lua_settop(lua_State*L,int 
idx){lua_lock(L);if(idx>=0){api_check(L,idx<=L->stack_last-L->base);while(L->
top<L->base+idx)setnilvalue(L->top++);L->top=L->base+idx;}else{api_check(L,-(
idx+1)<=(L->top-L->base));L->top+=idx+1;}lua_unlock(L);}LUA_API void 
lua_remove(lua_State*L,int idx){StkId p;lua_lock(L);p=luaA_index(L,idx);while(
++p<L->top)setobjs2s(p-1,p);L->top--;lua_unlock(L);}LUA_API void lua_insert(
lua_State*L,int idx){StkId p;StkId q;lua_lock(L);p=luaA_index(L,idx);for(q=L->
top;q>p;q--)setobjs2s(q,q-1);setobjs2s(p,L->top);lua_unlock(L);}LUA_API void 
lua_replace(lua_State*L,int idx){lua_lock(L);api_checknelems(L,1);setobj(
luaA_index(L,idx),L->top-1);L->top--;lua_unlock(L);}LUA_API void lua_pushvalue
(lua_State*L,int idx){lua_lock(L);setobj2s(L->top,luaA_index(L,idx));
api_incr_top(L);lua_unlock(L);}LUA_API int lua_type(lua_State*L,int idx){StkId
 o=luaA_indexAcceptable(L,idx);return(o==NULL)?LUA_TNONE:ttype(o);}LUA_API 
const char*lua_typename(lua_State*L,int t){UNUSED(L);return(t==LUA_TNONE)?
"no value":luaT_typenames[t];}LUA_API int lua_iscfunction(lua_State*L,int idx)
{StkId o=luaA_indexAcceptable(L,idx);return(o==NULL)?0:iscfunction(o);}LUA_API
 int lua_isnumber(lua_State*L,int idx){TObject n;const TObject*o=
luaA_indexAcceptable(L,idx);return(o!=NULL&&tonumber(o,&n));}LUA_API int 
lua_isstring(lua_State*L,int idx){int t=lua_type(L,idx);return(t==LUA_TSTRING
||t==LUA_TNUMBER);}LUA_API int lua_isuserdata(lua_State*L,int idx){const 
TObject*o=luaA_indexAcceptable(L,idx);return(o!=NULL&&(ttisuserdata(o)||
ttislightuserdata(o)));}LUA_API int lua_rawequal(lua_State*L,int index1,int 
index2){StkId o1=luaA_indexAcceptable(L,index1);StkId o2=luaA_indexAcceptable(
L,index2);return(o1==NULL||o2==NULL)?0:luaO_rawequalObj(o1,o2);}LUA_API int 
lua_equal(lua_State*L,int index1,int index2){StkId o1,o2;int i;lua_lock(L);o1=
luaA_indexAcceptable(L,index1);o2=luaA_indexAcceptable(L,index2);i=(o1==NULL||
o2==NULL)?0:equalobj(L,o1,o2);lua_unlock(L);return i;}LUA_API int lua_lessthan
(lua_State*L,int index1,int index2){StkId o1,o2;int i;lua_lock(L);o1=
luaA_indexAcceptable(L,index1);o2=luaA_indexAcceptable(L,index2);i=(o1==NULL||
o2==NULL)?0:luaV_lessthan(L,o1,o2);lua_unlock(L);return i;}LUA_API lua_Number 
lua_tonumber(lua_State*L,int idx){TObject n;const TObject*o=
luaA_indexAcceptable(L,idx);if(o!=NULL&&tonumber(o,&n))return nvalue(o);else 
return 0;}LUA_API int lua_toboolean(lua_State*L,int idx){const TObject*o=
luaA_indexAcceptable(L,idx);return(o!=NULL)&&!l_isfalse(o);}LUA_API const char
*lua_tostring(lua_State*L,int idx){StkId o=luaA_indexAcceptable(L,idx);if(o==
NULL)return NULL;else if(ttisstring(o))return svalue(o);else{const char*s;
lua_lock(L);s=(luaV_tostring(L,o)?svalue(o):NULL);luaC_checkGC(L);lua_unlock(L
);return s;}}LUA_API size_t lua_strlen(lua_State*L,int idx){StkId o=
luaA_indexAcceptable(L,idx);if(o==NULL)return 0;else if(ttisstring(o))return 
tsvalue(o)->tsv.len;else{size_t l;lua_lock(L);l=(luaV_tostring(L,o)?tsvalue(o)
->tsv.len:0);lua_unlock(L);return l;}}LUA_API lua_CFunction lua_tocfunction(
lua_State*L,int idx){StkId o=luaA_indexAcceptable(L,idx);return(o==NULL||!
iscfunction(o))?NULL:clvalue(o)->c.f;}LUA_API void*lua_touserdata(lua_State*L,
int idx){StkId o=luaA_indexAcceptable(L,idx);if(o==NULL)return NULL;switch(
ttype(o)){case LUA_TUSERDATA:return(uvalue(o)+1);case LUA_TLIGHTUSERDATA:
return pvalue(o);default:return NULL;}}LUA_API lua_State*lua_tothread(
lua_State*L,int idx){StkId o=luaA_indexAcceptable(L,idx);return(o==NULL||!
ttisthread(o))?NULL:thvalue(o);}LUA_API const void*lua_topointer(lua_State*L,
int idx){StkId o=luaA_indexAcceptable(L,idx);if(o==NULL)return NULL;else{
switch(ttype(o)){case LUA_TTABLE:return hvalue(o);case LUA_TFUNCTION:return 
clvalue(o);case LUA_TTHREAD:return thvalue(o);case LUA_TUSERDATA:case 
LUA_TLIGHTUSERDATA:return lua_touserdata(L,idx);default:return NULL;}}}LUA_API
 void lua_pushnil(lua_State*L){lua_lock(L);setnilvalue(L->top);api_incr_top(L)
;lua_unlock(L);}LUA_API void lua_pushnumber(lua_State*L,lua_Number n){lua_lock
(L);setnvalue(L->top,n);api_incr_top(L);lua_unlock(L);}LUA_API void 
lua_pushlstring(lua_State*L,const char*s,size_t len){lua_lock(L);luaC_checkGC(
L);setsvalue2s(L->top,luaS_newlstr(L,s,len));api_incr_top(L);lua_unlock(L);}
LUA_API void lua_pushstring(lua_State*L,const char*s){if(s==NULL)lua_pushnil(L
);else lua_pushlstring(L,s,strlen(s));}LUA_API const char*lua_pushvfstring(
lua_State*L,const char*fmt,va_list argp){const char*ret;lua_lock(L);
luaC_checkGC(L);ret=luaO_pushvfstring(L,fmt,argp);lua_unlock(L);return ret;}
LUA_API const char*lua_pushfstring(lua_State*L,const char*fmt,...){const char*
ret;va_list argp;lua_lock(L);luaC_checkGC(L);va_start(argp,fmt);ret=
luaO_pushvfstring(L,fmt,argp);va_end(argp);lua_unlock(L);return ret;}LUA_API 
void lua_pushcclosure(lua_State*L,lua_CFunction fn,int n){Closure*cl;lua_lock(
L);luaC_checkGC(L);api_checknelems(L,n);cl=luaF_newCclosure(L,n);cl->c.f=fn;L
->top-=n;while(n--)setobj2n(&cl->c.upvalue[n],L->top+n);setclvalue(L->top,cl);
api_incr_top(L);lua_unlock(L);}LUA_API void lua_pushboolean(lua_State*L,int b)
{lua_lock(L);setbvalue(L->top,(b!=0));api_incr_top(L);lua_unlock(L);}LUA_API 
void lua_pushlightuserdata(lua_State*L,void*p){lua_lock(L);setpvalue(L->top,p)
;api_incr_top(L);lua_unlock(L);}LUA_API void lua_gettable(lua_State*L,int idx)
{StkId t;lua_lock(L);t=luaA_index(L,idx);setobj2s(L->top-1,luaV_gettable(L,t,L
->top-1,0));lua_unlock(L);}LUA_API void lua_rawget(lua_State*L,int idx){StkId 
t;lua_lock(L);t=luaA_index(L,idx);api_check(L,ttistable(t));setobj2s(L->top-1,
luaH_get(hvalue(t),L->top-1));lua_unlock(L);}LUA_API void lua_rawgeti(
lua_State*L,int idx,int n){StkId o;lua_lock(L);o=luaA_index(L,idx);api_check(L
,ttistable(o));setobj2s(L->top,luaH_getnum(hvalue(o),n));api_incr_top(L);
lua_unlock(L);}LUA_API void lua_newtable(lua_State*L){lua_lock(L);luaC_checkGC
(L);sethvalue(L->top,luaH_new(L,0,0));api_incr_top(L);lua_unlock(L);}LUA_API 
int lua_getmetatable(lua_State*L,int objindex){const TObject*obj;Table*mt=NULL
;int res;lua_lock(L);obj=luaA_indexAcceptable(L,objindex);if(obj!=NULL){switch
(ttype(obj)){case LUA_TTABLE:mt=hvalue(obj)->metatable;break;case 
LUA_TUSERDATA:mt=uvalue(obj)->uv.metatable;break;}}if(mt==NULL||mt==hvalue(
defaultmeta(L)))res=0;else{sethvalue(L->top,mt);api_incr_top(L);res=1;}
lua_unlock(L);return res;}LUA_API void lua_getfenv(lua_State*L,int idx){StkId 
o;lua_lock(L);o=luaA_index(L,idx);setobj2s(L->top,isLfunction(o)?&clvalue(o)->
l.g:gt(L));api_incr_top(L);lua_unlock(L);}LUA_API void lua_settable(lua_State*
L,int idx){StkId t;lua_lock(L);api_checknelems(L,2);t=luaA_index(L,idx);
luaV_settable(L,t,L->top-2,L->top-1);L->top-=2;lua_unlock(L);}LUA_API void 
lua_rawset(lua_State*L,int idx){StkId t;lua_lock(L);api_checknelems(L,2);t=
luaA_index(L,idx);api_check(L,ttistable(t));setobj2t(luaH_set(L,hvalue(t),L->
top-2),L->top-1);L->top-=2;lua_unlock(L);}LUA_API void lua_rawseti(lua_State*L
,int idx,int n){StkId o;lua_lock(L);api_checknelems(L,1);o=luaA_index(L,idx);
api_check(L,ttistable(o));setobj2t(luaH_setnum(L,hvalue(o),n),L->top-1);L->top
--;lua_unlock(L);}LUA_API int lua_setmetatable(lua_State*L,int objindex){
TObject*obj,*mt;int res=1;lua_lock(L);api_checknelems(L,1);obj=luaA_index(L,
objindex);mt=(!ttisnil(L->top-1))?L->top-1:defaultmeta(L);api_check(L,
ttistable(mt));switch(ttype(obj)){case LUA_TTABLE:{hvalue(obj)->metatable=
hvalue(mt);break;}case LUA_TUSERDATA:{uvalue(obj)->uv.metatable=hvalue(mt);
break;}default:{res=0;break;}}L->top--;lua_unlock(L);return res;}LUA_API int 
lua_setfenv(lua_State*L,int idx){StkId o;int res=0;lua_lock(L);api_checknelems
(L,1);o=luaA_index(L,idx);L->top--;api_check(L,ttistable(L->top));if(
isLfunction(o)){res=1;clvalue(o)->l.g=*(L->top);}lua_unlock(L);return res;}
LUA_API void lua_call(lua_State*L,int nargs,int nresults){StkId func;lua_lock(
L);api_checknelems(L,nargs+1);func=L->top-(nargs+1);luaD_call(L,func,nresults)
;lua_unlock(L);}struct CallS{StkId func;int nresults;};static void f_call(
lua_State*L,void*ud){struct CallS*c=cast(struct CallS*,ud);luaD_call(L,c->func
,c->nresults);}LUA_API int lua_pcall(lua_State*L,int nargs,int nresults,int 
errfunc){struct CallS c;int status;ptrdiff_t func;lua_lock(L);func=(errfunc==0
)?0:savestack(L,luaA_index(L,errfunc));c.func=L->top-(nargs+1);c.nresults=
nresults;status=luaD_pcall(L,f_call,&c,savestack(L,c.func),func);lua_unlock(L)
;return status;}struct CCallS{lua_CFunction func;void*ud;};static void f_Ccall
(lua_State*L,void*ud){struct CCallS*c=cast(struct CCallS*,ud);Closure*cl;cl=
luaF_newCclosure(L,0);cl->c.f=c->func;setclvalue(L->top,cl);incr_top(L);
setpvalue(L->top,c->ud);incr_top(L);luaD_call(L,L->top-2,0);}LUA_API int 
lua_cpcall(lua_State*L,lua_CFunction func,void*ud){struct CCallS c;int status;
lua_lock(L);c.func=func;c.ud=ud;status=luaD_pcall(L,f_Ccall,&c,savestack(L,L->
top),0);lua_unlock(L);return status;}LUA_API int lua_load(lua_State*L,
lua_Chunkreader reader,void*data,const char*chunkname){ZIO z;int status;int c;
lua_lock(L);if(!chunkname)chunkname="?";luaZ_init(&z,reader,data,chunkname);c=
luaZ_lookahead(&z);status=luaD_protectedparser(L,&z,(c==LUA_SIGNATURE[0]));
lua_unlock(L);return status;}LUA_API int lua_dump(lua_State*L,lua_Chunkwriter 
writer,void*data){int status;TObject*o;lua_lock(L);api_checknelems(L,1);o=L->
top-1;if(isLfunction(o)&&clvalue(o)->l.nupvalues==0){luaU_dump(L,clvalue(o)->l
.p,writer,data);status=1;}else status=0;lua_unlock(L);return status;}
#define GCscalel(x) ((x)>>10)
#define GCscale(x) (cast(int,GCscalel(x)))
#define GCunscale(x) (cast(lu_mem,x)<<10)
LUA_API int lua_getgcthreshold(lua_State*L){int threshold;lua_lock(L);
threshold=GCscale(G(L)->GCthreshold);lua_unlock(L);return threshold;}LUA_API 
int lua_getgccount(lua_State*L){int count;lua_lock(L);count=GCscale(G(L)->
nblocks);lua_unlock(L);return count;}LUA_API void lua_setgcthreshold(lua_State
*L,int newthreshold){lua_lock(L);if(cast(lu_mem,newthreshold)>GCscalel(
MAX_LUMEM))G(L)->GCthreshold=MAX_LUMEM;else G(L)->GCthreshold=GCunscale(
newthreshold);luaC_checkGC(L);lua_unlock(L);}LUA_API const char*lua_version(
void){return LUA_VERSION;}LUA_API int lua_error(lua_State*L){lua_lock(L);
api_checknelems(L,1);luaG_errormsg(L);lua_unlock(L);return 0;}LUA_API int 
lua_next(lua_State*L,int idx){StkId t;int more;lua_lock(L);t=luaA_index(L,idx)
;api_check(L,ttistable(t));more=luaH_next(L,hvalue(t),L->top-1);if(more){
api_incr_top(L);}else L->top-=1;lua_unlock(L);return more;}LUA_API void 
lua_concat(lua_State*L,int n){lua_lock(L);luaC_checkGC(L);api_checknelems(L,n)
;if(n>=2){luaV_concat(L,n,L->top-L->base-1);L->top-=(n-1);}else if(n==0){
setsvalue2s(L->top,luaS_newlstr(L,NULL,0));api_incr_top(L);}lua_unlock(L);}
LUA_API void*lua_newuserdata(lua_State*L,size_t size){Udata*u;lua_lock(L);
luaC_checkGC(L);u=luaS_newudata(L,size);setuvalue(L->top,u);api_incr_top(L);
lua_unlock(L);return u+1;}LUA_API int lua_pushupvalues(lua_State*L){Closure*
func;int n,i;lua_lock(L);api_check(L,iscfunction(L->base-1));func=clvalue(L->
base-1);n=func->c.nupvalues;luaD_checkstack(L,n+LUA_MINSTACK);for(i=0;i<n;i++)
{setobj2s(L->top,&func->c.upvalue[i]);L->top++;}lua_unlock(L);return n;}static
 const char*aux_upvalue(lua_State*L,int funcindex,int n,TObject**val){Closure*
f;StkId fi=luaA_index(L,funcindex);if(!ttisfunction(fi))return NULL;f=clvalue(
fi);if(f->c.isC){if(n>f->c.nupvalues)return NULL;*val=&f->c.upvalue[n-1];
return"";}else{Proto*p=f->l.p;if(n>p->sizeupvalues)return NULL;*val=f->l.
upvals[n-1]->v;return getstr(p->upvalues[n-1]);}}LUA_API const char*
lua_getupvalue(lua_State*L,int funcindex,int n){const char*name;TObject*val;
lua_lock(L);name=aux_upvalue(L,funcindex,n,&val);if(name){setobj2s(L->top,val)
;api_incr_top(L);}lua_unlock(L);return name;}LUA_API const char*lua_setupvalue
(lua_State*L,int funcindex,int n){const char*name;TObject*val;lua_lock(L);
api_checknelems(L,1);name=aux_upvalue(L,funcindex,n,&val);if(name){L->top--;
setobj(val,L->top);}lua_unlock(L);return name;}
#line 1 "lauxlib.c"
#define lauxlib_c
#line 1 "lauxlib.h"
#ifndef lauxlib_h
#define lauxlib_h
#ifndef LUALIB_API
#define LUALIB_API LUA_API
#endif
typedef struct luaL_reg{const char*name;lua_CFunction func;}luaL_reg;
LUALIB_API void luaL_openlib(lua_State*L,const char*libname,const luaL_reg*l,
int nup);LUALIB_API int luaL_getmetafield(lua_State*L,int obj,const char*e);
LUALIB_API int luaL_callmeta(lua_State*L,int obj,const char*e);LUALIB_API int 
luaL_typerror(lua_State*L,int narg,const char*tname);LUALIB_API int 
luaL_argerror(lua_State*L,int numarg,const char*extramsg);LUALIB_API const 
char*luaL_checklstring(lua_State*L,int numArg,size_t*l);LUALIB_API const char*
luaL_optlstring(lua_State*L,int numArg,const char*def,size_t*l);LUALIB_API 
lua_Number luaL_checknumber(lua_State*L,int numArg);LUALIB_API lua_Number 
luaL_optnumber(lua_State*L,int nArg,lua_Number def);LUALIB_API void 
luaL_checkstack(lua_State*L,int sz,const char*msg);LUALIB_API void 
luaL_checktype(lua_State*L,int narg,int t);LUALIB_API void luaL_checkany(
lua_State*L,int narg);LUALIB_API int luaL_newmetatable(lua_State*L,const char*
tname);LUALIB_API void luaL_getmetatable(lua_State*L,const char*tname);
LUALIB_API void*luaL_checkudata(lua_State*L,int ud,const char*tname);
LUALIB_API void luaL_where(lua_State*L,int lvl);LUALIB_API int luaL_error(
lua_State*L,const char*fmt,...);LUALIB_API int luaL_findstring(const char*st,
const char*const lst[]);LUALIB_API int luaL_ref(lua_State*L,int t);LUALIB_API 
void luaL_unref(lua_State*L,int t,int ref);LUALIB_API int luaL_getn(lua_State*
L,int t);LUALIB_API void luaL_setn(lua_State*L,int t,int n);LUALIB_API int 
luaL_loadfile(lua_State*L,const char*filename);LUALIB_API int luaL_loadbuffer(
lua_State*L,const char*buff,size_t sz,const char*name);
#define luaL_argcheck(L, cond,numarg,extramsg)if(!(cond))luaL_argerror(L,\
numarg,extramsg)
#define luaL_checkstring(L,n) (luaL_checklstring(L,(n),NULL))
#define luaL_optstring(L,n,d) (luaL_optlstring(L,(n),(d),NULL))
#define luaL_checkint(L,n) ((int)luaL_checknumber(L,n))
#define luaL_checklong(L,n) ((long)luaL_checknumber(L,n))
#define luaL_optint(L,n,d) ((int)luaL_optnumber(L,n,(lua_Number)(d)))
#define luaL_optlong(L,n,d) ((long)luaL_optnumber(L,n,(lua_Number)(d)))
#ifndef LUAL_BUFFERSIZE
#define LUAL_BUFFERSIZE BUFSIZ
#endif
typedef struct luaL_Buffer{char*p;int lvl;lua_State*L;char buffer[
LUAL_BUFFERSIZE];}luaL_Buffer;
#define luaL_putchar(B,c) ((void)((B)->p<((B)->buffer+LUAL_BUFFERSIZE)||\
luaL_prepbuffer(B)),(*(B)->p++=(char)(c)))
#define luaL_addsize(B,n) ((B)->p+=(n))
LUALIB_API void luaL_buffinit(lua_State*L,luaL_Buffer*B);LUALIB_API char*
luaL_prepbuffer(luaL_Buffer*B);LUALIB_API void luaL_addlstring(luaL_Buffer*B,
const char*s,size_t l);LUALIB_API void luaL_addstring(luaL_Buffer*B,const char
*s);LUALIB_API void luaL_addvalue(luaL_Buffer*B);LUALIB_API void 
luaL_pushresult(luaL_Buffer*B);LUALIB_API int lua_dofile(lua_State*L,const 
char*filename);LUALIB_API int lua_dostring(lua_State*L,const char*str);
LUALIB_API int lua_dobuffer(lua_State*L,const char*buff,size_t sz,const char*n
);
#define luaL_check_lstr luaL_checklstring
#define luaL_opt_lstr luaL_optlstring
#define luaL_check_number luaL_checknumber
#define luaL_opt_number luaL_optnumber
#define luaL_arg_check luaL_argcheck
#define luaL_check_string luaL_checkstring
#define luaL_opt_string luaL_optstring
#define luaL_check_int luaL_checkint
#define luaL_check_long luaL_checklong
#define luaL_opt_int luaL_optint
#define luaL_opt_long luaL_optlong
#endif
#line 24 "lauxlib.c"
#define RESERVED_REFS 2
#define FREELIST_REF 1
#define ARRAYSIZE_REF 2
#define abs_index(L, i)((i)>0||(i)<=LUA_REGISTRYINDEX?(i):lua_gettop(L)+(i)+1)
LUALIB_API int luaL_argerror(lua_State*L,int narg,const char*extramsg){
lua_Debug ar;lua_getstack(L,0,&ar);lua_getinfo(L,"n",&ar);if(strcmp(ar.
namewhat,"method")==0){narg--;if(narg==0)return luaL_error(L,
"calling `%s' on bad self (%s)",ar.name,extramsg);}if(ar.name==NULL)ar.name=
"?";return luaL_error(L,"bad argument #%d to `%s' (%s)",narg,ar.name,extramsg)
;}LUALIB_API int luaL_typerror(lua_State*L,int narg,const char*tname){const 
char*msg=lua_pushfstring(L,"%s expected, got %s",tname,lua_typename(L,lua_type
(L,narg)));return luaL_argerror(L,narg,msg);}static void tag_error(lua_State*L
,int narg,int tag){luaL_typerror(L,narg,lua_typename(L,tag));}LUALIB_API void 
luaL_where(lua_State*L,int level){lua_Debug ar;if(lua_getstack(L,level,&ar)){
lua_getinfo(L,"Snl",&ar);if(ar.currentline>0){lua_pushfstring(L,"%s:%d: ",ar.
short_src,ar.currentline);return;}}lua_pushliteral(L,"");}LUALIB_API int 
luaL_error(lua_State*L,const char*fmt,...){va_list argp;va_start(argp,fmt);
luaL_where(L,1);lua_pushvfstring(L,fmt,argp);va_end(argp);lua_concat(L,2);
return lua_error(L);}LUALIB_API int luaL_findstring(const char*name,const char
*const list[]){int i;for(i=0;list[i];i++)if(strcmp(list[i],name)==0)return i;
return-1;}LUALIB_API int luaL_newmetatable(lua_State*L,const char*tname){
lua_pushstring(L,tname);lua_rawget(L,LUA_REGISTRYINDEX);if(!lua_isnil(L,-1))
return 0;lua_pop(L,1);lua_newtable(L);lua_pushstring(L,tname);lua_pushvalue(L,
-2);lua_rawset(L,LUA_REGISTRYINDEX);lua_pushvalue(L,-1);lua_pushstring(L,tname
);lua_rawset(L,LUA_REGISTRYINDEX);return 1;}LUALIB_API void luaL_getmetatable(
lua_State*L,const char*tname){lua_pushstring(L,tname);lua_rawget(L,
LUA_REGISTRYINDEX);}LUALIB_API void*luaL_checkudata(lua_State*L,int ud,const 
char*tname){const char*tn;if(!lua_getmetatable(L,ud))return NULL;lua_rawget(L,
LUA_REGISTRYINDEX);tn=lua_tostring(L,-1);if(tn&&(strcmp(tn,tname)==0)){lua_pop
(L,1);return lua_touserdata(L,ud);}else{lua_pop(L,1);return NULL;}}LUALIB_API 
void luaL_checkstack(lua_State*L,int space,const char*mes){if(!lua_checkstack(
L,space))luaL_error(L,"stack overflow (%s)",mes);}LUALIB_API void 
luaL_checktype(lua_State*L,int narg,int t){if(lua_type(L,narg)!=t)tag_error(L,
narg,t);}LUALIB_API void luaL_checkany(lua_State*L,int narg){if(lua_type(L,
narg)==LUA_TNONE)luaL_argerror(L,narg,"value expected");}LUALIB_API const char
*luaL_checklstring(lua_State*L,int narg,size_t*len){const char*s=lua_tostring(
L,narg);if(!s)tag_error(L,narg,LUA_TSTRING);if(len)*len=lua_strlen(L,narg);
return s;}LUALIB_API const char*luaL_optlstring(lua_State*L,int narg,const 
char*def,size_t*len){if(lua_isnoneornil(L,narg)){if(len)*len=(def?strlen(def):
0);return def;}else return luaL_checklstring(L,narg,len);}LUALIB_API 
lua_Number luaL_checknumber(lua_State*L,int narg){lua_Number d=lua_tonumber(L,
narg);if(d==0&&!lua_isnumber(L,narg))tag_error(L,narg,LUA_TNUMBER);return d;}
LUALIB_API lua_Number luaL_optnumber(lua_State*L,int narg,lua_Number def){if(
lua_isnoneornil(L,narg))return def;else return luaL_checknumber(L,narg);}
LUALIB_API int luaL_getmetafield(lua_State*L,int obj,const char*event){if(!
lua_getmetatable(L,obj))return 0;lua_pushstring(L,event);lua_rawget(L,-2);if(
lua_isnil(L,-1)){lua_pop(L,2);return 0;}else{lua_remove(L,-2);return 1;}}
LUALIB_API int luaL_callmeta(lua_State*L,int obj,const char*event){obj=
abs_index(L,obj);if(!luaL_getmetafield(L,obj,event))return 0;lua_pushvalue(L,
obj);lua_call(L,1,1);return 1;}LUALIB_API void luaL_openlib(lua_State*L,const 
char*libname,const luaL_reg*l,int nup){if(libname){lua_pushstring(L,libname);
lua_gettable(L,LUA_GLOBALSINDEX);if(lua_isnil(L,-1)){lua_pop(L,1);lua_newtable
(L);lua_pushstring(L,libname);lua_pushvalue(L,-2);lua_settable(L,
LUA_GLOBALSINDEX);}lua_insert(L,-(nup+1));}for(;l->name;l++){int i;
lua_pushstring(L,l->name);for(i=0;i<nup;i++)lua_pushvalue(L,-(nup+1));
lua_pushcclosure(L,l->func,nup);lua_settable(L,-(nup+3));}lua_pop(L,nup);}
static int checkint(lua_State*L,int topop){int n=(int)lua_tonumber(L,-1);if(n
==0&&!lua_isnumber(L,-1))n=-1;lua_pop(L,topop);return n;}static void getsizes(
lua_State*L){lua_rawgeti(L,LUA_REGISTRYINDEX,ARRAYSIZE_REF);if(lua_isnil(L,-1)
){lua_pop(L,1);lua_newtable(L);lua_pushvalue(L,-1);lua_setmetatable(L,-2);
lua_pushliteral(L,"__mode");lua_pushliteral(L,"k");lua_rawset(L,-3);
lua_pushvalue(L,-1);lua_rawseti(L,LUA_REGISTRYINDEX,ARRAYSIZE_REF);}}void 
luaL_setn(lua_State*L,int t,int n){t=abs_index(L,t);lua_pushliteral(L,"n");
lua_rawget(L,t);if(checkint(L,1)>=0){lua_pushliteral(L,"n");lua_pushnumber(L,(
lua_Number)n);lua_rawset(L,t);}else{getsizes(L);lua_pushvalue(L,t);
lua_pushnumber(L,(lua_Number)n);lua_rawset(L,-3);lua_pop(L,1);}}int luaL_getn(
lua_State*L,int t){int n;t=abs_index(L,t);lua_pushliteral(L,"n");lua_rawget(L,
t);if((n=checkint(L,1))>=0)return n;getsizes(L);lua_pushvalue(L,t);lua_rawget(
L,-2);if((n=checkint(L,2))>=0)return n;for(n=1;;n++){lua_rawgeti(L,t,n);if(
lua_isnil(L,-1))break;lua_pop(L,1);}lua_pop(L,1);return n-1;}
#define bufflen(B) ((B)->p-(B)->buffer)
#define bufffree(B) ((size_t)(LUAL_BUFFERSIZE-bufflen(B)))
#define LIMIT (LUA_MINSTACK/2)
static int emptybuffer(luaL_Buffer*B){size_t l=bufflen(B);if(l==0)return 0;
else{lua_pushlstring(B->L,B->buffer,l);B->p=B->buffer;B->lvl++;return 1;}}
static void adjuststack(luaL_Buffer*B){if(B->lvl>1){lua_State*L=B->L;int toget
=1;size_t toplen=lua_strlen(L,-1);do{size_t l=lua_strlen(L,-(toget+1));if(B->
lvl-toget+1>=LIMIT||toplen>l){toplen+=l;toget++;}else break;}while(toget<B->
lvl);lua_concat(L,toget);B->lvl=B->lvl-toget+1;}}LUALIB_API char*
luaL_prepbuffer(luaL_Buffer*B){if(emptybuffer(B))adjuststack(B);return B->
buffer;}LUALIB_API void luaL_addlstring(luaL_Buffer*B,const char*s,size_t l){
while(l--)luaL_putchar(B,*s++);}LUALIB_API void luaL_addstring(luaL_Buffer*B,
const char*s){luaL_addlstring(B,s,strlen(s));}LUALIB_API void luaL_pushresult(
luaL_Buffer*B){emptybuffer(B);lua_concat(B->L,B->lvl);B->lvl=1;}LUALIB_API 
void luaL_addvalue(luaL_Buffer*B){lua_State*L=B->L;size_t vl=lua_strlen(L,-1);
if(vl<=bufffree(B)){memcpy(B->p,lua_tostring(L,-1),vl);B->p+=vl;lua_pop(L,1);}
else{if(emptybuffer(B))lua_insert(L,-2);B->lvl++;adjuststack(B);}}LUALIB_API 
void luaL_buffinit(lua_State*L,luaL_Buffer*B){B->L=L;B->p=B->buffer;B->lvl=0;}
LUALIB_API int luaL_ref(lua_State*L,int t){int ref;t=abs_index(L,t);if(
lua_isnil(L,-1)){lua_pop(L,1);return LUA_REFNIL;}lua_rawgeti(L,t,FREELIST_REF)
;ref=(int)lua_tonumber(L,-1);lua_pop(L,1);if(ref!=0){lua_rawgeti(L,t,ref);
lua_rawseti(L,t,FREELIST_REF);}else{ref=luaL_getn(L,t);if(ref<RESERVED_REFS)
ref=RESERVED_REFS;ref++;luaL_setn(L,t,ref);}lua_rawseti(L,t,ref);return ref;}
LUALIB_API void luaL_unref(lua_State*L,int t,int ref){if(ref>=0){t=abs_index(L
,t);lua_rawgeti(L,t,FREELIST_REF);lua_rawseti(L,t,ref);lua_pushnumber(L,(
lua_Number)ref);lua_rawseti(L,t,FREELIST_REF);}}typedef struct LoadF{FILE*f;
char buff[LUAL_BUFFERSIZE];}LoadF;static const char*getF(lua_State*L,void*ud,
size_t*size){LoadF*lf=(LoadF*)ud;(void)L;if(feof(lf->f))return NULL;*size=
fread(lf->buff,1,LUAL_BUFFERSIZE,lf->f);return(*size>0)?lf->buff:NULL;}static 
int errfile(lua_State*L,int fnameindex){const char*filename=lua_tostring(L,
fnameindex)+1;lua_pushfstring(L,"cannot read %s: %s",filename,strerror(errno))
;lua_remove(L,fnameindex);return LUA_ERRFILE;}LUALIB_API int luaL_loadfile(
lua_State*L,const char*filename){LoadF lf;int status,readstatus;int c;int 
fnameindex=lua_gettop(L)+1;if(filename==NULL){lua_pushliteral(L,"=stdin");lf.f
=stdin;}else{lua_pushfstring(L,"@%s",filename);lf.f=fopen(filename,"r");}if(lf
.f==NULL)return errfile(L,fnameindex);c=ungetc(getc(lf.f),lf.f);if(!(isspace(c
)||isprint(c))&&lf.f!=stdin){fclose(lf.f);lf.f=fopen(filename,"rb");if(lf.f==
NULL)return errfile(L,fnameindex);}status=lua_load(L,getF,&lf,lua_tostring(L,-
1));readstatus=ferror(lf.f);if(lf.f!=stdin)fclose(lf.f);if(readstatus){
lua_settop(L,fnameindex);return errfile(L,fnameindex);}lua_remove(L,fnameindex
);return status;}typedef struct LoadS{const char*s;size_t size;}LoadS;static 
const char*getS(lua_State*L,void*ud,size_t*size){LoadS*ls=(LoadS*)ud;(void)L;
if(ls->size==0)return NULL;*size=ls->size;ls->size=0;return ls->s;}LUALIB_API 
int luaL_loadbuffer(lua_State*L,const char*buff,size_t size,const char*name){
LoadS ls;ls.s=buff;ls.size=size;return lua_load(L,getS,&ls,name);}static void 
callalert(lua_State*L,int status){if(status!=0){lua_getglobal(L,"_ALERT");if(
lua_isfunction(L,-1)){lua_insert(L,-2);lua_call(L,1,0);}else{fprintf(stderr,
"%s\n",lua_tostring(L,-2));lua_pop(L,2);}}}static int aux_do(lua_State*L,int 
status){if(status==0){status=lua_pcall(L,0,LUA_MULTRET,0);}callalert(L,status)
;return status;}LUALIB_API int lua_dofile(lua_State*L,const char*filename){
return aux_do(L,luaL_loadfile(L,filename));}LUALIB_API int lua_dobuffer(
lua_State*L,const char*buff,size_t size,const char*name){return aux_do(L,
luaL_loadbuffer(L,buff,size,name));}LUALIB_API int lua_dostring(lua_State*L,
const char*str){return lua_dobuffer(L,str,strlen(str),str);}
#line 1 "lbaselib.c"
#define lbaselib_c
#line 1 "lualib.h"
#ifndef lualib_h
#define lualib_h
#ifndef LUALIB_API
#define LUALIB_API LUA_API
#endif
#define LUA_COLIBNAME "coroutine"
LUALIB_API int luaopen_base(lua_State*L);
#define LUA_TABLIBNAME "table"
LUALIB_API int luaopen_table(lua_State*L);
#define LUA_IOLIBNAME "io"
#define LUA_OSLIBNAME "os"
LUALIB_API int luaopen_io(lua_State*L);
#define LUA_STRLIBNAME "string"
LUALIB_API int luaopen_string(lua_State*L);
#define LUA_MATHLIBNAME "math"
LUALIB_API int luaopen_math(lua_State*L);
#define LUA_DBLIBNAME "debug"
LUALIB_API int luaopen_debug(lua_State*L);LUALIB_API int luaopen_loadlib(
lua_State*L);
#ifndef lua_assert
#define lua_assert(c) 
#endif
#define lua_baselibopen luaopen_base
#define lua_tablibopen luaopen_table
#define lua_iolibopen luaopen_io
#define lua_strlibopen luaopen_string
#define lua_mathlibopen luaopen_math
#define lua_dblibopen luaopen_debug
#endif
#line 20 "lbaselib.c"
static int luaB_print(lua_State*L){int n=lua_gettop(L);int i;lua_getglobal(L,
"tostring");for(i=1;i<=n;i++){const char*s;lua_pushvalue(L,-1);lua_pushvalue(L
,i);lua_call(L,1,1);s=lua_tostring(L,-1);if(s==NULL)return luaL_error(L,
"`tostring' must return a string to `print'");if(i>1)fputs("\t",stdout);fputs(
s,stdout);lua_pop(L,1);}fputs("\n",stdout);return 0;}static int luaB_tonumber(
lua_State*L){int base=luaL_optint(L,2,10);if(base==10){luaL_checkany(L,1);if(
lua_isnumber(L,1)){lua_pushnumber(L,lua_tonumber(L,1));return 1;}}else{const 
char*s1=luaL_checkstring(L,1);char*s2;unsigned long n;luaL_argcheck(L,2<=base
&&base<=36,2,"base out of range");n=strtoul(s1,&s2,base);if(s1!=s2){while(
isspace((unsigned char)(*s2)))s2++;if(*s2=='\0'){lua_pushnumber(L,(lua_Number)
n);return 1;}}}lua_pushnil(L);return 1;}static int luaB_error(lua_State*L){int
 level=luaL_optint(L,2,1);luaL_checkany(L,1);if(!lua_isstring(L,1)||level==0)
lua_pushvalue(L,1);else{luaL_where(L,level);lua_pushvalue(L,1);lua_concat(L,2)
;}return lua_error(L);}static int luaB_getmetatable(lua_State*L){luaL_checkany
(L,1);if(!lua_getmetatable(L,1)){lua_pushnil(L);return 1;}luaL_getmetafield(L,
1,"__metatable");return 1;}static int luaB_setmetatable(lua_State*L){int t=
lua_type(L,2);luaL_checktype(L,1,LUA_TTABLE);luaL_argcheck(L,t==LUA_TNIL||t==
LUA_TTABLE,2,"nil or table expected");if(luaL_getmetafield(L,1,"__metatable"))
luaL_error(L,"cannot change a protected metatable");lua_settop(L,2);
lua_setmetatable(L,1);return 1;}static void getfunc(lua_State*L){if(
lua_isfunction(L,1))lua_pushvalue(L,1);else{lua_Debug ar;int level=luaL_optint
(L,1,1);luaL_argcheck(L,level>=0,1,"level must be non-negative");if(
lua_getstack(L,level,&ar)==0)luaL_argerror(L,1,"invalid level");lua_getinfo(L,
"f",&ar);if(lua_isnil(L,-1))luaL_error(L,
"no function environment for tail call at level %d",level);}}static int 
aux_getfenv(lua_State*L){lua_getfenv(L,-1);lua_pushliteral(L,"__fenv");
lua_rawget(L,-2);return!lua_isnil(L,-1);}static int luaB_getfenv(lua_State*L){
getfunc(L);if(!aux_getfenv(L))lua_pop(L,1);return 1;}static int luaB_setfenv(
lua_State*L){luaL_checktype(L,2,LUA_TTABLE);getfunc(L);if(aux_getfenv(L))
luaL_error(L,"`setfenv' cannot change a protected environment");else lua_pop(L
,2);lua_pushvalue(L,2);if(lua_isnumber(L,1)&&lua_tonumber(L,1)==0)lua_replace(
L,LUA_GLOBALSINDEX);else if(lua_setfenv(L,-2)==0)luaL_error(L,
"`setfenv' cannot change environment of given function");return 0;}static int 
luaB_rawequal(lua_State*L){luaL_checkany(L,1);luaL_checkany(L,2);
lua_pushboolean(L,lua_rawequal(L,1,2));return 1;}static int luaB_rawget(
lua_State*L){luaL_checktype(L,1,LUA_TTABLE);luaL_checkany(L,2);lua_rawget(L,1)
;return 1;}static int luaB_rawset(lua_State*L){luaL_checktype(L,1,LUA_TTABLE);
luaL_checkany(L,2);luaL_checkany(L,3);lua_rawset(L,1);return 1;}static int 
luaB_gcinfo(lua_State*L){lua_pushnumber(L,(lua_Number)lua_getgccount(L));
lua_pushnumber(L,(lua_Number)lua_getgcthreshold(L));return 2;}static int 
luaB_collectgarbage(lua_State*L){lua_setgcthreshold(L,luaL_optint(L,1,0));
return 0;}static int luaB_type(lua_State*L){luaL_checkany(L,1);lua_pushstring(
L,lua_typename(L,lua_type(L,1)));return 1;}static int luaB_next(lua_State*L){
luaL_checktype(L,1,LUA_TTABLE);lua_settop(L,2);if(lua_next(L,1))return 2;else{
lua_pushnil(L);return 1;}}static int luaB_pairs(lua_State*L){luaL_checktype(L,
1,LUA_TTABLE);lua_pushliteral(L,"next");lua_rawget(L,LUA_GLOBALSINDEX);
lua_pushvalue(L,1);lua_pushnil(L);return 3;}static int luaB_ipairs(lua_State*L
){lua_Number i=lua_tonumber(L,2);luaL_checktype(L,1,LUA_TTABLE);if(i==0&&
lua_isnone(L,2)){lua_pushliteral(L,"ipairs");lua_rawget(L,LUA_GLOBALSINDEX);
lua_pushvalue(L,1);lua_pushnumber(L,0);return 3;}else{i++;lua_pushnumber(L,i);
lua_rawgeti(L,1,(int)i);return(lua_isnil(L,-1))?0:2;}}static int load_aux(
lua_State*L,int status){if(status==0)return 1;else{lua_pushnil(L);lua_insert(L
,-2);return 2;}}static int luaB_loadstring(lua_State*L){size_t l;const char*s=
luaL_checklstring(L,1,&l);const char*chunkname=luaL_optstring(L,2,s);return 
load_aux(L,luaL_loadbuffer(L,s,l,chunkname));}static int luaB_loadfile(
lua_State*L){const char*fname=luaL_optstring(L,1,NULL);return load_aux(L,
luaL_loadfile(L,fname));}static int luaB_dofile(lua_State*L){const char*fname=
luaL_optstring(L,1,NULL);int n=lua_gettop(L);int status=luaL_loadfile(L,fname)
;if(status!=0)lua_error(L);lua_call(L,0,LUA_MULTRET);return lua_gettop(L)-n;}
static int luaB_assert(lua_State*L){luaL_checkany(L,1);if(!lua_toboolean(L,1))
return luaL_error(L,"%s",luaL_optstring(L,2,"assertion failed!"));lua_settop(L
,1);return 1;}static int luaB_unpack(lua_State*L){int n,i;luaL_checktype(L,1,
LUA_TTABLE);n=luaL_getn(L,1);luaL_checkstack(L,n,"table too big to unpack");
for(i=1;i<=n;i++)lua_rawgeti(L,1,i);return n;}static int luaB_pcall(lua_State*
L){int status;luaL_checkany(L,1);status=lua_pcall(L,lua_gettop(L)-1,
LUA_MULTRET,0);lua_pushboolean(L,(status==0));lua_insert(L,1);return 
lua_gettop(L);}static int luaB_xpcall(lua_State*L){int status;luaL_checkany(L,
2);lua_settop(L,2);lua_insert(L,1);status=lua_pcall(L,0,LUA_MULTRET,1);
lua_pushboolean(L,(status==0));lua_replace(L,1);return lua_gettop(L);}static 
int luaB_tostring(lua_State*L){char buff[128];luaL_checkany(L,1);if(
luaL_callmeta(L,1,"__tostring"))return 1;switch(lua_type(L,1)){case 
LUA_TNUMBER:lua_pushstring(L,lua_tostring(L,1));return 1;case LUA_TSTRING:
lua_pushvalue(L,1);return 1;case LUA_TBOOLEAN:lua_pushstring(L,(lua_toboolean(
L,1)?"true":"false"));return 1;case LUA_TTABLE:sprintf(buff,"table: %p",
lua_topointer(L,1));break;case LUA_TFUNCTION:sprintf(buff,"function: %p",
lua_topointer(L,1));break;case LUA_TUSERDATA:case LUA_TLIGHTUSERDATA:sprintf(
buff,"userdata: %p",lua_touserdata(L,1));break;case LUA_TTHREAD:sprintf(buff,
"thread: %p",(void*)lua_tothread(L,1));break;case LUA_TNIL:lua_pushliteral(L,
"nil");return 1;}lua_pushstring(L,buff);return 1;}static int luaB_newproxy(
lua_State*L){lua_settop(L,1);lua_newuserdata(L,0);if(lua_toboolean(L,1)==0)
return 1;else if(lua_isboolean(L,1)){lua_newtable(L);lua_pushvalue(L,-1);
lua_pushboolean(L,1);lua_rawset(L,lua_upvalueindex(1));}else{int validproxy=0;
if(lua_getmetatable(L,1)){lua_rawget(L,lua_upvalueindex(1));validproxy=
lua_toboolean(L,-1);lua_pop(L,1);}luaL_argcheck(L,validproxy,1,
"boolean or proxy expected");lua_getmetatable(L,1);}lua_setmetatable(L,2);
return 1;}
#define REQTAB "_LOADED"
#define LUA_PATH "LUA_PATH"
#ifndef LUA_PATH_SEP
#define LUA_PATH_SEP ';'
#endif
#ifndef LUA_PATH_MARK
#define LUA_PATH_MARK '?'
#endif
#ifndef LUA_PATH_DEFAULT
#define LUA_PATH_DEFAULT "?;?.lua"
#endif
static const char*getpath(lua_State*L){const char*path;lua_getglobal(L,
LUA_PATH);path=lua_tostring(L,-1);lua_pop(L,1);if(path)return path;path=getenv
(LUA_PATH);if(path)return path;return LUA_PATH_DEFAULT;}static const char*
pushnextpath(lua_State*L,const char*path){const char*l;if(*path=='\0')return 
NULL;if(*path==LUA_PATH_SEP)path++;l=strchr(path,LUA_PATH_SEP);if(l==NULL)l=
path+strlen(path);lua_pushlstring(L,path,l-path);return l;}static void 
pushcomposename(lua_State*L){const char*path=lua_tostring(L,-1);const char*
wild;int n=1;while((wild=strchr(path,LUA_PATH_MARK))!=NULL){luaL_checkstack(L,
3,"too many marks in a path component");lua_pushlstring(L,path,wild-path);
lua_pushvalue(L,1);path=wild+1;n+=2;}lua_pushstring(L,path);lua_concat(L,n);}
static int luaB_require(lua_State*L){const char*path;int status=LUA_ERRFILE;
luaL_checkstring(L,1);lua_settop(L,1);lua_getglobal(L,REQTAB);if(!lua_istable(
L,2))return luaL_error(L,"`"REQTAB"' is not a table");path=getpath(L);
lua_pushvalue(L,1);lua_rawget(L,2);if(lua_toboolean(L,-1))return 1;else{while(
status==LUA_ERRFILE){lua_settop(L,3);if((path=pushnextpath(L,path))==NULL)
break;pushcomposename(L);status=luaL_loadfile(L,lua_tostring(L,-1));}}switch(
status){case 0:{lua_getglobal(L,"_REQUIREDNAME");lua_insert(L,-2);
lua_pushvalue(L,1);lua_setglobal(L,"_REQUIREDNAME");lua_call(L,0,1);lua_insert
(L,-2);lua_setglobal(L,"_REQUIREDNAME");if(lua_isnil(L,-1)){lua_pushboolean(L,
1);lua_replace(L,-2);}lua_pushvalue(L,1);lua_pushvalue(L,-2);lua_rawset(L,2);
return 1;}case LUA_ERRFILE:{return luaL_error(L,
"could not load package `%s' from path `%s'",lua_tostring(L,1),getpath(L));}
default:{return luaL_error(L,"error loading package `%s' (%s)",lua_tostring(L,
1),lua_tostring(L,-1));}}}static const luaL_reg base_funcs[]={{"error",
luaB_error},{"getmetatable",luaB_getmetatable},{"setmetatable",
luaB_setmetatable},{"getfenv",luaB_getfenv},{"setfenv",luaB_setfenv},{"next",
luaB_next},{"ipairs",luaB_ipairs},{"pairs",luaB_pairs},{"print",luaB_print},{
"tonumber",luaB_tonumber},{"tostring",luaB_tostring},{"type",luaB_type},{
"assert",luaB_assert},{"unpack",luaB_unpack},{"rawequal",luaB_rawequal},{
"rawget",luaB_rawget},{"rawset",luaB_rawset},{"pcall",luaB_pcall},{"xpcall",
luaB_xpcall},{"collectgarbage",luaB_collectgarbage},{"gcinfo",luaB_gcinfo},{
"loadfile",luaB_loadfile},{"dofile",luaB_dofile},{"loadstring",luaB_loadstring
},{"require",luaB_require},{NULL,NULL}};static int auxresume(lua_State*L,
lua_State*co,int narg){int status;if(!lua_checkstack(co,narg))luaL_error(L,
"too many arguments to resume");lua_xmove(L,co,narg);status=lua_resume(co,narg
);if(status==0){int nres=lua_gettop(co);if(!lua_checkstack(L,nres))luaL_error(
L,"too many results to resume");lua_xmove(co,L,nres);return nres;}else{
lua_xmove(co,L,1);return-1;}}static int luaB_coresume(lua_State*L){lua_State*
co=lua_tothread(L,1);int r;luaL_argcheck(L,co,1,"coroutine expected");r=
auxresume(L,co,lua_gettop(L)-1);if(r<0){lua_pushboolean(L,0);lua_insert(L,-2);
return 2;}else{lua_pushboolean(L,1);lua_insert(L,-(r+1));return r+1;}}static 
int luaB_auxwrap(lua_State*L){lua_State*co=lua_tothread(L,lua_upvalueindex(1))
;int r=auxresume(L,co,lua_gettop(L));if(r<0){if(lua_isstring(L,-1)){luaL_where
(L,1);lua_insert(L,-2);lua_concat(L,2);}lua_error(L);}return r;}static int 
luaB_cocreate(lua_State*L){lua_State*NL=lua_newthread(L);luaL_argcheck(L,
lua_isfunction(L,1)&&!lua_iscfunction(L,1),1,"Lua function expected");
lua_pushvalue(L,1);lua_xmove(L,NL,1);return 1;}static int luaB_cowrap(
lua_State*L){luaB_cocreate(L);lua_pushcclosure(L,luaB_auxwrap,1);return 1;}
static int luaB_yield(lua_State*L){return lua_yield(L,lua_gettop(L));}static 
int luaB_costatus(lua_State*L){lua_State*co=lua_tothread(L,1);luaL_argcheck(L,
co,1,"coroutine expected");if(L==co)lua_pushliteral(L,"running");else{
lua_Debug ar;if(lua_getstack(co,0,&ar)==0&&lua_gettop(co)==0)lua_pushliteral(L
,"dead");else lua_pushliteral(L,"suspended");}return 1;}static const luaL_reg 
co_funcs[]={{"create",luaB_cocreate},{"wrap",luaB_cowrap},{"resume",
luaB_coresume},{"yield",luaB_yield},{"status",luaB_costatus},{NULL,NULL}};
static void base_open(lua_State*L){lua_pushliteral(L,"_G");lua_pushvalue(L,
LUA_GLOBALSINDEX);luaL_openlib(L,NULL,base_funcs,0);lua_pushliteral(L,
"_VERSION");lua_pushliteral(L,LUA_VERSION);lua_rawset(L,-3);lua_pushliteral(L,
"newproxy");lua_newtable(L);lua_pushvalue(L,-1);lua_setmetatable(L,-2);
lua_pushliteral(L,"__mode");lua_pushliteral(L,"k");lua_rawset(L,-3);
lua_pushcclosure(L,luaB_newproxy,1);lua_rawset(L,-3);lua_rawset(L,-1);}
LUALIB_API int luaopen_base(lua_State*L){base_open(L);luaL_openlib(L,
LUA_COLIBNAME,co_funcs,0);lua_newtable(L);lua_setglobal(L,REQTAB);return 0;}
#line 1 "lcode.c"
#define lcode_c
#line 1 "lcode.h"
#ifndef lcode_h
#define lcode_h
#line 1 "llex.h"
#ifndef llex_h
#define llex_h
#define FIRST_RESERVED 257
#define TOKEN_LEN (sizeof("function")/sizeof(char))
enum RESERVED{TK_AND=FIRST_RESERVED,TK_BREAK,TK_DO,TK_ELSE,TK_ELSEIF,TK_END,
TK_FALSE,TK_FOR,TK_FUNCTION,TK_IF,TK_IN,TK_LOCAL,TK_NIL,TK_NOT,TK_OR,TK_REPEAT
,TK_RETURN,TK_THEN,TK_TRUE,TK_UNTIL,TK_WHILE,TK_NAME,TK_CONCAT,TK_DOTS,TK_EQ,
TK_GE,TK_LE,TK_NE,TK_NUMBER,TK_STRING,TK_EOS};
#define NUM_RESERVED (cast(int,TK_WHILE-FIRST_RESERVED+1))
typedef union{lua_Number r;TString*ts;}SemInfo;typedef struct Token{int token;
SemInfo seminfo;}Token;typedef struct LexState{int current;int linenumber;int 
lastline;Token t;Token lookahead;struct FuncState*fs;struct lua_State*L;ZIO*z;
Mbuffer*buff;TString*source;int nestlevel;}LexState;void luaX_init(lua_State*L
);void luaX_setinput(lua_State*L,LexState*LS,ZIO*z,TString*source);int 
luaX_lex(LexState*LS,SemInfo*seminfo);void luaX_checklimit(LexState*ls,int val
,int limit,const char*msg);void luaX_syntaxerror(LexState*ls,const char*s);
void luaX_errorline(LexState*ls,const char*s,const char*token,int line);const 
char*luaX_token2str(LexState*ls,int token);
#endif
#line 11 "lcode.h"
#line 1 "lopcodes.h"
#ifndef lopcodes_h
#define lopcodes_h
enum OpMode{iABC,iABx,iAsBx};
#define SIZE_C 9
#define SIZE_B 9
#define SIZE_Bx (SIZE_C+SIZE_B)
#define SIZE_A 8
#define SIZE_OP 6
#define POS_C SIZE_OP
#define POS_B (POS_C+SIZE_C)
#define POS_Bx POS_C
#define POS_A (POS_B+SIZE_B)
#if SIZE_Bx <BITS_INT-1
#define MAXARG_Bx ((1<<SIZE_Bx)-1)
#define MAXARG_sBx (MAXARG_Bx>>1)
#else
#define MAXARG_Bx MAX_INT
#define MAXARG_sBx MAX_INT
#endif
#define MAXARG_A ((1<<SIZE_A)-1)
#define MAXARG_B ((1<<SIZE_B)-1)
#define MAXARG_C ((1<<SIZE_C)-1)
#define MASK1(n,p) ((~((~(Instruction)0)<<n))<<p)
#define MASK0(n,p) (~MASK1(n,p))
#define GET_OPCODE(i) (cast(OpCode,(i)&MASK1(SIZE_OP,0)))
#define SET_OPCODE(i,o) ((i)=(((i)&MASK0(SIZE_OP,0))|cast(Instruction,o)))
#define GETARG_A(i) (cast(int,(i)>>POS_A))
#define SETARG_A(i,u) ((i)=(((i)&MASK0(SIZE_A,POS_A))|((cast(Instruction,u)<<\
POS_A)&MASK1(SIZE_A,POS_A))))
#define GETARG_B(i) (cast(int,((i)>>POS_B)&MASK1(SIZE_B,0)))
#define SETARG_B(i,b) ((i)=(((i)&MASK0(SIZE_B,POS_B))|((cast(Instruction,b)<<\
POS_B)&MASK1(SIZE_B,POS_B))))
#define GETARG_C(i) (cast(int,((i)>>POS_C)&MASK1(SIZE_C,0)))
#define SETARG_C(i,b) ((i)=(((i)&MASK0(SIZE_C,POS_C))|((cast(Instruction,b)<<\
POS_C)&MASK1(SIZE_C,POS_C))))
#define GETARG_Bx(i) (cast(int,((i)>>POS_Bx)&MASK1(SIZE_Bx,0)))
#define SETARG_Bx(i,b) ((i)=(((i)&MASK0(SIZE_Bx,POS_Bx))|((cast(Instruction,b)\
<<POS_Bx)&MASK1(SIZE_Bx,POS_Bx))))
#define GETARG_sBx(i) (GETARG_Bx(i)-MAXARG_sBx)
#define SETARG_sBx(i,b) SETARG_Bx((i),cast(unsigned int,(b)+MAXARG_sBx))
#define CREATE_ABC(o,a,b,c) (cast(Instruction,o)|(cast(Instruction,a)<<POS_A)|\
(cast(Instruction,b)<<POS_B)|(cast(Instruction,c)<<POS_C))
#define CREATE_ABx(o,a,bc) (cast(Instruction,o)|(cast(Instruction,a)<<POS_A)|(\
cast(Instruction,bc)<<POS_Bx))
#define NO_REG MAXARG_A
typedef enum{OP_MOVE,OP_LOADK,OP_LOADBOOL,OP_LOADNIL,OP_GETUPVAL,OP_GETGLOBAL,
OP_GETTABLE,OP_SETGLOBAL,OP_SETUPVAL,OP_SETTABLE,OP_NEWTABLE,OP_SELF,OP_ADD,
OP_SUB,OP_MUL,OP_DIV,OP_POW,OP_UNM,OP_NOT,OP_CONCAT,OP_JMP,OP_EQ,OP_LT,OP_LE,
OP_TEST,OP_CALL,OP_TAILCALL,OP_RETURN,OP_FORLOOP,OP_TFORLOOP,OP_TFORPREP,
OP_SETLIST,OP_SETLISTO,OP_CLOSE,OP_CLOSURE}OpCode;
#define NUM_OPCODES (cast(int,OP_CLOSURE+1))
enum OpModeMask{OpModeBreg=2,OpModeBrk,OpModeCrk,OpModesetA,OpModeK,OpModeT};
extern const lu_byte luaP_opmodes[NUM_OPCODES];
#define getOpMode(m) (cast(enum OpMode,luaP_opmodes[m]&3))
#define testOpMode(m, b)(luaP_opmodes[m]&(1<<(b)))
#ifdef LUA_OPNAMES
extern const char*const luaP_opnames[];
#endif
#define LFIELDS_PER_FLUSH 32
#endif
#line 13 "lcode.h"
#line 1 "lparser.h"
#ifndef lparser_h
#define lparser_h
typedef enum{VVOID,VNIL,VTRUE,VFALSE,VK,VLOCAL,VUPVAL,VGLOBAL,VINDEXED,VJMP,
VRELOCABLE,VNONRELOC,VCALL}expkind;typedef struct expdesc{expkind k;int info,
aux;int t;int f;}expdesc;struct BlockCnt;typedef struct FuncState{Proto*f;
Table*h;struct FuncState*prev;struct LexState*ls;struct lua_State*L;struct 
BlockCnt*bl;int pc;int lasttarget;int jpc;int freereg;int nk;int np;int 
nlocvars;int nactvar;expdesc upvalues[MAXUPVALUES];int actvar[MAXVARS];}
FuncState;Proto*luaY_parser(lua_State*L,ZIO*z,Mbuffer*buff);
#endif
#line 14 "lcode.h"
#define NO_JUMP (-1)
typedef enum BinOpr{OPR_ADD,OPR_SUB,OPR_MULT,OPR_DIV,OPR_POW,OPR_CONCAT,OPR_NE
,OPR_EQ,OPR_LT,OPR_LE,OPR_GT,OPR_GE,OPR_AND,OPR_OR,OPR_NOBINOPR}BinOpr;
#define binopistest(op) ((op)>=OPR_NE)
typedef enum UnOpr{OPR_MINUS,OPR_NOT,OPR_NOUNOPR}UnOpr;
#define getcode(fs,e) ((fs)->f->code[(e)->info])
#define luaK_codeAsBx(fs,o,A,sBx) luaK_codeABx(fs,o,A,(sBx)+MAXARG_sBx)
int luaK_code(FuncState*fs,Instruction i,int line);int luaK_codeABx(FuncState*
fs,OpCode o,int A,unsigned int Bx);int luaK_codeABC(FuncState*fs,OpCode o,int 
A,int B,int C);void luaK_fixline(FuncState*fs,int line);void luaK_nil(
FuncState*fs,int from,int n);void luaK_reserveregs(FuncState*fs,int n);void 
luaK_checkstack(FuncState*fs,int n);int luaK_stringK(FuncState*fs,TString*s);
int luaK_numberK(FuncState*fs,lua_Number r);void luaK_dischargevars(FuncState*
fs,expdesc*e);int luaK_exp2anyreg(FuncState*fs,expdesc*e);void 
luaK_exp2nextreg(FuncState*fs,expdesc*e);void luaK_exp2val(FuncState*fs,
expdesc*e);int luaK_exp2RK(FuncState*fs,expdesc*e);void luaK_self(FuncState*fs
,expdesc*e,expdesc*key);void luaK_indexed(FuncState*fs,expdesc*t,expdesc*k);
void luaK_goiftrue(FuncState*fs,expdesc*e);void luaK_goiffalse(FuncState*fs,
expdesc*e);void luaK_storevar(FuncState*fs,expdesc*var,expdesc*e);void 
luaK_setcallreturns(FuncState*fs,expdesc*var,int nresults);int luaK_jump(
FuncState*fs);void luaK_patchlist(FuncState*fs,int list,int target);void 
luaK_patchtohere(FuncState*fs,int list);void luaK_concat(FuncState*fs,int*l1,
int l2);int luaK_getlabel(FuncState*fs);void luaK_prefix(FuncState*fs,UnOpr op
,expdesc*v);void luaK_infix(FuncState*fs,BinOpr op,expdesc*v);void luaK_posfix
(FuncState*fs,BinOpr op,expdesc*v1,expdesc*v2);
#endif
#line 15 "lcode.c"
#define hasjumps(e) ((e)->t!=(e)->f)
void luaK_nil(FuncState*fs,int from,int n){Instruction*previous;if(fs->pc>fs->
lasttarget&&GET_OPCODE(*(previous=&fs->f->code[fs->pc-1]))==OP_LOADNIL){int 
pfrom=GETARG_A(*previous);int pto=GETARG_B(*previous);if(pfrom<=from&&from<=
pto+1){if(from+n-1>pto)SETARG_B(*previous,from+n-1);return;}}luaK_codeABC(fs,
OP_LOADNIL,from,from+n-1,0);}int luaK_jump(FuncState*fs){int jpc=fs->jpc;int j
;fs->jpc=NO_JUMP;j=luaK_codeAsBx(fs,OP_JMP,0,NO_JUMP);luaK_concat(fs,&j,jpc);
return j;}static int luaK_condjump(FuncState*fs,OpCode op,int A,int B,int C){
luaK_codeABC(fs,op,A,B,C);return luaK_jump(fs);}static void luaK_fixjump(
FuncState*fs,int pc,int dest){Instruction*jmp=&fs->f->code[pc];int offset=dest
-(pc+1);lua_assert(dest!=NO_JUMP);if(abs(offset)>MAXARG_sBx)luaX_syntaxerror(
fs->ls,"control structure too long");SETARG_sBx(*jmp,offset);}int 
luaK_getlabel(FuncState*fs){fs->lasttarget=fs->pc;return fs->pc;}static int 
luaK_getjump(FuncState*fs,int pc){int offset=GETARG_sBx(fs->f->code[pc]);if(
offset==NO_JUMP)return NO_JUMP;else return(pc+1)+offset;}static Instruction*
getjumpcontrol(FuncState*fs,int pc){Instruction*pi=&fs->f->code[pc];if(pc>=1&&
testOpMode(GET_OPCODE(*(pi-1)),OpModeT))return pi-1;else return pi;}static int
 need_value(FuncState*fs,int list,int cond){for(;list!=NO_JUMP;list=
luaK_getjump(fs,list)){Instruction i=*getjumpcontrol(fs,list);if(GET_OPCODE(i)
!=OP_TEST||GETARG_C(i)!=cond)return 1;}return 0;}static void patchtestreg(
Instruction*i,int reg){if(reg==NO_REG)reg=GETARG_B(*i);SETARG_A(*i,reg);}
static void luaK_patchlistaux(FuncState*fs,int list,int ttarget,int treg,int 
ftarget,int freg,int dtarget){while(list!=NO_JUMP){int next=luaK_getjump(fs,
list);Instruction*i=getjumpcontrol(fs,list);if(GET_OPCODE(*i)!=OP_TEST){
lua_assert(dtarget!=NO_JUMP);luaK_fixjump(fs,list,dtarget);}else{if(GETARG_C(*
i)){lua_assert(ttarget!=NO_JUMP);patchtestreg(i,treg);luaK_fixjump(fs,list,
ttarget);}else{lua_assert(ftarget!=NO_JUMP);patchtestreg(i,freg);luaK_fixjump(
fs,list,ftarget);}}list=next;}}static void luaK_dischargejpc(FuncState*fs){
luaK_patchlistaux(fs,fs->jpc,fs->pc,NO_REG,fs->pc,NO_REG,fs->pc);fs->jpc=
NO_JUMP;}void luaK_patchlist(FuncState*fs,int list,int target){if(target==fs->
pc)luaK_patchtohere(fs,list);else{lua_assert(target<fs->pc);luaK_patchlistaux(
fs,list,target,NO_REG,target,NO_REG,target);}}void luaK_patchtohere(FuncState*
fs,int list){luaK_getlabel(fs);luaK_concat(fs,&fs->jpc,list);}void luaK_concat
(FuncState*fs,int*l1,int l2){if(l2==NO_JUMP)return;else if(*l1==NO_JUMP)*l1=l2
;else{int list=*l1;int next;while((next=luaK_getjump(fs,list))!=NO_JUMP)list=
next;luaK_fixjump(fs,list,l2);}}void luaK_checkstack(FuncState*fs,int n){int 
newstack=fs->freereg+n;if(newstack>fs->f->maxstacksize){if(newstack>=MAXSTACK)
luaX_syntaxerror(fs->ls,"function or expression too complex");fs->f->
maxstacksize=cast(lu_byte,newstack);}}void luaK_reserveregs(FuncState*fs,int n
){luaK_checkstack(fs,n);fs->freereg+=n;}static void freereg(FuncState*fs,int 
reg){if(reg>=fs->nactvar&&reg<MAXSTACK){fs->freereg--;lua_assert(reg==fs->
freereg);}}static void freeexp(FuncState*fs,expdesc*e){if(e->k==VNONRELOC)
freereg(fs,e->info);}static int addk(FuncState*fs,TObject*k,TObject*v){const 
TObject*idx=luaH_get(fs->h,k);if(ttisnumber(idx)){lua_assert(luaO_rawequalObj(
&fs->f->k[cast(int,nvalue(idx))],v));return cast(int,nvalue(idx));}else{Proto*
f=fs->f;luaM_growvector(fs->L,f->k,fs->nk,f->sizek,TObject,MAXARG_Bx,
"constant table overflow");setobj2n(&f->k[fs->nk],v);setnvalue(luaH_set(fs->L,
fs->h,k),cast(lua_Number,fs->nk));return fs->nk++;}}int luaK_stringK(FuncState
*fs,TString*s){TObject o;setsvalue(&o,s);return addk(fs,&o,&o);}int 
luaK_numberK(FuncState*fs,lua_Number r){TObject o;setnvalue(&o,r);return addk(
fs,&o,&o);}static int nil_constant(FuncState*fs){TObject k,v;setnilvalue(&v);
sethvalue(&k,fs->h);return addk(fs,&k,&v);}void luaK_setcallreturns(FuncState*
fs,expdesc*e,int nresults){if(e->k==VCALL){SETARG_C(getcode(fs,e),nresults+1);
if(nresults==1){e->k=VNONRELOC;e->info=GETARG_A(getcode(fs,e));}}}void 
luaK_dischargevars(FuncState*fs,expdesc*e){switch(e->k){case VLOCAL:{e->k=
VNONRELOC;break;}case VUPVAL:{e->info=luaK_codeABC(fs,OP_GETUPVAL,0,e->info,0)
;e->k=VRELOCABLE;break;}case VGLOBAL:{e->info=luaK_codeABx(fs,OP_GETGLOBAL,0,e
->info);e->k=VRELOCABLE;break;}case VINDEXED:{freereg(fs,e->aux);freereg(fs,e
->info);e->info=luaK_codeABC(fs,OP_GETTABLE,0,e->info,e->aux);e->k=VRELOCABLE;
break;}case VCALL:{luaK_setcallreturns(fs,e,1);break;}default:break;}}static 
int code_label(FuncState*fs,int A,int b,int jump){luaK_getlabel(fs);return 
luaK_codeABC(fs,OP_LOADBOOL,A,b,jump);}static void discharge2reg(FuncState*fs,
expdesc*e,int reg){luaK_dischargevars(fs,e);switch(e->k){case VNIL:{luaK_nil(
fs,reg,1);break;}case VFALSE:case VTRUE:{luaK_codeABC(fs,OP_LOADBOOL,reg,e->k
==VTRUE,0);break;}case VK:{luaK_codeABx(fs,OP_LOADK,reg,e->info);break;}case 
VRELOCABLE:{Instruction*pc=&getcode(fs,e);SETARG_A(*pc,reg);break;}case 
VNONRELOC:{if(reg!=e->info)luaK_codeABC(fs,OP_MOVE,reg,e->info,0);break;}
default:{lua_assert(e->k==VVOID||e->k==VJMP);return;}}e->info=reg;e->k=
VNONRELOC;}static void discharge2anyreg(FuncState*fs,expdesc*e){if(e->k!=
VNONRELOC){luaK_reserveregs(fs,1);discharge2reg(fs,e,fs->freereg-1);}}static 
void luaK_exp2reg(FuncState*fs,expdesc*e,int reg){discharge2reg(fs,e,reg);if(e
->k==VJMP)luaK_concat(fs,&e->t,e->info);if(hasjumps(e)){int final;int p_f=
NO_JUMP;int p_t=NO_JUMP;if(need_value(fs,e->t,1)||need_value(fs,e->f,0)){int 
fj=NO_JUMP;if(e->k!=VJMP)fj=luaK_jump(fs);p_f=code_label(fs,reg,0,1);p_t=
code_label(fs,reg,1,0);luaK_patchtohere(fs,fj);}final=luaK_getlabel(fs);
luaK_patchlistaux(fs,e->f,p_f,NO_REG,final,reg,p_f);luaK_patchlistaux(fs,e->t,
final,reg,p_t,NO_REG,p_t);}e->f=e->t=NO_JUMP;e->info=reg;e->k=VNONRELOC;}void 
luaK_exp2nextreg(FuncState*fs,expdesc*e){luaK_dischargevars(fs,e);freeexp(fs,e
);luaK_reserveregs(fs,1);luaK_exp2reg(fs,e,fs->freereg-1);}int luaK_exp2anyreg
(FuncState*fs,expdesc*e){luaK_dischargevars(fs,e);if(e->k==VNONRELOC){if(!
hasjumps(e))return e->info;if(e->info>=fs->nactvar){luaK_exp2reg(fs,e,e->info)
;return e->info;}}luaK_exp2nextreg(fs,e);return e->info;}void luaK_exp2val(
FuncState*fs,expdesc*e){if(hasjumps(e))luaK_exp2anyreg(fs,e);else 
luaK_dischargevars(fs,e);}int luaK_exp2RK(FuncState*fs,expdesc*e){luaK_exp2val
(fs,e);switch(e->k){case VNIL:{if(fs->nk+MAXSTACK<=MAXARG_C){e->info=
nil_constant(fs);e->k=VK;return e->info+MAXSTACK;}else break;}case VK:{if(e->
info+MAXSTACK<=MAXARG_C)return e->info+MAXSTACK;else break;}default:break;}
return luaK_exp2anyreg(fs,e);}void luaK_storevar(FuncState*fs,expdesc*var,
expdesc*exp){switch(var->k){case VLOCAL:{freeexp(fs,exp);luaK_exp2reg(fs,exp,
var->info);return;}case VUPVAL:{int e=luaK_exp2anyreg(fs,exp);luaK_codeABC(fs,
OP_SETUPVAL,e,var->info,0);break;}case VGLOBAL:{int e=luaK_exp2anyreg(fs,exp);
luaK_codeABx(fs,OP_SETGLOBAL,e,var->info);break;}case VINDEXED:{int e=
luaK_exp2RK(fs,exp);luaK_codeABC(fs,OP_SETTABLE,var->info,var->aux,e);break;}
default:{lua_assert(0);break;}}freeexp(fs,exp);}void luaK_self(FuncState*fs,
expdesc*e,expdesc*key){int func;luaK_exp2anyreg(fs,e);freeexp(fs,e);func=fs->
freereg;luaK_reserveregs(fs,2);luaK_codeABC(fs,OP_SELF,func,e->info,
luaK_exp2RK(fs,key));freeexp(fs,key);e->info=func;e->k=VNONRELOC;}static void 
invertjump(FuncState*fs,expdesc*e){Instruction*pc=getjumpcontrol(fs,e->info);
lua_assert(testOpMode(GET_OPCODE(*pc),OpModeT)&&GET_OPCODE(*pc)!=OP_TEST);
SETARG_A(*pc,!(GETARG_A(*pc)));}static int jumponcond(FuncState*fs,expdesc*e,
int cond){if(e->k==VRELOCABLE){Instruction ie=getcode(fs,e);if(GET_OPCODE(ie)
==OP_NOT){fs->pc--;return luaK_condjump(fs,OP_TEST,NO_REG,GETARG_B(ie),!cond);
}}discharge2anyreg(fs,e);freeexp(fs,e);return luaK_condjump(fs,OP_TEST,NO_REG,
e->info,cond);}void luaK_goiftrue(FuncState*fs,expdesc*e){int pc;
luaK_dischargevars(fs,e);switch(e->k){case VK:case VTRUE:{pc=NO_JUMP;break;}
case VFALSE:{pc=luaK_jump(fs);break;}case VJMP:{invertjump(fs,e);pc=e->info;
break;}default:{pc=jumponcond(fs,e,0);break;}}luaK_concat(fs,&e->f,pc);}void 
luaK_goiffalse(FuncState*fs,expdesc*e){int pc;luaK_dischargevars(fs,e);switch(
e->k){case VNIL:case VFALSE:{pc=NO_JUMP;break;}case VTRUE:{pc=luaK_jump(fs);
break;}case VJMP:{pc=e->info;break;}default:{pc=jumponcond(fs,e,1);break;}}
luaK_concat(fs,&e->t,pc);}static void codenot(FuncState*fs,expdesc*e){
luaK_dischargevars(fs,e);switch(e->k){case VNIL:case VFALSE:{e->k=VTRUE;break;
}case VK:case VTRUE:{e->k=VFALSE;break;}case VJMP:{invertjump(fs,e);break;}
case VRELOCABLE:case VNONRELOC:{discharge2anyreg(fs,e);freeexp(fs,e);e->info=
luaK_codeABC(fs,OP_NOT,0,e->info,0);e->k=VRELOCABLE;break;}default:{lua_assert
(0);break;}}{int temp=e->f;e->f=e->t;e->t=temp;}}void luaK_indexed(FuncState*
fs,expdesc*t,expdesc*k){t->aux=luaK_exp2RK(fs,k);t->k=VINDEXED;}void 
luaK_prefix(FuncState*fs,UnOpr op,expdesc*e){if(op==OPR_MINUS){luaK_exp2val(fs
,e);if(e->k==VK&&ttisnumber(&fs->f->k[e->info]))e->info=luaK_numberK(fs,-
nvalue(&fs->f->k[e->info]));else{luaK_exp2anyreg(fs,e);freeexp(fs,e);e->info=
luaK_codeABC(fs,OP_UNM,0,e->info,0);e->k=VRELOCABLE;}}else codenot(fs,e);}void
 luaK_infix(FuncState*fs,BinOpr op,expdesc*v){switch(op){case OPR_AND:{
luaK_goiftrue(fs,v);luaK_patchtohere(fs,v->t);v->t=NO_JUMP;break;}case OPR_OR:
{luaK_goiffalse(fs,v);luaK_patchtohere(fs,v->f);v->f=NO_JUMP;break;}case 
OPR_CONCAT:{luaK_exp2nextreg(fs,v);break;}default:{luaK_exp2RK(fs,v);break;}}}
static void codebinop(FuncState*fs,expdesc*res,BinOpr op,int o1,int o2){if(op
<=OPR_POW){OpCode opc=cast(OpCode,(op-OPR_ADD)+OP_ADD);res->info=luaK_codeABC(
fs,opc,0,o1,o2);res->k=VRELOCABLE;}else{static const OpCode ops[]={OP_EQ,OP_EQ
,OP_LT,OP_LE,OP_LT,OP_LE};int cond=1;if(op>=OPR_GT){int temp;temp=o1;o1=o2;o2=
temp;}else if(op==OPR_NE)cond=0;res->info=luaK_condjump(fs,ops[op-OPR_NE],cond
,o1,o2);res->k=VJMP;}}void luaK_posfix(FuncState*fs,BinOpr op,expdesc*e1,
expdesc*e2){switch(op){case OPR_AND:{lua_assert(e1->t==NO_JUMP);
luaK_dischargevars(fs,e2);luaK_concat(fs,&e1->f,e2->f);e1->k=e2->k;e1->info=e2
->info;e1->aux=e2->aux;e1->t=e2->t;break;}case OPR_OR:{lua_assert(e1->f==
NO_JUMP);luaK_dischargevars(fs,e2);luaK_concat(fs,&e1->t,e2->t);e1->k=e2->k;e1
->info=e2->info;e1->aux=e2->aux;e1->f=e2->f;break;}case OPR_CONCAT:{
luaK_exp2val(fs,e2);if(e2->k==VRELOCABLE&&GET_OPCODE(getcode(fs,e2))==
OP_CONCAT){lua_assert(e1->info==GETARG_B(getcode(fs,e2))-1);freeexp(fs,e1);
SETARG_B(getcode(fs,e2),e1->info);e1->k=e2->k;e1->info=e2->info;}else{
luaK_exp2nextreg(fs,e2);freeexp(fs,e2);freeexp(fs,e1);e1->info=luaK_codeABC(fs
,OP_CONCAT,0,e1->info,e2->info);e1->k=VRELOCABLE;}break;}default:{int o1=
luaK_exp2RK(fs,e1);int o2=luaK_exp2RK(fs,e2);freeexp(fs,e2);freeexp(fs,e1);
codebinop(fs,e1,op,o1,o2);}}}void luaK_fixline(FuncState*fs,int line){fs->f->
lineinfo[fs->pc-1]=line;}int luaK_code(FuncState*fs,Instruction i,int line){
Proto*f=fs->f;luaK_dischargejpc(fs);luaM_growvector(fs->L,f->code,fs->pc,f->
sizecode,Instruction,MAX_INT,"code size overflow");f->code[fs->pc]=i;
luaM_growvector(fs->L,f->lineinfo,fs->pc,f->sizelineinfo,int,MAX_INT,
"code size overflow");f->lineinfo[fs->pc]=line;return fs->pc++;}int 
luaK_codeABC(FuncState*fs,OpCode o,int a,int b,int c){lua_assert(getOpMode(o)
==iABC);return luaK_code(fs,CREATE_ABC(o,a,b,c),fs->ls->lastline);}int 
luaK_codeABx(FuncState*fs,OpCode o,int a,unsigned int bc){lua_assert(getOpMode
(o)==iABx||getOpMode(o)==iAsBx);return luaK_code(fs,CREATE_ABx(o,a,bc),fs->ls
->lastline);}
#line 1 "ldblib.c"
#define ldblib_c
static void settabss(lua_State*L,const char*i,const char*v){lua_pushstring(L,i
);lua_pushstring(L,v);lua_rawset(L,-3);}static void settabsi(lua_State*L,const
 char*i,int v){lua_pushstring(L,i);lua_pushnumber(L,(lua_Number)v);lua_rawset(
L,-3);}static int getinfo(lua_State*L){lua_Debug ar;const char*options=
luaL_optstring(L,2,"flnSu");if(lua_isnumber(L,1)){if(!lua_getstack(L,(int)(
lua_tonumber(L,1)),&ar)){lua_pushnil(L);return 1;}}else if(lua_isfunction(L,1)
){lua_pushfstring(L,">%s",options);options=lua_tostring(L,-1);lua_pushvalue(L,
1);}else return luaL_argerror(L,1,"function or level expected");if(!
lua_getinfo(L,options,&ar))return luaL_argerror(L,2,"invalid option");
lua_newtable(L);for(;*options;options++){switch(*options){case'S':settabss(L,
"source",ar.source);settabss(L,"short_src",ar.short_src);settabsi(L,
"linedefined",ar.linedefined);settabss(L,"what",ar.what);break;case'l':
settabsi(L,"currentline",ar.currentline);break;case'u':settabsi(L,"nups",ar.
nups);break;case'n':settabss(L,"name",ar.name);settabss(L,"namewhat",ar.
namewhat);break;case'f':lua_pushliteral(L,"func");lua_pushvalue(L,-3);
lua_rawset(L,-3);break;}}return 1;}static int getlocal(lua_State*L){lua_Debug 
ar;const char*name;if(!lua_getstack(L,luaL_checkint(L,1),&ar))return 
luaL_argerror(L,1,"level out of range");name=lua_getlocal(L,&ar,luaL_checkint(
L,2));if(name){lua_pushstring(L,name);lua_pushvalue(L,-2);return 2;}else{
lua_pushnil(L);return 1;}}static int setlocal(lua_State*L){lua_Debug ar;if(!
lua_getstack(L,luaL_checkint(L,1),&ar))return luaL_argerror(L,1,
"level out of range");luaL_checkany(L,3);lua_pushstring(L,lua_setlocal(L,&ar,
luaL_checkint(L,2)));return 1;}static int auxupvalue(lua_State*L,int get){
const char*name;int n=luaL_checkint(L,2);luaL_checktype(L,1,LUA_TFUNCTION);if(
lua_iscfunction(L,1))return 0;name=get?lua_getupvalue(L,1,n):lua_setupvalue(L,
1,n);if(name==NULL)return 0;lua_pushstring(L,name);lua_insert(L,-(get+1));
return get+1;}static int getupvalue(lua_State*L){return auxupvalue(L,1);}
static int setupvalue(lua_State*L){luaL_checkany(L,3);return auxupvalue(L,0);}
static const char KEY_HOOK='h';static void hookf(lua_State*L,lua_Debug*ar){
static const char*const hooknames[]={"call","return","line","count",
"tail return"};lua_pushlightuserdata(L,(void*)&KEY_HOOK);lua_rawget(L,
LUA_REGISTRYINDEX);if(lua_isfunction(L,-1)){lua_pushstring(L,hooknames[(int)ar
->event]);if(ar->currentline>=0)lua_pushnumber(L,(lua_Number)ar->currentline);
else lua_pushnil(L);lua_assert(lua_getinfo(L,"lS",ar));lua_call(L,2,0);}else 
lua_pop(L,1);}static int makemask(const char*smask,int count){int mask=0;if(
strchr(smask,'c'))mask|=LUA_MASKCALL;if(strchr(smask,'r'))mask|=LUA_MASKRET;if
(strchr(smask,'l'))mask|=LUA_MASKLINE;if(count>0)mask|=LUA_MASKCOUNT;return 
mask;}static char*unmakemask(int mask,char*smask){int i=0;if(mask&LUA_MASKCALL
)smask[i++]='c';if(mask&LUA_MASKRET)smask[i++]='r';if(mask&LUA_MASKLINE)smask[
i++]='l';smask[i]='\0';return smask;}static int sethook(lua_State*L){if(
lua_isnoneornil(L,1)){lua_settop(L,1);lua_sethook(L,NULL,0,0);}else{const char
*smask=luaL_checkstring(L,2);int count=luaL_optint(L,3,0);luaL_checktype(L,1,
LUA_TFUNCTION);lua_sethook(L,hookf,makemask(smask,count),count);}
lua_pushlightuserdata(L,(void*)&KEY_HOOK);lua_pushvalue(L,1);lua_rawset(L,
LUA_REGISTRYINDEX);return 0;}static int gethook(lua_State*L){char buff[5];int 
mask=lua_gethookmask(L);lua_Hook hook=lua_gethook(L);if(hook!=NULL&&hook!=
hookf)lua_pushliteral(L,"external hook");else{lua_pushlightuserdata(L,(void*)&
KEY_HOOK);lua_rawget(L,LUA_REGISTRYINDEX);}lua_pushstring(L,unmakemask(mask,
buff));lua_pushnumber(L,(lua_Number)lua_gethookcount(L));return 3;}static int 
debug(lua_State*L){for(;;){char buffer[250];fputs("lua_debug> ",stderr);if(
fgets(buffer,sizeof(buffer),stdin)==0||strcmp(buffer,"cont\n")==0)return 0;
lua_dostring(L,buffer);lua_settop(L,0);}}
#define LEVELS1 12
#define LEVELS2 10
static int errorfb(lua_State*L){int level=1;int firstpart=1;lua_Debug ar;if(
lua_gettop(L)==0)lua_pushliteral(L,"");else if(!lua_isstring(L,1))return 1;
else lua_pushliteral(L,"\n");lua_pushliteral(L,"stack traceback:");while(
lua_getstack(L,level++,&ar)){if(level>LEVELS1&&firstpart){if(!lua_getstack(L,
level+LEVELS2,&ar))level--;else{lua_pushliteral(L,"\n\t...");while(
lua_getstack(L,level+LEVELS2,&ar))level++;}firstpart=0;continue;}
lua_pushliteral(L,"\n\t");lua_getinfo(L,"Snl",&ar);lua_pushfstring(L,"%s:",ar.
short_src);if(ar.currentline>0)lua_pushfstring(L,"%d:",ar.currentline);switch(
*ar.namewhat){case'g':case'l':case'f':case'm':lua_pushfstring(L,
" in function `%s'",ar.name);break;default:{if(*ar.what=='m')lua_pushfstring(L
," in main chunk");else if(*ar.what=='C'||*ar.what=='t')lua_pushliteral(L," ?"
);else lua_pushfstring(L," in function <%s:%d>",ar.short_src,ar.linedefined);}
}lua_concat(L,lua_gettop(L));}lua_concat(L,lua_gettop(L));return 1;}static 
const luaL_reg dblib[]={{"getlocal",getlocal},{"getinfo",getinfo},{"gethook",
gethook},{"getupvalue",getupvalue},{"sethook",sethook},{"setlocal",setlocal},{
"setupvalue",setupvalue},{"debug",debug},{"traceback",errorfb},{NULL,NULL}};
LUALIB_API int luaopen_debug(lua_State*L){luaL_openlib(L,LUA_DBLIBNAME,dblib,0
);lua_pushliteral(L,"_TRACEBACK");lua_pushcfunction(L,errorfb);lua_settable(L,
LUA_GLOBALSINDEX);return 1;}
#line 1 "ldebug.c"
#define ldebug_c
static const char*getfuncname(CallInfo*ci,const char**name);
#define isLua(ci) (!((ci)->state&CI_C))
static int currentpc(CallInfo*ci){if(!isLua(ci))return-1;if(ci->state&
CI_HASFRAME)ci->u.l.savedpc=*ci->u.l.pc;return pcRel(ci->u.l.savedpc,ci_func(
ci)->l.p);}static int currentline(CallInfo*ci){int pc=currentpc(ci);if(pc<0)
return-1;else return getline(ci_func(ci)->l.p,pc);}void luaG_inithooks(
lua_State*L){CallInfo*ci;for(ci=L->ci;ci!=L->base_ci;ci--)currentpc(ci);L->
hookinit=1;}LUA_API int lua_sethook(lua_State*L,lua_Hook func,int mask,int 
count){if(func==NULL||mask==0){mask=0;func=NULL;}L->hook=func;L->basehookcount
=count;resethookcount(L);L->hookmask=cast(lu_byte,mask);L->hookinit=0;return 1
;}LUA_API lua_Hook lua_gethook(lua_State*L){return L->hook;}LUA_API int 
lua_gethookmask(lua_State*L){return L->hookmask;}LUA_API int lua_gethookcount(
lua_State*L){return L->basehookcount;}LUA_API int lua_getstack(lua_State*L,int
 level,lua_Debug*ar){int status;CallInfo*ci;lua_lock(L);for(ci=L->ci;level>0&&
ci>L->base_ci;ci--){level--;if(!(ci->state&CI_C))level-=ci->u.l.tailcalls;}if(
level>0||ci==L->base_ci)status=0;else if(level<0){status=1;ar->i_ci=0;}else{
status=1;ar->i_ci=ci-L->base_ci;}lua_unlock(L);return status;}static Proto*
getluaproto(CallInfo*ci){return(isLua(ci)?ci_func(ci)->l.p:NULL);}LUA_API 
const char*lua_getlocal(lua_State*L,const lua_Debug*ar,int n){const char*name;
CallInfo*ci;Proto*fp;lua_lock(L);name=NULL;ci=L->base_ci+ar->i_ci;fp=
getluaproto(ci);if(fp){name=luaF_getlocalname(fp,n,currentpc(ci));if(name)
luaA_pushobject(L,ci->base+(n-1));}lua_unlock(L);return name;}LUA_API const 
char*lua_setlocal(lua_State*L,const lua_Debug*ar,int n){const char*name;
CallInfo*ci;Proto*fp;lua_lock(L);name=NULL;ci=L->base_ci+ar->i_ci;fp=
getluaproto(ci);L->top--;if(fp){name=luaF_getlocalname(fp,n,currentpc(ci));if(
!name||name[0]=='(')name=NULL;else setobjs2s(ci->base+(n-1),L->top);}
lua_unlock(L);return name;}static void funcinfo(lua_Debug*ar,StkId func){
Closure*cl=clvalue(func);if(cl->c.isC){ar->source="=[C]";ar->linedefined=-1;ar
->what="C";}else{ar->source=getstr(cl->l.p->source);ar->linedefined=cl->l.p->
lineDefined;ar->what=(ar->linedefined==0)?"main":"Lua";}luaO_chunkid(ar->
short_src,ar->source,LUA_IDSIZE);}static const char*travglobals(lua_State*L,
const TObject*o){Table*g=hvalue(gt(L));int i=sizenode(g);while(i--){Node*n=
gnode(g,i);if(luaO_rawequalObj(o,gval(n))&&ttisstring(gkey(n)))return getstr(
tsvalue(gkey(n)));}return NULL;}static void info_tailcall(lua_State*L,
lua_Debug*ar){ar->name=ar->namewhat="";ar->what="tail";ar->linedefined=ar->
currentline=-1;ar->source="=(tail call)";luaO_chunkid(ar->short_src,ar->source
,LUA_IDSIZE);ar->nups=0;setnilvalue(L->top);}static int auxgetinfo(lua_State*L
,const char*what,lua_Debug*ar,StkId f,CallInfo*ci){int status=1;for(;*what;
what++){switch(*what){case'S':{funcinfo(ar,f);break;}case'l':{ar->currentline=
(ci)?currentline(ci):-1;break;}case'u':{ar->nups=clvalue(f)->c.nupvalues;break
;}case'n':{ar->namewhat=(ci)?getfuncname(ci,&ar->name):NULL;if(ar->namewhat==
NULL){if((ar->name=travglobals(L,f))!=NULL)ar->namewhat="global";else ar->
namewhat="";}break;}case'f':{setobj2s(L->top,f);break;}default:status=0;}}
return status;}LUA_API int lua_getinfo(lua_State*L,const char*what,lua_Debug*
ar){int status=1;lua_lock(L);if(*what=='>'){StkId f=L->top-1;if(!ttisfunction(
f))luaG_runerror(L,"value for `lua_getinfo' is not a function");status=
auxgetinfo(L,what+1,ar,f,NULL);L->top--;}else if(ar->i_ci!=0){CallInfo*ci=L->
base_ci+ar->i_ci;lua_assert(ttisfunction(ci->base-1));status=auxgetinfo(L,what
,ar,ci->base-1,ci);}else info_tailcall(L,ar);if(strchr(what,'f'))incr_top(L);
lua_unlock(L);return status;}
#define check(x) if(!(x))return 0;
#define checkjump(pt,pc) check(0<=pc&&pc<pt->sizecode)
#define checkreg(pt,reg) check((reg)<(pt)->maxstacksize)
static int precheck(const Proto*pt){check(pt->maxstacksize<=MAXSTACK);check(pt
->sizelineinfo==pt->sizecode||pt->sizelineinfo==0);lua_assert(pt->numparams+pt
->is_vararg<=pt->maxstacksize);check(GET_OPCODE(pt->code[pt->sizecode-1])==
OP_RETURN);return 1;}static int checkopenop(const Proto*pt,int pc){Instruction
 i=pt->code[pc+1];switch(GET_OPCODE(i)){case OP_CALL:case OP_TAILCALL:case 
OP_RETURN:{check(GETARG_B(i)==0);return 1;}case OP_SETLISTO:return 1;default:
return 0;}}static int checkRK(const Proto*pt,int r){return(r<pt->maxstacksize
||(r>=MAXSTACK&&r-MAXSTACK<pt->sizek));}static Instruction luaG_symbexec(const
 Proto*pt,int lastpc,int reg){int pc;int last;last=pt->sizecode-1;check(
precheck(pt));for(pc=0;pc<lastpc;pc++){const Instruction i=pt->code[pc];OpCode
 op=GET_OPCODE(i);int a=GETARG_A(i);int b=0;int c=0;checkreg(pt,a);switch(
getOpMode(op)){case iABC:{b=GETARG_B(i);c=GETARG_C(i);if(testOpMode(op,
OpModeBreg)){checkreg(pt,b);}else if(testOpMode(op,OpModeBrk))check(checkRK(pt
,b));if(testOpMode(op,OpModeCrk))check(checkRK(pt,c));break;}case iABx:{b=
GETARG_Bx(i);if(testOpMode(op,OpModeK))check(b<pt->sizek);break;}case iAsBx:{b
=GETARG_sBx(i);break;}}if(testOpMode(op,OpModesetA)){if(a==reg)last=pc;}if(
testOpMode(op,OpModeT)){check(pc+2<pt->sizecode);check(GET_OPCODE(pt->code[pc+
1])==OP_JMP);}switch(op){case OP_LOADBOOL:{check(c==0||pc+2<pt->sizecode);
break;}case OP_LOADNIL:{if(a<=reg&&reg<=b)last=pc;break;}case OP_GETUPVAL:case
 OP_SETUPVAL:{check(b<pt->nups);break;}case OP_GETGLOBAL:case OP_SETGLOBAL:{
check(ttisstring(&pt->k[b]));break;}case OP_SELF:{checkreg(pt,a+1);if(reg==a+1
)last=pc;break;}case OP_CONCAT:{check(c<MAXSTACK&&b<c);break;}case OP_TFORLOOP
:checkreg(pt,a+c+5);if(reg>=a)last=pc;case OP_FORLOOP:checkreg(pt,a+2);case 
OP_JMP:{int dest=pc+1+b;check(0<=dest&&dest<pt->sizecode);if(reg!=NO_REG&&pc<
dest&&dest<=lastpc)pc+=b;break;}case OP_CALL:case OP_TAILCALL:{if(b!=0){
checkreg(pt,a+b-1);}c--;if(c==LUA_MULTRET){check(checkopenop(pt,pc));}else if(
c!=0)checkreg(pt,a+c-1);if(reg>=a)last=pc;break;}case OP_RETURN:{b--;if(b>0)
checkreg(pt,a+b-1);break;}case OP_SETLIST:{checkreg(pt,a+(b&(LFIELDS_PER_FLUSH
-1))+1);break;}case OP_CLOSURE:{int nup;check(b<pt->sizep);nup=pt->p[b]->nups;
check(pc+nup<pt->sizecode);for(;nup>0;nup--){OpCode op1=GET_OPCODE(pt->code[pc
+nup]);check(op1==OP_GETUPVAL||op1==OP_MOVE);}break;}default:break;}}return pt
->code[last];}
#undef check
#undef checkjump
#undef checkreg
int luaG_checkcode(const Proto*pt){return luaG_symbexec(pt,pt->sizecode,NO_REG
);}static const char*kname(Proto*p,int c){c=c-MAXSTACK;if(c>=0&&ttisstring(&p
->k[c]))return svalue(&p->k[c]);else return"?";}static const char*getobjname(
CallInfo*ci,int stackpos,const char**name){if(isLua(ci)){Proto*p=ci_func(ci)->
l.p;int pc=currentpc(ci);Instruction i;*name=luaF_getlocalname(p,stackpos+1,pc
);if(*name)return"local";i=luaG_symbexec(p,pc,stackpos);lua_assert(pc!=-1);
switch(GET_OPCODE(i)){case OP_GETGLOBAL:{int g=GETARG_Bx(i);lua_assert(
ttisstring(&p->k[g]));*name=svalue(&p->k[g]);return"global";}case OP_MOVE:{int
 a=GETARG_A(i);int b=GETARG_B(i);if(b<a)return getobjname(ci,b,name);break;}
case OP_GETTABLE:{int k=GETARG_C(i);*name=kname(p,k);return"field";}case 
OP_SELF:{int k=GETARG_C(i);*name=kname(p,k);return"method";}default:break;}}
return NULL;}static const char*getfuncname(CallInfo*ci,const char**name){
Instruction i;if((isLua(ci)&&ci->u.l.tailcalls>0)||!isLua(ci-1))return NULL;ci
--;i=ci_func(ci)->l.p->code[currentpc(ci)];if(GET_OPCODE(i)==OP_CALL||
GET_OPCODE(i)==OP_TAILCALL)return getobjname(ci,GETARG_A(i),name);else return 
NULL;}static int isinstack(CallInfo*ci,const TObject*o){StkId p;for(p=ci->base
;p<ci->top;p++)if(o==p)return 1;return 0;}void luaG_typeerror(lua_State*L,
const TObject*o,const char*op){const char*name=NULL;const char*t=
luaT_typenames[ttype(o)];const char*kind=(isinstack(L->ci,o))?getobjname(L->ci
,o-L->base,&name):NULL;if(kind)luaG_runerror(L,
"attempt to %s %s `%s' (a %s value)",op,kind,name,t);else luaG_runerror(L,
"attempt to %s a %s value",op,t);}void luaG_concaterror(lua_State*L,StkId p1,
StkId p2){if(ttisstring(p1))p1=p2;lua_assert(!ttisstring(p1));luaG_typeerror(L
,p1,"concatenate");}void luaG_aritherror(lua_State*L,const TObject*p1,const 
TObject*p2){TObject temp;if(luaV_tonumber(p1,&temp)==NULL)p2=p1;luaG_typeerror
(L,p2,"perform arithmetic on");}int luaG_ordererror(lua_State*L,const TObject*
p1,const TObject*p2){const char*t1=luaT_typenames[ttype(p1)];const char*t2=
luaT_typenames[ttype(p2)];if(t1[2]==t2[2])luaG_runerror(L,
"attempt to compare two %s values",t1);else luaG_runerror(L,
"attempt to compare %s with %s",t1,t2);return 0;}static void addinfo(lua_State
*L,const char*msg){CallInfo*ci=L->ci;if(isLua(ci)){char buff[LUA_IDSIZE];int 
line=currentline(ci);luaO_chunkid(buff,getstr(getluaproto(ci)->source),
LUA_IDSIZE);luaO_pushfstring(L,"%s:%d: %s",buff,line,msg);}}void luaG_errormsg
(lua_State*L){if(L->errfunc!=0){StkId errfunc=restorestack(L,L->errfunc);if(!
ttisfunction(errfunc))luaD_throw(L,LUA_ERRERR);setobjs2s(L->top,L->top-1);
setobjs2s(L->top-1,errfunc);incr_top(L);luaD_call(L,L->top-2,1);}luaD_throw(L,
LUA_ERRRUN);}void luaG_runerror(lua_State*L,const char*fmt,...){va_list argp;
va_start(argp,fmt);addinfo(L,luaO_pushvfstring(L,fmt,argp));va_end(argp);
luaG_errormsg(L);}
#line 1 "ldo.c"
#define ldo_c
struct lua_longjmp{struct lua_longjmp*previous;jmp_buf b;volatile int status;}
;static void seterrorobj(lua_State*L,int errcode,StkId oldtop){switch(errcode)
{case LUA_ERRMEM:{setsvalue2s(oldtop,luaS_new(L,MEMERRMSG));break;}case 
LUA_ERRERR:{setsvalue2s(oldtop,luaS_new(L,"error in error handling"));break;}
case LUA_ERRSYNTAX:case LUA_ERRRUN:{setobjs2s(oldtop,L->top-1);break;}}L->top=
oldtop+1;}void luaD_throw(lua_State*L,int errcode){if(L->errorJmp){L->errorJmp
->status=errcode;longjmp(L->errorJmp->b,1);}else{G(L)->panic(L);exit(
EXIT_FAILURE);}}int luaD_rawrunprotected(lua_State*L,Pfunc f,void*ud){struct 
lua_longjmp lj;lj.status=0;lj.previous=L->errorJmp;L->errorJmp=&lj;if(setjmp(
lj.b)==0)(*f)(L,ud);L->errorJmp=lj.previous;return lj.status;}static void 
restore_stack_limit(lua_State*L){L->stack_last=L->stack+L->stacksize-1;if(L->
size_ci>LUA_MAXCALLS){int inuse=(L->ci-L->base_ci);if(inuse+1<LUA_MAXCALLS)
luaD_reallocCI(L,LUA_MAXCALLS);}}static void correctstack(lua_State*L,TObject*
oldstack){CallInfo*ci;GCObject*up;L->top=(L->top-oldstack)+L->stack;for(up=L->
openupval;up!=NULL;up=up->gch.next)gcotouv(up)->v=(gcotouv(up)->v-oldstack)+L
->stack;for(ci=L->base_ci;ci<=L->ci;ci++){ci->top=(ci->top-oldstack)+L->stack;
ci->base=(ci->base-oldstack)+L->stack;}L->base=L->ci->base;}void 
luaD_reallocstack(lua_State*L,int newsize){TObject*oldstack=L->stack;
luaM_reallocvector(L,L->stack,L->stacksize,newsize,TObject);L->stacksize=
newsize;L->stack_last=L->stack+newsize-1-EXTRA_STACK;correctstack(L,oldstack);
}void luaD_reallocCI(lua_State*L,int newsize){CallInfo*oldci=L->base_ci;
luaM_reallocvector(L,L->base_ci,L->size_ci,newsize,CallInfo);L->size_ci=cast(
unsigned short,newsize);L->ci=(L->ci-oldci)+L->base_ci;L->end_ci=L->base_ci+L
->size_ci;}void luaD_growstack(lua_State*L,int n){if(n<=L->stacksize)
luaD_reallocstack(L,2*L->stacksize);else luaD_reallocstack(L,L->stacksize+n+
EXTRA_STACK);}static void luaD_growCI(lua_State*L){if(L->size_ci>LUA_MAXCALLS)
luaD_throw(L,LUA_ERRERR);else{luaD_reallocCI(L,2*L->size_ci);if(L->size_ci>
LUA_MAXCALLS)luaG_runerror(L,"stack overflow");}}void luaD_callhook(lua_State*
L,int event,int line){lua_Hook hook=L->hook;if(hook&&L->allowhook){ptrdiff_t 
top=savestack(L,L->top);ptrdiff_t ci_top=savestack(L,L->ci->top);lua_Debug ar;
ar.event=event;ar.currentline=line;if(event==LUA_HOOKTAILRET)ar.i_ci=0;else ar
.i_ci=L->ci-L->base_ci;luaD_checkstack(L,LUA_MINSTACK);L->ci->top=L->top+
LUA_MINSTACK;L->allowhook=0;lua_unlock(L);(*hook)(L,&ar);lua_lock(L);
lua_assert(!L->allowhook);L->allowhook=1;L->ci->top=restorestack(L,ci_top);L->
top=restorestack(L,top);}}static void adjust_varargs(lua_State*L,int nfixargs,
StkId base){int i;Table*htab;TObject nname;int actual=L->top-base;if(actual<
nfixargs){luaD_checkstack(L,nfixargs-actual);for(;actual<nfixargs;++actual)
setnilvalue(L->top++);}actual-=nfixargs;htab=luaH_new(L,actual,1);for(i=0;i<
actual;i++)setobj2n(luaH_setnum(L,htab,i+1),L->top-actual+i);setsvalue(&nname,
luaS_newliteral(L,"n"));setnvalue(luaH_set(L,htab,&nname),cast(lua_Number,
actual));L->top-=actual;sethvalue(L->top,htab);incr_top(L);}static StkId 
tryfuncTM(lua_State*L,StkId func){const TObject*tm=luaT_gettmbyobj(L,func,
TM_CALL);StkId p;ptrdiff_t funcr=savestack(L,func);if(!ttisfunction(tm))
luaG_typeerror(L,func,"call");for(p=L->top;p>func;p--)setobjs2s(p,p-1);
incr_top(L);func=restorestack(L,funcr);setobj2s(func,tm);return func;}StkId 
luaD_precall(lua_State*L,StkId func){LClosure*cl;ptrdiff_t funcr=savestack(L,
func);if(!ttisfunction(func))func=tryfuncTM(L,func);if(L->ci+1==L->end_ci)
luaD_growCI(L);else condhardstacktests(luaD_reallocCI(L,L->size_ci));cl=&
clvalue(func)->l;if(!cl->isC){CallInfo*ci;Proto*p=cl->p;if(p->is_vararg)
adjust_varargs(L,p->numparams,func+1);luaD_checkstack(L,p->maxstacksize);ci=++
L->ci;L->base=L->ci->base=restorestack(L,funcr)+1;ci->top=L->base+p->
maxstacksize;ci->u.l.savedpc=p->code;ci->u.l.tailcalls=0;ci->state=CI_SAVEDPC;
while(L->top<ci->top)setnilvalue(L->top++);L->top=ci->top;return NULL;}else{
CallInfo*ci;int n;luaD_checkstack(L,LUA_MINSTACK);ci=++L->ci;L->base=L->ci->
base=restorestack(L,funcr)+1;ci->top=L->top+LUA_MINSTACK;ci->state=CI_C;if(L->
hookmask&LUA_MASKCALL)luaD_callhook(L,LUA_HOOKCALL,-1);lua_unlock(L);
#ifdef LUA_COMPATUPVALUES
lua_pushupvalues(L);
#endif
n=(*clvalue(L->base-1)->c.f)(L);lua_lock(L);return L->top-n;}}static StkId 
callrethooks(lua_State*L,StkId firstResult){ptrdiff_t fr=savestack(L,
firstResult);luaD_callhook(L,LUA_HOOKRET,-1);if(!(L->ci->state&CI_C)){while(L
->ci->u.l.tailcalls--)luaD_callhook(L,LUA_HOOKTAILRET,-1);}return restorestack
(L,fr);}void luaD_poscall(lua_State*L,int wanted,StkId firstResult){StkId res;
if(L->hookmask&LUA_MASKRET)firstResult=callrethooks(L,firstResult);res=L->base
-1;L->ci--;L->base=L->ci->base;while(wanted!=0&&firstResult<L->top){setobjs2s(
res++,firstResult++);wanted--;}while(wanted-->0)setnilvalue(res++);L->top=res;
}void luaD_call(lua_State*L,StkId func,int nResults){StkId firstResult;
lua_assert(!(L->ci->state&CI_CALLING));if(++L->nCcalls>=LUA_MAXCCALLS){if(L->
nCcalls==LUA_MAXCCALLS)luaG_runerror(L,"C stack overflow");else if(L->nCcalls
>=(LUA_MAXCCALLS+(LUA_MAXCCALLS>>3)))luaD_throw(L,LUA_ERRERR);}firstResult=
luaD_precall(L,func);if(firstResult==NULL)firstResult=luaV_execute(L);
luaD_poscall(L,nResults,firstResult);L->nCcalls--;luaC_checkGC(L);}static void
 resume(lua_State*L,void*ud){StkId firstResult;int nargs=*cast(int*,ud);
CallInfo*ci=L->ci;if(ci==L->base_ci){lua_assert(nargs<L->top-L->base);
luaD_precall(L,L->top-(nargs+1));}else{lua_assert(ci->state&CI_YIELD);if(ci->
state&CI_C){int nresults;lua_assert((ci-1)->state&CI_SAVEDPC);lua_assert(
GET_OPCODE(*((ci-1)->u.l.savedpc-1))==OP_CALL||GET_OPCODE(*((ci-1)->u.l.
savedpc-1))==OP_TAILCALL);nresults=GETARG_C(*((ci-1)->u.l.savedpc-1))-1;
luaD_poscall(L,nresults,L->top-nargs);if(nresults>=0)L->top=L->ci->top;}else{
ci->state&=~CI_YIELD;}}firstResult=luaV_execute(L);if(firstResult!=NULL)
luaD_poscall(L,LUA_MULTRET,firstResult);}static int resume_error(lua_State*L,
const char*msg){L->top=L->ci->base;setsvalue2s(L->top,luaS_new(L,msg));
incr_top(L);lua_unlock(L);return LUA_ERRRUN;}LUA_API int lua_resume(lua_State*
L,int nargs){int status;lu_byte old_allowhooks;lua_lock(L);if(L->ci==L->
base_ci){if(nargs>=L->top-L->base)return resume_error(L,
"cannot resume dead coroutine");}else if(!(L->ci->state&CI_YIELD))return 
resume_error(L,"cannot resume non-suspended coroutine");old_allowhooks=L->
allowhook;lua_assert(L->errfunc==0&&L->nCcalls==0);status=luaD_rawrunprotected
(L,resume,&nargs);if(status!=0){L->ci=L->base_ci;L->base=L->ci->base;L->
nCcalls=0;luaF_close(L,L->base);seterrorobj(L,status,L->base);L->allowhook=
old_allowhooks;restore_stack_limit(L);}lua_unlock(L);return status;}LUA_API 
int lua_yield(lua_State*L,int nresults){CallInfo*ci;lua_lock(L);ci=L->ci;if(L
->nCcalls>0)luaG_runerror(L,
"attempt to yield across metamethod/C-call boundary");if(ci->state&CI_C){if((
ci-1)->state&CI_C)luaG_runerror(L,"cannot yield a C function");if(L->top-
nresults>L->base){int i;for(i=0;i<nresults;i++)setobjs2s(L->base+i,L->top-
nresults+i);L->top=L->base+nresults;}}ci->state|=CI_YIELD;lua_unlock(L);return
-1;}int luaD_pcall(lua_State*L,Pfunc func,void*u,ptrdiff_t old_top,ptrdiff_t 
ef){int status;unsigned short oldnCcalls=L->nCcalls;ptrdiff_t old_ci=saveci(L,
L->ci);lu_byte old_allowhooks=L->allowhook;ptrdiff_t old_errfunc=L->errfunc;L
->errfunc=ef;status=luaD_rawrunprotected(L,func,u);if(status!=0){StkId oldtop=
restorestack(L,old_top);luaF_close(L,oldtop);seterrorobj(L,status,oldtop);L->
nCcalls=oldnCcalls;L->ci=restoreci(L,old_ci);L->base=L->ci->base;L->allowhook=
old_allowhooks;restore_stack_limit(L);}L->errfunc=old_errfunc;return status;}
struct SParser{ZIO*z;Mbuffer buff;int bin;};static void f_parser(lua_State*L,
void*ud){struct SParser*p;Proto*tf;Closure*cl;luaC_checkGC(L);p=cast(struct 
SParser*,ud);tf=p->bin?luaU_undump(L,p->z,&p->buff):luaY_parser(L,p->z,&p->
buff);cl=luaF_newLclosure(L,0,gt(L));cl->l.p=tf;setclvalue(L->top,cl);incr_top
(L);}int luaD_protectedparser(lua_State*L,ZIO*z,int bin){struct SParser p;int 
status;ptrdiff_t oldtopr=savestack(L,L->top);p.z=z;p.bin=bin;luaZ_initbuffer(L
,&p.buff);status=luaD_rawrunprotected(L,f_parser,&p);luaZ_freebuffer(L,&p.buff
);if(status!=0){StkId oldtop=restorestack(L,oldtopr);seterrorobj(L,status,
oldtop);}return status;}
#line 1 "ldump.c"
#define ldump_c
#define DumpVector(b,n,size,D) DumpBlock(b,(n)*(size),D)
#define DumpLiteral(s,D) DumpBlock(""s,(sizeof(s))-1,D)
typedef struct{lua_State*L;lua_Chunkwriter write;void*data;}DumpState;static 
void DumpBlock(const void*b,size_t size,DumpState*D){lua_unlock(D->L);(*D->
write)(D->L,b,size,D->data);lua_lock(D->L);}static void DumpByte(int y,
DumpState*D){char x=(char)y;DumpBlock(&x,sizeof(x),D);}static void DumpInt(int
 x,DumpState*D){DumpBlock(&x,sizeof(x),D);}static void DumpSize(size_t x,
DumpState*D){DumpBlock(&x,sizeof(x),D);}static void DumpNumber(lua_Number x,
DumpState*D){DumpBlock(&x,sizeof(x),D);}static void DumpString(TString*s,
DumpState*D){if(s==NULL||getstr(s)==NULL)DumpSize(0,D);else{size_t size=s->tsv
.len+1;DumpSize(size,D);DumpBlock(getstr(s),size,D);}}static void DumpCode(
const Proto*f,DumpState*D){DumpInt(f->sizecode,D);DumpVector(f->code,f->
sizecode,sizeof(*f->code),D);}static void DumpLocals(const Proto*f,DumpState*D
){int i,n=f->sizelocvars;DumpInt(n,D);for(i=0;i<n;i++){DumpString(f->locvars[i
].varname,D);DumpInt(f->locvars[i].startpc,D);DumpInt(f->locvars[i].endpc,D);}
}static void DumpLines(const Proto*f,DumpState*D){DumpInt(f->sizelineinfo,D);
DumpVector(f->lineinfo,f->sizelineinfo,sizeof(*f->lineinfo),D);}static void 
DumpUpvalues(const Proto*f,DumpState*D){int i,n=f->sizeupvalues;DumpInt(n,D);
for(i=0;i<n;i++)DumpString(f->upvalues[i],D);}static void DumpFunction(const 
Proto*f,const TString*p,DumpState*D);static void DumpConstants(const Proto*f,
DumpState*D){int i,n;DumpInt(n=f->sizek,D);for(i=0;i<n;i++){const TObject*o=&f
->k[i];DumpByte(ttype(o),D);switch(ttype(o)){case LUA_TNUMBER:DumpNumber(
nvalue(o),D);break;case LUA_TSTRING:DumpString(tsvalue(o),D);break;case 
LUA_TNIL:break;default:lua_assert(0);break;}}DumpInt(n=f->sizep,D);for(i=0;i<n
;i++)DumpFunction(f->p[i],f->source,D);}static void DumpFunction(const Proto*f
,const TString*p,DumpState*D){DumpString((f->source==p)?NULL:f->source,D);
DumpInt(f->lineDefined,D);DumpByte(f->nups,D);DumpByte(f->numparams,D);
DumpByte(f->is_vararg,D);DumpByte(f->maxstacksize,D);DumpLines(f,D);DumpLocals
(f,D);DumpUpvalues(f,D);DumpConstants(f,D);DumpCode(f,D);}static void 
DumpHeader(DumpState*D){DumpLiteral(LUA_SIGNATURE,D);DumpByte(VERSION,D);
DumpByte(luaU_endianness(),D);DumpByte(sizeof(int),D);DumpByte(sizeof(size_t),
D);DumpByte(sizeof(Instruction),D);DumpByte(SIZE_OP,D);DumpByte(SIZE_A,D);
DumpByte(SIZE_B,D);DumpByte(SIZE_C,D);DumpByte(sizeof(lua_Number),D);
DumpNumber(TEST_NUMBER,D);}void luaU_dump(lua_State*L,const Proto*Main,
lua_Chunkwriter w,void*data){DumpState D;D.L=L;D.write=w;D.data=data;
DumpHeader(&D);DumpFunction(Main,NULL,&D);}
#line 1 "lfunc.c"
#define lfunc_c
#define sizeCclosure(n) (cast(int,sizeof(CClosure))+cast(int,sizeof(TObject)*(\
(n)-1)))
#define sizeLclosure(n) (cast(int,sizeof(LClosure))+cast(int,sizeof(TObject*)*\
((n)-1)))
Closure*luaF_newCclosure(lua_State*L,int nelems){Closure*c=cast(Closure*,
luaM_malloc(L,sizeCclosure(nelems)));luaC_link(L,valtogco(c),LUA_TFUNCTION);c
->c.isC=1;c->c.nupvalues=cast(lu_byte,nelems);return c;}Closure*
luaF_newLclosure(lua_State*L,int nelems,TObject*e){Closure*c=cast(Closure*,
luaM_malloc(L,sizeLclosure(nelems)));luaC_link(L,valtogco(c),LUA_TFUNCTION);c
->l.isC=0;c->l.g=*e;c->l.nupvalues=cast(lu_byte,nelems);return c;}UpVal*
luaF_findupval(lua_State*L,StkId level){GCObject**pp=&L->openupval;UpVal*p;
UpVal*v;while((p=ngcotouv(*pp))!=NULL&&p->v>=level){if(p->v==level)return p;pp
=&p->next;}v=luaM_new(L,UpVal);v->tt=LUA_TUPVAL;v->marked=1;v->v=level;v->next
=*pp;*pp=valtogco(v);return v;}void luaF_close(lua_State*L,StkId level){UpVal*
p;while((p=ngcotouv(L->openupval))!=NULL&&p->v>=level){setobj(&p->value,p->v);
p->v=&p->value;L->openupval=p->next;luaC_link(L,valtogco(p),LUA_TUPVAL);}}
Proto*luaF_newproto(lua_State*L){Proto*f=luaM_new(L,Proto);luaC_link(L,
valtogco(f),LUA_TPROTO);f->k=NULL;f->sizek=0;f->p=NULL;f->sizep=0;f->code=NULL
;f->sizecode=0;f->sizelineinfo=0;f->sizeupvalues=0;f->nups=0;f->upvalues=NULL;
f->numparams=0;f->is_vararg=0;f->maxstacksize=0;f->lineinfo=NULL;f->
sizelocvars=0;f->locvars=NULL;f->lineDefined=0;f->source=NULL;return f;}void 
luaF_freeproto(lua_State*L,Proto*f){luaM_freearray(L,f->code,f->sizecode,
Instruction);luaM_freearray(L,f->p,f->sizep,Proto*);luaM_freearray(L,f->k,f->
sizek,TObject);luaM_freearray(L,f->lineinfo,f->sizelineinfo,int);
luaM_freearray(L,f->locvars,f->sizelocvars,struct LocVar);luaM_freearray(L,f->
upvalues,f->sizeupvalues,TString*);luaM_freelem(L,f);}void luaF_freeclosure(
lua_State*L,Closure*c){int size=(c->c.isC)?sizeCclosure(c->c.nupvalues):
sizeLclosure(c->l.nupvalues);luaM_free(L,c,size);}const char*luaF_getlocalname
(const Proto*f,int local_number,int pc){int i;for(i=0;i<f->sizelocvars&&f->
locvars[i].startpc<=pc;i++){if(pc<f->locvars[i].endpc){local_number--;if(
local_number==0)return getstr(f->locvars[i].varname);}}return NULL;}
#line 1 "lgc.c"
#define lgc_c
typedef struct GCState{GCObject*tmark;GCObject*wk;GCObject*wv;GCObject*wkv;
global_State*g;}GCState;
#define setbit(x,b) ((x)|=(1<<(b)))
#define resetbit(x,b) ((x)&=cast(lu_byte,~(1<<(b))))
#define testbit(x,b) ((x)&(1<<(b)))
#define unmark(x) resetbit((x)->gch.marked,0)
#define ismarked(x) ((x)->gch.marked&((1<<4)|1))
#define stringmark(s) setbit((s)->tsv.marked,0)
#define isfinalized(u) (!testbit((u)->uv.marked,1))
#define markfinalized(u) resetbit((u)->uv.marked,1)
#define KEYWEAKBIT 1
#define VALUEWEAKBIT 2
#define KEYWEAK (1<<KEYWEAKBIT)
#define VALUEWEAK (1<<VALUEWEAKBIT)
#define markobject(st,o) {checkconsistency(o);if(iscollectable(o)&&!ismarked(\
gcvalue(o)))reallymarkobject(st,gcvalue(o));}
#define condmarkobject(st,o,c) {checkconsistency(o);if(iscollectable(o)&&!\
ismarked(gcvalue(o))&&(c))reallymarkobject(st,gcvalue(o));}
#define markvalue(st,t) {if(!ismarked(valtogco(t)))reallymarkobject(st,\
valtogco(t));}
static void reallymarkobject(GCState*st,GCObject*o){lua_assert(!ismarked(o));
setbit(o->gch.marked,0);switch(o->gch.tt){case LUA_TUSERDATA:{markvalue(st,
gcotou(o)->uv.metatable);break;}case LUA_TFUNCTION:{gcotocl(o)->c.gclist=st->
tmark;st->tmark=o;break;}case LUA_TTABLE:{gcotoh(o)->gclist=st->tmark;st->
tmark=o;break;}case LUA_TTHREAD:{gcototh(o)->gclist=st->tmark;st->tmark=o;
break;}case LUA_TPROTO:{gcotop(o)->gclist=st->tmark;st->tmark=o;break;}default
:lua_assert(o->gch.tt==LUA_TSTRING);}}static void marktmu(GCState*st){GCObject
*u;for(u=st->g->tmudata;u;u=u->gch.next){unmark(u);reallymarkobject(st,u);}}
size_t luaC_separateudata(lua_State*L){size_t deadmem=0;GCObject**p=&G(L)->
rootudata;GCObject*curr;GCObject*collected=NULL;GCObject**lastcollected=&
collected;while((curr=*p)!=NULL){lua_assert(curr->gch.tt==LUA_TUSERDATA);if(
ismarked(curr)||isfinalized(gcotou(curr)))p=&curr->gch.next;else if(fasttm(L,
gcotou(curr)->uv.metatable,TM_GC)==NULL){markfinalized(gcotou(curr));p=&curr->
gch.next;}else{deadmem+=sizeudata(gcotou(curr)->uv.len);*p=curr->gch.next;curr
->gch.next=NULL;*lastcollected=curr;lastcollected=&curr->gch.next;}}*
lastcollected=G(L)->tmudata;G(L)->tmudata=collected;return deadmem;}static 
void removekey(Node*n){setnilvalue(gval(n));if(iscollectable(gkey(n)))setttype
(gkey(n),LUA_TNONE);}static void traversetable(GCState*st,Table*h){int i;int 
weakkey=0;int weakvalue=0;const TObject*mode;markvalue(st,h->metatable);
lua_assert(h->lsizenode||h->node==st->g->dummynode);mode=gfasttm(st->g,h->
metatable,TM_MODE);if(mode&&ttisstring(mode)){weakkey=(strchr(svalue(mode),'k'
)!=NULL);weakvalue=(strchr(svalue(mode),'v')!=NULL);if(weakkey||weakvalue){
GCObject**weaklist;h->marked&=~(KEYWEAK|VALUEWEAK);h->marked|=cast(lu_byte,(
weakkey<<KEYWEAKBIT)|(weakvalue<<VALUEWEAKBIT));weaklist=(weakkey&&weakvalue)?
&st->wkv:(weakkey)?&st->wk:&st->wv;h->gclist=*weaklist;*weaklist=valtogco(h);}
}if(!weakvalue){i=h->sizearray;while(i--)markobject(st,&h->array[i]);}i=
sizenode(h);while(i--){Node*n=gnode(h,i);if(!ttisnil(gval(n))){lua_assert(!
ttisnil(gkey(n)));condmarkobject(st,gkey(n),!weakkey);condmarkobject(st,gval(n
),!weakvalue);}}}static void traverseproto(GCState*st,Proto*f){int i;
stringmark(f->source);for(i=0;i<f->sizek;i++){if(ttisstring(f->k+i))stringmark
(tsvalue(f->k+i));}for(i=0;i<f->sizeupvalues;i++)stringmark(f->upvalues[i]);
for(i=0;i<f->sizep;i++)markvalue(st,f->p[i]);for(i=0;i<f->sizelocvars;i++)
stringmark(f->locvars[i].varname);lua_assert(luaG_checkcode(f));}static void 
traverseclosure(GCState*st,Closure*cl){if(cl->c.isC){int i;for(i=0;i<cl->c.
nupvalues;i++)markobject(st,&cl->c.upvalue[i]);}else{int i;lua_assert(cl->l.
nupvalues==cl->l.p->nups);markvalue(st,hvalue(&cl->l.g));markvalue(st,cl->l.p)
;for(i=0;i<cl->l.nupvalues;i++){UpVal*u=cl->l.upvals[i];if(!u->marked){
markobject(st,&u->value);u->marked=1;}}}}static void checkstacksizes(lua_State
*L,StkId max){int used=L->ci-L->base_ci;if(4*used<L->size_ci&&2*BASIC_CI_SIZE<
L->size_ci)luaD_reallocCI(L,L->size_ci/2);else condhardstacktests(
luaD_reallocCI(L,L->size_ci));used=max-L->stack;if(4*used<L->stacksize&&2*(
BASIC_STACK_SIZE+EXTRA_STACK)<L->stacksize)luaD_reallocstack(L,L->stacksize/2)
;else condhardstacktests(luaD_reallocstack(L,L->stacksize));}static void 
traversestack(GCState*st,lua_State*L1){StkId o,lim;CallInfo*ci;markobject(st,
gt(L1));lim=L1->top;for(ci=L1->base_ci;ci<=L1->ci;ci++){lua_assert(ci->top<=L1
->stack_last);lua_assert(ci->state&(CI_C|CI_HASFRAME|CI_SAVEDPC));if(lim<ci->
top)lim=ci->top;}for(o=L1->stack;o<L1->top;o++)markobject(st,o);for(;o<=lim;o
++)setnilvalue(o);checkstacksizes(L1,lim);}static void propagatemarks(GCState*
st){while(st->tmark){switch(st->tmark->gch.tt){case LUA_TTABLE:{Table*h=gcotoh
(st->tmark);st->tmark=h->gclist;traversetable(st,h);break;}case LUA_TFUNCTION:
{Closure*cl=gcotocl(st->tmark);st->tmark=cl->c.gclist;traverseclosure(st,cl);
break;}case LUA_TTHREAD:{lua_State*th=gcototh(st->tmark);st->tmark=th->gclist;
traversestack(st,th);break;}case LUA_TPROTO:{Proto*p=gcotop(st->tmark);st->
tmark=p->gclist;traverseproto(st,p);break;}default:lua_assert(0);}}}static int
 valismarked(const TObject*o){if(ttisstring(o))stringmark(tsvalue(o));return!
iscollectable(o)||testbit(o->value.gc->gch.marked,0);}static void 
cleartablekeys(GCObject*l){while(l){Table*h=gcotoh(l);int i=sizenode(h);
lua_assert(h->marked&KEYWEAK);while(i--){Node*n=gnode(h,i);if(!valismarked(
gkey(n)))removekey(n);}l=h->gclist;}}static void cleartablevalues(GCObject*l){
while(l){Table*h=gcotoh(l);int i=h->sizearray;lua_assert(h->marked&VALUEWEAK);
while(i--){TObject*o=&h->array[i];if(!valismarked(o))setnilvalue(o);}i=
sizenode(h);while(i--){Node*n=gnode(h,i);if(!valismarked(gval(n)))removekey(n)
;}l=h->gclist;}}static void freeobj(lua_State*L,GCObject*o){switch(o->gch.tt){
case LUA_TPROTO:luaF_freeproto(L,gcotop(o));break;case LUA_TFUNCTION:
luaF_freeclosure(L,gcotocl(o));break;case LUA_TUPVAL:luaM_freelem(L,gcotouv(o)
);break;case LUA_TTABLE:luaH_free(L,gcotoh(o));break;case LUA_TTHREAD:{
lua_assert(gcototh(o)!=L&&gcototh(o)!=G(L)->mainthread);luaE_freethread(L,
gcototh(o));break;}case LUA_TSTRING:{luaM_free(L,o,sizestring(gcotots(o)->tsv.
len));break;}case LUA_TUSERDATA:{luaM_free(L,o,sizeudata(gcotou(o)->uv.len));
break;}default:lua_assert(0);}}static int sweeplist(lua_State*L,GCObject**p,
int limit){GCObject*curr;int count=0;while((curr=*p)!=NULL){if(curr->gch.
marked>limit){unmark(curr);p=&curr->gch.next;}else{count++;*p=curr->gch.next;
freeobj(L,curr);}}return count;}static void sweepstrings(lua_State*L,int all){
int i;for(i=0;i<G(L)->strt.size;i++){G(L)->strt.nuse-=sweeplist(L,&G(L)->strt.
hash[i],all);}}static void checkSizes(lua_State*L,size_t deadmem){if(G(L)->
strt.nuse<cast(ls_nstr,G(L)->strt.size/4)&&G(L)->strt.size>MINSTRTABSIZE*2)
luaS_resize(L,G(L)->strt.size/2);if(luaZ_sizebuffer(&G(L)->buff)>LUA_MINBUFFER
*2){size_t newsize=luaZ_sizebuffer(&G(L)->buff)/2;luaZ_resizebuffer(L,&G(L)->
buff,newsize);}G(L)->GCthreshold=2*G(L)->nblocks-deadmem;}static void do1gcTM(
lua_State*L,Udata*udata){const TObject*tm=fasttm(L,udata->uv.metatable,TM_GC);
if(tm!=NULL){setobj2s(L->top,tm);setuvalue(L->top+1,udata);L->top+=2;luaD_call
(L,L->top-2,0);}}void luaC_callGCTM(lua_State*L){lu_byte oldah=L->allowhook;L
->allowhook=0;L->top++;while(G(L)->tmudata!=NULL){GCObject*o=G(L)->tmudata;
Udata*udata=gcotou(o);G(L)->tmudata=udata->uv.next;udata->uv.next=G(L)->
rootudata;G(L)->rootudata=o;setuvalue(L->top-1,udata);unmark(o);markfinalized(
udata);do1gcTM(L,udata);}L->top--;L->allowhook=oldah;}void luaC_sweep(
lua_State*L,int all){if(all)all=256;sweeplist(L,&G(L)->rootudata,all);
sweepstrings(L,all);sweeplist(L,&G(L)->rootgc,all);}static void markroot(
GCState*st,lua_State*L){global_State*g=st->g;markobject(st,defaultmeta(L));
markobject(st,registry(L));traversestack(st,g->mainthread);if(L!=g->mainthread
)markvalue(st,L);}static size_t mark(lua_State*L){size_t deadmem;GCState st;
GCObject*wkv;st.g=G(L);st.tmark=NULL;st.wkv=st.wk=st.wv=NULL;markroot(&st,L);
propagatemarks(&st);cleartablevalues(st.wkv);cleartablevalues(st.wv);wkv=st.
wkv;st.wkv=NULL;st.wv=NULL;deadmem=luaC_separateudata(L);marktmu(&st);
propagatemarks(&st);cleartablekeys(wkv);cleartablekeys(st.wk);cleartablevalues
(st.wv);cleartablekeys(st.wkv);cleartablevalues(st.wkv);return deadmem;}void 
luaC_collectgarbage(lua_State*L){size_t deadmem=mark(L);luaC_sweep(L,0);
checkSizes(L,deadmem);luaC_callGCTM(L);}void luaC_link(lua_State*L,GCObject*o,
lu_byte tt){o->gch.next=G(L)->rootgc;G(L)->rootgc=o;o->gch.marked=0;o->gch.tt=
tt;}
#line 1 "liolib.c"
#define liolib_c
#ifndef USE_TMPNAME
#ifdef __GNUC__
#define USE_TMPNAME 0
#else
#define USE_TMPNAME 1
#endif
#endif
#ifndef USE_POPEN
#ifdef _POSIX_C_SOURCE
#if _POSIX_C_SOURCE >=2
#define USE_POPEN 1
#endif
#endif
#endif
#ifndef USE_POPEN
#define USE_POPEN 0
#endif
#if !USE_POPEN
#define pclose(f) (-1)
#endif
#define FILEHANDLE "FILE*"
#define IO_INPUT "_input"
#define IO_OUTPUT "_output"
static int pushresult(lua_State*L,int i,const char*filename){if(i){
lua_pushboolean(L,1);return 1;}else{lua_pushnil(L);if(filename)lua_pushfstring
(L,"%s: %s",filename,strerror(errno));else lua_pushfstring(L,"%s",strerror(
errno));lua_pushnumber(L,errno);return 3;}}static FILE**topfile(lua_State*L,
int findex){FILE**f=(FILE**)luaL_checkudata(L,findex,FILEHANDLE);if(f==NULL)
luaL_argerror(L,findex,"bad file");return f;}static int io_type(lua_State*L){
FILE**f=(FILE**)luaL_checkudata(L,1,FILEHANDLE);if(f==NULL)lua_pushnil(L);else
 if(*f==NULL)lua_pushliteral(L,"closed file");else lua_pushliteral(L,"file");
return 1;}static FILE*tofile(lua_State*L,int findex){FILE**f=topfile(L,findex)
;if(*f==NULL)luaL_error(L,"attempt to use a closed file");return*f;}static 
FILE**newfile(lua_State*L){FILE**pf=(FILE**)lua_newuserdata(L,sizeof(FILE*));*
pf=NULL;luaL_getmetatable(L,FILEHANDLE);lua_setmetatable(L,-2);return pf;}
static void registerfile(lua_State*L,FILE*f,const char*name,const char*impname
){lua_pushstring(L,name);*newfile(L)=f;if(impname){lua_pushstring(L,impname);
lua_pushvalue(L,-2);lua_settable(L,-6);}lua_settable(L,-3);}static int 
aux_close(lua_State*L){FILE*f=tofile(L,1);if(f==stdin||f==stdout||f==stderr)
return 0;else{int ok=(pclose(f)!=-1)||(fclose(f)==0);if(ok)*(FILE**)
lua_touserdata(L,1)=NULL;return ok;}}static int io_close(lua_State*L){if(
lua_isnone(L,1)&&lua_type(L,lua_upvalueindex(1))==LUA_TTABLE){lua_pushstring(L
,IO_OUTPUT);lua_rawget(L,lua_upvalueindex(1));}return pushresult(L,aux_close(L
),NULL);}static int io_gc(lua_State*L){FILE**f=topfile(L,1);if(*f!=NULL)
aux_close(L);return 0;}static int io_tostring(lua_State*L){char buff[128];FILE
**f=topfile(L,1);if(*f==NULL)strcpy(buff,"closed");else sprintf(buff,"%p",
lua_touserdata(L,1));lua_pushfstring(L,"file (%s)",buff);return 1;}static int 
io_open(lua_State*L){const char*filename=luaL_checkstring(L,1);const char*mode
=luaL_optstring(L,2,"r");FILE**pf=newfile(L);*pf=fopen(filename,mode);return(*
pf==NULL)?pushresult(L,0,filename):1;}static int io_popen(lua_State*L){
#if !USE_POPEN
luaL_error(L,"`popen' not supported");return 0;
#else
const char*filename=luaL_checkstring(L,1);const char*mode=luaL_optstring(L,2,
"r");FILE**pf=newfile(L);*pf=popen(filename,mode);return(*pf==NULL)?pushresult
(L,0,filename):1;
#endif
}static int io_tmpfile(lua_State*L){FILE**pf=newfile(L);*pf=tmpfile();return(*
pf==NULL)?pushresult(L,0,NULL):1;}static FILE*getiofile(lua_State*L,const char
*name){lua_pushstring(L,name);lua_rawget(L,lua_upvalueindex(1));return tofile(
L,-1);}static int g_iofile(lua_State*L,const char*name,const char*mode){if(!
lua_isnoneornil(L,1)){const char*filename=lua_tostring(L,1);lua_pushstring(L,
name);if(filename){FILE**pf=newfile(L);*pf=fopen(filename,mode);if(*pf==NULL){
lua_pushfstring(L,"%s: %s",filename,strerror(errno));luaL_argerror(L,1,
lua_tostring(L,-1));}}else{tofile(L,1);lua_pushvalue(L,1);}lua_rawset(L,
lua_upvalueindex(1));}lua_pushstring(L,name);lua_rawget(L,lua_upvalueindex(1))
;return 1;}static int io_input(lua_State*L){return g_iofile(L,IO_INPUT,"r");}
static int io_output(lua_State*L){return g_iofile(L,IO_OUTPUT,"w");}static int
 io_readline(lua_State*L);static void aux_lines(lua_State*L,int idx,int close)
{lua_pushliteral(L,FILEHANDLE);lua_rawget(L,LUA_REGISTRYINDEX);lua_pushvalue(L
,idx);lua_pushboolean(L,close);lua_pushcclosure(L,io_readline,3);}static int 
f_lines(lua_State*L){tofile(L,1);aux_lines(L,1,0);return 1;}static int 
io_lines(lua_State*L){if(lua_isnoneornil(L,1)){lua_pushstring(L,IO_INPUT);
lua_rawget(L,lua_upvalueindex(1));return f_lines(L);}else{const char*filename=
luaL_checkstring(L,1);FILE**pf=newfile(L);*pf=fopen(filename,"r");
luaL_argcheck(L,*pf,1,strerror(errno));aux_lines(L,lua_gettop(L),1);return 1;}
}static int read_number(lua_State*L,FILE*f){lua_Number d;if(fscanf(f,
LUA_NUMBER_SCAN,&d)==1){lua_pushnumber(L,d);return 1;}else return 0;}static 
int test_eof(lua_State*L,FILE*f){int c=getc(f);ungetc(c,f);lua_pushlstring(L,
NULL,0);return(c!=EOF);}static int read_line(lua_State*L,FILE*f){luaL_Buffer b
;luaL_buffinit(L,&b);for(;;){size_t l;char*p=luaL_prepbuffer(&b);if(fgets(p,
LUAL_BUFFERSIZE,f)==NULL){luaL_pushresult(&b);return(lua_strlen(L,-1)>0);}l=
strlen(p);if(p[l-1]!='\n')luaL_addsize(&b,l);else{luaL_addsize(&b,l-1);
luaL_pushresult(&b);return 1;}}}static int read_chars(lua_State*L,FILE*f,
size_t n){size_t rlen;size_t nr;luaL_Buffer b;luaL_buffinit(L,&b);rlen=
LUAL_BUFFERSIZE;do{char*p=luaL_prepbuffer(&b);if(rlen>n)rlen=n;nr=fread(p,
sizeof(char),rlen,f);luaL_addsize(&b,nr);n-=nr;}while(n>0&&nr==rlen);
luaL_pushresult(&b);return(n==0||lua_strlen(L,-1)>0);}static int g_read(
lua_State*L,FILE*f,int first){int nargs=lua_gettop(L)-1;int success;int n;if(
nargs==0){success=read_line(L,f);n=first+1;}else{luaL_checkstack(L,nargs+
LUA_MINSTACK,"too many arguments");success=1;for(n=first;nargs--&&success;n++)
{if(lua_type(L,n)==LUA_TNUMBER){size_t l=(size_t)lua_tonumber(L,n);success=(l
==0)?test_eof(L,f):read_chars(L,f,l);}else{const char*p=lua_tostring(L,n);
luaL_argcheck(L,p&&p[0]=='*',n,"invalid option");switch(p[1]){case'n':success=
read_number(L,f);break;case'l':success=read_line(L,f);break;case'a':read_chars
(L,f,~((size_t)0));success=1;break;case'w':return luaL_error(L,
"obsolete option `*w' to `read'");default:return luaL_argerror(L,n,
"invalid format");}}}}if(!success){lua_pop(L,1);lua_pushnil(L);}return n-first
;}static int io_read(lua_State*L){return g_read(L,getiofile(L,IO_INPUT),1);}
static int f_read(lua_State*L){return g_read(L,tofile(L,1),2);}static int 
io_readline(lua_State*L){FILE*f=*(FILE**)lua_touserdata(L,lua_upvalueindex(2))
;if(f==NULL)luaL_error(L,"file is already closed");if(read_line(L,f))return 1;
else{if(lua_toboolean(L,lua_upvalueindex(3))){lua_settop(L,0);lua_pushvalue(L,
lua_upvalueindex(2));aux_close(L);}return 0;}}static int g_write(lua_State*L,
FILE*f,int arg){int nargs=lua_gettop(L)-1;int status=1;for(;nargs--;arg++){if(
lua_type(L,arg)==LUA_TNUMBER){status=status&&fprintf(f,LUA_NUMBER_FMT,
lua_tonumber(L,arg))>0;}else{size_t l;const char*s=luaL_checklstring(L,arg,&l)
;status=status&&(fwrite(s,sizeof(char),l,f)==l);}}return pushresult(L,status,
NULL);}static int io_write(lua_State*L){return g_write(L,getiofile(L,IO_OUTPUT
),1);}static int f_write(lua_State*L){return g_write(L,tofile(L,1),2);}static 
int f_seek(lua_State*L){static const int mode[]={SEEK_SET,SEEK_CUR,SEEK_END};
static const char*const modenames[]={"set","cur","end",NULL};FILE*f=tofile(L,1
);int op=luaL_findstring(luaL_optstring(L,2,"cur"),modenames);long offset=
luaL_optlong(L,3,0);luaL_argcheck(L,op!=-1,2,"invalid mode");op=fseek(f,offset
,mode[op]);if(op)return pushresult(L,0,NULL);else{lua_pushnumber(L,ftell(f));
return 1;}}static int io_flush(lua_State*L){return pushresult(L,fflush(
getiofile(L,IO_OUTPUT))==0,NULL);}static int f_flush(lua_State*L){return 
pushresult(L,fflush(tofile(L,1))==0,NULL);}static const luaL_reg iolib[]={{
"input",io_input},{"output",io_output},{"lines",io_lines},{"close",io_close},{
"flush",io_flush},{"open",io_open},{"popen",io_popen},{"read",io_read},{
"tmpfile",io_tmpfile},{"type",io_type},{"write",io_write},{NULL,NULL}};static 
const luaL_reg flib[]={{"flush",f_flush},{"read",f_read},{"lines",f_lines},{
"seek",f_seek},{"write",f_write},{"close",io_close},{"__gc",io_gc},{
"__tostring",io_tostring},{NULL,NULL}};static void createmeta(lua_State*L){
luaL_newmetatable(L,FILEHANDLE);lua_pushliteral(L,"__index");lua_pushvalue(L,-
2);lua_rawset(L,-3);luaL_openlib(L,NULL,flib,0);}static int io_execute(
lua_State*L){lua_pushnumber(L,system(luaL_checkstring(L,1)));return 1;}static 
int io_remove(lua_State*L){const char*filename=luaL_checkstring(L,1);return 
pushresult(L,remove(filename)==0,filename);}static int io_rename(lua_State*L){
const char*fromname=luaL_checkstring(L,1);const char*toname=luaL_checkstring(L
,2);return pushresult(L,rename(fromname,toname)==0,fromname);}static int 
io_tmpname(lua_State*L){
#if !USE_TMPNAME
luaL_error(L,"`tmpname' not supported");return 0;
#else
char buff[L_tmpnam];if(tmpnam(buff)!=buff)return luaL_error(L,
"unable to generate a unique filename in `tmpname'");lua_pushstring(L,buff);
return 1;
#endif
}static int io_getenv(lua_State*L){lua_pushstring(L,getenv(luaL_checkstring(L,
1)));return 1;}static int io_clock(lua_State*L){lua_pushnumber(L,((lua_Number)
clock())/(lua_Number)CLOCKS_PER_SEC);return 1;}static void setfield(lua_State*
L,const char*key,int value){lua_pushstring(L,key);lua_pushnumber(L,value);
lua_rawset(L,-3);}static void setboolfield(lua_State*L,const char*key,int 
value){lua_pushstring(L,key);lua_pushboolean(L,value);lua_rawset(L,-3);}static
 int getboolfield(lua_State*L,const char*key){int res;lua_pushstring(L,key);
lua_gettable(L,-2);res=lua_toboolean(L,-1);lua_pop(L,1);return res;}static int
 getfield(lua_State*L,const char*key,int d){int res;lua_pushstring(L,key);
lua_gettable(L,-2);if(lua_isnumber(L,-1))res=(int)(lua_tonumber(L,-1));else{if
(d==-2)return luaL_error(L,"field `%s' missing in date table",key);res=d;}
lua_pop(L,1);return res;}static int io_date(lua_State*L){const char*s=
luaL_optstring(L,1,"%c");time_t t=(time_t)(luaL_optnumber(L,2,-1));struct tm*
stm;if(t==(time_t)(-1))t=time(NULL);if(*s=='!'){stm=gmtime(&t);s++;}else stm=
localtime(&t);if(stm==NULL)lua_pushnil(L);else if(strcmp(s,"*t")==0){
lua_newtable(L);setfield(L,"sec",stm->tm_sec);setfield(L,"min",stm->tm_min);
setfield(L,"hour",stm->tm_hour);setfield(L,"day",stm->tm_mday);setfield(L,
"month",stm->tm_mon+1);setfield(L,"year",stm->tm_year+1900);setfield(L,"wday",
stm->tm_wday+1);setfield(L,"yday",stm->tm_yday+1);setboolfield(L,"isdst",stm->
tm_isdst);}else{char b[256];if(strftime(b,sizeof(b),s,stm))lua_pushstring(L,b)
;else return luaL_error(L,"`date' format too long");}return 1;}static int 
io_time(lua_State*L){if(lua_isnoneornil(L,1))lua_pushnumber(L,time(NULL));else
{time_t t;struct tm ts;luaL_checktype(L,1,LUA_TTABLE);lua_settop(L,1);ts.
tm_sec=getfield(L,"sec",0);ts.tm_min=getfield(L,"min",0);ts.tm_hour=getfield(L
,"hour",12);ts.tm_mday=getfield(L,"day",-2);ts.tm_mon=getfield(L,"month",-2)-1
;ts.tm_year=getfield(L,"year",-2)-1900;ts.tm_isdst=getboolfield(L,"isdst");t=
mktime(&ts);if(t==(time_t)(-1))lua_pushnil(L);else lua_pushnumber(L,t);}return
 1;}static int io_difftime(lua_State*L){lua_pushnumber(L,difftime((time_t)(
luaL_checknumber(L,1)),(time_t)(luaL_optnumber(L,2,0))));return 1;}static int 
io_setloc(lua_State*L){static const int cat[]={LC_ALL,LC_COLLATE,LC_CTYPE,
LC_MONETARY,LC_NUMERIC,LC_TIME};static const char*const catnames[]={"all",
"collate","ctype","monetary","numeric","time",NULL};const char*l=lua_tostring(
L,1);int op=luaL_findstring(luaL_optstring(L,2,"all"),catnames);luaL_argcheck(
L,l||lua_isnoneornil(L,1),1,"string expected");luaL_argcheck(L,op!=-1,2,
"invalid option");lua_pushstring(L,setlocale(cat[op],l));return 1;}static int 
io_exit(lua_State*L){exit(luaL_optint(L,1,EXIT_SUCCESS));return 0;}static 
const luaL_reg syslib[]={{"clock",io_clock},{"date",io_date},{"difftime",
io_difftime},{"execute",io_execute},{"exit",io_exit},{"getenv",io_getenv},{
"remove",io_remove},{"rename",io_rename},{"setlocale",io_setloc},{"time",
io_time},{"tmpname",io_tmpname},{NULL,NULL}};LUALIB_API int luaopen_io(
lua_State*L){luaL_openlib(L,LUA_OSLIBNAME,syslib,0);createmeta(L);
lua_pushvalue(L,-1);luaL_openlib(L,LUA_IOLIBNAME,iolib,1);registerfile(L,stdin
,"stdin",IO_INPUT);registerfile(L,stdout,"stdout",IO_OUTPUT);registerfile(L,
stderr,"stderr",NULL);return 1;}
#line 1 "llex.c"
#define llex_c
#define next(LS) (LS->current=zgetc(LS->z))
static const char*const token2string[]={"and","break","do","else","elseif",
"end","false","for","function","if","in","local","nil","not","or","repeat",
"return","then","true","until","while","*name","..","...","==",">=","<=","~=",
"*number","*string","<eof>"};void luaX_init(lua_State*L){int i;for(i=0;i<
NUM_RESERVED;i++){TString*ts=luaS_new(L,token2string[i]);luaS_fix(ts);
lua_assert(strlen(token2string[i])+1<=TOKEN_LEN);ts->tsv.reserved=cast(lu_byte
,i+1);}}
#define MAXSRC 80
void luaX_checklimit(LexState*ls,int val,int limit,const char*msg){if(val>
limit){msg=luaO_pushfstring(ls->L,"too many %s (limit=%d)",msg,limit);
luaX_syntaxerror(ls,msg);}}void luaX_errorline(LexState*ls,const char*s,const 
char*token,int line){lua_State*L=ls->L;char buff[MAXSRC];luaO_chunkid(buff,
getstr(ls->source),MAXSRC);luaO_pushfstring(L,"%s:%d: %s near `%s'",buff,line,
s,token);luaD_throw(L,LUA_ERRSYNTAX);}static void luaX_error(LexState*ls,const
 char*s,const char*token){luaX_errorline(ls,s,token,ls->linenumber);}void 
luaX_syntaxerror(LexState*ls,const char*msg){const char*lasttoken;switch(ls->t
.token){case TK_NAME:lasttoken=getstr(ls->t.seminfo.ts);break;case TK_STRING:
case TK_NUMBER:lasttoken=luaZ_buffer(ls->buff);break;default:lasttoken=
luaX_token2str(ls,ls->t.token);break;}luaX_error(ls,msg,lasttoken);}const char
*luaX_token2str(LexState*ls,int token){if(token<FIRST_RESERVED){lua_assert(
token==(unsigned char)token);return luaO_pushfstring(ls->L,"%c",token);}else 
return token2string[token-FIRST_RESERVED];}static void luaX_lexerror(LexState*
ls,const char*s,int token){if(token==TK_EOS)luaX_error(ls,s,luaX_token2str(ls,
token));else luaX_error(ls,s,luaZ_buffer(ls->buff));}static void inclinenumber
(LexState*LS){next(LS);++LS->linenumber;luaX_checklimit(LS,LS->linenumber,
MAX_INT,"lines in a chunk");}void luaX_setinput(lua_State*L,LexState*LS,ZIO*z,
TString*source){LS->L=L;LS->lookahead.token=TK_EOS;LS->z=z;LS->fs=NULL;LS->
linenumber=1;LS->lastline=1;LS->source=source;next(LS);if(LS->current=='#'){do
{next(LS);}while(LS->current!='\n'&&LS->current!=EOZ);}}
#define EXTRABUFF 32
#define MAXNOCHECK 5
#define checkbuffer(LS, len)if(((len)+MAXNOCHECK)*sizeof(char)>luaZ_sizebuffer\
((LS)->buff))luaZ_openspace((LS)->L,(LS)->buff,(len)+EXTRABUFF)
#define save(LS, c,l)(luaZ_buffer((LS)->buff)[l++]=cast(char,c))
#define save_and_next(LS, l)(save(LS,LS->current,l),next(LS))
static size_t readname(LexState*LS){size_t l=0;checkbuffer(LS,l);do{
checkbuffer(LS,l);save_and_next(LS,l);}while(isalnum(LS->current)||LS->current
=='_');save(LS,'\0',l);return l-1;}static void read_numeral(LexState*LS,int 
comma,SemInfo*seminfo){size_t l=0;checkbuffer(LS,l);if(comma)save(LS,'.',l);
while(isdigit(LS->current)){checkbuffer(LS,l);save_and_next(LS,l);}if(LS->
current=='.'){save_and_next(LS,l);if(LS->current=='.'){save_and_next(LS,l);
save(LS,'\0',l);luaX_lexerror(LS,
"ambiguous syntax (decimal point x string concatenation)",TK_NUMBER);}}while(
isdigit(LS->current)){checkbuffer(LS,l);save_and_next(LS,l);}if(LS->current==
'e'||LS->current=='E'){save_and_next(LS,l);if(LS->current=='+'||LS->current==
'-')save_and_next(LS,l);while(isdigit(LS->current)){checkbuffer(LS,l);
save_and_next(LS,l);}}save(LS,'\0',l);if(!luaO_str2d(luaZ_buffer(LS->buff),&
seminfo->r))luaX_lexerror(LS,"malformed number",TK_NUMBER);}static void 
read_long_string(LexState*LS,SemInfo*seminfo){int cont=0;size_t l=0;
checkbuffer(LS,l);save(LS,'[',l);save_and_next(LS,l);if(LS->current=='\n')
inclinenumber(LS);for(;;){checkbuffer(LS,l);switch(LS->current){case EOZ:save(
LS,'\0',l);luaX_lexerror(LS,(seminfo)?"unfinished long string":
"unfinished long comment",TK_EOS);break;case'[':save_and_next(LS,l);if(LS->
current=='['){cont++;save_and_next(LS,l);}continue;case']':save_and_next(LS,l)
;if(LS->current==']'){if(cont==0)goto endloop;cont--;save_and_next(LS,l);}
continue;case'\n':save(LS,'\n',l);inclinenumber(LS);if(!seminfo)l=0;continue;
default:save_and_next(LS,l);}}endloop:save_and_next(LS,l);save(LS,'\0',l);if(
seminfo)seminfo->ts=luaS_newlstr(LS->L,luaZ_buffer(LS->buff)+2,l-5);}static 
void read_string(LexState*LS,int del,SemInfo*seminfo){size_t l=0;checkbuffer(
LS,l);save_and_next(LS,l);while(LS->current!=del){checkbuffer(LS,l);switch(LS
->current){case EOZ:save(LS,'\0',l);luaX_lexerror(LS,"unfinished string",
TK_EOS);break;case'\n':save(LS,'\0',l);luaX_lexerror(LS,"unfinished string",
TK_STRING);break;case'\\':next(LS);switch(LS->current){case'a':save(LS,'\a',l)
;next(LS);break;case'b':save(LS,'\b',l);next(LS);break;case'f':save(LS,'\f',l)
;next(LS);break;case'n':save(LS,'\n',l);next(LS);break;case'r':save(LS,'\r',l)
;next(LS);break;case't':save(LS,'\t',l);next(LS);break;case'v':save(LS,'\v',l)
;next(LS);break;case'\n':save(LS,'\n',l);inclinenumber(LS);break;case EOZ:
break;default:{if(!isdigit(LS->current))save_and_next(LS,l);else{int c=0;int i
=0;do{c=10*c+(LS->current-'0');next(LS);}while(++i<3&&isdigit(LS->current));if
(c>UCHAR_MAX){save(LS,'\0',l);luaX_lexerror(LS,"escape sequence too large",
TK_STRING);}save(LS,c,l);}}}break;default:save_and_next(LS,l);}}save_and_next(
LS,l);save(LS,'\0',l);seminfo->ts=luaS_newlstr(LS->L,luaZ_buffer(LS->buff)+1,l
-3);}int luaX_lex(LexState*LS,SemInfo*seminfo){for(;;){switch(LS->current){
case'\n':{inclinenumber(LS);continue;}case'-':{next(LS);if(LS->current!='-')
return'-';next(LS);if(LS->current=='['&&(next(LS),LS->current=='['))
read_long_string(LS,NULL);else while(LS->current!='\n'&&LS->current!=EOZ)next(
LS);continue;}case'[':{next(LS);if(LS->current!='[')return'[';else{
read_long_string(LS,seminfo);return TK_STRING;}}case'=':{next(LS);if(LS->
current!='=')return'=';else{next(LS);return TK_EQ;}}case'<':{next(LS);if(LS->
current!='=')return'<';else{next(LS);return TK_LE;}}case'>':{next(LS);if(LS->
current!='=')return'>';else{next(LS);return TK_GE;}}case'~':{next(LS);if(LS->
current!='=')return'~';else{next(LS);return TK_NE;}}case'"':case'\'':{
read_string(LS,LS->current,seminfo);return TK_STRING;}case'.':{next(LS);if(LS
->current=='.'){next(LS);if(LS->current=='.'){next(LS);return TK_DOTS;}else 
return TK_CONCAT;}else if(!isdigit(LS->current))return'.';else{read_numeral(LS
,1,seminfo);return TK_NUMBER;}}case EOZ:{return TK_EOS;}default:{if(isspace(LS
->current)){next(LS);continue;}else if(isdigit(LS->current)){read_numeral(LS,0
,seminfo);return TK_NUMBER;}else if(isalpha(LS->current)||LS->current=='_'){
size_t l=readname(LS);TString*ts=luaS_newlstr(LS->L,luaZ_buffer(LS->buff),l);
if(ts->tsv.reserved>0)return ts->tsv.reserved-1+FIRST_RESERVED;seminfo->ts=ts;
return TK_NAME;}else{int c=LS->current;if(iscntrl(c))luaX_error(LS,
"invalid control char",luaO_pushfstring(LS->L,"char(%d)",c));next(LS);return c
;}}}}}
#undef next
#line 1 "lmem.c"
#define lmem_c
#ifndef l_realloc
#define l_realloc(b,os,s) realloc(b,s)
#endif
#ifndef l_free
#define l_free(b,os) free(b)
#endif
#define MINSIZEARRAY 4
void*luaM_growaux(lua_State*L,void*block,int*size,int size_elems,int limit,
const char*errormsg){void*newblock;int newsize=(*size)*2;if(newsize<
MINSIZEARRAY)newsize=MINSIZEARRAY;else if(*size>=limit/2){if(*size<limit-
MINSIZEARRAY)newsize=limit;else luaG_runerror(L,errormsg);}newblock=
luaM_realloc(L,block,cast(lu_mem,*size)*cast(lu_mem,size_elems),cast(lu_mem,
newsize)*cast(lu_mem,size_elems));*size=newsize;return newblock;}void*
luaM_realloc(lua_State*L,void*block,lu_mem oldsize,lu_mem size){lua_assert((
oldsize==0)==(block==NULL));if(size==0){if(block!=NULL){l_free(block,oldsize);
block=NULL;}else return NULL;}else if(size>=MAX_SIZET)luaG_runerror(L,
"memory allocation error: block too big");else{block=l_realloc(block,oldsize,
size);if(block==NULL){if(L)luaD_throw(L,LUA_ERRMEM);else return NULL;}}if(L){
lua_assert(G(L)!=NULL&&G(L)->nblocks>0);G(L)->nblocks-=oldsize;G(L)->nblocks+=
size;}return block;}
#line 1 "loadlib.c"
#undef LOADLIB
#ifdef USE_DLOPEN
#define LOADLIB
#include <dlfcn.h> /* dg: magic anchor comment */
static int loadlib(lua_State*L){const char*path=luaL_checkstring(L,1);const 
char*init=luaL_checkstring(L,2);void*lib=dlopen(path,RTLD_NOW);if(lib!=NULL){
lua_CFunction f=(lua_CFunction)dlsym(lib,init);if(f!=NULL){
lua_pushlightuserdata(L,lib);lua_pushcclosure(L,f,1);return 1;}}lua_pushnil(L)
;lua_pushstring(L,dlerror());lua_pushstring(L,(lib!=NULL)?"init":"open");if(
lib!=NULL)dlclose(lib);return 3;}
#endif
#ifndef USE_DLL
#ifdef _WIN32
#define USE_DLL 1
#else
#define USE_DLL 0
#endif
#endif
#if USE_DLL
#define LOADLIB
#include <windows.h> /* dg: magic anchor comment */
static void pusherror(lua_State*L){int error=GetLastError();char buffer[128];
if(FormatMessage(FORMAT_MESSAGE_IGNORE_INSERTS|FORMAT_MESSAGE_FROM_SYSTEM,0,
error,0,buffer,sizeof(buffer),0))lua_pushstring(L,buffer);else lua_pushfstring
(L,"system error %d\n",error);}static int loadlib(lua_State*L){const char*path
=luaL_checkstring(L,1);const char*init=luaL_checkstring(L,2);HINSTANCE lib=
LoadLibrary(path);if(lib!=NULL){lua_CFunction f=(lua_CFunction)GetProcAddress(
lib,init);if(f!=NULL){lua_pushlightuserdata(L,lib);lua_pushcclosure(L,f,1);
return 1;}}lua_pushnil(L);pusherror(L);lua_pushstring(L,(lib!=NULL)?"init":
"open");if(lib!=NULL)FreeLibrary(lib);return 3;}
#endif
#ifndef LOADLIB
#ifdef linux
#define LOADLIB
#endif
#ifdef sun
#define LOADLIB
#endif
#ifdef sgi
#define LOADLIB
#endif
#ifdef BSD
#define LOADLIB
#endif
#ifdef _WIN32
#define LOADLIB
#endif
#ifdef LOADLIB
#undef LOADLIB
#define LOADLIB "`loadlib' not installed (check your Lua configuration)"
#else
#define LOADLIB "`loadlib' not supported"
#endif
static int loadlib(lua_State*L){lua_pushnil(L);lua_pushliteral(L,LOADLIB);
lua_pushliteral(L,"absent");return 3;}
#endif
LUALIB_API int luaopen_loadlib(lua_State*L){lua_register(L,"loadlib",loadlib);
return 0;}
#line 1 "lobject.c"
#define lobject_c
#ifndef lua_str2number
#define lua_str2number(s,p) strtod((s),(p))
#endif
const TObject luaO_nilobject={LUA_TNIL,{NULL}};int luaO_int2fb(unsigned int x)
{int m=0;while(x>=(1<<3)){x=(x+1)>>1;m++;}return(m<<3)|cast(int,x);}int 
luaO_log2(unsigned int x){static const lu_byte log_8[255]={0,1,1,2,2,2,2,3,3,3
,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5
,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7
,7,7,7,7,7,7,7,7,7,7,7};if(x>=0x00010000){if(x>=0x01000000)return log_8[((x>>
24)&0xff)-1]+24;else return log_8[((x>>16)&0xff)-1]+16;}else{if(x>=0x00000100)
return log_8[((x>>8)&0xff)-1]+8;else if(x)return log_8[(x&0xff)-1];return-1;}}
int luaO_rawequalObj(const TObject*t1,const TObject*t2){if(ttype(t1)!=ttype(t2
))return 0;else switch(ttype(t1)){case LUA_TNIL:return 1;case LUA_TNUMBER:
return nvalue(t1)==nvalue(t2);case LUA_TBOOLEAN:return bvalue(t1)==bvalue(t2);
case LUA_TLIGHTUSERDATA:return pvalue(t1)==pvalue(t2);default:lua_assert(
iscollectable(t1));return gcvalue(t1)==gcvalue(t2);}}int luaO_str2d(const char
*s,lua_Number*result){char*endptr;lua_Number res=lua_str2number(s,&endptr);if(
endptr==s)return 0;while(isspace((unsigned char)(*endptr)))endptr++;if(*endptr
!='\0')return 0;*result=res;return 1;}static void pushstr(lua_State*L,const 
char*str){setsvalue2s(L->top,luaS_new(L,str));incr_top(L);}const char*
luaO_pushvfstring(lua_State*L,const char*fmt,va_list argp){int n=1;pushstr(L,
"");for(;;){const char*e=strchr(fmt,'%');if(e==NULL)break;setsvalue2s(L->top,
luaS_newlstr(L,fmt,e-fmt));incr_top(L);switch(*(e+1)){case's':pushstr(L,va_arg
(argp,char*));break;case'c':{char buff[2];buff[0]=cast(char,va_arg(argp,int));
buff[1]='\0';pushstr(L,buff);break;}case'd':setnvalue(L->top,cast(lua_Number,
va_arg(argp,int)));incr_top(L);break;case'f':setnvalue(L->top,cast(lua_Number,
va_arg(argp,l_uacNumber)));incr_top(L);break;case'%':pushstr(L,"%");break;
default:lua_assert(0);}n+=2;fmt=e+2;}pushstr(L,fmt);luaV_concat(L,n+1,L->top-L
->base-1);L->top-=n;return svalue(L->top-1);}const char*luaO_pushfstring(
lua_State*L,const char*fmt,...){const char*msg;va_list argp;va_start(argp,fmt)
;msg=luaO_pushvfstring(L,fmt,argp);va_end(argp);return msg;}void luaO_chunkid(
char*out,const char*source,int bufflen){if(*source=='='){strncpy(out,source+1,
bufflen);out[bufflen-1]='\0';}else{if(*source=='@'){int l;source++;bufflen-=
sizeof(" `...' ");l=strlen(source);strcpy(out,"");if(l>bufflen){source+=(l-
bufflen);strcat(out,"...");}strcat(out,source);}else{int len=strcspn(source,
"\n");bufflen-=sizeof(" [string \"...\"] ");if(len>bufflen)len=bufflen;strcpy(
out,"[string \"");if(source[len]!='\0'){strncat(out,source,len);strcat(out,
"...");}else strcat(out,source);strcat(out,"\"]");}}}
#line 1 "lopcodes.c"
#define lopcodes_c
#ifdef LUA_OPNAMES
const char*const luaP_opnames[]={"MOVE","LOADK","LOADBOOL","LOADNIL",
"GETUPVAL","GETGLOBAL","GETTABLE","SETGLOBAL","SETUPVAL","SETTABLE","NEWTABLE"
,"SELF","ADD","SUB","MUL","DIV","POW","UNM","NOT","CONCAT","JMP","EQ","LT",
"LE","TEST","CALL","TAILCALL","RETURN","FORLOOP","TFORLOOP","TFORPREP",
"SETLIST","SETLISTO","CLOSE","CLOSURE"};
#endif
#define opmode(t,b,bk,ck,sa,k,m) (((t)<<OpModeT)|((b)<<OpModeBreg)|((bk)<<\
OpModeBrk)|((ck)<<OpModeCrk)|((sa)<<OpModesetA)|((k)<<OpModeK)|(m))
const lu_byte luaP_opmodes[NUM_OPCODES]={opmode(0,1,0,0,1,0,iABC),opmode(0,0,0
,0,1,1,iABx),opmode(0,0,0,0,1,0,iABC),opmode(0,1,0,0,1,0,iABC),opmode(0,0,0,0,
1,0,iABC),opmode(0,0,0,0,1,1,iABx),opmode(0,1,0,1,1,0,iABC),opmode(0,0,0,0,0,1
,iABx),opmode(0,0,0,0,0,0,iABC),opmode(0,0,1,1,0,0,iABC),opmode(0,0,0,0,1,0,
iABC),opmode(0,1,0,1,1,0,iABC),opmode(0,0,1,1,1,0,iABC),opmode(0,0,1,1,1,0,
iABC),opmode(0,0,1,1,1,0,iABC),opmode(0,0,1,1,1,0,iABC),opmode(0,0,1,1,1,0,
iABC),opmode(0,1,0,0,1,0,iABC),opmode(0,1,0,0,1,0,iABC),opmode(0,1,0,1,1,0,
iABC),opmode(0,0,0,0,0,0,iAsBx),opmode(1,0,1,1,0,0,iABC),opmode(1,0,1,1,0,0,
iABC),opmode(1,0,1,1,0,0,iABC),opmode(1,1,0,0,1,0,iABC),opmode(0,0,0,0,0,0,
iABC),opmode(0,0,0,0,0,0,iABC),opmode(0,0,0,0,0,0,iABC),opmode(0,0,0,0,0,0,
iAsBx),opmode(1,0,0,0,0,0,iABC),opmode(0,0,0,0,0,0,iAsBx),opmode(0,0,0,0,0,0,
iABx),opmode(0,0,0,0,0,0,iABx),opmode(0,0,0,0,0,0,iABC),opmode(0,0,0,0,1,0,
iABx)};
#line 1 "lparser.c"
#define lparser_c
#define getlocvar(fs, i)((fs)->f->locvars[(fs)->actvar[i]])
#define enterlevel(ls) if(++(ls)->nestlevel>LUA_MAXPARSERLEVEL)\
luaX_syntaxerror(ls,"too many syntax levels");
#define leavelevel(ls) ((ls)->nestlevel--)
typedef struct BlockCnt{struct BlockCnt*previous;int breaklist;int nactvar;int
 upval;int isbreakable;}BlockCnt;static void chunk(LexState*ls);static void 
expr(LexState*ls,expdesc*v);static void next(LexState*ls){ls->lastline=ls->
linenumber;if(ls->lookahead.token!=TK_EOS){ls->t=ls->lookahead;ls->lookahead.
token=TK_EOS;}else ls->t.token=luaX_lex(ls,&ls->t.seminfo);}static void 
lookahead(LexState*ls){lua_assert(ls->lookahead.token==TK_EOS);ls->lookahead.
token=luaX_lex(ls,&ls->lookahead.seminfo);}static void error_expected(LexState
*ls,int token){luaX_syntaxerror(ls,luaO_pushfstring(ls->L,"`%s' expected",
luaX_token2str(ls,token)));}static int testnext(LexState*ls,int c){if(ls->t.
token==c){next(ls);return 1;}else return 0;}static void check(LexState*ls,int 
c){if(!testnext(ls,c))error_expected(ls,c);}
#define check_condition(ls,c,msg) {if(!(c))luaX_syntaxerror(ls,msg);}
static void check_match(LexState*ls,int what,int who,int where){if(!testnext(
ls,what)){if(where==ls->linenumber)error_expected(ls,what);else{
luaX_syntaxerror(ls,luaO_pushfstring(ls->L,
"`%s' expected (to close `%s' at line %d)",luaX_token2str(ls,what),
luaX_token2str(ls,who),where));}}}static TString*str_checkname(LexState*ls){
TString*ts;check_condition(ls,(ls->t.token==TK_NAME),"<name> expected");ts=ls
->t.seminfo.ts;next(ls);return ts;}static void init_exp(expdesc*e,expkind k,
int i){e->f=e->t=NO_JUMP;e->k=k;e->info=i;}static void codestring(LexState*ls,
expdesc*e,TString*s){init_exp(e,VK,luaK_stringK(ls->fs,s));}static void 
checkname(LexState*ls,expdesc*e){codestring(ls,e,str_checkname(ls));}static 
int luaI_registerlocalvar(LexState*ls,TString*varname){FuncState*fs=ls->fs;
Proto*f=fs->f;luaM_growvector(ls->L,f->locvars,fs->nlocvars,f->sizelocvars,
LocVar,MAX_INT,"");f->locvars[fs->nlocvars].varname=varname;return fs->
nlocvars++;}static void new_localvar(LexState*ls,TString*name,int n){FuncState
*fs=ls->fs;luaX_checklimit(ls,fs->nactvar+n+1,MAXVARS,"local variables");fs->
actvar[fs->nactvar+n]=luaI_registerlocalvar(ls,name);}static void 
adjustlocalvars(LexState*ls,int nvars){FuncState*fs=ls->fs;fs->nactvar+=nvars;
for(;nvars;nvars--){getlocvar(fs,fs->nactvar-nvars).startpc=fs->pc;}}static 
void removevars(LexState*ls,int tolevel){FuncState*fs=ls->fs;while(fs->nactvar
>tolevel)getlocvar(fs,--fs->nactvar).endpc=fs->pc;}static void new_localvarstr
(LexState*ls,const char*name,int n){new_localvar(ls,luaS_new(ls->L,name),n);}
static void create_local(LexState*ls,const char*name){new_localvarstr(ls,name,
0);adjustlocalvars(ls,1);}static int indexupvalue(FuncState*fs,TString*name,
expdesc*v){int i;Proto*f=fs->f;for(i=0;i<f->nups;i++){if(fs->upvalues[i].k==v
->k&&fs->upvalues[i].info==v->info){lua_assert(fs->f->upvalues[i]==name);
return i;}}luaX_checklimit(fs->ls,f->nups+1,MAXUPVALUES,"upvalues");
luaM_growvector(fs->L,fs->f->upvalues,f->nups,fs->f->sizeupvalues,TString*,
MAX_INT,"");fs->f->upvalues[f->nups]=name;fs->upvalues[f->nups]=*v;return f->
nups++;}static int searchvar(FuncState*fs,TString*n){int i;for(i=fs->nactvar-1
;i>=0;i--){if(n==getlocvar(fs,i).varname)return i;}return-1;}static void 
markupval(FuncState*fs,int level){BlockCnt*bl=fs->bl;while(bl&&bl->nactvar>
level)bl=bl->previous;if(bl)bl->upval=1;}static void singlevaraux(FuncState*fs
,TString*n,expdesc*var,int base){if(fs==NULL)init_exp(var,VGLOBAL,NO_REG);else
{int v=searchvar(fs,n);if(v>=0){init_exp(var,VLOCAL,v);if(!base)markupval(fs,v
);}else{singlevaraux(fs->prev,n,var,0);if(var->k==VGLOBAL){if(base)var->info=
luaK_stringK(fs,n);}else{var->info=indexupvalue(fs,n,var);var->k=VUPVAL;}}}}
static TString*singlevar(LexState*ls,expdesc*var,int base){TString*varname=
str_checkname(ls);singlevaraux(ls->fs,varname,var,base);return varname;}static
 void adjust_assign(LexState*ls,int nvars,int nexps,expdesc*e){FuncState*fs=ls
->fs;int extra=nvars-nexps;if(e->k==VCALL){extra++;if(extra<=0)extra=0;else 
luaK_reserveregs(fs,extra-1);luaK_setcallreturns(fs,e,extra);}else{if(e->k!=
VVOID)luaK_exp2nextreg(fs,e);if(extra>0){int reg=fs->freereg;luaK_reserveregs(
fs,extra);luaK_nil(fs,reg,extra);}}}static void code_params(LexState*ls,int 
nparams,int dots){FuncState*fs=ls->fs;adjustlocalvars(ls,nparams);
luaX_checklimit(ls,fs->nactvar,MAXPARAMS,"parameters");fs->f->numparams=cast(
lu_byte,fs->nactvar);fs->f->is_vararg=cast(lu_byte,dots);if(dots)create_local(
ls,"arg");luaK_reserveregs(fs,fs->nactvar);}static void enterblock(FuncState*
fs,BlockCnt*bl,int isbreakable){bl->breaklist=NO_JUMP;bl->isbreakable=
isbreakable;bl->nactvar=fs->nactvar;bl->upval=0;bl->previous=fs->bl;fs->bl=bl;
lua_assert(fs->freereg==fs->nactvar);}static void leaveblock(FuncState*fs){
BlockCnt*bl=fs->bl;fs->bl=bl->previous;removevars(fs->ls,bl->nactvar);if(bl->
upval)luaK_codeABC(fs,OP_CLOSE,bl->nactvar,0,0);lua_assert(bl->nactvar==fs->
nactvar);fs->freereg=fs->nactvar;luaK_patchtohere(fs,bl->breaklist);}static 
void pushclosure(LexState*ls,FuncState*func,expdesc*v){FuncState*fs=ls->fs;
Proto*f=fs->f;int i;luaM_growvector(ls->L,f->p,fs->np,f->sizep,Proto*,
MAXARG_Bx,"constant table overflow");f->p[fs->np++]=func->f;init_exp(v,
VRELOCABLE,luaK_codeABx(fs,OP_CLOSURE,0,fs->np-1));for(i=0;i<func->f->nups;i++
){OpCode o=(func->upvalues[i].k==VLOCAL)?OP_MOVE:OP_GETUPVAL;luaK_codeABC(fs,o
,0,func->upvalues[i].info,0);}}static void open_func(LexState*ls,FuncState*fs)
{Proto*f=luaF_newproto(ls->L);fs->f=f;fs->prev=ls->fs;fs->ls=ls;fs->L=ls->L;ls
->fs=fs;fs->pc=0;fs->lasttarget=0;fs->jpc=NO_JUMP;fs->freereg=0;fs->nk=0;fs->h
=luaH_new(ls->L,0,0);fs->np=0;fs->nlocvars=0;fs->nactvar=0;fs->bl=NULL;f->
source=ls->source;f->maxstacksize=2;}static void close_func(LexState*ls){
lua_State*L=ls->L;FuncState*fs=ls->fs;Proto*f=fs->f;removevars(ls,0);
luaK_codeABC(fs,OP_RETURN,0,1,0);luaM_reallocvector(L,f->code,f->sizecode,fs->
pc,Instruction);f->sizecode=fs->pc;luaM_reallocvector(L,f->lineinfo,f->
sizelineinfo,fs->pc,int);f->sizelineinfo=fs->pc;luaM_reallocvector(L,f->k,f->
sizek,fs->nk,TObject);f->sizek=fs->nk;luaM_reallocvector(L,f->p,f->sizep,fs->
np,Proto*);f->sizep=fs->np;luaM_reallocvector(L,f->locvars,f->sizelocvars,fs->
nlocvars,LocVar);f->sizelocvars=fs->nlocvars;luaM_reallocvector(L,f->upvalues,
f->sizeupvalues,f->nups,TString*);f->sizeupvalues=f->nups;lua_assert(
luaG_checkcode(f));lua_assert(fs->bl==NULL);ls->fs=fs->prev;}Proto*luaY_parser
(lua_State*L,ZIO*z,Mbuffer*buff){struct LexState lexstate;struct FuncState 
funcstate;lexstate.buff=buff;lexstate.nestlevel=0;luaX_setinput(L,&lexstate,z,
luaS_new(L,zname(z)));open_func(&lexstate,&funcstate);next(&lexstate);chunk(&
lexstate);check_condition(&lexstate,(lexstate.t.token==TK_EOS),
"<eof> expected");close_func(&lexstate);lua_assert(funcstate.prev==NULL);
lua_assert(funcstate.f->nups==0);lua_assert(lexstate.nestlevel==0);return 
funcstate.f;}static void luaY_field(LexState*ls,expdesc*v){FuncState*fs=ls->fs
;expdesc key;luaK_exp2anyreg(fs,v);next(ls);checkname(ls,&key);luaK_indexed(fs
,v,&key);}static void luaY_index(LexState*ls,expdesc*v){next(ls);expr(ls,v);
luaK_exp2val(ls->fs,v);check(ls,']');}struct ConsControl{expdesc v;expdesc*t;
int nh;int na;int tostore;};static void recfield(LexState*ls,struct 
ConsControl*cc){FuncState*fs=ls->fs;int reg=ls->fs->freereg;expdesc key,val;if
(ls->t.token==TK_NAME){luaX_checklimit(ls,cc->nh,MAX_INT,
"items in a constructor");cc->nh++;checkname(ls,&key);}else luaY_index(ls,&key
);check(ls,'=');luaK_exp2RK(fs,&key);expr(ls,&val);luaK_codeABC(fs,OP_SETTABLE
,cc->t->info,luaK_exp2RK(fs,&key),luaK_exp2RK(fs,&val));fs->freereg=reg;}
static void closelistfield(FuncState*fs,struct ConsControl*cc){if(cc->v.k==
VVOID)return;luaK_exp2nextreg(fs,&cc->v);cc->v.k=VVOID;if(cc->tostore==
LFIELDS_PER_FLUSH){luaK_codeABx(fs,OP_SETLIST,cc->t->info,cc->na-1);cc->
tostore=0;fs->freereg=cc->t->info+1;}}static void lastlistfield(FuncState*fs,
struct ConsControl*cc){if(cc->tostore==0)return;if(cc->v.k==VCALL){
luaK_setcallreturns(fs,&cc->v,LUA_MULTRET);luaK_codeABx(fs,OP_SETLISTO,cc->t->
info,cc->na-1);}else{if(cc->v.k!=VVOID)luaK_exp2nextreg(fs,&cc->v);
luaK_codeABx(fs,OP_SETLIST,cc->t->info,cc->na-1);}fs->freereg=cc->t->info+1;}
static void listfield(LexState*ls,struct ConsControl*cc){expr(ls,&cc->v);
luaX_checklimit(ls,cc->na,MAXARG_Bx,"items in a constructor");cc->na++;cc->
tostore++;}static void constructor(LexState*ls,expdesc*t){FuncState*fs=ls->fs;
int line=ls->linenumber;int pc=luaK_codeABC(fs,OP_NEWTABLE,0,0,0);struct 
ConsControl cc;cc.na=cc.nh=cc.tostore=0;cc.t=t;init_exp(t,VRELOCABLE,pc);
init_exp(&cc.v,VVOID,0);luaK_exp2nextreg(ls->fs,t);check(ls,'{');do{lua_assert
(cc.v.k==VVOID||cc.tostore>0);testnext(ls,';');if(ls->t.token=='}')break;
closelistfield(fs,&cc);switch(ls->t.token){case TK_NAME:{lookahead(ls);if(ls->
lookahead.token!='=')listfield(ls,&cc);else recfield(ls,&cc);break;}case'[':{
recfield(ls,&cc);break;}default:{listfield(ls,&cc);break;}}}while(testnext(ls,
',')||testnext(ls,';'));check_match(ls,'}','{',line);lastlistfield(fs,&cc);
SETARG_B(fs->f->code[pc],luaO_int2fb(cc.na));SETARG_C(fs->f->code[pc],
luaO_log2(cc.nh)+1);}static void parlist(LexState*ls){int nparams=0;int dots=0
;if(ls->t.token!=')'){do{switch(ls->t.token){case TK_DOTS:dots=1;next(ls);
break;case TK_NAME:new_localvar(ls,str_checkname(ls),nparams++);break;default:
luaX_syntaxerror(ls,"<name> or `...' expected");}}while(!dots&&testnext(ls,','
));}code_params(ls,nparams,dots);}static void body(LexState*ls,expdesc*e,int 
needself,int line){FuncState new_fs;open_func(ls,&new_fs);new_fs.f->
lineDefined=line;check(ls,'(');if(needself)create_local(ls,"self");parlist(ls)
;check(ls,')');chunk(ls);check_match(ls,TK_END,TK_FUNCTION,line);close_func(ls
);pushclosure(ls,&new_fs,e);}static int explist1(LexState*ls,expdesc*v){int n=
1;expr(ls,v);while(testnext(ls,',')){luaK_exp2nextreg(ls->fs,v);expr(ls,v);n++
;}return n;}static void funcargs(LexState*ls,expdesc*f){FuncState*fs=ls->fs;
expdesc args;int base,nparams;int line=ls->linenumber;switch(ls->t.token){case
'(':{if(line!=ls->lastline)luaX_syntaxerror(ls,
"ambiguous syntax (function call x new statement)");next(ls);if(ls->t.token==
')')args.k=VVOID;else{explist1(ls,&args);luaK_setcallreturns(fs,&args,
LUA_MULTRET);}check_match(ls,')','(',line);break;}case'{':{constructor(ls,&
args);break;}case TK_STRING:{codestring(ls,&args,ls->t.seminfo.ts);next(ls);
break;}default:{luaX_syntaxerror(ls,"function arguments expected");return;}}
lua_assert(f->k==VNONRELOC);base=f->info;if(args.k==VCALL)nparams=LUA_MULTRET;
else{if(args.k!=VVOID)luaK_exp2nextreg(fs,&args);nparams=fs->freereg-(base+1);
}init_exp(f,VCALL,luaK_codeABC(fs,OP_CALL,base,nparams+1,2));luaK_fixline(fs,
line);fs->freereg=base+1;}static void prefixexp(LexState*ls,expdesc*v){switch(
ls->t.token){case'(':{int line=ls->linenumber;next(ls);expr(ls,v);check_match(
ls,')','(',line);luaK_dischargevars(ls->fs,v);return;}case TK_NAME:{singlevar(
ls,v,1);return;}
#ifdef LUA_COMPATUPSYNTAX
case'%':{TString*varname;int line=ls->linenumber;next(ls);varname=singlevar(ls
,v,1);if(v->k!=VUPVAL)luaX_errorline(ls,"global upvalues are obsolete",getstr(
varname),line);return;}
#endif
default:{luaX_syntaxerror(ls,"unexpected symbol");return;}}}static void 
primaryexp(LexState*ls,expdesc*v){FuncState*fs=ls->fs;prefixexp(ls,v);for(;;){
switch(ls->t.token){case'.':{luaY_field(ls,v);break;}case'[':{expdesc key;
luaK_exp2anyreg(fs,v);luaY_index(ls,&key);luaK_indexed(fs,v,&key);break;}case
':':{expdesc key;next(ls);checkname(ls,&key);luaK_self(fs,v,&key);funcargs(ls,
v);break;}case'(':case TK_STRING:case'{':{luaK_exp2nextreg(fs,v);funcargs(ls,v
);break;}default:return;}}}static void simpleexp(LexState*ls,expdesc*v){switch
(ls->t.token){case TK_NUMBER:{init_exp(v,VK,luaK_numberK(ls->fs,ls->t.seminfo.
r));next(ls);break;}case TK_STRING:{codestring(ls,v,ls->t.seminfo.ts);next(ls)
;break;}case TK_NIL:{init_exp(v,VNIL,0);next(ls);break;}case TK_TRUE:{init_exp
(v,VTRUE,0);next(ls);break;}case TK_FALSE:{init_exp(v,VFALSE,0);next(ls);break
;}case'{':{constructor(ls,v);break;}case TK_FUNCTION:{next(ls);body(ls,v,0,ls
->linenumber);break;}default:{primaryexp(ls,v);break;}}}static UnOpr getunopr(
int op){switch(op){case TK_NOT:return OPR_NOT;case'-':return OPR_MINUS;default
:return OPR_NOUNOPR;}}static BinOpr getbinopr(int op){switch(op){case'+':
return OPR_ADD;case'-':return OPR_SUB;case'*':return OPR_MULT;case'/':return 
OPR_DIV;case'^':return OPR_POW;case TK_CONCAT:return OPR_CONCAT;case TK_NE:
return OPR_NE;case TK_EQ:return OPR_EQ;case'<':return OPR_LT;case TK_LE:return
 OPR_LE;case'>':return OPR_GT;case TK_GE:return OPR_GE;case TK_AND:return 
OPR_AND;case TK_OR:return OPR_OR;default:return OPR_NOBINOPR;}}static const 
struct{lu_byte left;lu_byte right;}priority[]={{6,6},{6,6},{7,7},{7,7},{10,9},
{5,4},{3,3},{3,3},{3,3},{3,3},{3,3},{3,3},{2,2},{1,1}};
#define UNARY_PRIORITY 8
static BinOpr subexpr(LexState*ls,expdesc*v,int limit){BinOpr op;UnOpr uop;
enterlevel(ls);uop=getunopr(ls->t.token);if(uop!=OPR_NOUNOPR){next(ls);subexpr
(ls,v,UNARY_PRIORITY);luaK_prefix(ls->fs,uop,v);}else simpleexp(ls,v);op=
getbinopr(ls->t.token);while(op!=OPR_NOBINOPR&&cast(int,priority[op].left)>
limit){expdesc v2;BinOpr nextop;next(ls);luaK_infix(ls->fs,op,v);nextop=
subexpr(ls,&v2,cast(int,priority[op].right));luaK_posfix(ls->fs,op,v,&v2);op=
nextop;}leavelevel(ls);return op;}static void expr(LexState*ls,expdesc*v){
subexpr(ls,v,-1);}static int block_follow(int token){switch(token){case 
TK_ELSE:case TK_ELSEIF:case TK_END:case TK_UNTIL:case TK_EOS:return 1;default:
return 0;}}static void block(LexState*ls){FuncState*fs=ls->fs;BlockCnt bl;
enterblock(fs,&bl,0);chunk(ls);lua_assert(bl.breaklist==NO_JUMP);leaveblock(fs
);}struct LHS_assign{struct LHS_assign*prev;expdesc v;};static void 
check_conflict(LexState*ls,struct LHS_assign*lh,expdesc*v){FuncState*fs=ls->fs
;int extra=fs->freereg;int conflict=0;for(;lh;lh=lh->prev){if(lh->v.k==
VINDEXED){if(lh->v.info==v->info){conflict=1;lh->v.info=extra;}if(lh->v.aux==v
->info){conflict=1;lh->v.aux=extra;}}}if(conflict){luaK_codeABC(fs,OP_MOVE,fs
->freereg,v->info,0);luaK_reserveregs(fs,1);}}static void assignment(LexState*
ls,struct LHS_assign*lh,int nvars){expdesc e;check_condition(ls,VLOCAL<=lh->v.
k&&lh->v.k<=VINDEXED,"syntax error");if(testnext(ls,',')){struct LHS_assign nv
;nv.prev=lh;primaryexp(ls,&nv.v);if(nv.v.k==VLOCAL)check_conflict(ls,lh,&nv.v)
;assignment(ls,&nv,nvars+1);}else{int nexps;check(ls,'=');nexps=explist1(ls,&e
);if(nexps!=nvars){adjust_assign(ls,nvars,nexps,&e);if(nexps>nvars)ls->fs->
freereg-=nexps-nvars;}else{luaK_setcallreturns(ls->fs,&e,1);luaK_storevar(ls->
fs,&lh->v,&e);return;}}init_exp(&e,VNONRELOC,ls->fs->freereg-1);luaK_storevar(
ls->fs,&lh->v,&e);}static void cond(LexState*ls,expdesc*v){expr(ls,v);if(v->k
==VNIL)v->k=VFALSE;luaK_goiftrue(ls->fs,v);luaK_patchtohere(ls->fs,v->t);}
#ifndef MAXEXPWHILE
#define MAXEXPWHILE 100
#endif
#define EXTRAEXP 5
static void whilestat(LexState*ls,int line){Instruction codeexp[MAXEXPWHILE+
EXTRAEXP];int lineexp;int i;int sizeexp;FuncState*fs=ls->fs;int whileinit,
blockinit,expinit;expdesc v;BlockCnt bl;next(ls);whileinit=luaK_jump(fs);
expinit=luaK_getlabel(fs);expr(ls,&v);if(v.k==VK)v.k=VTRUE;lineexp=ls->
linenumber;luaK_goiffalse(fs,&v);luaK_concat(fs,&v.f,fs->jpc);fs->jpc=NO_JUMP;
sizeexp=fs->pc-expinit;if(sizeexp>MAXEXPWHILE)luaX_syntaxerror(ls,
"`while' condition too complex");for(i=0;i<sizeexp;i++)codeexp[i]=fs->f->code[
expinit+i];fs->pc=expinit;enterblock(fs,&bl,1);check(ls,TK_DO);blockinit=
luaK_getlabel(fs);block(ls);luaK_patchtohere(fs,whileinit);if(v.t!=NO_JUMP)v.t
+=fs->pc-expinit;if(v.f!=NO_JUMP)v.f+=fs->pc-expinit;for(i=0;i<sizeexp;i++)
luaK_code(fs,codeexp[i],lineexp);check_match(ls,TK_END,TK_WHILE,line);
leaveblock(fs);luaK_patchlist(fs,v.t,blockinit);luaK_patchtohere(fs,v.f);}
static void repeatstat(LexState*ls,int line){FuncState*fs=ls->fs;int 
repeat_init=luaK_getlabel(fs);expdesc v;BlockCnt bl;enterblock(fs,&bl,1);next(
ls);block(ls);check_match(ls,TK_UNTIL,TK_REPEAT,line);cond(ls,&v);
luaK_patchlist(fs,v.f,repeat_init);leaveblock(fs);}static int exp1(LexState*ls
){expdesc e;int k;expr(ls,&e);k=e.k;luaK_exp2nextreg(ls->fs,&e);return k;}
static void forbody(LexState*ls,int base,int line,int nvars,int isnum){
BlockCnt bl;FuncState*fs=ls->fs;int prep,endfor;adjustlocalvars(ls,nvars);
check(ls,TK_DO);enterblock(fs,&bl,1);prep=luaK_getlabel(fs);block(ls);
luaK_patchtohere(fs,prep-1);endfor=(isnum)?luaK_codeAsBx(fs,OP_FORLOOP,base,
NO_JUMP):luaK_codeABC(fs,OP_TFORLOOP,base,0,nvars-3);luaK_fixline(fs,line);
luaK_patchlist(fs,(isnum)?endfor:luaK_jump(fs),prep);leaveblock(fs);}static 
void fornum(LexState*ls,TString*varname,int line){FuncState*fs=ls->fs;int base
=fs->freereg;new_localvar(ls,varname,0);new_localvarstr(ls,"(for limit)",1);
new_localvarstr(ls,"(for step)",2);check(ls,'=');exp1(ls);check(ls,',');exp1(
ls);if(testnext(ls,','))exp1(ls);else{luaK_codeABx(fs,OP_LOADK,fs->freereg,
luaK_numberK(fs,1));luaK_reserveregs(fs,1);}luaK_codeABC(fs,OP_SUB,fs->freereg
-3,fs->freereg-3,fs->freereg-1);luaK_jump(fs);forbody(ls,base,line,3,1);}
static void forlist(LexState*ls,TString*indexname){FuncState*fs=ls->fs;expdesc
 e;int nvars=0;int line;int base=fs->freereg;new_localvarstr(ls,
"(for generator)",nvars++);new_localvarstr(ls,"(for state)",nvars++);
new_localvar(ls,indexname,nvars++);while(testnext(ls,','))new_localvar(ls,
str_checkname(ls),nvars++);check(ls,TK_IN);line=ls->linenumber;adjust_assign(
ls,nvars,explist1(ls,&e),&e);luaK_checkstack(fs,3);luaK_codeAsBx(fs,
OP_TFORPREP,base,NO_JUMP);forbody(ls,base,line,nvars,0);}static void forstat(
LexState*ls,int line){FuncState*fs=ls->fs;TString*varname;BlockCnt bl;
enterblock(fs,&bl,0);next(ls);varname=str_checkname(ls);switch(ls->t.token){
case'=':fornum(ls,varname,line);break;case',':case TK_IN:forlist(ls,varname);
break;default:luaX_syntaxerror(ls,"`=' or `in' expected");}check_match(ls,
TK_END,TK_FOR,line);leaveblock(fs);}static void test_then_block(LexState*ls,
expdesc*v){next(ls);cond(ls,v);check(ls,TK_THEN);block(ls);}static void ifstat
(LexState*ls,int line){FuncState*fs=ls->fs;expdesc v;int escapelist=NO_JUMP;
test_then_block(ls,&v);while(ls->t.token==TK_ELSEIF){luaK_concat(fs,&
escapelist,luaK_jump(fs));luaK_patchtohere(fs,v.f);test_then_block(ls,&v);}if(
ls->t.token==TK_ELSE){luaK_concat(fs,&escapelist,luaK_jump(fs));
luaK_patchtohere(fs,v.f);next(ls);block(ls);}else luaK_concat(fs,&escapelist,v
.f);luaK_patchtohere(fs,escapelist);check_match(ls,TK_END,TK_IF,line);}static 
void localfunc(LexState*ls){expdesc v,b;FuncState*fs=ls->fs;new_localvar(ls,
str_checkname(ls),0);init_exp(&v,VLOCAL,fs->freereg);luaK_reserveregs(fs,1);
adjustlocalvars(ls,1);body(ls,&b,0,ls->linenumber);luaK_storevar(fs,&v,&b);
getlocvar(fs,fs->nactvar-1).startpc=fs->pc;}static void localstat(LexState*ls)
{int nvars=0;int nexps;expdesc e;do{new_localvar(ls,str_checkname(ls),nvars++)
;}while(testnext(ls,','));if(testnext(ls,'='))nexps=explist1(ls,&e);else{e.k=
VVOID;nexps=0;}adjust_assign(ls,nvars,nexps,&e);adjustlocalvars(ls,nvars);}
static int funcname(LexState*ls,expdesc*v){int needself=0;singlevar(ls,v,1);
while(ls->t.token=='.')luaY_field(ls,v);if(ls->t.token==':'){needself=1;
luaY_field(ls,v);}return needself;}static void funcstat(LexState*ls,int line){
int needself;expdesc v,b;next(ls);needself=funcname(ls,&v);body(ls,&b,needself
,line);luaK_storevar(ls->fs,&v,&b);luaK_fixline(ls->fs,line);}static void 
exprstat(LexState*ls){FuncState*fs=ls->fs;struct LHS_assign v;primaryexp(ls,&v
.v);if(v.v.k==VCALL){luaK_setcallreturns(fs,&v.v,0);}else{v.prev=NULL;
assignment(ls,&v,1);}}static void retstat(LexState*ls){FuncState*fs=ls->fs;
expdesc e;int first,nret;next(ls);if(block_follow(ls->t.token)||ls->t.token==
';')first=nret=0;else{nret=explist1(ls,&e);if(e.k==VCALL){luaK_setcallreturns(
fs,&e,LUA_MULTRET);if(nret==1){SET_OPCODE(getcode(fs,&e),OP_TAILCALL);
lua_assert(GETARG_A(getcode(fs,&e))==fs->nactvar);}first=fs->nactvar;nret=
LUA_MULTRET;}else{if(nret==1)first=luaK_exp2anyreg(fs,&e);else{
luaK_exp2nextreg(fs,&e);first=fs->nactvar;lua_assert(nret==fs->freereg-first);
}}}luaK_codeABC(fs,OP_RETURN,first,nret+1,0);}static void breakstat(LexState*
ls){FuncState*fs=ls->fs;BlockCnt*bl=fs->bl;int upval=0;next(ls);while(bl&&!bl
->isbreakable){upval|=bl->upval;bl=bl->previous;}if(!bl)luaX_syntaxerror(ls,
"no loop to break");if(upval)luaK_codeABC(fs,OP_CLOSE,bl->nactvar,0,0);
luaK_concat(fs,&bl->breaklist,luaK_jump(fs));}static int statement(LexState*ls
){int line=ls->linenumber;switch(ls->t.token){case TK_IF:{ifstat(ls,line);
return 0;}case TK_WHILE:{whilestat(ls,line);return 0;}case TK_DO:{next(ls);
block(ls);check_match(ls,TK_END,TK_DO,line);return 0;}case TK_FOR:{forstat(ls,
line);return 0;}case TK_REPEAT:{repeatstat(ls,line);return 0;}case TK_FUNCTION
:{funcstat(ls,line);return 0;}case TK_LOCAL:{next(ls);if(testnext(ls,
TK_FUNCTION))localfunc(ls);else localstat(ls);return 0;}case TK_RETURN:{
retstat(ls);return 1;}case TK_BREAK:{breakstat(ls);return 1;}default:{exprstat
(ls);return 0;}}}static void chunk(LexState*ls){int islast=0;enterlevel(ls);
while(!islast&&!block_follow(ls->t.token)){islast=statement(ls);testnext(ls,
';');lua_assert(ls->fs->freereg>=ls->fs->nactvar);ls->fs->freereg=ls->fs->
nactvar;}leavelevel(ls);}
#line 1 "lposix.c"
#define MYNAME "posix"
#define MYVERSION MYNAME" library for "LUA_VERSION" / Nov 2003"
#ifndef MYBUFSIZ
#define MYBUFSIZ 512
#endif
#line 1 "modemuncher.h"
struct modeLookup{char rwx;mode_t bits;};typedef struct modeLookup modeLookup;
static modeLookup modesel[]={{'r',S_IRUSR},{'w',S_IWUSR},{'x',S_IXUSR},{'r',
S_IRGRP},{'w',S_IWGRP},{'x',S_IXGRP},{'r',S_IROTH},{'w',S_IWOTH},{'x',S_IXOTH}
,{(char)NULL,(mode_t)-1}};static int rwxrwxrwx(mode_t*mode,const char*p){int 
count;mode_t tmp_mode=*mode;tmp_mode&=~(S_ISUID|S_ISGID);for(count=0;count<9;
count++){if(*p==modesel[count].rwx)tmp_mode|=modesel[count].bits;else if(*p==
'-')tmp_mode&=~modesel[count].bits;else if(*p=='s')switch(count){case 2:
tmp_mode|=S_ISUID|S_IXUSR;break;case 5:tmp_mode|=S_ISGID|S_IXGRP;break;default
:return-4;break;}p++;}*mode=tmp_mode;return 0;}static void modechopper(mode_t 
mode,char*p){int count;char*pp;pp=p;for(count=0;count<9;count++){if(mode&
modesel[count].bits)*p=modesel[count].rwx;else*p='-';p++;}*p=0;if(mode&S_ISUID
)pp[2]=(mode&S_IXUSR)?'s':'S';if(mode&S_ISGID)pp[5]=(mode&S_IXGRP)?'s':'S';}
static int mode_munch(mode_t*mode,const char*p){char op=0;mode_t affected_bits
,ch_mode;int doneFlag=0;
#ifdef DEBUG
char tmp[10];
#endif
#ifdef DEBUG
modechopper(*mode,tmp);printf("modemuncher: got base mode = %s\n",tmp);
#endif
while(!doneFlag){affected_bits=0;ch_mode=0;
#ifdef DEBUG
printf("modemuncher step 1\n");
#endif
if(*p=='r'||*p=='-')return rwxrwxrwx(mode,p);for(;;p++)switch(*p){case'u':
affected_bits|=04700;break;case'g':affected_bits|=02070;break;case'o':
affected_bits|=01007;break;case'a':affected_bits|=07777;break;case' ':break;
default:goto no_more_affected;}no_more_affected:if(affected_bits==0)
affected_bits=07777;
#ifdef DEBUG
printf("modemuncher step 2 (*p='%c')\n",*p);
#endif
switch(*p){case'+':case'-':case'=':op=*p;break;case' ':break;default:return-1;
}
#ifdef DEBUG
printf("modemuncher step 3\n");
#endif
for(p++;*p!=0;p++)switch(*p){case'r':ch_mode|=00444;break;case'w':ch_mode|=
00222;break;case'x':ch_mode|=00111;break;case's':ch_mode|=06000;break;case' ':
break;default:goto specs_done;}specs_done:
#ifdef DEBUG
printf("modemuncher step 4\n");
#endif
if(*p!=',')doneFlag=1;if(*p!=0&&*p!=' '&&*p!=','){
#ifdef DEBUG
printf("modemuncher: comma error!\n");printf("modemuncher: doneflag = %u\n",
doneFlag);
#endif
return-2;}p++;if(ch_mode)switch(op){case'+':*mode=*mode|=ch_mode&affected_bits
;break;case'-':*mode=*mode&=~(ch_mode&affected_bits);break;case'=':*mode=
ch_mode&affected_bits;break;default:return-3;}}
#ifdef DEBUG
modechopper(*mode,tmp);printf("modemuncher: returning mode = %s\n",tmp);
#endif
return 0;}
#line 38 "lposix.c"
static const char*filetype(mode_t m){if(S_ISREG(m))return"regular";else if(
S_ISLNK(m))return"link";else if(S_ISDIR(m))return"directory";else if(S_ISCHR(m
))return"character device";else if(S_ISBLK(m))return"block device";else if(
S_ISFIFO(m))return"fifo";
#ifdef S_ISSOCK
else if(S_ISSOCK(m))return"socket";
#endif
else return"?";}typedef int(*Selector)(lua_State*L,int i,const void*data);
static int doselection(lua_State*L,int i,const char*const S[],Selector F,const
 void*data){if(lua_isnone(L,i)){lua_newtable(L);for(i=0;S[i]!=NULL;i++){
lua_pushstring(L,S[i]);F(L,i,data);lua_settable(L,-3);}return 1;}else{int j=
luaL_findstring(luaL_checkstring(L,i),S);if(j==-1)luaL_argerror(L,i,
"unknown selector");return F(L,j,data);}}static void storeindex(lua_State*L,
int i,const char*value){lua_pushstring(L,value);lua_rawseti(L,-2,i);}static 
void storestring(lua_State*L,const char*name,const char*value){lua_pushstring(
L,name);lua_pushstring(L,value);lua_settable(L,-3);}static void storenumber(
lua_State*L,const char*name,lua_Number value){lua_pushstring(L,name);
lua_pushnumber(L,value);lua_settable(L,-3);}static int pusherror(lua_State*L,
const char*info){lua_pushnil(L);if(info==NULL)lua_pushstring(L,strerror(errno)
);else lua_pushfstring(L,"%s: %s",info,strerror(errno));lua_pushnumber(L,errno
);return 3;}static int lposix_pushresult(lua_State*L,int i,const char*info){if
(i!=-1){lua_pushnumber(L,i);return 1;}else return pusherror(L,info);}static 
void badoption(lua_State*L,int i,const char*what,int option){luaL_argerror(L,2
,lua_pushfstring(L,"unknown %s option `%c'",what,option));}static uid_t 
mygetuid(lua_State*L,int i){if(lua_isnone(L,i))return-1;else if(lua_isnumber(L
,i))return(uid_t)lua_tonumber(L,i);else if(lua_isstring(L,i)){struct passwd*p=
getpwnam(lua_tostring(L,i));return(p==NULL)?-1:p->pw_uid;}else return 
luaL_typerror(L,i,"string or number");}static gid_t mygetgid(lua_State*L,int i
){if(lua_isnone(L,i))return-1;else if(lua_isnumber(L,i))return(gid_t)
lua_tonumber(L,i);else if(lua_isstring(L,i)){struct group*g=getgrnam(
lua_tostring(L,i));return(g==NULL)?-1:g->gr_gid;}else return luaL_typerror(L,i
,"string or number");}static int Perrno(lua_State*L){lua_pushstring(L,strerror
(errno));lua_pushnumber(L,errno);return 2;}static int Pdir(lua_State*L){const 
char*path=luaL_optstring(L,1,".");DIR*d=opendir(path);if(d==NULL)return 
pusherror(L,path);else{int i;struct dirent*entry;lua_newtable(L);for(i=1;(
entry=readdir(d))!=NULL;i++)storeindex(L,i,entry->d_name);closedir(d);return 1
;}}static int aux_files(lua_State*L){DIR*d=lua_touserdata(L,lua_upvalueindex(1
));struct dirent*entry;if(d==NULL)luaL_error(L,"attempt to use closed dir");
entry=readdir(d);if(entry==NULL){closedir(d);lua_pushnil(L);lua_replace(L,
lua_upvalueindex(1));lua_pushnil(L);}else{lua_pushstring(L,entry->d_name);
#if 0
#ifdef _DIRENT_HAVE_D_TYPE
lua_pushstring(L,filetype(DTTOIF(entry->d_type)));return 2;
#endif
#endif
}return 1;}static int Pfiles(lua_State*L){const char*path=luaL_optstring(L,1,
".");DIR*d=opendir(path);if(d==NULL)return pusherror(L,path);else{
lua_pushlightuserdata(L,d);lua_pushcclosure(L,aux_files,1);return 1;}}static 
int Pgetcwd(lua_State*L){char buf[MYBUFSIZ];if(getcwd(buf,sizeof(buf))==NULL)
return pusherror(L,".");else{lua_pushstring(L,buf);return 1;}}static int 
Pmkdir(lua_State*L){const char*path=luaL_checkstring(L,1);return 
lposix_pushresult(L,mkdir(path,0777),path);}static int Pchdir(lua_State*L){
const char*path=luaL_checkstring(L,1);return lposix_pushresult(L,chdir(path),
path);}static int Prmdir(lua_State*L){const char*path=luaL_checkstring(L,1);
return lposix_pushresult(L,rmdir(path),path);}static int Punlink(lua_State*L){
const char*path=luaL_checkstring(L,1);return lposix_pushresult(L,unlink(path),
path);}static int Plink(lua_State*L){const char*oldpath=luaL_checkstring(L,1);
const char*newpath=luaL_checkstring(L,2);return lposix_pushresult(L,link(
oldpath,newpath),NULL);}static int Psymlink(lua_State*L){const char*oldpath=
luaL_checkstring(L,1);const char*newpath=luaL_checkstring(L,2);return 
lposix_pushresult(L,symlink(oldpath,newpath),NULL);}static int Preadlink(
lua_State*L){char buf[MYBUFSIZ];const char*path=luaL_checkstring(L,1);int n=
readlink(path,buf,sizeof(buf));if(n==-1)return pusherror(L,path);
lua_pushlstring(L,buf,n);return 1;}static int Paccess(lua_State*L){int mode=
F_OK;const char*path=luaL_checkstring(L,1);const char*s;for(s=luaL_optstring(L
,2,"f");*s!=0;s++)switch(*s){case' ':break;case'r':mode|=R_OK;break;case'w':
mode|=W_OK;break;case'x':mode|=X_OK;break;case'f':mode|=F_OK;break;default:
badoption(L,2,"mode",*s);break;}return lposix_pushresult(L,access(path,mode),
path);}static int Pmkfifo(lua_State*L){const char*path=luaL_checkstring(L,1);
return lposix_pushresult(L,mkfifo(path,0777),path);}static int Pexec(lua_State
*L){const char*path=luaL_checkstring(L,1);int i,n=lua_gettop(L);char**argv=
malloc((n+1)*sizeof(char*));if(argv==NULL)luaL_error(L,"not enough memory");
argv[0]=(char*)path;for(i=1;i<n;i++)argv[i]=(char*)luaL_checkstring(L,i+1);
argv[i]=NULL;execvp(path,argv);return pusherror(L,path);}static int Pfork(
lua_State*L){return lposix_pushresult(L,fork(),NULL);}static int Pwait(
lua_State*L){pid_t pid=luaL_optint(L,1,-1);return lposix_pushresult(L,waitpid(
pid,NULL,0),NULL);}static int Pkill(lua_State*L){pid_t pid=luaL_checkint(L,1);
int sig=luaL_optint(L,2,SIGTERM);return lposix_pushresult(L,kill(pid,sig),NULL
);}static int Psleep(lua_State*L){unsigned int seconds=luaL_checkint(L,1);
lua_pushnumber(L,sleep(seconds));return 1;}static int Pputenv(lua_State*L){
size_t l;const char*s=luaL_checklstring(L,1,&l);char*e=malloc(++l);return 
lposix_pushresult(L,(e==NULL)?-1:putenv(memcpy(e,s,l)),s);}
#ifdef linux
static int Psetenv(lua_State*L){const char*name=luaL_checkstring(L,1);const 
char*value=luaL_checkstring(L,2);int overwrite=lua_isnoneornil(L,3)||
lua_toboolean(L,3);return lposix_pushresult(L,setenv(name,value,overwrite),
name);}static int Punsetenv(lua_State*L){const char*name=luaL_checkstring(L,1)
;unsetenv(name);return 0;}
#endif
static int Pgetenv(lua_State*L){if(lua_isnone(L,1)){extern char**environ;char*
*e;if(*environ==NULL)lua_pushnil(L);else lua_newtable(L);for(e=environ;*e!=
NULL;e++){char*s=*e;char*eq=strchr(s,'=');if(eq==NULL){lua_pushstring(L,s);
lua_pushboolean(L,0);}else{lua_pushlstring(L,s,eq-s);lua_pushstring(L,eq+1);}
lua_settable(L,-3);}}else lua_pushstring(L,getenv(luaL_checkstring(L,1)));
return 1;}static int Pumask(lua_State*L){char m[10];mode_t mode;umask(mode=
umask(0));mode=(~mode)&0777;if(!lua_isnone(L,1)){if(mode_munch(&mode,
luaL_checkstring(L,1))){lua_pushnil(L);return 1;}mode&=0777;umask(~mode);}
modechopper(mode,m);lua_pushstring(L,m);return 1;}static int Pchmod(lua_State*
L){mode_t mode;struct stat s;const char*path=luaL_checkstring(L,1);const char*
modestr=luaL_checkstring(L,2);if(stat(path,&s))return pusherror(L,path);mode=s
.st_mode;if(mode_munch(&mode,modestr))luaL_argerror(L,2,"bad mode");return 
lposix_pushresult(L,chmod(path,mode),path);}static int Pchown(lua_State*L){
const char*path=luaL_checkstring(L,1);uid_t uid=mygetuid(L,2);gid_t gid=
mygetgid(L,3);return lposix_pushresult(L,chown(path,uid,gid),path);}static int
 Putime(lua_State*L){struct utimbuf times;time_t currtime=time(NULL);const 
char*path=luaL_checkstring(L,1);times.modtime=luaL_optnumber(L,2,currtime);
times.actime=luaL_optnumber(L,3,currtime);return lposix_pushresult(L,utime(
path,&times),path);}static int FgetID(lua_State*L,int i,const void*data){
switch(i){case 0:lua_pushnumber(L,getegid());break;case 1:lua_pushnumber(L,
geteuid());break;case 2:lua_pushnumber(L,getgid());break;case 3:lua_pushnumber
(L,getuid());break;case 4:lua_pushnumber(L,getpgrp());break;case 5:
lua_pushnumber(L,getpid());break;case 6:lua_pushnumber(L,getppid());break;}
return 1;}static const char*const SgetID[]={"egid","euid","gid","uid","pgrp",
"pid","ppid",NULL};static int Pgetprocessid(lua_State*L){return doselection(L,
1,SgetID,FgetID,NULL);}static int Pttyname(lua_State*L){int fd=luaL_optint(L,1
,0);lua_pushstring(L,ttyname(fd));return 1;}static int Pctermid(lua_State*L){
char b[L_ctermid];lua_pushstring(L,ctermid(b));return 1;}static int Pgetlogin(
lua_State*L){lua_pushstring(L,getlogin());return 1;}static int Fgetpasswd(
lua_State*L,int i,const void*data){const struct passwd*p=data;switch(i){case 0
:lua_pushstring(L,p->pw_name);break;case 1:lua_pushnumber(L,p->pw_uid);break;
case 2:lua_pushnumber(L,p->pw_gid);break;case 3:lua_pushstring(L,p->pw_dir);
break;case 4:lua_pushstring(L,p->pw_shell);break;case 5:lua_pushstring(L,p->
pw_gecos);break;case 6:lua_pushstring(L,p->pw_passwd);break;}return 1;}static 
const char*const Sgetpasswd[]={"name","uid","gid","dir","shell","gecos",
"passwd",NULL};static int Pgetpasswd(lua_State*L){struct passwd*p=NULL;if(
lua_isnoneornil(L,1))p=getpwuid(geteuid());else if(lua_isnumber(L,1))p=
getpwuid((uid_t)lua_tonumber(L,1));else if(lua_isstring(L,1))p=getpwnam(
lua_tostring(L,1));else luaL_typerror(L,1,"string or number");if(p==NULL)
lua_pushnil(L);else doselection(L,2,Sgetpasswd,Fgetpasswd,p);return 1;}static 
int Pgetgroup(lua_State*L){struct group*g=NULL;if(lua_isnumber(L,1))g=getgrgid
((gid_t)lua_tonumber(L,1));else if(lua_isstring(L,1))g=getgrnam(lua_tostring(L
,1));else luaL_typerror(L,1,"string or number");if(g==NULL)lua_pushnil(L);else
{int i;lua_newtable(L);storestring(L,"name",g->gr_name);storenumber(L,"gid",g
->gr_gid);for(i=0;g->gr_mem[i]!=NULL;i++)storeindex(L,i+1,g->gr_mem[i]);}
return 1;}static int Psetuid(lua_State*L){return lposix_pushresult(L,setuid(
mygetuid(L,1)),NULL);}static int Psetgid(lua_State*L){return lposix_pushresult
(L,setgid(mygetgid(L,1)),NULL);}struct mytimes{struct tms t;clock_t elapsed;};
#define pushtime(L,x) lua_pushnumber(L,((lua_Number)x)/CLOCKS_PER_SEC)
static int Ftimes(lua_State*L,int i,const void*data){const struct mytimes*t=
data;switch(i){case 0:pushtime(L,t->t.tms_utime);break;case 1:pushtime(L,t->t.
tms_stime);break;case 2:pushtime(L,t->t.tms_cutime);break;case 3:pushtime(L,t
->t.tms_cstime);break;case 4:pushtime(L,t->elapsed);break;}return 1;}static 
const char*const Stimes[]={"utime","stime","cutime","cstime","elapsed",NULL};
#define storetime(L,name,x) storenumber(L,name,(lua_Number)x/CLK_TCK)
static int Ptimes(lua_State*L){struct mytimes t;t.elapsed=times(&t.t);return 
doselection(L,1,Stimes,Ftimes,&t);}struct mystat{struct stat s;char mode[10];
const char*type;};static int Fstat(lua_State*L,int i,const void*data){const 
struct mystat*s=data;switch(i){case 0:lua_pushstring(L,s->mode);break;case 1:
lua_pushnumber(L,s->s.st_ino);break;case 2:lua_pushnumber(L,s->s.st_dev);break
;case 3:lua_pushnumber(L,s->s.st_nlink);break;case 4:lua_pushnumber(L,s->s.
st_uid);break;case 5:lua_pushnumber(L,s->s.st_gid);break;case 6:lua_pushnumber
(L,s->s.st_size);break;case 7:lua_pushnumber(L,s->s.st_atime);break;case 8:
lua_pushnumber(L,s->s.st_mtime);break;case 9:lua_pushnumber(L,s->s.st_ctime);
break;case 10:lua_pushstring(L,s->type);break;case 11:lua_pushnumber(L,s->s.
st_mode);break;}return 1;}static const char*const Sstat[]={"mode","ino","dev",
"nlink","uid","gid","size","atime","mtime","ctime","type","_mode",NULL};static
 int Pstat(lua_State*L){struct mystat s;const char*path=luaL_checkstring(L,1);
if(stat(path,&s.s)==-1)return pusherror(L,path);s.type=filetype(s.s.st_mode);
modechopper(s.s.st_mode,s.mode);return doselection(L,2,Sstat,Fstat,&s);}static
 int Puname(lua_State*L){struct utsname u;luaL_Buffer b;const char*s;if(uname(
&u)==-1)return pusherror(L,NULL);luaL_buffinit(L,&b);for(s=luaL_optstring(L,1,
"%s %n %r %v %m");*s;s++)if(*s!='%')luaL_putchar(&b,*s);else switch(*++s){case
'%':luaL_putchar(&b,*s);break;case'm':luaL_addstring(&b,u.machine);break;case
'n':luaL_addstring(&b,u.nodename);break;case'r':luaL_addstring(&b,u.release);
break;case's':luaL_addstring(&b,u.sysname);break;case'v':luaL_addstring(&b,u.
version);break;default:badoption(L,2,"format",*s);break;}luaL_pushresult(&b);
return 1;}static const int Kpathconf[]={_PC_LINK_MAX,_PC_MAX_CANON,
_PC_MAX_INPUT,_PC_NAME_MAX,_PC_PATH_MAX,_PC_PIPE_BUF,_PC_CHOWN_RESTRICTED,
_PC_NO_TRUNC,_PC_VDISABLE,-1};static int Fpathconf(lua_State*L,int i,const 
void*data){const char*path=data;lua_pushnumber(L,pathconf(path,Kpathconf[i]));
return 1;}static const char*const Spathconf[]={"link_max","max_canon",
"max_input","name_max","path_max","pipe_buf","chown_restricted","no_trunc",
"vdisable",NULL};static int Ppathconf(lua_State*L){const char*path=
luaL_checkstring(L,1);return doselection(L,2,Spathconf,Fpathconf,path);}static
 const int Ksysconf[]={_SC_ARG_MAX,_SC_CHILD_MAX,_SC_CLK_TCK,_SC_NGROUPS_MAX,
_SC_STREAM_MAX,_SC_TZNAME_MAX,_SC_OPEN_MAX,_SC_JOB_CONTROL,_SC_SAVED_IDS,
_SC_VERSION,-1};static int Fsysconf(lua_State*L,int i,const void*data){
lua_pushnumber(L,sysconf(Ksysconf[i]));return 1;}static const char*const 
Ssysconf[]={"arg_max","child_max","clk_tck","ngroups_max","stream_max",
"tzname_max","open_max","job_control","saved_ids","version",NULL};static int 
Psysconf(lua_State*L){return doselection(L,1,Ssysconf,Fsysconf,NULL);}static 
const luaL_reg R[]={{"access",Paccess},{"chdir",Pchdir},{"chmod",Pchmod},{
"chown",Pchown},{"ctermid",Pctermid},{"dir",Pdir},{"errno",Perrno},{"exec",
Pexec},{"files",Pfiles},{"fork",Pfork},{"getcwd",Pgetcwd},{"getenv",Pgetenv},{
"getgroup",Pgetgroup},{"getlogin",Pgetlogin},{"getpasswd",Pgetpasswd},{
"getprocessid",Pgetprocessid},{"kill",Pkill},{"link",Plink},{"mkdir",Pmkdir},{
"mkfifo",Pmkfifo},{"pathconf",Ppathconf},{"putenv",Pputenv},{"readlink",
Preadlink},{"rmdir",Prmdir},{"setgid",Psetgid},{"setuid",Psetuid},{"sleep",
Psleep},{"stat",Pstat},{"symlink",Psymlink},{"sysconf",Psysconf},{"times",
Ptimes},{"ttyname",Pttyname},{"umask",Pumask},{"uname",Puname},{"unlink",
Punlink},{"utime",Putime},{"wait",Pwait},
#ifdef linux
{"setenv",Psetenv},{"unsetenv",Punsetenv},
#endif
{NULL,NULL}};LUALIB_API int luaopen_posix(lua_State*L){luaL_openlib(L,MYNAME,R
,0);lua_pushliteral(L,"version");lua_pushliteral(L,MYVERSION);lua_settable(L,-
3);return 1;}
#line 1 "lstate.c"
#define lstate_c
#ifndef LUA_USERSTATE
#define EXTRASPACE 0
#else
union UEXTRASPACE{L_Umaxalign a;LUA_USERSTATE b;};
#define EXTRASPACE (sizeof(union UEXTRASPACE))
#endif
static int default_panic(lua_State*L){UNUSED(L);return 0;}static lua_State*
mallocstate(lua_State*L){lu_byte*block=(lu_byte*)luaM_malloc(L,sizeof(
lua_State)+EXTRASPACE);if(block==NULL)return NULL;else{block+=EXTRASPACE;
return cast(lua_State*,block);}}static void freestate(lua_State*L,lua_State*L1
){luaM_free(L,cast(lu_byte*,L1)-EXTRASPACE,sizeof(lua_State)+EXTRASPACE);}
static void stack_init(lua_State*L1,lua_State*L){L1->stack=luaM_newvector(L,
BASIC_STACK_SIZE+EXTRA_STACK,TObject);L1->stacksize=BASIC_STACK_SIZE+
EXTRA_STACK;L1->top=L1->stack;L1->stack_last=L1->stack+(L1->stacksize-
EXTRA_STACK)-1;L1->base_ci=luaM_newvector(L,BASIC_CI_SIZE,CallInfo);L1->ci=L1
->base_ci;L1->ci->state=CI_C;setnilvalue(L1->top++);L1->base=L1->ci->base=L1->
top;L1->ci->top=L1->top+LUA_MINSTACK;L1->size_ci=BASIC_CI_SIZE;L1->end_ci=L1->
base_ci+L1->size_ci;}static void freestack(lua_State*L,lua_State*L1){
luaM_freearray(L,L1->base_ci,L1->size_ci,CallInfo);luaM_freearray(L,L1->stack,
L1->stacksize,TObject);}static void f_luaopen(lua_State*L,void*ud){
global_State*g=luaM_new(NULL,global_State);UNUSED(ud);if(g==NULL)luaD_throw(L,
LUA_ERRMEM);L->l_G=g;g->mainthread=L;g->GCthreshold=0;g->strt.size=0;g->strt.
nuse=0;g->strt.hash=NULL;setnilvalue(defaultmeta(L));setnilvalue(registry(L));
luaZ_initbuffer(L,&g->buff);g->panic=default_panic;g->rootgc=NULL;g->rootudata
=NULL;g->tmudata=NULL;setnilvalue(gkey(g->dummynode));setnilvalue(gval(g->
dummynode));g->dummynode->next=NULL;g->nblocks=sizeof(lua_State)+sizeof(
global_State);stack_init(L,L);defaultmeta(L)->tt=LUA_TTABLE;sethvalue(
defaultmeta(L),luaH_new(L,0,0));hvalue(defaultmeta(L))->metatable=hvalue(
defaultmeta(L));sethvalue(gt(L),luaH_new(L,0,4));sethvalue(registry(L),
luaH_new(L,4,4));luaS_resize(L,MINSTRTABSIZE);luaT_init(L);luaX_init(L);
luaS_fix(luaS_newliteral(L,MEMERRMSG));g->GCthreshold=4*G(L)->nblocks;}static 
void preinit_state(lua_State*L){L->stack=NULL;L->stacksize=0;L->errorJmp=NULL;
L->hook=NULL;L->hookmask=L->hookinit=0;L->basehookcount=0;L->allowhook=1;
resethookcount(L);L->openupval=NULL;L->size_ci=0;L->nCcalls=0;L->base_ci=L->ci
=NULL;L->errfunc=0;setnilvalue(gt(L));}static void close_state(lua_State*L){
luaF_close(L,L->stack);if(G(L)){luaC_sweep(L,1);lua_assert(G(L)->rootgc==NULL)
;lua_assert(G(L)->rootudata==NULL);luaS_freeall(L);luaZ_freebuffer(L,&G(L)->
buff);}freestack(L,L);if(G(L)){lua_assert(G(L)->nblocks==sizeof(lua_State)+
sizeof(global_State));luaM_freelem(NULL,G(L));}freestate(NULL,L);}lua_State*
luaE_newthread(lua_State*L){lua_State*L1=mallocstate(L);luaC_link(L,valtogco(
L1),LUA_TTHREAD);preinit_state(L1);L1->l_G=L->l_G;stack_init(L1,L);setobj2n(gt
(L1),gt(L));return L1;}void luaE_freethread(lua_State*L,lua_State*L1){
luaF_close(L1,L1->stack);lua_assert(L1->openupval==NULL);freestack(L,L1);
freestate(L,L1);}LUA_API lua_State*lua_open(void){lua_State*L=mallocstate(NULL
);if(L){L->tt=LUA_TTHREAD;L->marked=0;L->next=L->gclist=NULL;preinit_state(L);
L->l_G=NULL;if(luaD_rawrunprotected(L,f_luaopen,NULL)!=0){close_state(L);L=
NULL;}}lua_userstateopen(L);return L;}static void callallgcTM(lua_State*L,void
*ud){UNUSED(ud);luaC_callGCTM(L);}LUA_API void lua_close(lua_State*L){lua_lock
(L);L=G(L)->mainthread;luaF_close(L,L->stack);luaC_separateudata(L);L->errfunc
=0;do{L->ci=L->base_ci;L->base=L->top=L->ci->base;L->nCcalls=0;}while(
luaD_rawrunprotected(L,callallgcTM,NULL)!=0);lua_assert(G(L)->tmudata==NULL);
close_state(L);}
#line 1 "lstring.c"
#define lstring_c
void luaS_freeall(lua_State*L){lua_assert(G(L)->strt.nuse==0);luaM_freearray(L
,G(L)->strt.hash,G(L)->strt.size,TString*);}void luaS_resize(lua_State*L,int 
newsize){GCObject**newhash=luaM_newvector(L,newsize,GCObject*);stringtable*tb=
&G(L)->strt;int i;for(i=0;i<newsize;i++)newhash[i]=NULL;for(i=0;i<tb->size;i++
){GCObject*p=tb->hash[i];while(p){GCObject*next=p->gch.next;lu_hash h=gcotots(
p)->tsv.hash;int h1=lmod(h,newsize);lua_assert(cast(int,h%newsize)==lmod(h,
newsize));p->gch.next=newhash[h1];newhash[h1]=p;p=next;}}luaM_freearray(L,tb->
hash,tb->size,TString*);tb->size=newsize;tb->hash=newhash;}static TString*
newlstr(lua_State*L,const char*str,size_t l,lu_hash h){TString*ts=cast(TString
*,luaM_malloc(L,sizestring(l)));stringtable*tb;ts->tsv.len=l;ts->tsv.hash=h;ts
->tsv.marked=0;ts->tsv.tt=LUA_TSTRING;ts->tsv.reserved=0;memcpy(ts+1,str,l*
sizeof(char));((char*)(ts+1))[l]='\0';tb=&G(L)->strt;h=lmod(h,tb->size);ts->
tsv.next=tb->hash[h];tb->hash[h]=valtogco(ts);tb->nuse++;if(tb->nuse>cast(
ls_nstr,tb->size)&&tb->size<=MAX_INT/2)luaS_resize(L,tb->size*2);return ts;}
TString*luaS_newlstr(lua_State*L,const char*str,size_t l){GCObject*o;lu_hash h
=(lu_hash)l;size_t step=(l>>5)+1;size_t l1;for(l1=l;l1>=step;l1-=step)h=h^((h
<<5)+(h>>2)+(unsigned char)(str[l1-1]));for(o=G(L)->strt.hash[lmod(h,G(L)->
strt.size)];o!=NULL;o=o->gch.next){TString*ts=gcotots(o);if(ts->tsv.len==l&&(
memcmp(str,getstr(ts),l)==0))return ts;}return newlstr(L,str,l,h);}Udata*
luaS_newudata(lua_State*L,size_t s){Udata*u;u=cast(Udata*,luaM_malloc(L,
sizeudata(s)));u->uv.marked=(1<<1);u->uv.tt=LUA_TUSERDATA;u->uv.len=s;u->uv.
metatable=hvalue(defaultmeta(L));u->uv.next=G(L)->rootudata;G(L)->rootudata=
valtogco(u);return u;}
#line 1 "lstrlib.c"
#define lstrlib_c
#ifndef uchar
#define uchar(c) ((unsigned char)(c))
#endif
typedef long sint32;static int str_len(lua_State*L){size_t l;luaL_checklstring
(L,1,&l);lua_pushnumber(L,(lua_Number)l);return 1;}static sint32 posrelat(
sint32 pos,size_t len){return(pos>=0)?pos:(sint32)len+pos+1;}static int 
str_sub(lua_State*L){size_t l;const char*s=luaL_checklstring(L,1,&l);sint32 
start=posrelat(luaL_checklong(L,2),l);sint32 end=posrelat(luaL_optlong(L,3,-1)
,l);if(start<1)start=1;if(end>(sint32)l)end=(sint32)l;if(start<=end)
lua_pushlstring(L,s+start-1,end-start+1);else lua_pushliteral(L,"");return 1;}
static int str_lower(lua_State*L){size_t l;size_t i;luaL_Buffer b;const char*s
=luaL_checklstring(L,1,&l);luaL_buffinit(L,&b);for(i=0;i<l;i++)luaL_putchar(&b
,tolower(uchar(s[i])));luaL_pushresult(&b);return 1;}static int str_upper(
lua_State*L){size_t l;size_t i;luaL_Buffer b;const char*s=luaL_checklstring(L,
1,&l);luaL_buffinit(L,&b);for(i=0;i<l;i++)luaL_putchar(&b,toupper(uchar(s[i]))
);luaL_pushresult(&b);return 1;}static int str_rep(lua_State*L){size_t l;
luaL_Buffer b;const char*s=luaL_checklstring(L,1,&l);int n=luaL_checkint(L,2);
luaL_buffinit(L,&b);while(n-->0)luaL_addlstring(&b,s,l);luaL_pushresult(&b);
return 1;}static int str_byte(lua_State*L){size_t l;const char*s=
luaL_checklstring(L,1,&l);sint32 pos=posrelat(luaL_optlong(L,2,1),l);if(pos<=0
||(size_t)(pos)>l)return 0;lua_pushnumber(L,uchar(s[pos-1]));return 1;}static 
int str_char(lua_State*L){int n=lua_gettop(L);int i;luaL_Buffer b;
luaL_buffinit(L,&b);for(i=1;i<=n;i++){int c=luaL_checkint(L,i);luaL_argcheck(L
,uchar(c)==c,i,"invalid value");luaL_putchar(&b,uchar(c));}luaL_pushresult(&b)
;return 1;}static int writer(lua_State*L,const void*b,size_t size,void*B){(
void)L;luaL_addlstring((luaL_Buffer*)B,(const char*)b,size);return 1;}static 
int str_dump(lua_State*L){luaL_Buffer b;luaL_checktype(L,1,LUA_TFUNCTION);
luaL_buffinit(L,&b);if(!lua_dump(L,writer,&b))luaL_error(L,
"unable to dump given function");luaL_pushresult(&b);return 1;}
#ifndef MAX_CAPTURES
#define MAX_CAPTURES 32
#endif
#define CAP_UNFINISHED (-1)
#define CAP_POSITION (-2)
typedef struct MatchState{const char*src_init;const char*src_end;lua_State*L;
int level;struct{const char*init;sint32 len;}capture[MAX_CAPTURES];}MatchState
;
#define ESC '%'
#define SPECIALS "^$*+?.([%-"
static int check_capture(MatchState*ms,int l){l-='1';if(l<0||l>=ms->level||ms
->capture[l].len==CAP_UNFINISHED)return luaL_error(ms->L,
"invalid capture index");return l;}static int capture_to_close(MatchState*ms){
int level=ms->level;for(level--;level>=0;level--)if(ms->capture[level].len==
CAP_UNFINISHED)return level;return luaL_error(ms->L,"invalid pattern capture")
;}static const char*luaI_classend(MatchState*ms,const char*p){switch(*p++){
case ESC:{if(*p=='\0')luaL_error(ms->L,"malformed pattern (ends with `%')");
return p+1;}case'[':{if(*p=='^')p++;do{if(*p=='\0')luaL_error(ms->L,
"malformed pattern (missing `]')");if(*(p++)==ESC&&*p!='\0')p++;}while(*p!=']'
);return p+1;}default:{return p;}}}static int match_class(int c,int cl){int 
res;switch(tolower(cl)){case'a':res=isalpha(c);break;case'c':res=iscntrl(c);
break;case'd':res=isdigit(c);break;case'l':res=islower(c);break;case'p':res=
ispunct(c);break;case's':res=isspace(c);break;case'u':res=isupper(c);break;
case'w':res=isalnum(c);break;case'x':res=isxdigit(c);break;case'z':res=(c==0);
break;default:return(cl==c);}return(islower(cl)?res:!res);}static int 
matchbracketclass(int c,const char*p,const char*ec){int sig=1;if(*(p+1)=='^'){
sig=0;p++;}while(++p<ec){if(*p==ESC){p++;if(match_class(c,*p))return sig;}else
 if((*(p+1)=='-')&&(p+2<ec)){p+=2;if(uchar(*(p-2))<=c&&c<=uchar(*p))return sig
;}else if(uchar(*p)==c)return sig;}return!sig;}static int luaI_singlematch(int
 c,const char*p,const char*ep){switch(*p){case'.':return 1;case ESC:return 
match_class(c,*(p+1));case'[':return matchbracketclass(c,p,ep-1);default:
return(uchar(*p)==c);}}static const char*match(MatchState*ms,const char*s,
const char*p);static const char*matchbalance(MatchState*ms,const char*s,const 
char*p){if(*p==0||*(p+1)==0)luaL_error(ms->L,"unbalanced pattern");if(*s!=*p)
return NULL;else{int b=*p;int e=*(p+1);int cont=1;while(++s<ms->src_end){if(*s
==e){if(--cont==0)return s+1;}else if(*s==b)cont++;}}return NULL;}static const
 char*max_expand(MatchState*ms,const char*s,const char*p,const char*ep){sint32
 i=0;while((s+i)<ms->src_end&&luaI_singlematch(uchar(*(s+i)),p,ep))i++;while(i
>=0){const char*res=match(ms,(s+i),ep+1);if(res)return res;i--;}return NULL;}
static const char*min_expand(MatchState*ms,const char*s,const char*p,const 
char*ep){for(;;){const char*res=match(ms,s,ep+1);if(res!=NULL)return res;else 
if(s<ms->src_end&&luaI_singlematch(uchar(*s),p,ep))s++;else return NULL;}}
static const char*start_capture(MatchState*ms,const char*s,const char*p,int 
what){const char*res;int level=ms->level;if(level>=MAX_CAPTURES)luaL_error(ms
->L,"too many captures");ms->capture[level].init=s;ms->capture[level].len=what
;ms->level=level+1;if((res=match(ms,s,p))==NULL)ms->level--;return res;}static
 const char*end_capture(MatchState*ms,const char*s,const char*p){int l=
capture_to_close(ms);const char*res;ms->capture[l].len=s-ms->capture[l].init;
if((res=match(ms,s,p))==NULL)ms->capture[l].len=CAP_UNFINISHED;return res;}
static const char*match_capture(MatchState*ms,const char*s,int l){size_t len;l
=check_capture(ms,l);len=ms->capture[l].len;if((size_t)(ms->src_end-s)>=len&&
memcmp(ms->capture[l].init,s,len)==0)return s+len;else return NULL;}static 
const char*match(MatchState*ms,const char*s,const char*p){init:switch(*p){case
'(':{if(*(p+1)==')')return start_capture(ms,s,p+2,CAP_POSITION);else return 
start_capture(ms,s,p+1,CAP_UNFINISHED);}case')':{return end_capture(ms,s,p+1);
}case ESC:{switch(*(p+1)){case'b':{s=matchbalance(ms,s,p+2);if(s==NULL)return 
NULL;p+=4;goto init;}case'f':{const char*ep;char previous;p+=2;if(*p!='[')
luaL_error(ms->L,"missing `[' after `%%f' in pattern");ep=luaI_classend(ms,p);
previous=(s==ms->src_init)?'\0':*(s-1);if(matchbracketclass(uchar(previous),p,
ep-1)||!matchbracketclass(uchar(*s),p,ep-1))return NULL;p=ep;goto init;}
default:{if(isdigit(uchar(*(p+1)))){s=match_capture(ms,s,*(p+1));if(s==NULL)
return NULL;p+=2;goto init;}goto dflt;}}}case'\0':{return s;}case'$':{if(*(p+1
)=='\0')return(s==ms->src_end)?s:NULL;else goto dflt;}default:dflt:{const char
*ep=luaI_classend(ms,p);int m=s<ms->src_end&&luaI_singlematch(uchar(*s),p,ep);
switch(*ep){case'?':{const char*res;if(m&&((res=match(ms,s+1,ep+1))!=NULL))
return res;p=ep+1;goto init;}case'*':{return max_expand(ms,s,p,ep);}case'+':{
return(m?max_expand(ms,s+1,p,ep):NULL);}case'-':{return min_expand(ms,s,p,ep);
}default:{if(!m)return NULL;s++;p=ep;goto init;}}}}}static const char*lmemfind
(const char*s1,size_t l1,const char*s2,size_t l2){if(l2==0)return s1;else if(
l2>l1)return NULL;else{const char*init;l2--;l1=l1-l2;while(l1>0&&(init=(const 
char*)memchr(s1,*s2,l1))!=NULL){init++;if(memcmp(init,s2+1,l2)==0)return init-
1;else{l1-=init-s1;s1=init;}}return NULL;}}static void push_onecapture(
MatchState*ms,int i){int l=ms->capture[i].len;if(l==CAP_UNFINISHED)luaL_error(
ms->L,"unfinished capture");if(l==CAP_POSITION)lua_pushnumber(ms->L,(
lua_Number)(ms->capture[i].init-ms->src_init+1));else lua_pushlstring(ms->L,ms
->capture[i].init,l);}static int push_captures(MatchState*ms,const char*s,
const char*e){int i;luaL_checkstack(ms->L,ms->level,"too many captures");if(ms
->level==0&&s){lua_pushlstring(ms->L,s,e-s);return 1;}else{for(i=0;i<ms->level
;i++)push_onecapture(ms,i);return ms->level;}}static int str_find(lua_State*L)
{size_t l1,l2;const char*s=luaL_checklstring(L,1,&l1);const char*p=
luaL_checklstring(L,2,&l2);sint32 init=posrelat(luaL_optlong(L,3,1),l1)-1;if(
init<0)init=0;else if((size_t)(init)>l1)init=(sint32)l1;if(lua_toboolean(L,4)
||strpbrk(p,SPECIALS)==NULL){const char*s2=lmemfind(s+init,l1-init,p,l2);if(s2
){lua_pushnumber(L,(lua_Number)(s2-s+1));lua_pushnumber(L,(lua_Number)(s2-s+l2
));return 2;}}else{MatchState ms;int anchor=(*p=='^')?(p++,1):0;const char*s1=
s+init;ms.L=L;ms.src_init=s;ms.src_end=s+l1;do{const char*res;ms.level=0;if((
res=match(&ms,s1,p))!=NULL){lua_pushnumber(L,(lua_Number)(s1-s+1));
lua_pushnumber(L,(lua_Number)(res-s));return push_captures(&ms,NULL,0)+2;}}
while(s1++<ms.src_end&&!anchor);}lua_pushnil(L);return 1;}static int gfind_aux
(lua_State*L){MatchState ms;const char*s=lua_tostring(L,lua_upvalueindex(1));
size_t ls=lua_strlen(L,lua_upvalueindex(1));const char*p=lua_tostring(L,
lua_upvalueindex(2));const char*src;ms.L=L;ms.src_init=s;ms.src_end=s+ls;for(
src=s+(size_t)lua_tonumber(L,lua_upvalueindex(3));src<=ms.src_end;src++){const
 char*e;ms.level=0;if((e=match(&ms,src,p))!=NULL){int newstart=e-s;if(e==src)
newstart++;lua_pushnumber(L,(lua_Number)newstart);lua_replace(L,
lua_upvalueindex(3));return push_captures(&ms,src,e);}}return 0;}static int 
gfind(lua_State*L){luaL_checkstring(L,1);luaL_checkstring(L,2);lua_settop(L,2)
;lua_pushnumber(L,0);lua_pushcclosure(L,gfind_aux,3);return 1;}static void 
add_s(MatchState*ms,luaL_Buffer*b,const char*s,const char*e){lua_State*L=ms->L
;if(lua_isstring(L,3)){const char*news=lua_tostring(L,3);size_t l=lua_strlen(L
,3);size_t i;for(i=0;i<l;i++){if(news[i]!=ESC)luaL_putchar(b,news[i]);else{i++
;if(!isdigit(uchar(news[i])))luaL_putchar(b,news[i]);else{int level=
check_capture(ms,news[i]);push_onecapture(ms,level);luaL_addvalue(b);}}}}else{
int n;lua_pushvalue(L,3);n=push_captures(ms,s,e);lua_call(L,n,1);if(
lua_isstring(L,-1))luaL_addvalue(b);else lua_pop(L,1);}}static int str_gsub(
lua_State*L){size_t srcl;const char*src=luaL_checklstring(L,1,&srcl);const 
char*p=luaL_checkstring(L,2);int max_s=luaL_optint(L,4,srcl+1);int anchor=(*p
=='^')?(p++,1):0;int n=0;MatchState ms;luaL_Buffer b;luaL_argcheck(L,
lua_gettop(L)>=3&&(lua_isstring(L,3)||lua_isfunction(L,3)),3,
"string or function expected");luaL_buffinit(L,&b);ms.L=L;ms.src_init=src;ms.
src_end=src+srcl;while(n<max_s){const char*e;ms.level=0;e=match(&ms,src,p);if(
e){n++;add_s(&ms,&b,src,e);}if(e&&e>src)src=e;else if(src<ms.src_end)
luaL_putchar(&b,*src++);else break;if(anchor)break;}luaL_addlstring(&b,src,ms.
src_end-src);luaL_pushresult(&b);lua_pushnumber(L,(lua_Number)n);return 2;}
#define MAX_ITEM 512
#define MAX_FORMAT 20
static void luaI_addquoted(lua_State*L,luaL_Buffer*b,int arg){size_t l;const 
char*s=luaL_checklstring(L,arg,&l);luaL_putchar(b,'"');while(l--){switch(*s){
case'"':case'\\':case'\n':{luaL_putchar(b,'\\');luaL_putchar(b,*s);break;}case
'\0':{luaL_addlstring(b,"\\000",4);break;}default:{luaL_putchar(b,*s);break;}}
s++;}luaL_putchar(b,'"');}static const char*scanformat(lua_State*L,const char*
strfrmt,char*form,int*hasprecision){const char*p=strfrmt;while(strchr("-+ #0",
*p))p++;if(isdigit(uchar(*p)))p++;if(isdigit(uchar(*p)))p++;if(*p=='.'){p++;*
hasprecision=1;if(isdigit(uchar(*p)))p++;if(isdigit(uchar(*p)))p++;}if(isdigit
(uchar(*p)))luaL_error(L,"invalid format (width or precision too long)");if(p-
strfrmt+2>MAX_FORMAT)luaL_error(L,"invalid format (too long)");form[0]='%';
strncpy(form+1,strfrmt,p-strfrmt+1);form[p-strfrmt+2]=0;return p;}static int 
str_format(lua_State*L){int arg=1;size_t sfl;const char*strfrmt=
luaL_checklstring(L,arg,&sfl);const char*strfrmt_end=strfrmt+sfl;luaL_Buffer b
;luaL_buffinit(L,&b);while(strfrmt<strfrmt_end){if(*strfrmt!='%')luaL_putchar(
&b,*strfrmt++);else if(*++strfrmt=='%')luaL_putchar(&b,*strfrmt++);else{char 
form[MAX_FORMAT];char buff[MAX_ITEM];int hasprecision=0;if(isdigit(uchar(*
strfrmt))&&*(strfrmt+1)=='$')return luaL_error(L,
"obsolete option (d$) to `format'");arg++;strfrmt=scanformat(L,strfrmt,form,&
hasprecision);switch(*strfrmt++){case'c':case'd':case'i':{sprintf(buff,form,
luaL_checkint(L,arg));break;}case'o':case'u':case'x':case'X':{sprintf(buff,
form,(unsigned int)(luaL_checknumber(L,arg)));break;}case'e':case'E':case'f':
case'g':case'G':{sprintf(buff,form,luaL_checknumber(L,arg));break;}case'q':{
luaI_addquoted(L,&b,arg);continue;}case's':{size_t l;const char*s=
luaL_checklstring(L,arg,&l);if(!hasprecision&&l>=100){lua_pushvalue(L,arg);
luaL_addvalue(&b);continue;}else{sprintf(buff,form,s);break;}}default:{return 
luaL_error(L,"invalid option to `format'");}}luaL_addlstring(&b,buff,strlen(
buff));}}luaL_pushresult(&b);return 1;}static const luaL_reg strlib[]={{"len",
str_len},{"sub",str_sub},{"lower",str_lower},{"upper",str_upper},{"char",
str_char},{"rep",str_rep},{"byte",str_byte},{"format",str_format},{"dump",
str_dump},{"find",str_find},{"gfind",gfind},{"gsub",str_gsub},{NULL,NULL}};
LUALIB_API int luaopen_string(lua_State*L){luaL_openlib(L,LUA_STRLIBNAME,
strlib,0);return 1;}
#line 1 "ltable.c"
#define ltable_c
#if BITS_INT >26
#define MAXBITS 24
#else
#define MAXBITS (BITS_INT-2)
#endif
#define toobig(x) ((((x)-1)>>MAXBITS)!=0)
#ifndef lua_number2int
#define lua_number2int(i,n) ((i)=(int)(n))
#endif
#define hashpow2(t,n) (gnode(t,lmod((n),sizenode(t))))
#define hashstr(t,str) hashpow2(t,(str)->tsv.hash)
#define hashboolean(t,p) hashpow2(t,p)
#define hashmod(t,n) (gnode(t,((n)%((sizenode(t)-1)|1))))
#define hashpointer(t,p) hashmod(t,IntPoint(p))
#define numints cast(int,sizeof(lua_Number)/sizeof(int))
static Node*hashnum(const Table*t,lua_Number n){unsigned int a[numints];int i;
n+=1;lua_assert(sizeof(a)<=sizeof(n));memcpy(a,&n,sizeof(a));for(i=1;i<numints
;i++)a[0]+=a[i];return hashmod(t,cast(lu_hash,a[0]));}Node*luaH_mainposition(
const Table*t,const TObject*key){switch(ttype(key)){case LUA_TNUMBER:return 
hashnum(t,nvalue(key));case LUA_TSTRING:return hashstr(t,tsvalue(key));case 
LUA_TBOOLEAN:return hashboolean(t,bvalue(key));case LUA_TLIGHTUSERDATA:return 
hashpointer(t,pvalue(key));default:return hashpointer(t,gcvalue(key));}}static
 int arrayindex(const TObject*key){if(ttisnumber(key)){int k;lua_number2int(k,
(nvalue(key)));if(cast(lua_Number,k)==nvalue(key)&&k>=1&&!toobig(k))return k;}
return-1;}static int luaH_index(lua_State*L,Table*t,StkId key){int i;if(
ttisnil(key))return-1;i=arrayindex(key);if(0<=i&&i<=t->sizearray){return i-1;}
else{const TObject*v=luaH_get(t,key);if(v==&luaO_nilobject)luaG_runerror(L,
"invalid key for `next'");i=cast(int,(cast(const lu_byte*,v)-cast(const 
lu_byte*,gval(gnode(t,0))))/sizeof(Node));return i+t->sizearray;}}int 
luaH_next(lua_State*L,Table*t,StkId key){int i=luaH_index(L,t,key);for(i++;i<t
->sizearray;i++){if(!ttisnil(&t->array[i])){setnvalue(key,cast(lua_Number,i+1)
);setobj2s(key+1,&t->array[i]);return 1;}}for(i-=t->sizearray;i<sizenode(t);i
++){if(!ttisnil(gval(gnode(t,i)))){setobj2s(key,gkey(gnode(t,i)));setobj2s(key
+1,gval(gnode(t,i)));return 1;}}return 0;}static void computesizes(int nums[],
int ntotal,int*narray,int*nhash){int i;int a=nums[0];int na=a;int n=(na==0)?-1
:0;for(i=1;a<*narray&&*narray>=twoto(i-1);i++){if(nums[i]>0){a+=nums[i];if(a>=
twoto(i-1)){n=i;na=a;}}}lua_assert(na<=*narray&&*narray<=ntotal);*nhash=ntotal
-na;*narray=(n==-1)?0:twoto(n);lua_assert(na<=*narray&&na>=*narray/2);}static 
void numuse(const Table*t,int*narray,int*nhash){int nums[MAXBITS+1];int i,lg;
int totaluse=0;for(i=0,lg=0;lg<=MAXBITS;lg++){int ttlg=twoto(lg);if(ttlg>t->
sizearray){ttlg=t->sizearray;if(i>=ttlg)break;}nums[lg]=0;for(;i<ttlg;i++){if(
!ttisnil(&t->array[i])){nums[lg]++;totaluse++;}}}for(;lg<=MAXBITS;lg++)nums[lg
]=0;*narray=totaluse;i=sizenode(t);while(i--){Node*n=&t->node[i];if(!ttisnil(
gval(n))){int k=arrayindex(gkey(n));if(k>=0){nums[luaO_log2(k-1)+1]++;(*narray
)++;}totaluse++;}}computesizes(nums,totaluse,narray,nhash);}static void 
setarrayvector(lua_State*L,Table*t,int size){int i;luaM_reallocvector(L,t->
array,t->sizearray,size,TObject);for(i=t->sizearray;i<size;i++)setnilvalue(&t
->array[i]);t->sizearray=size;}static void setnodevector(lua_State*L,Table*t,
int lsize){int i;int size=twoto(lsize);if(lsize>MAXBITS)luaG_runerror(L,
"table overflow");if(lsize==0){t->node=G(L)->dummynode;lua_assert(ttisnil(gkey
(t->node)));lua_assert(ttisnil(gval(t->node)));lua_assert(t->node->next==NULL)
;}else{t->node=luaM_newvector(L,size,Node);for(i=0;i<size;i++){t->node[i].next
=NULL;setnilvalue(gkey(gnode(t,i)));setnilvalue(gval(gnode(t,i)));}}t->
lsizenode=cast(lu_byte,lsize);t->firstfree=gnode(t,size-1);}static void resize
(lua_State*L,Table*t,int nasize,int nhsize){int i;int oldasize=t->sizearray;
int oldhsize=t->lsizenode;Node*nold;Node temp[1];if(oldhsize)nold=t->node;else
{lua_assert(t->node==G(L)->dummynode);temp[0]=t->node[0];nold=temp;setnilvalue
(gkey(G(L)->dummynode));setnilvalue(gval(G(L)->dummynode));lua_assert(G(L)->
dummynode->next==NULL);}if(nasize>oldasize)setarrayvector(L,t,nasize);
setnodevector(L,t,nhsize);if(nasize<oldasize){t->sizearray=nasize;for(i=nasize
;i<oldasize;i++){if(!ttisnil(&t->array[i]))setobjt2t(luaH_setnum(L,t,i+1),&t->
array[i]);}luaM_reallocvector(L,t->array,oldasize,nasize,TObject);}for(i=twoto
(oldhsize)-1;i>=0;i--){Node*old=nold+i;if(!ttisnil(gval(old)))setobjt2t(
luaH_set(L,t,gkey(old)),gval(old));}if(oldhsize)luaM_freearray(L,nold,twoto(
oldhsize),Node);}static void rehash(lua_State*L,Table*t){int nasize,nhsize;
numuse(t,&nasize,&nhsize);resize(L,t,nasize,luaO_log2(nhsize)+1);}Table*
luaH_new(lua_State*L,int narray,int lnhash){Table*t=luaM_new(L,Table);
luaC_link(L,valtogco(t),LUA_TTABLE);t->metatable=hvalue(defaultmeta(L));t->
flags=cast(lu_byte,~0);t->array=NULL;t->sizearray=0;t->lsizenode=0;t->node=
NULL;setarrayvector(L,t,narray);setnodevector(L,t,lnhash);return t;}void 
luaH_free(lua_State*L,Table*t){if(t->lsizenode)luaM_freearray(L,t->node,
sizenode(t),Node);luaM_freearray(L,t->array,t->sizearray,TObject);luaM_freelem
(L,t);}
#if 0
void luaH_remove(Table*t,Node*e){Node*mp=luaH_mainposition(t,gkey(e));if(e!=mp
){while(mp->next!=e)mp=mp->next;mp->next=e->next;}else{if(e->next!=NULL)??}
lua_assert(ttisnil(gval(node)));setnilvalue(gkey(e));e->next=NULL;}
#endif
static TObject*newkey(lua_State*L,Table*t,const TObject*key){TObject*val;Node*
mp=luaH_mainposition(t,key);if(!ttisnil(gval(mp))){Node*othern=
luaH_mainposition(t,gkey(mp));Node*n=t->firstfree;if(othern!=mp){while(othern
->next!=mp)othern=othern->next;othern->next=n;*n=*mp;mp->next=NULL;setnilvalue
(gval(mp));}else{n->next=mp->next;mp->next=n;mp=n;}}setobj2t(gkey(mp),key);
lua_assert(ttisnil(gval(mp)));for(;;){if(ttisnil(gkey(t->firstfree)))return 
gval(mp);else if(t->firstfree==t->node)break;else(t->firstfree)--;}setbvalue(
gval(mp),0);rehash(L,t);val=cast(TObject*,luaH_get(t,key));lua_assert(
ttisboolean(val));setnilvalue(val);return val;}static const TObject*
luaH_getany(Table*t,const TObject*key){if(ttisnil(key))return&luaO_nilobject;
else{Node*n=luaH_mainposition(t,key);do{if(luaO_rawequalObj(gkey(n),key))
return gval(n);else n=n->next;}while(n);return&luaO_nilobject;}}const TObject*
luaH_getnum(Table*t,int key){if(1<=key&&key<=t->sizearray)return&t->array[key-
1];else{lua_Number nk=cast(lua_Number,key);Node*n=hashnum(t,nk);do{if(
ttisnumber(gkey(n))&&nvalue(gkey(n))==nk)return gval(n);else n=n->next;}while(
n);return&luaO_nilobject;}}const TObject*luaH_getstr(Table*t,TString*key){Node
*n=hashstr(t,key);do{if(ttisstring(gkey(n))&&tsvalue(gkey(n))==key)return gval
(n);else n=n->next;}while(n);return&luaO_nilobject;}const TObject*luaH_get(
Table*t,const TObject*key){switch(ttype(key)){case LUA_TSTRING:return 
luaH_getstr(t,tsvalue(key));case LUA_TNUMBER:{int k;lua_number2int(k,(nvalue(
key)));if(cast(lua_Number,k)==nvalue(key))return luaH_getnum(t,k);}default:
return luaH_getany(t,key);}}TObject*luaH_set(lua_State*L,Table*t,const TObject
*key){const TObject*p=luaH_get(t,key);t->flags=0;if(p!=&luaO_nilobject)return 
cast(TObject*,p);else{if(ttisnil(key))luaG_runerror(L,"table index is nil");
else if(ttisnumber(key)&&nvalue(key)!=nvalue(key))luaG_runerror(L,
"table index is NaN");return newkey(L,t,key);}}TObject*luaH_setnum(lua_State*L
,Table*t,int key){const TObject*p=luaH_getnum(t,key);if(p!=&luaO_nilobject)
return cast(TObject*,p);else{TObject k;setnvalue(&k,cast(lua_Number,key));
return newkey(L,t,&k);}}
#line 1 "ltablib.c"
#define ltablib_c
#define aux_getn(L,n) (luaL_checktype(L,n,LUA_TTABLE),luaL_getn(L,n))
static int luaB_foreachi(lua_State*L){int i;int n=aux_getn(L,1);luaL_checktype
(L,2,LUA_TFUNCTION);for(i=1;i<=n;i++){lua_pushvalue(L,2);lua_pushnumber(L,(
lua_Number)i);lua_rawgeti(L,1,i);lua_call(L,2,1);if(!lua_isnil(L,-1))return 1;
lua_pop(L,1);}return 0;}static int luaB_foreach(lua_State*L){luaL_checktype(L,
1,LUA_TTABLE);luaL_checktype(L,2,LUA_TFUNCTION);lua_pushnil(L);for(;;){if(
lua_next(L,1)==0)return 0;lua_pushvalue(L,2);lua_pushvalue(L,-3);lua_pushvalue
(L,-3);lua_call(L,2,1);if(!lua_isnil(L,-1))return 1;lua_pop(L,2);}}static int 
luaB_getn(lua_State*L){lua_pushnumber(L,(lua_Number)aux_getn(L,1));return 1;}
static int luaB_setn(lua_State*L){luaL_checktype(L,1,LUA_TTABLE);luaL_setn(L,1
,luaL_checkint(L,2));return 0;}static int luaB_tinsert(lua_State*L){int v=
lua_gettop(L);int n=aux_getn(L,1)+1;int pos;if(v==2)pos=n;else{pos=
luaL_checkint(L,2);if(pos>n)n=pos;v=3;}luaL_setn(L,1,n);while(--n>=pos){
lua_rawgeti(L,1,n);lua_rawseti(L,1,n+1);}lua_pushvalue(L,v);lua_rawseti(L,1,
pos);return 0;}static int luaB_tremove(lua_State*L){int n=aux_getn(L,1);int 
pos=luaL_optint(L,2,n);if(n<=0)return 0;luaL_setn(L,1,n-1);lua_rawgeti(L,1,pos
);for(;pos<n;pos++){lua_rawgeti(L,1,pos+1);lua_rawseti(L,1,pos);}lua_pushnil(L
);lua_rawseti(L,1,n);return 1;}static int str_concat(lua_State*L){luaL_Buffer 
b;size_t lsep;const char*sep=luaL_optlstring(L,2,"",&lsep);int i=luaL_optint(L
,3,1);int n=luaL_optint(L,4,0);luaL_checktype(L,1,LUA_TTABLE);if(n==0)n=
luaL_getn(L,1);luaL_buffinit(L,&b);for(;i<=n;i++){lua_rawgeti(L,1,i);
luaL_argcheck(L,lua_isstring(L,-1),1,"table contains non-strings");
luaL_addvalue(&b);if(i!=n)luaL_addlstring(&b,sep,lsep);}luaL_pushresult(&b);
return 1;}static void set2(lua_State*L,int i,int j){lua_rawseti(L,1,i);
lua_rawseti(L,1,j);}static int sort_comp(lua_State*L,int a,int b){if(!
lua_isnil(L,2)){int res;lua_pushvalue(L,2);lua_pushvalue(L,a-1);lua_pushvalue(
L,b-2);lua_call(L,2,1);res=lua_toboolean(L,-1);lua_pop(L,1);return res;}else 
return lua_lessthan(L,a,b);}static void auxsort(lua_State*L,int l,int u){while
(l<u){int i,j;lua_rawgeti(L,1,l);lua_rawgeti(L,1,u);if(sort_comp(L,-1,-2))set2
(L,l,u);else lua_pop(L,2);if(u-l==1)break;i=(l+u)/2;lua_rawgeti(L,1,i);
lua_rawgeti(L,1,l);if(sort_comp(L,-2,-1))set2(L,i,l);else{lua_pop(L,1);
lua_rawgeti(L,1,u);if(sort_comp(L,-1,-2))set2(L,i,u);else lua_pop(L,2);}if(u-l
==2)break;lua_rawgeti(L,1,i);lua_pushvalue(L,-1);lua_rawgeti(L,1,u-1);set2(L,i
,u-1);i=l;j=u-1;for(;;){while(lua_rawgeti(L,1,++i),sort_comp(L,-1,-2)){if(i>u)
luaL_error(L,"invalid order function for sorting");lua_pop(L,1);}while(
lua_rawgeti(L,1,--j),sort_comp(L,-3,-1)){if(j<l)luaL_error(L,
"invalid order function for sorting");lua_pop(L,1);}if(j<i){lua_pop(L,3);break
;}set2(L,i,j);}lua_rawgeti(L,1,u-1);lua_rawgeti(L,1,i);set2(L,u-1,i);if(i-l<u-
i){j=l;i=i-1;l=i+2;}else{j=i+1;i=u;u=j-2;}auxsort(L,j,i);}}static int 
luaB_sort(lua_State*L){int n=aux_getn(L,1);luaL_checkstack(L,40,"");if(!
lua_isnoneornil(L,2))luaL_checktype(L,2,LUA_TFUNCTION);lua_settop(L,2);auxsort
(L,1,n);return 0;}static const luaL_reg tab_funcs[]={{"concat",str_concat},{
"foreach",luaB_foreach},{"foreachi",luaB_foreachi},{"getn",luaB_getn},{"setn",
luaB_setn},{"sort",luaB_sort},{"insert",luaB_tinsert},{"remove",luaB_tremove},
{NULL,NULL}};LUALIB_API int luaopen_table(lua_State*L){luaL_openlib(L,
LUA_TABLIBNAME,tab_funcs,0);return 1;}
#line 1 "ltests.c"
#define ltests_c
#ifdef LUA_DEBUG
#define lua_pushintegral(L,i) lua_pushnumber(L,cast(lua_Number,(i)))
static lua_State*lua_state=NULL;int islocked=0;
#define func_at(L,k) (L->ci->base+(k)-1)
static void setnameval(lua_State*L,const char*name,int val){lua_pushstring(L,
name);lua_pushintegral(L,val);lua_settable(L,-3);}
#define MARK 0x55
#ifndef EXTERNMEMCHECK
#define HEADER (sizeof(L_Umaxalign))
#define MARKSIZE 16
#define blockhead(b) (cast(char*,b)-HEADER)
#define setsize(newblock, size)(*cast(size_t*,newblock)=size)
#define checkblocksize(b, size)(size==(*cast(size_t*,blockhead(b))))
#define fillmem(mem,size) memset(mem,-MARK,size)
#else
#define HEADER 0
#define MARKSIZE 0
#define blockhead(b) (b)
#define setsize(newblock, size)
#define checkblocksize(b,size) (1)
#define fillmem(mem,size) 
#endif
unsigned long memdebug_numblocks=0;unsigned long memdebug_total=0;unsigned 
long memdebug_maxmem=0;unsigned long memdebug_memlimit=ULONG_MAX;static void*
checkblock(void*block,size_t size){void*b=blockhead(block);int i;for(i=0;i<
MARKSIZE;i++)lua_assert(*(cast(char*,b)+HEADER+size+i)==MARK+i);return b;}
static void freeblock(void*block,size_t size){if(block){lua_assert(
checkblocksize(block,size));block=checkblock(block,size);fillmem(block,size+
HEADER+MARKSIZE);free(block);memdebug_numblocks--;memdebug_total-=size;}}void*
debug_realloc(void*block,size_t oldsize,size_t size){lua_assert(oldsize==0||
checkblocksize(block,oldsize));lua_assert(block!=NULL||size>0);if(size==0){
freeblock(block,oldsize);return NULL;}else if(size>oldsize&&memdebug_total+
size-oldsize>memdebug_memlimit)return NULL;else{void*newblock;int i;size_t 
realsize=HEADER+size+MARKSIZE;size_t commonsize=(oldsize<size)?oldsize:size;if
(realsize<size)return NULL;newblock=malloc(realsize);if(newblock==NULL)return 
NULL;if(block){memcpy(cast(char*,newblock)+HEADER,block,commonsize);freeblock(
block,oldsize);}fillmem(cast(char*,newblock)+HEADER+commonsize,size-commonsize
);memdebug_total+=size;if(memdebug_total>memdebug_maxmem)memdebug_maxmem=
memdebug_total;memdebug_numblocks++;setsize(newblock,size);for(i=0;i<MARKSIZE;
i++)*(cast(char*,newblock)+HEADER+size+i)=cast(char,MARK+i);return cast(char*,
newblock)+HEADER;}}static char*buildop(Proto*p,int pc,char*buff){Instruction i
=p->code[pc];OpCode o=GET_OPCODE(i);const char*name=luaP_opnames[o];int line=
getline(p,pc);sprintf(buff,"(%4d) %4d - ",line,pc);switch(getOpMode(o)){case 
iABC:sprintf(buff+strlen(buff),"%-12s%4d %4d %4d",name,GETARG_A(i),GETARG_B(i)
,GETARG_C(i));break;case iABx:sprintf(buff+strlen(buff),"%-12s%4d %4d",name,
GETARG_A(i),GETARG_Bx(i));break;case iAsBx:sprintf(buff+strlen(buff),
"%-12s%4d %4d",name,GETARG_A(i),GETARG_sBx(i));break;}return buff;}
#if 0
void luaI_printcode(Proto*pt,int size){int pc;for(pc=0;pc<size;pc++){char buff
[100];printf("%s\n",buildop(pt,pc,buff));}printf("-------\n");}
#endif
static int listcode(lua_State*L){int pc;Proto*p;luaL_argcheck(L,lua_isfunction
(L,1)&&!lua_iscfunction(L,1),1,"Lua function expected");p=clvalue(func_at(L,1)
)->l.p;lua_newtable(L);setnameval(L,"maxstack",p->maxstacksize);setnameval(L,
"numparams",p->numparams);for(pc=0;pc<p->sizecode;pc++){char buff[100];
lua_pushintegral(L,pc+1);lua_pushstring(L,buildop(p,pc,buff));lua_settable(L,-
3);}return 1;}static int listk(lua_State*L){Proto*p;int i;luaL_argcheck(L,
lua_isfunction(L,1)&&!lua_iscfunction(L,1),1,"Lua function expected");p=
clvalue(func_at(L,1))->l.p;lua_newtable(L);for(i=0;i<p->sizek;i++){
lua_pushintegral(L,i+1);luaA_pushobject(L,p->k+i);lua_settable(L,-3);}return 1
;}static int listlocals(lua_State*L){Proto*p;int pc=luaL_checkint(L,2)-1;int i
=0;const char*name;luaL_argcheck(L,lua_isfunction(L,1)&&!lua_iscfunction(L,1),
1,"Lua function expected");p=clvalue(func_at(L,1))->l.p;while((name=
luaF_getlocalname(p,++i,pc))!=NULL)lua_pushstring(L,name);return i-1;}static 
int get_limits(lua_State*L){lua_newtable(L);setnameval(L,"BITS_INT",BITS_INT);
setnameval(L,"LFPF",LFIELDS_PER_FLUSH);setnameval(L,"MAXVARS",MAXVARS);
setnameval(L,"MAXPARAMS",MAXPARAMS);setnameval(L,"MAXSTACK",MAXSTACK);
setnameval(L,"MAXUPVALUES",MAXUPVALUES);return 1;}static int mem_query(
lua_State*L){if(lua_isnone(L,1)){lua_pushintegral(L,memdebug_total);
lua_pushintegral(L,memdebug_numblocks);lua_pushintegral(L,memdebug_maxmem);
return 3;}else{memdebug_memlimit=luaL_checkint(L,1);return 0;}}static int 
hash_query(lua_State*L){if(lua_isnone(L,2)){luaL_argcheck(L,lua_type(L,1)==
LUA_TSTRING,1,"string expected");lua_pushintegral(L,tsvalue(func_at(L,1))->tsv
.hash);}else{TObject*o=func_at(L,1);Table*t;luaL_checktype(L,2,LUA_TTABLE);t=
hvalue(func_at(L,2));lua_pushintegral(L,luaH_mainposition(t,o)-t->node);}
return 1;}static int stacklevel(lua_State*L){unsigned long a=0;
lua_pushintegral(L,(int)(L->top-L->stack));lua_pushintegral(L,(int)(L->
stack_last-L->stack));lua_pushintegral(L,(int)(L->ci-L->base_ci));
lua_pushintegral(L,(int)(L->end_ci-L->base_ci));lua_pushintegral(L,(unsigned 
long)&a);return 5;}static int table_query(lua_State*L){const Table*t;int i=
luaL_optint(L,2,-1);luaL_checktype(L,1,LUA_TTABLE);t=hvalue(func_at(L,1));if(i
==-1){lua_pushintegral(L,t->sizearray);lua_pushintegral(L,sizenode(t));
lua_pushintegral(L,t->firstfree-t->node);}else if(i<t->sizearray){
lua_pushintegral(L,i);luaA_pushobject(L,&t->array[i]);lua_pushnil(L);}else if(
(i-=t->sizearray)<sizenode(t)){if(!ttisnil(gval(gnode(t,i)))||ttisnil(gkey(
gnode(t,i)))||ttisnumber(gkey(gnode(t,i)))){luaA_pushobject(L,gkey(gnode(t,i))
);}else lua_pushstring(L,"<undef>");luaA_pushobject(L,gval(gnode(t,i)));if(t->
node[i].next)lua_pushintegral(L,t->node[i].next-t->node);else lua_pushnil(L);}
return 3;}static int string_query(lua_State*L){stringtable*tb=&G(L)->strt;int 
s=luaL_optint(L,2,0)-1;if(s==-1){lua_pushintegral(L,tb->nuse);lua_pushintegral
(L,tb->size);return 2;}else if(s<tb->size){GCObject*ts;int n=0;for(ts=tb->hash
[s];ts;ts=ts->gch.next){setsvalue2s(L->top,gcotots(ts));incr_top(L);n++;}
return n;}return 0;}static int tref(lua_State*L){int level=lua_gettop(L);int 
lock=luaL_optint(L,2,1);luaL_checkany(L,1);lua_pushvalue(L,1);lua_pushintegral
(L,lua_ref(L,lock));assert(lua_gettop(L)==level+1);return 1;}static int getref
(lua_State*L){int level=lua_gettop(L);lua_getref(L,luaL_checkint(L,1));assert(
lua_gettop(L)==level+1);return 1;}static int unref(lua_State*L){int level=
lua_gettop(L);lua_unref(L,luaL_checkint(L,1));assert(lua_gettop(L)==level);
return 0;}static int metatable(lua_State*L){luaL_checkany(L,1);if(lua_isnone(L
,2)){if(lua_getmetatable(L,1)==0)lua_pushnil(L);}else{lua_settop(L,2);
luaL_checktype(L,2,LUA_TTABLE);lua_setmetatable(L,1);}return 1;}static int 
upvalue(lua_State*L){int n=luaL_checkint(L,2);luaL_checktype(L,1,LUA_TFUNCTION
);if(lua_isnone(L,3)){const char*name=lua_getupvalue(L,1,n);if(name==NULL)
return 0;lua_pushstring(L,name);return 2;}else{const char*name=lua_setupvalue(
L,1,n);lua_pushstring(L,name);return 1;}}static int newuserdata(lua_State*L){
size_t size=luaL_checkint(L,1);char*p=cast(char*,lua_newuserdata(L,size));
while(size--)*p++='\0';return 1;}static int pushuserdata(lua_State*L){
lua_pushlightuserdata(L,cast(void*,luaL_checkint(L,1)));return 1;}static int 
udataval(lua_State*L){lua_pushintegral(L,cast(int,lua_touserdata(L,1)));return
 1;}static int doonnewstack(lua_State*L){lua_State*L1=lua_newthread(L);size_t 
l;const char*s=luaL_checklstring(L,1,&l);int status=luaL_loadbuffer(L1,s,l,s);
if(status==0)status=lua_pcall(L1,0,0,0);lua_pushintegral(L,status);return 1;}
static int s2d(lua_State*L){lua_pushnumber(L,*cast(const double*,
luaL_checkstring(L,1)));return 1;}static int d2s(lua_State*L){double d=
luaL_checknumber(L,1);lua_pushlstring(L,cast(char*,&d),sizeof(d));return 1;}
static int newstate(lua_State*L){lua_State*L1=lua_open();if(L1){
lua_userstateopen(L1);lua_pushintegral(L,(unsigned long)L1);}else lua_pushnil(
L);return 1;}static int loadlib(lua_State*L){static const luaL_reg libs[]={{
"mathlibopen",luaopen_math},{"strlibopen",luaopen_string},{"iolibopen",
luaopen_io},{"tablibopen",luaopen_table},{"dblibopen",luaopen_debug},{
"baselibopen",luaopen_base},{NULL,NULL}};lua_State*L1=cast(lua_State*,cast(
unsigned long,luaL_checknumber(L,1)));lua_pushvalue(L1,LUA_GLOBALSINDEX);
luaL_openlib(L1,NULL,libs,0);return 0;}static int closestate(lua_State*L){
lua_State*L1=cast(lua_State*,cast(unsigned long,luaL_checknumber(L,1)));
lua_close(L1);lua_unlock(L);return 0;}static int doremote(lua_State*L){
lua_State*L1=cast(lua_State*,cast(unsigned long,luaL_checknumber(L,1)));size_t
 lcode;const char*code=luaL_checklstring(L,2,&lcode);int status;lua_settop(L1,
0);status=luaL_loadbuffer(L1,code,lcode,code);if(status==0)status=lua_pcall(L1
,0,LUA_MULTRET,0);if(status!=0){lua_pushnil(L);lua_pushintegral(L,status);
lua_pushstring(L,lua_tostring(L1,-1));return 3;}else{int i=0;while(!lua_isnone
(L1,++i))lua_pushstring(L,lua_tostring(L1,i));lua_pop(L1,i-1);return i-1;}}
static int log2_aux(lua_State*L){lua_pushintegral(L,luaO_log2(luaL_checkint(L,
1)));return 1;}static int int2fb_aux(lua_State*L){int b=luaO_int2fb(
luaL_checkint(L,1));lua_pushintegral(L,b);lua_pushintegral(L,fb2int(b));return
 2;}static int test_do(lua_State*L){const char*p=luaL_checkstring(L,1);if(*p==
'@')lua_dofile(L,p+1);else lua_dostring(L,p);return lua_gettop(L);}static 
const char*const delimits=" \t\n,;";static void skip(const char**pc){while(**
pc!='\0'&&strchr(delimits,**pc))(*pc)++;}static int getnum_aux(lua_State*L,
const char**pc){int res=0;int sig=1;skip(pc);if(**pc=='.'){res=cast(int,
lua_tonumber(L,-1));lua_pop(L,1);(*pc)++;return res;}else if(**pc=='-'){sig=-1
;(*pc)++;}while(isdigit(cast(int,**pc)))res=res*10+(*(*pc)++)-'0';return sig*
res;}static const char*getname_aux(char*buff,const char**pc){int i=0;skip(pc);
while(**pc!='\0'&&!strchr(delimits,**pc))buff[i++]=*(*pc)++;buff[i]='\0';
return buff;}
#define EQ(s1) (strcmp(s1,inst)==0)
#define getnum (getnum_aux(L,&pc))
#define getname (getname_aux(buff,&pc))
static int testC(lua_State*L){char buff[30];const char*pc=luaL_checkstring(L,1
);for(;;){const char*inst=getname;if EQ("")return 0;else if EQ("isnumber"){
lua_pushintegral(L,lua_isnumber(L,getnum));}else if EQ("isstring"){
lua_pushintegral(L,lua_isstring(L,getnum));}else if EQ("istable"){
lua_pushintegral(L,lua_istable(L,getnum));}else if EQ("iscfunction"){
lua_pushintegral(L,lua_iscfunction(L,getnum));}else if EQ("isfunction"){
lua_pushintegral(L,lua_isfunction(L,getnum));}else if EQ("isuserdata"){
lua_pushintegral(L,lua_isuserdata(L,getnum));}else if EQ("isudataval"){
lua_pushintegral(L,lua_islightuserdata(L,getnum));}else if EQ("isnil"){
lua_pushintegral(L,lua_isnil(L,getnum));}else if EQ("isnull"){lua_pushintegral
(L,lua_isnone(L,getnum));}else if EQ("tonumber"){lua_pushnumber(L,lua_tonumber
(L,getnum));}else if EQ("tostring"){const char*s=lua_tostring(L,getnum);
lua_pushstring(L,s);}else if EQ("strlen"){lua_pushintegral(L,lua_strlen(L,
getnum));}else if EQ("tocfunction"){lua_pushcfunction(L,lua_tocfunction(L,
getnum));}else if EQ("return"){return getnum;}else if EQ("gettop"){
lua_pushintegral(L,lua_gettop(L));}else if EQ("settop"){lua_settop(L,getnum);}
else if EQ("pop"){lua_pop(L,getnum);}else if EQ("pushnum"){lua_pushintegral(L,
getnum);}else if EQ("pushnil"){lua_pushnil(L);}else if EQ("pushbool"){
lua_pushboolean(L,getnum);}else if EQ("tobool"){lua_pushintegral(L,
lua_toboolean(L,getnum));}else if EQ("pushvalue"){lua_pushvalue(L,getnum);}
else if EQ("pushcclosure"){lua_pushcclosure(L,testC,getnum);}else if EQ(
"pushupvalues"){lua_pushupvalues(L);}else if EQ("remove"){lua_remove(L,getnum)
;}else if EQ("insert"){lua_insert(L,getnum);}else if EQ("replace"){lua_replace
(L,getnum);}else if EQ("gettable"){lua_gettable(L,getnum);}else if EQ(
"settable"){lua_settable(L,getnum);}else if EQ("next"){lua_next(L,-2);}else if
 EQ("concat"){lua_concat(L,getnum);}else if EQ("lessthan"){int a=getnum;
lua_pushboolean(L,lua_lessthan(L,a,getnum));}else if EQ("equal"){int a=getnum;
lua_pushboolean(L,lua_equal(L,a,getnum));}else if EQ("rawcall"){int narg=
getnum;int nres=getnum;lua_call(L,narg,nres);}else if EQ("call"){int narg=
getnum;int nres=getnum;lua_pcall(L,narg,nres,0);}else if EQ("loadstring"){
size_t sl;const char*s=luaL_checklstring(L,getnum,&sl);luaL_loadbuffer(L,s,sl,
s);}else if EQ("loadfile"){luaL_loadfile(L,luaL_checkstring(L,getnum));}else 
if EQ("setmetatable"){lua_setmetatable(L,getnum);}else if EQ("getmetatable"){
if(lua_getmetatable(L,getnum)==0)lua_pushnil(L);}else if EQ("type"){
lua_pushstring(L,lua_typename(L,lua_type(L,getnum)));}else if EQ("getn"){int i
=getnum;lua_pushintegral(L,luaL_getn(L,i));}else if EQ("setn"){int i=getnum;
int n=cast(int,lua_tonumber(L,-1));luaL_setn(L,i,n);lua_pop(L,1);}else 
luaL_error(L,"unknown instruction %s",buff);}return 0;}static void yieldf(
lua_State*L,lua_Debug*ar){lua_yield(L,0);}static int setyhook(lua_State*L){if(
lua_isnoneornil(L,1))lua_sethook(L,NULL,0,0);else{const char*smask=
luaL_checkstring(L,1);int count=luaL_optint(L,2,0);int mask=0;if(strchr(smask,
'l'))mask|=LUA_MASKLINE;if(count>0)mask|=LUA_MASKCOUNT;lua_sethook(L,yieldf,
mask,count);}return 0;}static int coresume(lua_State*L){int status;lua_State*
co=lua_tothread(L,1);luaL_argcheck(L,co,1,"coroutine expected");status=
lua_resume(co,0);if(status!=0){lua_pushboolean(L,0);lua_insert(L,-2);return 2;
}else{lua_pushboolean(L,1);return 1;}}static const struct luaL_reg tests_funcs
[]={{"hash",hash_query},{"limits",get_limits},{"listcode",listcode},{"listk",
listk},{"listlocals",listlocals},{"loadlib",loadlib},{"stacklevel",stacklevel}
,{"querystr",string_query},{"querytab",table_query},{"doit",test_do},{"testC",
testC},{"ref",tref},{"getref",getref},{"unref",unref},{"d2s",d2s},{"s2d",s2d},
{"metatable",metatable},{"upvalue",upvalue},{"newuserdata",newuserdata},{
"pushuserdata",pushuserdata},{"udataval",udataval},{"doonnewstack",
doonnewstack},{"newstate",newstate},{"closestate",closestate},{"doremote",
doremote},{"log2",log2_aux},{"int2fb",int2fb_aux},{"totalmem",mem_query},{
"resume",coresume},{"setyhook",setyhook},{NULL,NULL}};static void fim(void){if
(!islocked)lua_close(lua_state);lua_assert(memdebug_numblocks==0);lua_assert(
memdebug_total==0);}static int l_panic(lua_State*L){UNUSED(L);fprintf(stderr,
"unable to recover; exiting\n");return 0;}int luaB_opentests(lua_State*L){
lua_atpanic(L,l_panic);lua_userstateopen(L);lua_state=L;luaL_openlib(L,"T",
tests_funcs,0);atexit(fim);return 0;}
#undef main
int main(int argc,char*argv[]){char*limit=getenv("MEMLIMIT");if(limit)
memdebug_memlimit=strtoul(limit,NULL,10);l_main(argc,argv);return 0;}
#endif
#line 1 "ltm.c"
#define ltm_c
const char*const luaT_typenames[]={"nil","boolean","userdata","number",
"string","table","function","userdata","thread"};void luaT_init(lua_State*L){
static const char*const luaT_eventname[]={"__index","__newindex","__gc",
"__mode","__eq","__add","__sub","__mul","__div","__pow","__unm","__lt","__le",
"__concat","__call"};int i;for(i=0;i<TM_N;i++){G(L)->tmname[i]=luaS_new(L,
luaT_eventname[i]);luaS_fix(G(L)->tmname[i]);}}const TObject*luaT_gettm(Table*
events,TMS event,TString*ename){const TObject*tm=luaH_getstr(events,ename);
lua_assert(event<=TM_EQ);if(ttisnil(tm)){events->flags|=cast(lu_byte,1u<<event
);return NULL;}else return tm;}const TObject*luaT_gettmbyobj(lua_State*L,const
 TObject*o,TMS event){TString*ename=G(L)->tmname[event];switch(ttype(o)){case 
LUA_TTABLE:return luaH_getstr(hvalue(o)->metatable,ename);case LUA_TUSERDATA:
return luaH_getstr(uvalue(o)->uv.metatable,ename);default:return&
luaO_nilobject;}}
#line 1 "lua.c"
#define lua_c
#ifdef LUA_USERCONFIG
#include LUA_USERCONFIG
#endif
#ifdef _POSIX_C_SOURCE
#define stdin_is_tty() isatty(0)
#else
#define stdin_is_tty() 1
#endif
#ifndef PROMPT
#define PROMPT "> "
#endif
#ifndef PROMPT2
#define PROMPT2 ">> "
#endif
#ifndef PROGNAME
#define PROGNAME "lua"
#endif
#ifndef lua_userinit
#define lua_userinit(L) openstdlibs(L)
#endif
#ifndef LUA_EXTRALIBS
#define LUA_EXTRALIBS 
#endif
static lua_State*L=NULL;static const char*progname=PROGNAME;LUALIB_API int 
luaopen_posix(lua_State*L);static const luaL_reg lualibs[]={{"base",
luaopen_base},{"table",luaopen_table},{"io",luaopen_io},{"string",
luaopen_string},{"debug",luaopen_debug},{"loadlib",luaopen_loadlib},{"posix",
luaopen_posix},LUA_EXTRALIBS{NULL,NULL}};static void lstop(lua_State*l,
lua_Debug*ar){(void)ar;lua_sethook(l,NULL,0,0);luaL_error(l,"interrupted!");}
static void laction(int i){signal(i,SIG_DFL);lua_sethook(L,lstop,LUA_MASKCALL|
LUA_MASKRET|LUA_MASKCOUNT,1);}static void print_usage(void){fprintf(stderr,
"usage: %s [options] [script [args]].\n""Available options are:\n"
"  -        execute stdin as a file\n""  -e stat  execute string `stat'\n"
"  -i       enter interactive mode after executing `script'\n"
"  -l name  load and run library `name'\n"
"  -v       show version information\n""  --       stop handling options\n",
progname);}static void l_message(const char*pname,const char*msg){if(pname)
fprintf(stderr,"%s: ",pname);fprintf(stderr,"%s\n",msg);}static int report(int
 status){const char*msg;if(status){msg=lua_tostring(L,-1);if(msg==NULL)msg=
"(error with no message)";l_message(progname,msg);lua_pop(L,1);}return status;
}static int lcall(int narg,int clear){int status;int base=lua_gettop(L)-narg;
lua_pushliteral(L,"_TRACEBACK");lua_rawget(L,LUA_GLOBALSINDEX);lua_insert(L,
base);signal(SIGINT,laction);status=lua_pcall(L,narg,(clear?0:LUA_MULTRET),
base);signal(SIGINT,SIG_DFL);lua_remove(L,base);return status;}static void 
print_version(void){l_message(NULL,LUA_VERSION"  "LUA_COPYRIGHT);}static void 
getargs(char*argv[],int n){int i;lua_newtable(L);for(i=0;argv[i];i++){
lua_pushnumber(L,i-n);lua_pushstring(L,argv[i]);lua_rawset(L,-3);}
lua_pushliteral(L,"n");lua_pushnumber(L,i-n-1);lua_rawset(L,-3);}static int 
docall(int status){if(status==0)status=lcall(0,1);return report(status);}
static int file_input(const char*name){return docall(luaL_loadfile(L,name));}
static int dostring(const char*s,const char*name){return docall(
luaL_loadbuffer(L,s,strlen(s),name));}static int load_file(const char*name){
lua_pushliteral(L,"require");lua_rawget(L,LUA_GLOBALSINDEX);if(!lua_isfunction
(L,-1)){lua_pop(L,1);return file_input(name);}else{lua_pushstring(L,name);
return report(lcall(1,1));}}
#ifndef lua_saveline
#define lua_saveline(L,line) 
#endif
#ifndef lua_readline
#define lua_readline(L,prompt) readline(L,prompt)
#ifndef MAXINPUT
#define MAXINPUT 512
#endif
static int readline(lua_State*l,const char*prompt){static char buffer[MAXINPUT
];if(prompt){fputs(prompt,stdout);fflush(stdout);}if(fgets(buffer,sizeof(
buffer),stdin)==NULL)return 0;else{lua_pushstring(l,buffer);return 1;}}
#endif
static const char*get_prompt(int firstline){const char*p=NULL;lua_pushstring(L
,firstline?"_PROMPT":"_PROMPT2");lua_rawget(L,LUA_GLOBALSINDEX);p=lua_tostring
(L,-1);if(p==NULL)p=(firstline?PROMPT:PROMPT2);lua_pop(L,1);return p;}static 
int incomplete(int status){if(status==LUA_ERRSYNTAX&&strstr(lua_tostring(L,-1)
,"near `<eof>'")!=NULL){lua_pop(L,1);return 1;}else return 0;}static int 
load_string(void){int status;lua_settop(L,0);if(lua_readline(L,get_prompt(1))
==0)return-1;if(lua_tostring(L,-1)[0]=='='){lua_pushfstring(L,"return %s",
lua_tostring(L,-1)+1);lua_remove(L,-2);}for(;;){status=luaL_loadbuffer(L,
lua_tostring(L,1),lua_strlen(L,1),"=stdin");if(!incomplete(status))break;if(
lua_readline(L,get_prompt(0))==0)return-1;lua_concat(L,lua_gettop(L));}
lua_saveline(L,lua_tostring(L,1));lua_remove(L,1);return status;}static void 
manual_input(void){int status;const char*oldprogname=progname;progname=NULL;
while((status=load_string())!=-1){if(status==0)status=lcall(0,0);report(status
);if(status==0&&lua_gettop(L)>0){lua_getglobal(L,"print");lua_insert(L,1);if(
lua_pcall(L,lua_gettop(L)-1,0,0)!=0)l_message(progname,lua_pushfstring(L,
"error calling `print' (%s)",lua_tostring(L,-1)));}}lua_settop(L,0);fputs("\n"
,stdout);progname=oldprogname;}static int handle_argv(char*argv[],int*
interactive){if(argv[1]==NULL){if(stdin_is_tty()){print_version();manual_input
();}else file_input(NULL);}else{int i;for(i=1;argv[i]!=NULL;i++){if(argv[i][0]
!='-')break;switch(argv[i][1]){case'-':{if(argv[i][2]!='\0'){print_usage();
return 1;}i++;goto endloop;}case'\0':{file_input(NULL);break;}case'i':{*
interactive=1;break;}case'v':{print_version();break;}case'e':{const char*chunk
=argv[i]+2;if(*chunk=='\0')chunk=argv[++i];if(chunk==NULL){print_usage();
return 1;}if(dostring(chunk,"=<command line>")!=0)return 1;break;}case'l':{
const char*filename=argv[i]+2;if(*filename=='\0')filename=argv[++i];if(
filename==NULL){print_usage();return 1;}if(load_file(filename))return 1;break;
}case'c':{l_message(progname,"option `-c' is deprecated");break;}case's':{
l_message(progname,"option `-s' is deprecated");break;}default:{print_usage();
return 1;}}}endloop:if(argv[i]!=NULL){const char*filename=argv[i];getargs(argv
,i);lua_setglobal(L,"arg");if(strcmp(filename,"/dev/stdin")==0)filename=NULL;
return file_input(filename);}}return 0;}static void openstdlibs(lua_State*l){
const luaL_reg*lib=lualibs;for(;lib->func;lib++){lib->func(l);lua_settop(l,0);
}}static int handle_luainit(void){const char*init=getenv("LUA_INIT");if(init==
NULL)return 0;else if(init[0]=='@')return file_input(init+1);else return 
dostring(init,"=LUA_INIT");}struct Smain{int argc;char**argv;int status;};
static int pmain(lua_State*l){struct Smain*s=(struct Smain*)lua_touserdata(l,1
);int status;int interactive=0;if(s->argv[0]&&s->argv[0][0])progname=s->argv[0
];L=l;lua_userinit(l);status=handle_luainit();if(status==0){status=handle_argv
(s->argv,&interactive);if(status==0&&interactive)manual_input();}s->status=
status;return 0;}int main(int argc,char*argv[]){int status;struct Smain s;
lua_State*l=lua_open();if(l==NULL){l_message(argv[0],
"cannot create state: not enough memory");return EXIT_FAILURE;}s.argc=argc;s.
argv=argv;status=lua_cpcall(l,&pmain,&s);report(status);lua_close(l);return(
status||s.status)?EXIT_FAILURE:EXIT_SUCCESS;}
#line 1 "lundump.c"
#define lundump_c
#define LoadByte (lu_byte)ezgetc
typedef struct{lua_State*L;ZIO*Z;Mbuffer*b;int swap;const char*name;}LoadState
;static void unexpectedEOZ(LoadState*S){luaG_runerror(S->L,
"unexpected end of file in %s",S->name);}static int ezgetc(LoadState*S){int c=
zgetc(S->Z);if(c==EOZ)unexpectedEOZ(S);return c;}static void ezread(LoadState*
S,void*b,int n){int r=luaZ_read(S->Z,b,n);if(r!=0)unexpectedEOZ(S);}static 
void LoadBlock(LoadState*S,void*b,size_t size){if(S->swap){char*p=(char*)b+
size-1;int n=size;while(n--)*p--=(char)ezgetc(S);}else ezread(S,b,size);}
static void LoadVector(LoadState*S,void*b,int m,size_t size){if(S->swap){char*
q=(char*)b;while(m--){char*p=q+size-1;int n=size;while(n--)*p--=(char)ezgetc(S
);q+=size;}}else ezread(S,b,m*size);}static int LoadInt(LoadState*S){int x;
LoadBlock(S,&x,sizeof(x));if(x<0)luaG_runerror(S->L,"bad integer in %s",S->
name);return x;}static size_t LoadSize(LoadState*S){size_t x;LoadBlock(S,&x,
sizeof(x));return x;}static lua_Number LoadNumber(LoadState*S){lua_Number x;
LoadBlock(S,&x,sizeof(x));return x;}static TString*LoadString(LoadState*S){
size_t size=LoadSize(S);if(size==0)return NULL;else{char*s=luaZ_openspace(S->L
,S->b,size);ezread(S,s,size);return luaS_newlstr(S->L,s,size-1);}}static void 
LoadCode(LoadState*S,Proto*f){int size=LoadInt(S);f->code=luaM_newvector(S->L,
size,Instruction);f->sizecode=size;LoadVector(S,f->code,size,sizeof(*f->code))
;}static void LoadLocals(LoadState*S,Proto*f){int i,n;n=LoadInt(S);f->locvars=
luaM_newvector(S->L,n,LocVar);f->sizelocvars=n;for(i=0;i<n;i++){f->locvars[i].
varname=LoadString(S);f->locvars[i].startpc=LoadInt(S);f->locvars[i].endpc=
LoadInt(S);}}static void LoadLines(LoadState*S,Proto*f){int size=LoadInt(S);f
->lineinfo=luaM_newvector(S->L,size,int);f->sizelineinfo=size;LoadVector(S,f->
lineinfo,size,sizeof(*f->lineinfo));}static void LoadUpvalues(LoadState*S,
Proto*f){int i,n;n=LoadInt(S);if(n!=0&&n!=f->nups)luaG_runerror(S->L,
"bad nupvalues in %s: read %d; expected %d",S->name,n,f->nups);f->upvalues=
luaM_newvector(S->L,n,TString*);f->sizeupvalues=n;for(i=0;i<n;i++)f->upvalues[
i]=LoadString(S);}static Proto*LoadFunction(LoadState*S,TString*p);static void
 LoadConstants(LoadState*S,Proto*f){int i,n;n=LoadInt(S);f->k=luaM_newvector(S
->L,n,TObject);f->sizek=n;for(i=0;i<n;i++){TObject*o=&f->k[i];int t=LoadByte(S
);switch(t){case LUA_TNUMBER:setnvalue(o,LoadNumber(S));break;case LUA_TSTRING
:setsvalue2n(o,LoadString(S));break;case LUA_TNIL:setnilvalue(o);break;default
:luaG_runerror(S->L,"bad constant type (%d) in %s",t,S->name);break;}}n=
LoadInt(S);f->p=luaM_newvector(S->L,n,Proto*);f->sizep=n;for(i=0;i<n;i++)f->p[
i]=LoadFunction(S,f->source);}static Proto*LoadFunction(LoadState*S,TString*p)
{Proto*f=luaF_newproto(S->L);f->source=LoadString(S);if(f->source==NULL)f->
source=p;f->lineDefined=LoadInt(S);f->nups=LoadByte(S);f->numparams=LoadByte(S
);f->is_vararg=LoadByte(S);f->maxstacksize=LoadByte(S);LoadLines(S,f);
LoadLocals(S,f);LoadUpvalues(S,f);LoadConstants(S,f);LoadCode(S,f);
#ifndef TRUST_BINARIES
if(!luaG_checkcode(f))luaG_runerror(S->L,"bad code in %s",S->name);
#endif
return f;}static void LoadSignature(LoadState*S){const char*s=LUA_SIGNATURE;
while(*s!=0&&ezgetc(S)==*s)++s;if(*s!=0)luaG_runerror(S->L,
"bad signature in %s",S->name);}static void TestSize(LoadState*S,int s,const 
char*what){int r=LoadByte(S);if(r!=s)luaG_runerror(S->L,
"virtual machine mismatch in %s: ""size of %s is %d but read %d",S->name,what,
s,r);}
#define TESTSIZE(s,w) TestSize(S,s,w)
#define V(v) v/16,v%16
static void LoadHeader(LoadState*S){int version;lua_Number x,tx=TEST_NUMBER;
LoadSignature(S);version=LoadByte(S);if(version>VERSION)luaG_runerror(S->L,
"%s too new: ""read version %d.%d; expected at most %d.%d",S->name,V(version),
V(VERSION));if(version<VERSION0)luaG_runerror(S->L,"%s too old: "
"read version %d.%d; expected at least %d.%d",S->name,V(version),V(VERSION0));
S->swap=(luaU_endianness()!=LoadByte(S));TESTSIZE(sizeof(int),"int");TESTSIZE(
sizeof(size_t),"size_t");TESTSIZE(sizeof(Instruction),"Instruction");TESTSIZE(
SIZE_OP,"OP");TESTSIZE(SIZE_A,"A");TESTSIZE(SIZE_B,"B");TESTSIZE(SIZE_C,"C");
TESTSIZE(sizeof(lua_Number),"number");x=LoadNumber(S);if((long)x!=(long)tx)
luaG_runerror(S->L,"unknown number format in %s",S->name);}static Proto*
LoadChunk(LoadState*S){LoadHeader(S);return LoadFunction(S,NULL);}Proto*
luaU_undump(lua_State*L,ZIO*Z,Mbuffer*buff){LoadState S;const char*s=zname(Z);
if(*s=='@'||*s=='=')S.name=s+1;else if(*s==LUA_SIGNATURE[0])S.name=
"binary string";else S.name=s;S.L=L;S.Z=Z;S.b=buff;return LoadChunk(&S);}int 
luaU_endianness(void){int x=1;return*(char*)&x;}
#line 1 "lvm.c"
#define lvm_c
#ifndef lua_number2str
#define lua_number2str(s,n) sprintf((s),LUA_NUMBER_FMT,(n))
#endif
#define MAXTAGLOOP 100
const TObject*luaV_tonumber(const TObject*obj,TObject*n){lua_Number num;if(
ttisnumber(obj))return obj;if(ttisstring(obj)&&luaO_str2d(svalue(obj),&num)){
setnvalue(n,num);return n;}else return NULL;}int luaV_tostring(lua_State*L,
StkId obj){if(!ttisnumber(obj))return 0;else{char s[32];lua_number2str(s,
nvalue(obj));setsvalue2s(obj,luaS_new(L,s));return 1;}}static void traceexec(
lua_State*L){lu_byte mask=L->hookmask;if(mask&LUA_MASKCOUNT){if(L->hookcount==
0){resethookcount(L);luaD_callhook(L,LUA_HOOKCOUNT,-1);return;}}if(mask&
LUA_MASKLINE){CallInfo*ci=L->ci;Proto*p=ci_func(ci)->l.p;int newline=getline(p
,pcRel(*ci->u.l.pc,p));if(!L->hookinit){luaG_inithooks(L);return;}lua_assert(
ci->state&CI_HASFRAME);if(pcRel(*ci->u.l.pc,p)==0)ci->u.l.savedpc=*ci->u.l.pc;
if(*ci->u.l.pc<=ci->u.l.savedpc||newline!=getline(p,pcRel(ci->u.l.savedpc,p)))
{luaD_callhook(L,LUA_HOOKLINE,newline);ci=L->ci;}ci->u.l.savedpc=*ci->u.l.pc;}
}static void callTMres(lua_State*L,const TObject*f,const TObject*p1,const 
TObject*p2){setobj2s(L->top,f);setobj2s(L->top+1,p1);setobj2s(L->top+2,p2);
luaD_checkstack(L,3);L->top+=3;luaD_call(L,L->top-3,1);L->top--;}static void 
callTM(lua_State*L,const TObject*f,const TObject*p1,const TObject*p2,const 
TObject*p3){setobj2s(L->top,f);setobj2s(L->top+1,p1);setobj2s(L->top+2,p2);
setobj2s(L->top+3,p3);luaD_checkstack(L,4);L->top+=4;luaD_call(L,L->top-4,0);}
static const TObject*luaV_index(lua_State*L,const TObject*t,TObject*key,int 
loop){const TObject*tm=fasttm(L,hvalue(t)->metatable,TM_INDEX);if(tm==NULL)
return&luaO_nilobject;if(ttisfunction(tm)){callTMres(L,tm,t,key);return L->top
;}else return luaV_gettable(L,tm,key,loop);}static const TObject*
luaV_getnotable(lua_State*L,const TObject*t,TObject*key,int loop){const 
TObject*tm=luaT_gettmbyobj(L,t,TM_INDEX);if(ttisnil(tm))luaG_typeerror(L,t,
"index");if(ttisfunction(tm)){callTMres(L,tm,t,key);return L->top;}else return
 luaV_gettable(L,tm,key,loop);}const TObject*luaV_gettable(lua_State*L,const 
TObject*t,TObject*key,int loop){if(loop>MAXTAGLOOP)luaG_runerror(L,
"loop in gettable");if(ttistable(t)){Table*h=hvalue(t);const TObject*v=
luaH_get(h,key);if(!ttisnil(v))return v;else return luaV_index(L,t,key,loop+1)
;}else return luaV_getnotable(L,t,key,loop+1);}void luaV_settable(lua_State*L,
const TObject*t,TObject*key,StkId val){const TObject*tm;int loop=0;do{if(
ttistable(t)){Table*h=hvalue(t);TObject*oldval=luaH_set(L,h,key);if(!ttisnil(
oldval)||(tm=fasttm(L,h->metatable,TM_NEWINDEX))==NULL){setobj2t(oldval,val);
return;}}else if(ttisnil(tm=luaT_gettmbyobj(L,t,TM_NEWINDEX)))luaG_typeerror(L
,t,"index");if(ttisfunction(tm)){callTM(L,tm,t,key,val);return;}t=tm;}while(++
loop<=MAXTAGLOOP);luaG_runerror(L,"loop in settable");}static int call_binTM(
lua_State*L,const TObject*p1,const TObject*p2,StkId res,TMS event){ptrdiff_t 
result=savestack(L,res);const TObject*tm=luaT_gettmbyobj(L,p1,event);if(
ttisnil(tm))tm=luaT_gettmbyobj(L,p2,event);if(!ttisfunction(tm))return 0;
callTMres(L,tm,p1,p2);res=restorestack(L,result);setobjs2s(res,L->top);return 
1;}static const TObject*get_compTM(lua_State*L,Table*mt1,Table*mt2,TMS event){
const TObject*tm1=fasttm(L,mt1,event);const TObject*tm2;if(tm1==NULL)return 
NULL;if(mt1==mt2)return tm1;tm2=fasttm(L,mt2,event);if(tm2==NULL)return NULL;
if(luaO_rawequalObj(tm1,tm2))return tm1;return NULL;}static int call_orderTM(
lua_State*L,const TObject*p1,const TObject*p2,TMS event){const TObject*tm1=
luaT_gettmbyobj(L,p1,event);const TObject*tm2;if(ttisnil(tm1))return-1;tm2=
luaT_gettmbyobj(L,p2,event);if(!luaO_rawequalObj(tm1,tm2))return-1;callTMres(L
,tm1,p1,p2);return!l_isfalse(L->top);}static int luaV_strcmp(const TString*ls,
const TString*rs){const char*l=getstr(ls);size_t ll=ls->tsv.len;const char*r=
getstr(rs);size_t lr=rs->tsv.len;for(;;){int temp=strcoll(l,r);if(temp!=0)
return temp;else{size_t len=strlen(l);if(len==lr)return(len==ll)?0:1;else if(
len==ll)return-1;len++;l+=len;ll-=len;r+=len;lr-=len;}}}int luaV_lessthan(
lua_State*L,const TObject*l,const TObject*r){int res;if(ttype(l)!=ttype(r))
return luaG_ordererror(L,l,r);else if(ttisnumber(l))return nvalue(l)<nvalue(r)
;else if(ttisstring(l))return luaV_strcmp(tsvalue(l),tsvalue(r))<0;else if((
res=call_orderTM(L,l,r,TM_LT))!=-1)return res;return luaG_ordererror(L,l,r);}
static int luaV_lessequal(lua_State*L,const TObject*l,const TObject*r){int res
;if(ttype(l)!=ttype(r))return luaG_ordererror(L,l,r);else if(ttisnumber(l))
return nvalue(l)<=nvalue(r);else if(ttisstring(l))return luaV_strcmp(tsvalue(l
),tsvalue(r))<=0;else if((res=call_orderTM(L,l,r,TM_LE))!=-1)return res;else 
if((res=call_orderTM(L,r,l,TM_LT))!=-1)return!res;return luaG_ordererror(L,l,r
);}int luaV_equalval(lua_State*L,const TObject*t1,const TObject*t2){const 
TObject*tm;lua_assert(ttype(t1)==ttype(t2));switch(ttype(t1)){case LUA_TNIL:
return 1;case LUA_TNUMBER:return nvalue(t1)==nvalue(t2);case LUA_TBOOLEAN:
return bvalue(t1)==bvalue(t2);case LUA_TLIGHTUSERDATA:return pvalue(t1)==
pvalue(t2);case LUA_TUSERDATA:{if(uvalue(t1)==uvalue(t2))return 1;tm=
get_compTM(L,uvalue(t1)->uv.metatable,uvalue(t2)->uv.metatable,TM_EQ);break;}
case LUA_TTABLE:{if(hvalue(t1)==hvalue(t2))return 1;tm=get_compTM(L,hvalue(t1)
->metatable,hvalue(t2)->metatable,TM_EQ);break;}default:return gcvalue(t1)==
gcvalue(t2);}if(tm==NULL)return 0;callTMres(L,tm,t1,t2);return!l_isfalse(L->
top);}void luaV_concat(lua_State*L,int total,int last){do{StkId top=L->base+
last+1;int n=2;if(!tostring(L,top-2)||!tostring(L,top-1)){if(!call_binTM(L,top
-2,top-1,top-2,TM_CONCAT))luaG_concaterror(L,top-2,top-1);}else if(tsvalue(top
-1)->tsv.len>0){lu_mem tl=cast(lu_mem,tsvalue(top-1)->tsv.len)+cast(lu_mem,
tsvalue(top-2)->tsv.len);char*buffer;int i;while(n<total&&tostring(L,top-n-1))
{tl+=tsvalue(top-n-1)->tsv.len;n++;}if(tl>MAX_SIZET)luaG_runerror(L,
"string size overflow");buffer=luaZ_openspace(L,&G(L)->buff,tl);tl=0;for(i=n;i
>0;i--){size_t l=tsvalue(top-i)->tsv.len;memcpy(buffer+tl,svalue(top-i),l);tl
+=l;}setsvalue2s(top-n,luaS_newlstr(L,buffer,tl));}total-=n-1;last-=n-1;}while
(total>1);}static void Arith(lua_State*L,StkId ra,const TObject*rb,const 
TObject*rc,TMS op){TObject tempb,tempc;const TObject*b,*c;if((b=luaV_tonumber(
rb,&tempb))!=NULL&&(c=luaV_tonumber(rc,&tempc))!=NULL){switch(op){case TM_ADD:
setnvalue(ra,nvalue(b)+nvalue(c));break;case TM_SUB:setnvalue(ra,nvalue(b)-
nvalue(c));break;case TM_MUL:setnvalue(ra,nvalue(b)*nvalue(c));break;case 
TM_DIV:setnvalue(ra,nvalue(b)/nvalue(c));break;case TM_POW:{const TObject*f=
luaH_getstr(hvalue(gt(L)),G(L)->tmname[TM_POW]);ptrdiff_t res=savestack(L,ra);
if(!ttisfunction(f))luaG_runerror(L,"`__pow' (`^' operator) is not a function"
);callTMres(L,f,b,c);ra=restorestack(L,res);setobjs2s(ra,L->top);break;}
default:lua_assert(0);break;}}else if(!call_binTM(L,rb,rc,ra,op))
luaG_aritherror(L,rb,rc);}
#define runtime_check(L, c){if(!(c))return 0;}
#define RA(i) (base+GETARG_A(i))
#define XRA(i) (L->base+GETARG_A(i))
#define RB(i) (base+GETARG_B(i))
#define RKB(i) ((GETARG_B(i)<MAXSTACK)?RB(i):k+GETARG_B(i)-MAXSTACK)
#define RC(i) (base+GETARG_C(i))
#define RKC(i) ((GETARG_C(i)<MAXSTACK)?RC(i):k+GETARG_C(i)-MAXSTACK)
#define KBx(i) (k+GETARG_Bx(i))
#define dojump(pc, i)((pc)+=(i))
StkId luaV_execute(lua_State*L){LClosure*cl;TObject*k;const Instruction*pc;
callentry:if(L->hookmask&LUA_MASKCALL){L->ci->u.l.pc=&pc;luaD_callhook(L,
LUA_HOOKCALL,-1);}retentry:L->ci->u.l.pc=&pc;lua_assert(L->ci->state==
CI_SAVEDPC||L->ci->state==(CI_SAVEDPC|CI_CALLING));L->ci->state=CI_HASFRAME;pc
=L->ci->u.l.savedpc;cl=&clvalue(L->base-1)->l;k=cl->p->k;for(;;){const 
Instruction i=*pc++;StkId base,ra;if((L->hookmask&(LUA_MASKLINE|LUA_MASKCOUNT)
)&&(--L->hookcount==0||L->hookmask&LUA_MASKLINE)){traceexec(L);if(L->ci->state
&CI_YIELD){L->ci->u.l.savedpc=pc-1;L->ci->state=CI_YIELD|CI_SAVEDPC;return 
NULL;}}base=L->base;ra=RA(i);lua_assert(L->ci->state&CI_HASFRAME);lua_assert(
base==L->ci->base);lua_assert(L->top<=L->stack+L->stacksize&&L->top>=base);
lua_assert(L->top==L->ci->top||GET_OPCODE(i)==OP_CALL||GET_OPCODE(i)==
OP_TAILCALL||GET_OPCODE(i)==OP_RETURN||GET_OPCODE(i)==OP_SETLISTO);switch(
GET_OPCODE(i)){case OP_MOVE:{setobjs2s(ra,RB(i));break;}case OP_LOADK:{
setobj2s(ra,KBx(i));break;}case OP_LOADBOOL:{setbvalue(ra,GETARG_B(i));if(
GETARG_C(i))pc++;break;}case OP_LOADNIL:{TObject*rb=RB(i);do{setnilvalue(rb--)
;}while(rb>=ra);break;}case OP_GETUPVAL:{int b=GETARG_B(i);setobj2s(ra,cl->
upvals[b]->v);break;}case OP_GETGLOBAL:{TObject*rb=KBx(i);const TObject*v;
lua_assert(ttisstring(rb)&&ttistable(&cl->g));v=luaH_getstr(hvalue(&cl->g),
tsvalue(rb));if(!ttisnil(v)){setobj2s(ra,v);}else setobj2s(XRA(i),luaV_index(L
,&cl->g,rb,0));break;}case OP_GETTABLE:{StkId rb=RB(i);TObject*rc=RKC(i);if(
ttistable(rb)){const TObject*v=luaH_get(hvalue(rb),rc);if(!ttisnil(v)){
setobj2s(ra,v);}else setobj2s(XRA(i),luaV_index(L,rb,rc,0));}else setobj2s(XRA
(i),luaV_getnotable(L,rb,rc,0));break;}case OP_SETGLOBAL:{lua_assert(
ttisstring(KBx(i))&&ttistable(&cl->g));luaV_settable(L,&cl->g,KBx(i),ra);break
;}case OP_SETUPVAL:{int b=GETARG_B(i);setobj(cl->upvals[b]->v,ra);break;}case 
OP_SETTABLE:{luaV_settable(L,ra,RKB(i),RKC(i));break;}case OP_NEWTABLE:{int b=
GETARG_B(i);b=fb2int(b);sethvalue(ra,luaH_new(L,b,GETARG_C(i)));luaC_checkGC(L
);break;}case OP_SELF:{StkId rb=RB(i);TObject*rc=RKC(i);runtime_check(L,
ttisstring(rc));setobjs2s(ra+1,rb);if(ttistable(rb)){const TObject*v=
luaH_getstr(hvalue(rb),tsvalue(rc));if(!ttisnil(v)){setobj2s(ra,v);}else 
setobj2s(XRA(i),luaV_index(L,rb,rc,0));}else setobj2s(XRA(i),luaV_getnotable(L
,rb,rc,0));break;}case OP_ADD:{TObject*rb=RKB(i);TObject*rc=RKC(i);if(
ttisnumber(rb)&&ttisnumber(rc)){setnvalue(ra,nvalue(rb)+nvalue(rc));}else 
Arith(L,ra,rb,rc,TM_ADD);break;}case OP_SUB:{TObject*rb=RKB(i);TObject*rc=RKC(
i);if(ttisnumber(rb)&&ttisnumber(rc)){setnvalue(ra,nvalue(rb)-nvalue(rc));}
else Arith(L,ra,rb,rc,TM_SUB);break;}case OP_MUL:{TObject*rb=RKB(i);TObject*rc
=RKC(i);if(ttisnumber(rb)&&ttisnumber(rc)){setnvalue(ra,nvalue(rb)*nvalue(rc))
;}else Arith(L,ra,rb,rc,TM_MUL);break;}case OP_DIV:{TObject*rb=RKB(i);TObject*
rc=RKC(i);if(ttisnumber(rb)&&ttisnumber(rc)){setnvalue(ra,nvalue(rb)/nvalue(rc
));}else Arith(L,ra,rb,rc,TM_DIV);break;}case OP_POW:{Arith(L,ra,RKB(i),RKC(i)
,TM_POW);break;}case OP_UNM:{const TObject*rb=RB(i);TObject temp;if(tonumber(
rb,&temp)){setnvalue(ra,-nvalue(rb));}else{setnilvalue(&temp);if(!call_binTM(L
,RB(i),&temp,ra,TM_UNM))luaG_aritherror(L,RB(i),&temp);}break;}case OP_NOT:{
int res=l_isfalse(RB(i));setbvalue(ra,res);break;}case OP_CONCAT:{int b=
GETARG_B(i);int c=GETARG_C(i);luaV_concat(L,c-b+1,c);base=L->base;setobjs2s(RA
(i),base+b);luaC_checkGC(L);break;}case OP_JMP:{dojump(pc,GETARG_sBx(i));break
;}case OP_EQ:{if(equalobj(L,RKB(i),RKC(i))!=GETARG_A(i))pc++;else dojump(pc,
GETARG_sBx(*pc)+1);break;}case OP_LT:{if(luaV_lessthan(L,RKB(i),RKC(i))!=
GETARG_A(i))pc++;else dojump(pc,GETARG_sBx(*pc)+1);break;}case OP_LE:{if(
luaV_lessequal(L,RKB(i),RKC(i))!=GETARG_A(i))pc++;else dojump(pc,GETARG_sBx(*
pc)+1);break;}case OP_TEST:{TObject*rb=RB(i);if(l_isfalse(rb)==GETARG_C(i))pc
++;else{setobjs2s(ra,rb);dojump(pc,GETARG_sBx(*pc)+1);}break;}case OP_CALL:
case OP_TAILCALL:{StkId firstResult;int b=GETARG_B(i);int nresults;if(b!=0)L->
top=ra+b;nresults=GETARG_C(i)-1;firstResult=luaD_precall(L,ra);if(firstResult)
{if(firstResult>L->top){lua_assert(L->ci->state==(CI_C|CI_YIELD));(L->ci-1)->u
.l.savedpc=pc;(L->ci-1)->state=CI_SAVEDPC;return NULL;}luaD_poscall(L,nresults
,firstResult);if(nresults>=0)L->top=L->ci->top;}else{if(GET_OPCODE(i)==OP_CALL
){(L->ci-1)->u.l.savedpc=pc;(L->ci-1)->state=(CI_SAVEDPC|CI_CALLING);}else{int
 aux;base=(L->ci-1)->base;ra=RA(i);if(L->openupval)luaF_close(L,base);for(aux=
0;ra+aux<L->top;aux++)setobjs2s(base+aux-1,ra+aux);(L->ci-1)->top=L->top=base+
aux;lua_assert(L->ci->state&CI_SAVEDPC);(L->ci-1)->u.l.savedpc=L->ci->u.l.
savedpc;(L->ci-1)->u.l.tailcalls++;(L->ci-1)->state=CI_SAVEDPC;L->ci--;L->base
=L->ci->base;}goto callentry;}break;}case OP_RETURN:{CallInfo*ci=L->ci-1;int b
=GETARG_B(i);if(b!=0)L->top=ra+b-1;lua_assert(L->ci->state&CI_HASFRAME);if(L->
openupval)luaF_close(L,base);L->ci->state=CI_SAVEDPC;L->ci->u.l.savedpc=pc;if(
!(ci->state&CI_CALLING)){lua_assert((ci->state&CI_C)||ci->u.l.pc!=&pc);return 
ra;}else{int nresults;lua_assert(ttisfunction(ci->base-1)&&(ci->state&
CI_SAVEDPC));lua_assert(GET_OPCODE(*(ci->u.l.savedpc-1))==OP_CALL);nresults=
GETARG_C(*(ci->u.l.savedpc-1))-1;luaD_poscall(L,nresults,ra);if(nresults>=0)L
->top=L->ci->top;goto retentry;}}case OP_FORLOOP:{lua_Number step,idx,limit;
const TObject*plimit=ra+1;const TObject*pstep=ra+2;if(!ttisnumber(ra))
luaG_runerror(L,"`for' initial value must be a number");if(!tonumber(plimit,ra
+1))luaG_runerror(L,"`for' limit must be a number");if(!tonumber(pstep,ra+2))
luaG_runerror(L,"`for' step must be a number");step=nvalue(pstep);idx=nvalue(
ra)+step;limit=nvalue(plimit);if(step>0?idx<=limit:idx>=limit){dojump(pc,
GETARG_sBx(i));chgnvalue(ra,idx);}break;}case OP_TFORLOOP:{int nvar=GETARG_C(i
)+1;StkId cb=ra+nvar+2;setobjs2s(cb,ra);setobjs2s(cb+1,ra+1);setobjs2s(cb+2,ra
+2);L->top=cb+3;luaD_call(L,cb,nvar);L->top=L->ci->top;ra=XRA(i)+2;cb=ra+nvar;
do{nvar--;setobjs2s(ra+nvar,cb+nvar);}while(nvar>0);if(ttisnil(ra))pc++;else 
dojump(pc,GETARG_sBx(*pc)+1);break;}case OP_TFORPREP:{if(ttistable(ra)){
setobjs2s(ra+1,ra);setobj2s(ra,luaH_getstr(hvalue(gt(L)),luaS_new(L,"next")));
}dojump(pc,GETARG_sBx(i));break;}case OP_SETLIST:case OP_SETLISTO:{int bc;int 
n;Table*h;runtime_check(L,ttistable(ra));h=hvalue(ra);bc=GETARG_Bx(i);if(
GET_OPCODE(i)==OP_SETLIST)n=(bc&(LFIELDS_PER_FLUSH-1))+1;else{n=L->top-ra-1;L
->top=L->ci->top;}bc&=~(LFIELDS_PER_FLUSH-1);for(;n>0;n--)setobj2t(luaH_setnum
(L,h,bc+n),ra+n);break;}case OP_CLOSE:{luaF_close(L,ra);break;}case OP_CLOSURE
:{Proto*p;Closure*ncl;int nup,j;p=cl->p->p[GETARG_Bx(i)];nup=p->nups;ncl=
luaF_newLclosure(L,nup,&cl->g);ncl->l.p=p;for(j=0;j<nup;j++,pc++){if(
GET_OPCODE(*pc)==OP_GETUPVAL)ncl->l.upvals[j]=cl->upvals[GETARG_B(*pc)];else{
lua_assert(GET_OPCODE(*pc)==OP_MOVE);ncl->l.upvals[j]=luaF_findupval(L,base+
GETARG_B(*pc));}}setclvalue(ra,ncl);luaC_checkGC(L);break;}}}}
#line 1 "lzio.c"
#define lzio_c
int luaZ_fill(ZIO*z){size_t size;const char*buff=z->reader(NULL,z->data,&size)
;if(buff==NULL||size==0)return EOZ;z->n=size-1;z->p=buff;return char2int(*(z->
p++));}int luaZ_lookahead(ZIO*z){if(z->n==0){int c=luaZ_fill(z);if(c==EOZ)
return c;z->n++;z->p--;}return char2int(*z->p);}void luaZ_init(ZIO*z,
lua_Chunkreader reader,void*data,const char*name){z->reader=reader;z->data=
data;z->name=name;z->n=0;z->p=NULL;}size_t luaZ_read(ZIO*z,void*b,size_t n){
while(n){size_t m;if(z->n==0){if(luaZ_fill(z)==EOZ)return n;else{++z->n;--z->p
;}}m=(n<=z->n)?n:z->n;memcpy(b,z->p,m);z->n-=m;z->p+=m;b=(char*)b+m;n-=m;}
return 0;}char*luaZ_openspace(lua_State*L,Mbuffer*buff,size_t n){if(n>buff->
buffsize){if(n<LUA_MINBUFFER)n=LUA_MINBUFFER;luaM_reallocvector(L,buff->buffer
,buff->buffsize,n,char);buff->buffsize=n;}return buff->buffer;}

