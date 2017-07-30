-- xpattern.lua
-- Preliminary regular expression-like support in Lua
-- Uses Lua patterns as the core building block.
--
-- Implemented in pure Lua with code generation technique.
-- It translates an expression into a snippet of Lua code
-- having a series of `string.match` calls, which is then
-- compiled (via `load`).
--
-- Like lpeg, does not support backtracking.
--
-- WARNING: This is experimental code.  The design and implementation
-- has not been thoroughly tested.
--
-- Version v20091021.
-- (c) 2008-2009 David Manura. Licensed under the same terms as Lua (MIT license).
-- Please post patches.

M = {}

local string = string
local format = string.format
local match  = string.match
local assert = assert
local error  = error
local ipairs = ipairs
local setmetatable = setmetatable
local type   = type
local print  = print
local load   = load


-- Adds whitespace to string `s`.
-- Whitespace string `ws` (default to '' if omitted) is prepended to each line
-- of `s`.  Also ensures `s` is is terminated by a newline.
local function add_whitespace(s, ws)
  ws = ws or ''
  s = s:gsub('[^\r\n]+', ws .. '%1')
  if s:match('[^\r\n]$') then
    s = s .. '\n'
  end
  return s
end

-- Counts the number `count` of captures '()' in Lua pattern string `pat`.
local function count_captures(pat)
  local count = 0
  local pos = 1
  while pos <= #pat do
    local pos2 = pat:match('^[^%(%%%[]+()', pos)
    if pos2 then
      pos = pos2
    elseif pat:match('^%(', pos) then
      count = count + 1
      pos = pos + 1
    elseif pat:match('^%%b..', pos) then
      pos = pos + 3
    elseif pat:match('^%%.', pos) then
      pos = pos + 2
    else
      local pos2 = pat:match('^%[[^%]%%]*()', pos)
      if pos2 then
        pos = pos2
        while 1 do
          local pos2 = pat:match('^%%.[^%]%%]*()', pos)
          if pos2 then
            pos = pos2
          elseif pat:match('^%]', pos) then
            pos = pos + 1
            break
          else
            error('syntax', 2)
          end
        end
      else
        error('syntax', 2)
      end
    end
  end
  return count
end
M._count_captures = count_captures


-- Appends '()' to Lua pattern string `pat`.
local function pat_append_pos(pat)
  local prefix = pat:match'^(.*)%$$'
  pat = prefix and prefix .. '()$' or pat .. '()'
  return pat
end

-- Prepends '()' to Lua pattern string `pat`.
local function pat_prepend_pos(pat)
  local postfix = pat:match'^%^(.*)'
  pat = postfix and '^()' .. postfix or '()' .. pat
  return pat
end


-- Prepends '^' to Lua pattern string `pat`.
local function pat_prepend_carrot(pat)
  local postfix = pat:match'^%^(.*)'
  pat = postfix and pat or '^' .. pat
  return pat
end


-- Return a string listing pattern capture variables with indices `firstidx`
-- to `lastidx`.
-- Ex: code_vars(1,2) --> 'c1,c2'
local function code_vars(firstidx, lastidx)
  local code = ''
  for i=firstidx,lastidx do
    code = code .. (i == firstidx and '' or ',') .. 'c' .. i
  end
  return code
end


-- Metatable for expression objects
local epat_mt = {}
epat_mt.__index = epat_mt


-- Builds an extended pattern object `epat` from Lua string pattern `pat`.
local function pattern(pat)
  local epat = setmetatable({}, epat_mt)
  epat.call = function(srcidx0, destidx0, totncaptures0)
    local ncaptures = count_captures(pat)
    local lvars =
      code_vars(totncaptures0+1, totncaptures0+ncaptures)
      .. (ncaptures == 0 and '' or ',') .. 'pos' .. destidx0
    local pat = pat_append_pos(pat)

    pat = pat_prepend_carrot(pat)

    local str = format('%q', pat)
    local code = lvars .. ' = match(s, ' .. str .. ', pos' .. srcidx0 .. ')\n'
    return code, ncaptures
  end
  epat.anchored = pat:sub(1,1) == '^'
  return epat
end


