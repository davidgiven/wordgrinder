-- xpattern_test.lua - test suite for xpattern.lua

-- utility function: convert list of values to string.
local function str(...)
  local n = select('#', ...)
  local t = {...}
  for i=1,n do t[i] = tostring(t[i]) end
  return table.concat(t, ',')
end

--local M = require "xpattern"
local P = M.P
M.debug = false

-- internal: _count_captures
assert(M._count_captures'' == 0)
assert(M._count_captures'a' == 0)
assert(not pcall(function() M._count_captures'%' end))
assert(M._count_captures'()' == 1)
assert(M._count_captures'%(%)' == 0)    -- %(
assert(M._count_captures'[()]' == 0)    -- () inside []
assert(M._count_captures'[%(%)]' == 0)  -- %( inside []
assert(M._count_captures'[%]()]' == 0)  -- %] inside []
assert(M._count_captures'[]()]' == 1)
assert(M._count_captures'%b()' == 0)    -- () on %b..
assert(M._count_captures'(()().())' == 4)   -- nested
-- more complex example
assert(M._count_captures'.(.%))[(]%(()' == 2)


-- simple matching
assert(str(P'':compile()('')) == '')
assert(str(P'':compile()('a')) == '')
assert(str(P'a':compile()('')) == '')
assert(str(P'a':compile()('a')) == 'a')
assert(str(P'a':compile()('ba')) == 'a')
assert(str(P'a+':compile()('baa')) == 'aa')

-- simple anchors
assert(str(P'^a+':compile()('aa')) == 'aa')
assert(str(P'^a+':compile()('baab')) == '') -- $ fail
assert(str(P'a+$':compile()('baa')) == 'aa')
assert(str(P'a+$':compile()('baab')) == '') -- $ fail

-- simple captures
assert(str(P'(a+)(b+)':compile()('baab')) == 'aa,b')
assert(str(P'^(a+)(b+)':compile()('baab')) == '')

-- simple sequences
local m = P():compile()
assert(str( m('') ) == '')
assert(str( m('a') ) == '')
local m = P(''):compile()
assert(str( m('') ) == '')
assert(str( m('a') ) == '')
local m = P('a', 'b', 'c'):compile()
assert(str( m('.a.') ) == '')
assert(str( m('.abc.') ) == 'abc')
local m = (P'a' * P'b' * P'c'):compile() -- identical
assert(str( m('.a.') ) == '')
assert(str( m('.abc.') ) == 'abc')
local m = P(P'a', 'b', P'c'):compile() -- identical
assert(str( m('.a.') ) == '')
assert(str( m('.abc.') ) == 'abc')
local m = P(P'a+', 'b+', P'c+'):compile()
assert(str( m('.abaabcc.') ) == 'aabcc')

-- simple alternation
local m = (P'aa+' + P'bb+'):compile()
assert(str( m('abbaa') ) == 'bb')
local m = (P'aa+' + P'bb+' + P'cc+'):compile()
assert(str( m('abccaa') ) == 'cc')

-- simple combinations
local m = ((P'(a+)' + P'b(b*)') * P'(c+)()'):compile()
assert(str( m("aacccdd")) == 'aa,nil,ccc,6')
assert(str( m("bbcccdd")) == 'nil,b,ccc,6')
assert(str( m("bbdd")) == '')
--print('?'..str( m("aabbcc")))
assert(str( m("aabbcc")) == 'nil,b,cc,7') -- alternative

-- simple replication (*)
local m = ( P'a'^0 ):compile()
assert(str(m'') == '')
assert(str(m'a') == 'a')
assert(str(m'aab') == 'aa')

-- replication (*)
local m = ( (P'a+' + P'b+')^0 ):compile()
assert(str(m'zabaabbc') == '')
assert(str(m'abaabb') == 'abaabb')
local m = ( (P'a+' * P'b+' + P'c+' * P'd+')^0 ):compile()
assert(str(m'aabbccddaa') == 'aabbccdd')
local m = ( P'aa'^0 * P'bb' * P'aa'^0 ):compile()
assert(str(m'aaccaaaabbaa') == 'aaaabbaa')

-- simple replication (+)
local m = ( P'a'^1 ):compile()
assert(str(m'') == '')
assert(str(m'a') == 'a')
assert(str(m'aab') == 'aa')

-- replacation (+)
local m = ( P'b' * P'a'^1 ):compile()
--print(m'b')
assert(str(m'b') == '')
assert(str(m'ba') == 'ba')
assert(str(m'baab') == 'baa')

-- simple replication (?)
local m = ( P'a'^-1 ):compile()
assert(str(m'') == '')
assert(str(m'a') == 'a')
assert(str(m'aab') == 'a')

-- replication (?)
local m = ( P'c' * (P'a+' + P'b+')^-1 ):compile()
assert(str(m'caabb') == 'caa')


-- Some of these examples from Mastering Regular Expressions (MRE),
-- 2nd Ed. Jeffrey .Friedl.

-- MRE p.19
local m = ( P'^' * (P'From' + P'Subject' + P'Date') * P':%s*(.*)' ):compile()
assert(str(m('Subject: test')) == 'test')

-- MRE p.13
local m = ( (P'Geo' + P'Je') * P'ff' * (P're' + P'er') * P'y' ):compile()
assert(str(m'Jeffrey') == 'Jeffrey')
assert(str(m'Jeffery') == 'Jeffery')
assert(str(m'Geoffrey') == 'Geoffrey')
assert(str(m'Geoffery') == 'Geoffery')
assert(str(m'Jefery') == '')
assert(str(m'Geofferi') == '')
assert(str(m'GeoffrezGeoffery') == 'Geoffery') -- skips
assert(str(m'JefferzGeoffery') == 'Geoffery') -- skips
assert(str(m'GeoffJeffery') == 'Jeffery') -- skips

-- MRE p.24
local m = ( P'%$[0-9]+' * P'%.[0-9][0-9]'^-1 ):compile()
assert(str(m'$20.00') == '$20.00')
assert(str(m'$20') == '$20')
assert(str(m'$20.00.00') == '$20.00')

-- example
--print 'example'
--local M = require "xpattern"
local P = M.P
local m = ( (P'(b+)' + P'(c+)') * P'[A-Z][a-z]'^0 * P'(.)()' ):compile()
local a,b,c,d = m('mmcccZzYybbZzYyddd') -- match c not b first
assert(a == nil and b == 'ccc' and c == 'b' and d == 11)

-- example
local m = P('foo', P'bar'+P'baz', 'qux'):compile()
assert(str(m'afoobazfoobarquxbar', 'foobarqux'))
local m = P('^foo', P'bar'+P'baz', 'qux'):compile() -- anchored
assert(str(m'afoobazfoobarquxbar', ''))
assert(str(m'foobarquxbar', ''))

-- http://lua-users.org/lists/lua-l/2009-10/msg00752.html
local m = (
  P'^' * ( ( P'ceil'+P'abs' +P'floor'+P'mod' +P'exp'+P'log'+P'pow'+
             P'sqrt'+P'acos'+P'asin' +P'atan'+P'cos'+P'sin'+P'tan'+
             P'deg' +P'rad' +P'random'
           ) * P'%('
           + P'[0-9%(%)%-%+%*%/%.%,]' + P'pi'
          )^1 * P'$'
):compile()
assert(m'cos(1+pi)' == 'cos(1+pi)')
assert(m'cos(1+p)' == nil) -- 'p'
assert(m'cos(12.3/2)+mod(2,3)' == 'cos(12.3/2)+mod(2,3)')
assert(m'cos(12.3/2)+mod(2,3) ' == nil) -- ' '
assert(m' cos(12.3/2)+mod(2,3)' == nil) -- ' '
assert(m'cos(12.3/2)+mod+2' == nil) -- no '('