-- Generates code from pattern `anypat` (either Lua pattern string or extended
-- pattern object).
--  `anypat`    - either Lua pattern string or extended pattern object
--  `srcidx0`   - index of variable holding position to start matching at
--  `destidx0`  - index of variable holding position to store subsequent
--                match position at.  stores nil if no match
--  `totncaptures0` - number of captures prior to this match
--  `code`      - Lua code string (code) and number of
--  `ncaptures` - number of captures in pattern.
local function gen(anypat, srcidx0, destidx0, totncaptures0)
  if type(anypat) == 'string' then
    anypat = pat_prepend_carrot(anypat)
    anypat = pattern(anypat)
  end
  local code, ncaptures = anypat(srcidx0, destidx0, totncaptures0)
  return code, ncaptures
end


-- Creates a new extended pattern object `epat` that is the concatenation of
-- the given list (of size >= 0) of pattern objects.
-- Specify a single string argument to convert a Lua pattern to an extended
-- pattern object.
local function seq(...) -- epats...
  -- Ensure args are extended pattern objects.
  local epats = {...}
  for i=1,#epats do
    if type(epats[i]) == 'string' then
      epats[i] = pattern(epats[i])
    end
  end

  local epat = setmetatable({}, epat_mt)
  epat.call = function(srcidx0, destidx0, totncaptures0, ws)
    if #epats == 0 then
      return 'pos' .. destidx0 .. ' = pos' .. srcidx0 .. '\n', 0
    elseif #epats == 1 then
      return epats[1](srcidx0, destidx0, totncaptures0, ws)
    else
      local ncaptures = 0
      local pat_code, pat_ncaptures =
          gen(epats[1], srcidx0, destidx0, totncaptures0+ncaptures, true)
      ncaptures = ncaptures + pat_ncaptures
      local code = add_whitespace(pat_code, '')

      for i=2,#epats do
        local pat_code, pat_ncaptures =
            gen(epats[i], destidx0, destidx0, totncaptures0+ncaptures, true)
        ncaptures = ncaptures + pat_ncaptures
        code =
          code ..
          'if pos' .. destidx0 .. ' then\n' ..
            add_whitespace(pat_code, '  ') ..
          'end\n'
      end
      return code, ncaptures
    end
  end
  if epats[1] and epats[1].anchored then
    epat.anchored = true
  end
  return epat
end
M.P = seq


-- Creates new extended pattern object `epat` that is the alternation of the
-- given list of pattern objects `epats...`.
local function alt(...) -- epats...
  -- Ensure args are extended pattern objects.
  local epats = {...}
  for i=1,#epats do
    if type(epats[i]) == 'string' then
      epats[i] = pattern(epats[i])
    end
  end

  local epat = setmetatable({}, epat_mt)
  epat.call = function(srcidx0, destidx0, totncaptures0)
    if #epats == 0 then
      return 'pos' .. destidx0 .. ' = pos' .. srcidx0 .. '\n', 0
    elseif #epats == 1 then
      return epats[1](srcidx0, destidx0, totncaptures0)
    else
      local ncaptures = 0
      local pat_code, pat_ncaptures =
          gen(epats[1], srcidx0, destidx0+1, totncaptures0+ncaptures, true)
      ncaptures = ncaptures + pat_ncaptures
      local code = 'local pos' .. destidx0+1 .. ' = pos' .. srcidx0 .. '\n' ..
                   add_whitespace(pat_code, '')

      for i=2,#epats do
        local pat_code, pat_ncaptures =
            gen(epats[i], srcidx0, destidx0+1, totncaptures0+ncaptures, true)
        ncaptures = ncaptures + pat_ncaptures
        code =
          code ..
          'if not pos' .. destidx0+1 .. ' then\n' ..
            add_whitespace(pat_code, '  ') ..
          'end\n'
      end
      code = code .. 'pos' .. destidx0 .. ' = pos' .. destidx0+1 .. '\n'
      return code, ncaptures
    end
  end
  return epat
end
M.alt = alt


-- Creates new extended pattern object `epat` that is zero or more repetitions
-- of the given pattern object `pat` (if one evaluates to false) or one or more
-- (if one evaluates to true).
local function star(pat, one)
  local epat = setmetatable({}, epat_mt)
  epat.call = function(srcidx0, destidx0, totncaptures0)
    local ncaptures = 0
    local destidx = destidx0 + 1
    local code = 'do\n' ..
                 '  local pos' .. destidx .. '=pos' .. srcidx0 .. '\n'
    local pat_code, pat_ncaptures =
        gen(pat, destidx, destidx, totncaptures0+ncaptures, true)
    ncaptures = ncaptures + pat_ncaptures
    code = code ..
      (one and ('  pos' .. destidx0 .. ' = nil\n')
           or  ('  pos' .. destidx0 .. ' = pos' .. srcidx0 .. '\n')) ..
      '  while 1 do\n' ..
           add_whitespace(pat_code, '    ') ..
      '    if pos' .. destidx .. ' then\n' ..
      '      pos' .. destidx0 .. '=pos' .. destidx .. '\n' ..
      '    else break end\n' ..
      '  end\n' ..
      'end\n'
    return code, ncaptures
  end
  return epat
end
M.star = star


-- Creates new extended pattern object `epat` that is zero or one of the
-- given pattern object `epat0`.
local function zero_or_one(epat0)
  local epat = setmetatable({}, epat_mt)
  epat.call = function(srcidx0, destidx0, totncaptures0)
    local ncaptures = 0
    local destidx = destidx0 + 1
    local code = 'do\n' ..
                 '  local pos' .. destidx .. '=pos' .. srcidx0 .. '\n'
    local epat0_code, epat0_ncaptures =
        gen(epat0, destidx, destidx, totncaptures0+ncaptures, true)
    ncaptures = ncaptures + epat0_ncaptures
    code = code ..
      add_whitespace(epat0_code) ..
      '  if pos' .. destidx .. ' then\n' ..
      '    pos' .. destidx0 .. '=pos' .. destidx .. '\n' ..
      '  else\n' ..
      '    pos' .. destidx0 .. '=pos' .. srcidx0 .. '\n' ..
      '  end\n' ..
      'end\n'
    return code, ncaptures
  end
  return epat
end
M.zero_or_one = zero_or_one


-- Gets Lua core code string `code` corresponding to pattern object `epat`
local function basic_code_of(epat)
  local pat_code, ncaptures = epat(1, 2, 0, true)
  local lvars = code_vars(1, ncaptures)

  if epat.anchored then
    local code =
      'local pos1=pos or 1\n' ..
      'local pos2\n' ..
      (lvars ~= '' and '  local ' .. lvars .. '\n' or '') ..
      add_whitespace(pat_code) .. '\n' ..
      'if pos2 then return ' .. (lvars ~= '' and lvars or 's:sub(pos1,pos2-1)') .. ' end\n'
    return code
  else
    local code =
        'for pos1=(pos or 1),#s do\n' ..
        '  local pos2\n'
    if lvars == '' then
      code =
        code ..
           add_whitespace(pat_code, '  ') ..
        '  if pos2 then return s:sub(pos1,pos2-1) end\n'
    else
      code =
        code ..
        '  local ' .. lvars .. '\n' ..
           add_whitespace(pat_code, '  ') ..
        '  if pos2 then return ' .. lvars .. ' end\n'
    end
    code =
        code ..
        'end\n'
    return code
  end
end
M.basic_code_of = basic_code_of


-- Gets Lua complete code string `code` corresponding to pattern object `epat`.
local function code_of(epat)
  local code =
    'local match = ...\n' ..
    'return function(s,pos)\n' ..
    add_whitespace(basic_code_of(epat), '  ') ..
    'end\n'
  return code
end
M.code_of = code_of


-- Compiles pattern object `epat` to Lua function `f`.
local function compile(epat)
  local code = code_of(epat)
  if M.debug then print('DEBUG:\n' .. code) end
  local f = assert(load(ChunkStream(code)))(match)
  return f
end
M.compile = compile


-- operator for pattern matching
function epat_mt.__call(epat, ...)
  return epat.call(...)
end


-- operator for pattern alternation
function epat_mt.__add(a_epat, b_epat)
  return alt(a_epat, b_epat)
end


-- operator for pattern concatenation
function epat_mt.__mul(a_epat, b_epat)
  return seq(a_epat, b_epat)
end


-- operator for pattern repetition
function epat_mt.__pow(epat, n)
  if n == 0 then
    return star(epat)
  elseif n == 1 then
    return star(epat, true)
  elseif n == -1 then
    return zero_or_one(epat)
  else
    error 'FIX - unimplemented'
  end
end


-- IMPROVE design?
epat_mt.compile       = compile
epat_mt.basic_code_of = basic_code_of
epat_mt.code_of       = code_of


