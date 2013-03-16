#!/bin/sh
# Prime Mover
#
# (C) 2006 David Given.
# Prime Mover is licensed under the MIT open source license. To get the full
# license text, run this file with the '--license' option.
#
# WARNING: this file contains hard-coded offsets --- do not edit!
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
	
PMEXEC="./.pm-exec-$ARCH"
set -e

GZFILE=/tmp/pm-$$.gz
CFILE=/tmp/pm-$$.c
trap "rm -f $GZFILE $CFILE" EXIT

extract_section() {
	dd skip=$1 count=$2 bs=1 if="$0" 2>/dev/null | cat
}

# If the bootstrap's built, run it.

if [ "$PMEXEC" -nt "$0" ]; then
	extract_section 1178   23147  | "$PMEXEC" /dev/stdin "$@"
	exit $?
fi

# Otherwise, compile it and restart.

echo "pm: bootstrapping..."

if [ -x "$(which gcc 2>/dev/null)" ]; then
	CC="gcc -O -s"
else
	CC="cc"
fi

extract_section 24325  157804 > /tmp/pm-$$.c
$CC $CFILE -o "$PMEXEC" && exec "$0" "$@"

echo "pm: bootstrap failed."
exit 1
#!/usr/bin/lua
local VERSION="0.1.6.2"
local stdin=io.stdin
local stdout=io.stdout
local stderr=io.stderr
local string_find=string.find
local string_gsub=string.gsub
local string_sub=string.sub
local string_byte=string.byte
local table_insert=table.insert
local table_getn=table.getn
local table_concat=table.concat
local posix_stat=posix.stat
local posix_readlink=posix.readlink
local posix_unlink=posix.unlink
local posix_rmdir=posix.rmdir
local os_time=os.time
local _G=_G
local _
local delete_output_files_on_error=true
local purge_intermediate_cache=false
local no_execute=false
local input_files={}
local targets={}
intermediate_cache_dir=".pm-cache/"
verbose=false
quiet=false
local sandbox={}
local scope={object=sandbox,next=nil}
local intermediate_cache={}
local intermediate_cache_count=0
local buildstages=0
local PARENT={}
local EMPTY={}
local REDIRECT={}
message=0
filetime=0
filetouch=0
install=0
rendertable=0
stringmodifier={}
setmetatable(_G,{__newindex=function(t,key,value)
error("Attempt to write to new global "..key)
end})
local function message(...)
stderr:write("pm: ")
stderr:write(unpack(arg))
stderr:write("\n")
end
_G.message=message
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
local function assert(message,result,e)
if result then
return result
end
if(type(message)=="string")then
message={message}
end
table.insert(message,": ")
table.insert(message,e)
usererror(unpack(message))
end
local function table_append(t,...)
for _,i in ipairs(arg)do
if(type(i)=="table")then
for _,j in ipairs(i)do
table_insert(t,j)
end
else
table_insert(t,i)
end
end
end
local function table_merge(t,...)
for _,i in ipairs(arg)do
for j,k in pairs(i)do
t[j]=k
end
end
end
function rendertable(i,tolerant)
if(type(i)=="string")or(type(i)=="number")then
return i
end
if(i==nil)or(i==EMPTY)then
return""
end
local t={}
for _,j in ipairs(i)do
if(type(j)~="string")and(type(j)~="number")then
if tolerant then
j="[object]"
else
error("attempt to expand a list containing an object")
end
end
local r=string_gsub(j,"\\","\\\\")
r=string_gsub(r,'"','\\"')
table_insert(t,r)
end
return'"'..table_concat(t,'" "')..'"'
end
local rendertable=rendertable
local function dirname(f)
local f,n=string_gsub(f,"/[^/]*$","")
if(n==0)then
return"."
end
return f
end
posix.dirname=dirname
local function absname(f)
if string.find(f,"^/")then
return f
end
return posix.getcwd().."/"..f
end
posix.absname=absname
local function copy(src,dest)
local s=string_gsub(src,"'","'\"'\"'")
local d=string_gsub(dest,"'","'\"'\"'")
local r=os.execute("cp '"..s.."' '"..d.."'")
if(r~=0)then
return nil,"unable to copy file"
end
return 0,nil
end
posix.copy=copy
local function mkcontainerdir(f)
f=dirname(f)
if not posix_stat(f,"type")then
mkcontainerdir(f)
local r=posix.mkdir(f)
if not r then
usererror("unable to create directory '"..f.."'")
end
end
end
local function do_install(self,src,dest)
src=absname(self:__expand(src))
dest=absname(self:__expand(dest))
if verbose then
message("installing '",src,"' --> '",dest,"'")
end
mkcontainerdir(dest)
local f,e=posix.symlink(src,dest)
if f then
return
end
if(e~=nil)then
f,e=posix.unlink(dest)
if f then
f,e=posix.symlink(src,dest)
if f then
return
end
end
end
self:__error("couldn't install '",src,"' to '",dest,
"': ",e)
end
function install(src,dest)
return function(self,inputs,outputs)
local src=src
local dest=dest
if(dest==nil)then
dest=src
src=outputs[1]
end
if(type(src)~="string")then
self:__error("pm.install needs a string or an object for an input")
end
if(type(dest)~="string")then
self:__error("pm.install needs a string for a destination")
end
return do_install(self,src,dest)
end
end
local function traceback(e)
local i=1
while true do
local t=debug.getinfo(i)
if not t then
break
end
if(t.short_src~="stdin")and(t.short_src~="[C]")then
if(t.currentline==-1)then
t.currentline=""
end
message("  ",t.short_src,":",t.currentline)
end
i=i+1
end
e=string_gsub(e,"^stdin:[0-9]*: ","")
usererror("error: ",e)
end
local statted_files={}
local function clear_stat_cache()
statted_files={}
end
local statted_files={}
local function filetime(f)
local t=statted_files[f]
if t then
return t
end
local realf=f
while true do
local newf,e=posix_readlink(realf)
if e then
break
end
realf=newf
end
t=posix_stat(realf,"mtime")or 0
statted_files[f]=t
return t
end
_G.filetime=filetime
local function filetouch(f)
if(type(f)=="string")then
f={f}
end
local t=os_time()
for _,i in ipairs(f)do
statted_files[i]=t
end
end
_G.filetouch=filetouch
local function create_intermediate_cache()
local d=dirname(intermediate_cache_dir)
if not quiet then
message("creating new intermediate file cache in '"..d.."'")
end
local f=posix.files(d)
if not f then
mkcontainerdir(d)
f=posix.mkdir(d)
if not f then
usererror("unable to create intermediate file cache directory")
end
else
local function rmdir(root)
local f=posix.files(root)
if not f then
return
end
for i in f do
if((i~=".")and(i~=".."))then
local fn=root.."/"..i
local t=posix_stat(fn,"type")
if(t=="regular")then
if not posix_unlink(fn)then
usererror("unable to purge intermediate file cache directory")
end
elseif(t=="directory")then
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
local fn=intermediate_cache_dir.."index"
local f=io.open(fn,"w")
if not f then
usererror("unable to save intermediate cache index file '",fn,"'")
end
f:write(intermediate_cache_count,"\n")
for i,j in pairs(intermediate_cache)do
f:write(i,"\n")
f:write(j,"\n")
end
f:close()
end
local function load_intermediate_cache()
local fn=intermediate_cache_dir.."index"
local f=io.open(fn,"r")
if not f then
create_intermediate_cache()
return
end
intermediate_cache_count=f:read("*l")
while true do
local l1=f:read("*l")
local l2=f:read("*l")
if(l1==nil)or(l2==nil)then
break
end
intermediate_cache[l1]=l2
end
f:close()
end
local function create_intermediate_cache_key(key)
local u=intermediate_cache[key]
if not u then
intermediate_cache_count=intermediate_cache_count+1u=intermediate_cache_count
intermediate_cache[key]=u
save_intermediate_cache()
end
return u
end
function stringmodifier.dirname(self,s)
if(type(s)=="table")then
if(table_getn(s)==1)then
s=s[1]
else
self:__error("tried to use string modifier 'dirname' on a table with more than one entry")
end
end
return dirname(s)
end
local metaclass={
class="metaclass",
__call=function(self,...)
local o={}
for i,j in pairs(self)do
o[i]=j
end
setmetatable(o,o)
local i=1
while true do
local s=debug.getinfo(i,"Sl")
if s then
if(string_byte(s.source)==64)then
o.definedat=string_sub(s.source,2)..":"..s.currentline
end
else
break
end
i=i+1
end
o:__init(unpack(arg))
return o
end,
__init=function(self,...)
end,
}
setmetatable(metaclass,metaclass)
local node=metaclass()
node.class="node"
function node:__init(t)
metaclass.__init(self)
if(type(t)=="string")then
t={t}
end
if(type(t)~="table")then
self:__error("can't be constructed with a ",type(t),"; try a table or a string")
end
for i,j in pairs(t)do
if(tonumber(i)==nil)then
self[i]=j
end
end
for _,i in ipairs(t)do
table_insert(self,i)
end
if t.class then
return
end
if self.ensure_n_children then
local n=self.ensure_n_children
if(table.getn(self)~=n)then
local one
if(n==1)then
one="one child"
else
one=n.." children"
end
self:_error("must have exactly ",one)
end
end
if self.ensure_at_least_one_child then if(table_getn(self)<1)then
self:__error("must have at least one child")
end
end
if self.construct_string_children_with then
local constructor=self.construct_string_children_with
for i,j in ipairs(self)do
if(type(j)=="string")then
self[i]=constructor{j}
end
end
end
if self.all_children_are_objects then for i,j in ipairs(self)do
if(type(j)~="table")then
self:__error("doesn't know what to do with child ",i,
", which is a ",type(j))
end
end
end
if self.install then
local t=type(self.install)
if(t=="string")or
(t=="function")then
self.install={self.install}
end
if(type(self.install)~="table")then
self:__error("doesn't know what to do with its installation command, ",
"which is a ",type(self.install)," but should be a table, function ",
"or string")
end
end
end
function node:__index(key)
local i=string_byte(key,1)
if(i>=65)and(i<=90)then
local recurse
recurse=function(s,key)
if not s then
return nil
end
local o=rawget(s.object,key)
if o then
if(type(o)=="table")then
if(o[1]==PARENT)then
local parent=recurse(s.next,key)
local newo={}
if parent then
if(type(parent)~="table")then
parent={parent}
end
for _,j in ipairs(parent)do
table_insert(newo,j)
end
end
for _,j in ipairs(o)do
if(j~=PARENT)then
table_insert(newo,j)
end
end
return newo
elseif(o[1]==REDIRECT)then
return self:__index(o[2])
end
end
return o
end
return recurse(s.next,key)
end
local fakescope={
next=scope,
object=self
}
return recurse(fakescope,key)
end
return rawget(self,key)
end
function node:__error(...)
usererror("object '",self.class,"', defined at ",
self.definedat,", ",unpack(arg))
end
function node:__outputs(inputs)
self:__error("didn't implement __outputs when it should have")
end
function node:__dependencies(inputs,outputs)
return inputs
end
function node:__timestamp(inputs,outputs)
local t=0
for _,i in ipairs(outputs)do
local tt=filetime(i)
if(tt>t)then
t=tt
end
end
return t
end
function node:__buildchildren()
local inputs={}
scope={object=self,next=scope}
for _,i in ipairs(self)do
table_append(inputs,i:__build())
end
self:__buildadditionalchildren()
scope=scope.next
return inputs
end
function node:__buildadditionalchildren()
end
function node:__build()
local inputs=self:__buildchildren()
self["in"]=inputs
local outputs=self:__outputs(inputs)
self.out=outputs
local t=self:__timestamp(inputs,outputs)
local depends=self:__dependencies(inputs,outputs)
local rebuild=false
if(t==0)then
rebuild=true
end
if(not rebuild and depends)then
for _,i in ipairs(depends)do
local tt=filetime(i)
if(tt>t)then
if verbose then
message("rebuilding ",self.class," because ",i," (",tt,") newer than ",
rendertable(outputs)," (",t,")")
end
rebuild=true
break
end
end
end
if rebuild then
self:__dobuild(inputs,outputs)
filetouch(outputs)
end
if self.install then
self:__invoke(self.install,inputs,outputs)
end
return outputs
end
function node:__dobuild(inputs,outputs)
self:__error("didn't implement __dobuild when it should have")
end
local PERCENT="\aPERCENT\a"
function node:__expand(s)
local searching=true
while searching do
searching=false
s=string_gsub(s,"%%{(.-)}%%",function(expr)
searching=true
local f,e=loadstring(expr,"expression")
if not f then
self:__error("couldn't compile the expression '",expr,"': ",e)
end
local env={self=self}
setmetatable(env,{
__index=function(_,key)
return sandbox[key]
end
})
setfenv(f,env)
f,e=pcall(f,self)
if not f then
self:__error("couldn't evaluate the expression '",expr,"': ",e)
end
return rendertable(e)end)
s=string_gsub(s,"%%(.-)%%",function(varname)
searching=true
if(varname=="")then
return PERCENT
end
local _,_,leftcolon,rightcolon=string_find(varname,"([^:]*):?(.*)$")
local _,_,varname,selectfrom,hyphen,selectto=string_find(leftcolon,"^([^[]*)%[?([^-%]]*)(%-?)([^%]]*)]?$")
local result=self:__index(varname)
if not result then
self:__error("doesn't understand variable '",varname,"'")
end
if(selectfrom~="")or(hyphen~="")or(selectto~="")then
if(type(result)~="table")then
self:__error("tried to use a [] selector on variable '",varname,
"', which doesn't contain a table")
end
local n=table_getn(result)
selectfrom=tonumber(selectfrom)
selectto=tonumber(selectto)
if(hyphen~="")then
if not selectfrom then
selectfrom=1
end
if not selectto then
selectto=n
end
else
if not selectto then
selectto=selectfrom
end
if not selectfrom then
self:__error("tried to use an empty selector on variable '",varname,"'")
end
end
if(selectfrom<1)or(selectto<1)or
(selectfrom>n)or(selectto>n)or
(selectto<selectfrom)then
self:__error("tried to use an invalid selector [",
selectfrom,"-",selectto,"] on variable '",varname,
"'; only [1-",n,"] is valid")
end
local newresult={}
for i=selectfrom,selectto do
table_insert(newresult,result[i])
end
result=newresult
end
if(rightcolon~="")then
local f=stringmodifier[rightcolon]
if not f then
self:__error("tried to use an unknown string modifier '",
rightcolon,"' on variable '",varname,"'")
end
result=f(self,result)
end
return rendertable(result)
end)
end
s=string_gsub(s,PERCENT,"%%")
return s
end
function node:__invoke(command,inputs,outputs)
if(type(command)~="table")then
command={command}
end
for _,s in ipairs(command)do
if(type(s)=="string")then
s=self:__expand(s)
if not quiet then
traceoutput(s)
end
if not no_execute then
local r=os.execute(s)
if(r~=0)then
return r
end
end
elseif(type(s)=="function")then
local r=s(self,inputs,outputs)
if r then
return r
end
end
end
return false
end
table_merge(sandbox,{
VERSION=VERSION,
assert=assert,
collectgarbage=collectgarbage,
dofile=dofile,
error=error,
getfenv=getfenv,
getmetatable=getmetatable,
gcinfo=gcinfo,
ipairs=ipairs,
loadfile=loadfile,
loadlib=loadlib,
loadstring=loadstring,
next=next,
pairs=pairs,
pcall=pcall,
print=print,
rawequal=rawequal,
rawget=rawget,
rawset=rawset,
require=require,
setfenv=setfenv,
setmetatable=setmetatable,
tonumber=tonumber,
tostring=tostring,
type=type,
unpack=unpack,
_VERSION=_VERSION,
xpcall=xpcall,
table=table,
io=io,
os=os,
posix=posix,
string=string,
debug=debug,
loadlib=loadlib,
pm=_G,
node=node,
PARENT=PARENT,
EMPTY=EMPTY,
REDIRECT=REDIRECT,
})
setmetatable(sandbox,{
__index=function(self,key)
local value=rawget(self,key)
if(value==nil)then
error(key.." could not be found in any applicable scope")
end
return value
end
})
setfenv(1,sandbox)
function include(f,...)
local c,e=loadfile(f)
if not c then
usererror("script compilation error: ",e)
end
setfenv(c,sandbox)
local arguments=arg
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
file=node{
class="file",
ensure_at_least_one_child=true,
__init=function(self,p)
node.__init(self,p)
if((type(p)=="table")and p.class)then
return
end
for i,j in ipairs(self)do
if(type(j)~="string")then
self:__error("doesn't know what to do with child ",i,
", which is a ",type(j))
end
end
end,
__timestamp=function(self,inputs,outputs)local t=0
for _,i in ipairs(outputs)do
i=self:__expand(i)
local tt=filetime(i)
if(tt==0)then
self:__error("is referring to the file '",i,"' which does not exist")
end
if(tt>t)then
t=tt
end
end
return t
end,
__outputs=function(self,inputs)
local o={}
local n
if self.only_n_children_are_outputs then
n=self.only_n_children_are_outputs
else
n=table_getn(inputs)
end
for i=1,n do
o[i]=self:__expand(inputs[i])
end
return o
end,
__buildchildren=function(self)
local outputs={}
table_append(outputs,self)
return outputs
end,
__dobuild=function(self,inputs,outputs)
end,
}
group=node{
class="group",
__outputs=function(self,inputs)
return inputs
end,
__dobuild=function(self,inputs,outputs)
end,
}
deponly=node{
class="deponly",
ensure_at_least_one_child=true,
__outputs=function(self,inputs)
return{}
end,
__dobuild=function(self,inputs,outputs)
end,
}
ith=node{
class="ith",
ensure_at_least_one_child=true,
__init=function(self,p)
node.__init(self,p)
if((type(p)=="table")and p.class)then
return
end
if self.i then
if self.from or self.to then
self:__error("can't have both an i property and a from or to property")
end
if(type(self.i)~="number")then
self:__error("doesn't know what to do with its i property, ",
"which is a ",type(self.i)," where a number was expected")
end
self.from=self.i
self.to=self.i
end
if self.from then
if(type(self.from)~="number")then
self:__error("doesn't know what to do with its from property, ",
"which is a ",type(self.from)," where a number was expected")
end
end
if self.to then
if(type(self.to)~="number")then
self:__error("doesn't know what to do with its to property, ",
"which is a ",type(self.to)," where a number was expected")
end
end
end,
__outputs=function(self,inputs)
local n=table_getn(inputs)
local from=self.from or 1
local to=self.to or n
if(from<1)or(to>n)then
self:__error("tried to select range ",from," to ",to,
" from only ",n," inputs")
end
local range={}
for i=from,to do
table_append(range,inputs[i])
end
return range
end,
__dobuild=function(self,inputs,outputs)
end,
}
foreach=node{
class="foreach",
__init=function(self,p)
node.__init(self,p)
if((type(p)=="table")and p.class)then
return
end
if not self.rule then
self:__error("must have a rule property")
end
if(type(self.rule)~="table")then
self:__error("doesn't know what to do with its rule property, ",
"which is a ",type(self.rule)," where a table was expected")
end
end,
__buildchildren=function(self)
scope={object=self,next=scope}
local intermediate={}
for _,i in ipairs(self)do
table_append(intermediate,i:__build())
end
local inputs={}
for _,i in ipairs(intermediate)do
local r=self.rule{i}
table_append(inputs,r:__build())
end
self:__buildadditionalchildren()
scope=scope.next
return inputs
end,
__outputs=function(self,inputs)
return inputs
end,
__dobuild=function(self,inputs,outputs)
end,
}
simple=node{
class="file",
construct_string_children_with=file,
all_children_are_objects=true,
__init=function(self,p)
node.__init(self,p)
if((type(p)=="table")and p.class)then
return
end
if not self.outputs then
self:__error("must have an outputs template set")
end
if(type(self.outputs)~="table")then
self:__error("doesn't know what to do with its outputs, which is a ",
type(self.outputs)," but should be a table")
end
if not self.command then
self:__error("must have a command specified")
end
if(type(self.command)=="string")then
self.command={self.command}
end
if(type(self.command)~="table")then
self:__error("doesn't know what to do with its command, which is a ",
type(self.command)," but should be a string or a table")
end
end,
__outputs=function(self,inputs)
local input
if inputs then
input=inputs[1]
end
if not input then
input=""
end
self.I=string_gsub(input,"^.*/","")
self.I=string_gsub(self.I,"%..-$","")
self.out={}
self.U=0
for _,i in ipairs(self.outputs)do
i=self:__expand(i)
table_append(self.out,i)
end
local cachekey=table_concat(self.command," && ")
cachekey=self:__expand(cachekey)
cachekey=create_intermediate_cache_key(cachekey)
self.U=pm.intermediate_cache_dir..cachekey
self.out={}
for _,i in ipairs(self.outputs)do
i=self:__expand(i)
mkcontainerdir(i)
table_append(self.out,i)
end
return self.out
end,
__dobuild=function(self,inputs,outputs)
local r=self:__invoke(self.command,inputs,outputs)
if r then
if delete_output_files_on_error then
self:__invoke({"%RM% %out%"})
end self:__error("failed to build with return code ",r)
end
end,
}
RM="rm -f"
INSTALL="ln -f"
setfenv(1,_G)
do
local function do_help(opt)
message("Prime Mover version ",VERSION," © 2006-2007 David Given")
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
message("Prime Mover version ",VERSION," © 2006 David Given")
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
intermediate_cache_dir=opt
return 1
end
local function do_inputfile(opt)
needarg(opt)
table_append(input_files,opt)
return 1
end
local function do_purgecache(opt)
purge_intermediate_cache=true
return 0
end
local function do_define(opt)
needarg(opt)
local s,e,key,value=string_find(opt,"^([^=]*)=(.*)$")
if not key then
key=opt
value=true
end
sandbox[key]=value
return 1
end
local function do_no_execute(opt)
no_execute=true
return 0
end
local function do_verbose(opt)
verbose=true
return 0
end
local function do_quiet(opt)
quiet=true
return 0
end
local argmap={
["h"]=do_help,
["help"]=do_help,
["c"]=do_cachedir,
["cachedir"]=do_cachedir,
["p"]=do_purgecache,
["purge"]=do_purgecache,
["f"]=do_inputfile,
["file"]=do_inputfile,
["D"]=do_define,
["define"]=do_define,
["n"]=do_no_execute,
["no-execute"]=do_no_execute,
["v"]=do_verbose,
["verbose"]=do_verbose,
["q"]=do_quiet,
["quiet"]=do_quiet,
["license"]=do_license,
}
local function unrecognisedarg(arg)
usererror("unrecognised option '",arg,"' --- try --help for help")
end
for i=1,table_getn(arg)do
local o=arg[i]
local op
if(string_byte(o,1)==45)then
if(string_byte(o,2)==45)then
o=string_sub(o,3)
local fn=argmap[o]
if not fn then
unrecognisedarg("--"..o)
end
local op=arg[i+1]
i=i+fn(op)
else
local od=string_sub(o,2,2)
local fn=argmap[od]
if not fn then
unrecognisedarg("-"..od)
end
op=string_sub(o,3)
if(op=="")then
op=arg[i+1]
i=i+fn(op)
else
fn(op)
end
end
else
table_append(targets,o)
end end
if(table_getn(input_files)==0)then
input_files={"pmfile"}
end
if(table_getn(targets)==0)then
targets={"default"}
end
end
for _,i in ipairs(input_files)do
sandbox.include(i,unpack(arg))
end
if purge_intermediate_cache then
create_intermediate_cache()
else
load_intermediate_cache()
end
for _,i in ipairs(targets)do
local o=sandbox[i]
if not o then
usererror("don't know how to build '",i,"'")
end
if((type(o)~="table")and not o.class)then
usererror("'",i,"' doesn't seem to be a valid target")
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

#include<signal.h>
#include<sys/wait.h>
#include<stdarg.h>
#include<errno.h>
#include<stdio.h>
#include<locale.h>
#include<sys/types.h>
#include<sys/utsname.h>
#include<stddef.h>
#include<grp.h>
#include<time.h>
#include<assert.h>
#include<sys/stat.h>
#include<ctype.h>
#include<utime.h>
#include<setjmp.h>
#include<dirent.h>
#include<sys/times.h>
#include<pwd.h>
#include<unistd.h>
#include<string.h>
#include<limits.h>
#include<fcntl.h>
#include<stdlib.h>
#define G0c
#ifndef l_c
#define l_c
#define a4a int
#define a_a "%d"
#define U7 "%d"
#define g8 "Lua 5.0.2 (patched for Prime Mover)"
#define v4a "Copyright (C) 1994-2004 Tecgraf, PUC-Rio"
#define k1b "R. Ierusalimschy, L. H. de Figueiredo & W. Celes"
#define B2 (-1)
#define L_ (-10000)
#define b0 (-10001)
#define O_(i) (b0-(i))
#define v3a 1
#define M_a 2
#define E0a 3
#define H3a 4
#define L0a 5
typedef
struct
a
a;typedef
int(*q0)(a*L);typedef
const
char*(*J5)(a*L,void*ud,size_t*sz);typedef
int(*D5)(a*L,const
void*p,size_t
sz,void*ud);
#define k0a (-1)
#define W5 0
#define l5 1
#define K1 2
#define P1 3
#define u1 4
#define H_ 5
#define e0 6
#define f1 7
#define c3 8
#define N3 20
#ifdef e_c
#include e_c
#endif
#ifndef a4a
typedef
double
U;
#else
typedef
a4a
U;
#endif
#ifndef K
#define K extern
#endif
K
a*i7a(void);K
void
h2a(a*L);K
a*D0a(a*L);K
q0
m6a(a*L,q0
t5b);K
int
D_(a*L);K
void
J0(a*L,int
F_);K
void
Y(a*L,int
F_);K
void
F5(a*L,int
F_);K
void
C1(a*L,int
F_);K
void
X5(a*L,int
F_);K
int
I7(a*L,int
sz);K
void
j0a(a*W0,a*to,int
n);K
int
x2(a*L,int
F_);K
int
Z1(a*L,int
F_);K
int
O3(a*L,int
F_);K
int
Y2a(a*L,int
F_);K
int
f2(a*L,int
F_);K
const
char*o7(a*L,int
tp);K
int
k9a(a*L,int
n9b,int
j9b);K
int
x5a(a*L,int
n9b,int
j9b);K
int
O1a(a*L,int
n9b,int
j9b);K
U
F0(a*L,int
F_);K
int
Y1(a*L,int
F_);K
const
char*o_(a*L,int
F_);K
size_t
S3(a*L,int
F_);K
q0
n2a(a*L,int
F_);K
void*b2(a*L,int
F_);K
a*q6(a*L,int
F_);K
const
void*r0a(a*L,int
F_);K
void
w_(a*L);K
void
N(a*L,U
n);K
void
b1(a*L,const
char*s,size_t
l);K
void
I(a*L,const
char*s);K
const
char*j1a(a*L,const
char*S6,va_list
a5);K
const
char*P_(a*L,const
char*S6,...);K
void
A1(a*L,q0
fn,int
n);K
void
o0(a*L,int
b);K
void
E1(a*L,void*p);K
void
s6(a*L,int
F_);K
void
z0(a*L,int
F_);K
void
d0(a*L,int
F_,int
n);K
void
U0(a*L);K
void*E5(a*L,size_t
sz);K
int
X2(a*L,int
I1a);K
void
E6a(a*L,int
F_);K
void
Q0(a*L,int
F_);K
void
G0(a*L,int
F_);K
void
G2(a*L,int
F_,int
n);K
int
Z2(a*L,int
I1a);K
int
t6a(a*L,int
F_);K
void
j4(a*L,int
Z4,int
A0);K
int
B4(a*L,int
Z4,int
A0,int
p4);K
int
N7a(a*L,q0
a0,void*ud);K
int
J1a(a*L,J5
m0a,void*dt,const
char*V8);K
int
a1b(a*L,D5
Q7a,void*e3);K
int
O4a(a*L,int
A0);K
int
z3a(a*L,int
Q1);K
int
n0a(a*L);K
int
X2a(a*L);K
void
T_a(a*L,int
T1a);K
const
char*E1b(void);K
int
X8(a*L);K
int
W3a(a*L,int
F_);K
void
T3(a*L,int
n);
#define l8b(L,u) (*(void**)(E5(L,sizeof(void*)))=(u))
#define k6b(L,i) (*(void**)(b2(L,i)))
#define V_(L,n) J0(L,-(n)-1)
#define x0b(L,n,f) (I(L,n),e8(L,f),Q0(L,b0))
#define e8(L,f) A1(L,f,0)
#define g2(L,n) (f2(L,n)==e0)
#define z6a(L,n) (f2(L,n)==H_)
#define E4a(L,n) (f2(L,n)==K1)
#define q3(L,n) (f2(L,n)==W5)
#define f_b(L,n) (f2(L,n)==l5)
#define i3(L,n) (f2(L,n)==k0a)
#define M1(L,n) (f2(L,n)<=0)
#define e_(L,s) b1(L,""s,(sizeof(s)/sizeof(char))-1)
K
int
H8(a*L);
#define n7b(L) Y(L,L_)
#define B8(L,s) (I(L,s),C1(L,-2),Q0(L,b0))
#define t5(L,s) (I(L,s),s6(L,b0))
#define Z_c (-2)
#define N2b (-1)
#define d8b(L,q0b) ((q0b)?k0b(L,L_):(I(L,"unlocked references are obsolete"),X8(L),0))
#define q5b(L,j7) g8a(L,L_,(j7))
#define L2b(L,j7) d0(L,L_,j7)
#ifndef a_a
#define a_a "%lf"
#endif
#ifndef U7
#define U7 "%.14g"
#endif
#define L1a 0
#define v6a 1
#define V4a 2
#define j4a 3
#define s2a 4
#define y7 (1<<L1a)
#define P_a (1<<v6a)
#define u6 (1<<V4a)
#define T6 (1<<j4a)
typedef
struct
D0
D0;typedef
void(*F8)(a*L,D0*ar);K
int
T2(a*L,int
z_,D0*ar);K
int
S5(a*L,const
char*v3,D0*ar);K
const
char*U4a(a*L,const
D0*ar,int
n);K
const
char*G5a(a*L,const
D0*ar,int
n);K
const
char*t_a(a*L,int
p7,int
n);K
const
char*h_a(a*L,int
p7,int
n);K
int
Q5(a*L,F8
a0,int
K4,int
z1);K
F8
G6a(a*L);K
int
u2a(a*L);K
int
h1a(a*L);
#define i9 60
struct
D0{int
S2;const
char*b_;const
char*z7;const
char*v3;const
char*n0;int
A2;int
k5;int
Y6;char
d9[i9];int
s5a;};
#endif
#ifndef m9b
#define m9b
#ifndef r5b
#define r5b
#ifndef v4b
#define v4b
#ifndef BITS_INT
#if INT_MAX-20<32760
#define BITS_INT 16
#else
#if INT_MAX>2147483640L
#define BITS_INT 32
#else
#error"you must define BITS_INT with number of bits in an integer"
#endif
#endif
#endif
typedef
unsigned
int
f_a;typedef
int
B0c;typedef
unsigned
long
k2;
#define f9a ULONG_MAX
typedef
long
I8a;typedef
unsigned
char
T_;
#define i9a ((size_t)(~(size_t)0)-2)
#define J7 (INT_MAX-2)
#define d6b(p) ((f_a)(p))
#ifndef j6a
typedef
union{double
u;void*s;long
l;}p8;
#else
typedef
j6a
p8;
#endif
#ifndef P9a
typedef
double
n6a;
#else
typedef
P9a
n6a;
#endif
#ifndef H
#define H(c)
#endif
#ifndef F1
#define F1(c,e) (e)
#endif
#ifndef P2a
#define P2a(x) ((void)(x))
#endif
#ifndef g_
#define g_(t,exp) ((t)(exp))
#endif
typedef
unsigned
long
j_;
#ifndef t6
#define t6 4096
#endif
#ifndef O6
#define O6 200
#endif
#ifndef g4a
#define g4a 2048
#endif
#define w2 250
#ifndef g6a
#define g6a 200
#endif
#ifndef S_a
#define S_a 32
#endif
#ifndef v5a
#define v5a 100
#endif
#ifndef t0a
#define t0a 32
#endif
#ifndef y8
#define y8 32
#endif
#ifndef Y_a
#define Y_a 200
#endif
#endif
#define B0b c3
#define E9 (B0b+1)
#define z9 (B0b+2)
typedef
union
u_
u_;
#define w4 u_*h_;T_ tt;T_ Y2
typedef
struct
i0b{w4;}i0b;typedef
union{u_*gc;void*p;U
n;int
b;}L_c;typedef
struct
X9b{int
tt;L_c
m_;}E;
#define I0(o) (V0(o)==W5)
#define Y0(o) (V0(o)==P1)
#define r1(o) (V0(o)==u1)
#define I2(o) (V0(o)==H_)
#define a2(o) (V0(o)==e0)
#define N2a(o) (V0(o)==l5)
#define f5a(o) (V0(o)==f1)
#define o8a(o) (V0(o)==c3)
#define G0a(o) (V0(o)==K1)
#define V0(o) ((o)->tt)
#define P7(o) F1(P4(o),(o)->m_.gc)
#define S2a(o) F1(G0a(o),(o)->m_.p)
#define s0(o) F1(Y0(o),(o)->m_.n)
#define q2(o) F1(r1(o),&(o)->m_.gc->ts)
#define f0a(o) F1(f5a(o),&(o)->m_.gc->u)
#define D2(o) F1(a2(o),&(o)->m_.gc->cl)
#define m1(o) F1(I2(o),&(o)->m_.gc->h)
#define g3a(o) F1(N2a(o),(o)->m_.b)
#define h2b(o) F1(o8a(o),&(o)->m_.gc->th)
#define p0a(o) (I0(o)||(N2a(o)&&g3a(o)==0))
#define N1(U1,x) {E*d6=(U1);d6->tt=P1;d6->m_.n=(x);}
#define z4b(U1,x) F1(V0(U1)==P1,(U1)->m_.n=(x))
#define g9a(U1,x) {E*d6=(U1);d6->tt=K1;d6->m_.p=(x);}
#define l2a(U1,x) {E*d6=(U1);d6->tt=l5;d6->m_.b=(x);}
#define z2a(U1,x) {E*d6=(U1);d6->tt=u1;d6->m_.gc=g_(u_*,(x));H(d6->m_.gc->E3.tt==u1);}
#define b5a(U1,x) {E*d6=(U1);d6->tt=f1;d6->m_.gc=g_(u_*,(x));H(d6->m_.gc->E3.tt==f1);}
#define H2b(U1,x) {E*d6=(U1);d6->tt=c3;d6->m_.gc=g_(u_*,(x));H(d6->m_.gc->E3.tt==c3);}
#define J0a(U1,x) {E*d6=(U1);d6->tt=e0;d6->m_.gc=g_(u_*,(x));H(d6->m_.gc->E3.tt==e0);}
#define z6(U1,x) {E*d6=(U1);d6->tt=H_;d6->m_.gc=g_(u_*,(x));H(d6->m_.gc->E3.tt==H_);}
#define S_(U1) ((U1)->tt=W5)
#define J8(U1) H(!P4(U1)||(V0(U1)==(U1)->m_.gc->E3.tt))
#define O9(l0c,o0c) {const E*o2=(o0c);E*o1=(l0c);J8(o2);o1->tt=o2->tt;o1->m_=o2->m_;}
#define i1 O9
#define l0 O9
#define G3 z2a
#define C9a O9
#define C1a O9
#define B3a O9
#define y1b z2a
#define a7b(U1,tt) (V0(U1)=(tt))
#define P4(o) (V0(o)>=u1)
typedef
E*t_;typedef
union
A_{p8
t3b;struct{w4;T_
B3;f_a
i2;size_t
G1;}x6;}A_;
#define I5(ts) g_(const char*,(ts)+1)
#define r9(o) I5(q2(o))
typedef
union
C_a{p8
t3b;struct{w4;struct
p0*r_;size_t
G1;}uv;}C_a;typedef
struct
E_{w4;E*k;j_*q1;struct
E_**p;int*n4;struct
d3a*s3;A_**k0;A_*n0;int
K3;int
j9;int
K2;int
t3;int
Q0a;int
r4;int
i8;u_*n5;T_
k5;T_
l7;T_
T8;T_
c2;}E_;typedef
struct
d3a{A_*O2;int
V2a;int
o_b;}d3a;typedef
struct
Q_a{w4;E*v;E
m_;}Q_a;
#define k4a w4;T_ isC;T_ h4;u_*n5
typedef
struct
f7a{k4a;q0
f;E
J4[1];}f7a;typedef
struct
P1a{k4a;struct
E_*p;E
g;Q_a*d2a[1];}P1a;typedef
union
C2{f7a
c;P1a
l;}C2;
#define N_a(o) (V0(o)==e0&&D2(o)->c.isC)
#define J2a(o) (V0(o)==e0&&!D2(o)->c.isC)
typedef
struct
M3{E
E_c;E
w_c;struct
M3*h_;}M3;typedef
struct
p0{w4;T_
E3a;T_
Z8;struct
p0*r_;E*w0;M3*h3;M3*w7;u_*n5;int
O1;}p0;
#define z_b(s,W) F1((W&(W-1))==0,(g_(int,(s)&((W)-1))))
#define o2a(x) (1<<(x))
#define q5(t) (o2a((t)->Z8))
extern
const
E
E2;int
l0a(unsigned
int
x);int
I2a(unsigned
int
x);
#define S4b(x) (((x)&7)<<((x)>>3))
int
y3(const
E*t1,const
E*t2);int
P3a(const
char*s,U*J1);const
char*T4(a*L,const
char*S6,va_list
a5);const
char*V2(a*L,const
char*S6,...);void
G7(char*m7,const
char*n0,int
G1);
#endif
void
H4(a*L,const
E*o);
#endif
#ifndef o6b
#define o6b
#ifndef n6b
#define n6b
#ifndef B_c
#define B_c
typedef
enum{M0b,A6a,l7b,H7b,a3b,P4b,k5b,h5b,A4b,d0b,T9b,B7b,r_c,J4b,Z7b,x9b}TMS;
#define f2b(g,et,e) (((et)->E3a&(1u<<(e)))?NULL:l8a(et,e,(g)->u5a[e]))
#define m3a(l,et,e) f2b(G(l),et,e)
const
E*l8a(p0*M_b,TMS
S2,A_*y7a);const
E*n3(a*L,const
E*o,TMS
S2);void
v9a(a*L);extern
const
char*const
g6[];
#endif
#ifndef w9b
#define w9b
#define EOZ (-1)
typedef
struct
Zio
h9;
#define l7a(c) g_(int,g_(unsigned char,(c)))
#define G7b(z) (((z)->n--)>0?l7a(*(z)->p++):C2a(z))
#define m7b(z) ((z)->b_)
void
p9a(h9*z,J5
m0a,void*e3,const
char*b_);size_t
b9a(h9*z,void*b,size_t
n);int
a3a(h9*z);typedef
struct
m6{char*c0;size_t
O8;}m6;char*W7(a*L,m6*p_,size_t
n);
#define w2a(L,p_) ((p_)->c0=NULL,(p_)->O8=0)
#define L9(p_) ((p_)->O8)
#define U5(p_) ((p_)->c0)
#define I0a(L,p_,W) (H0(L,(p_)->c0,(p_)->O8,W,char),(p_)->O8=W)
#define p2a(L,p_) I0a(L,p_,0)
struct
Zio{size_t
n;const
char*p;J5
m0a;void*e3;const
char*b_;};int
C2a(h9*z);
#endif
#ifndef n_
#define n_(L) ((void)0)
#endif
#ifndef f_
#define f_(L) ((void)0)
#endif
#ifndef S4
#define S4(l)
#endif
struct
L_a;
#define F3(L) (&G(L)->T0b)
#define gt(L) (&L->_gt)
#define a6(L) (&G(L)->r4b)
#define d7 5
#define w0a 8
#define E8 (2*N3)
typedef
struct
k8{u_**i2;I8a
N6a;int
W;}k8;typedef
struct
m0{t_
k_;t_
X;int
h0;union{struct{const
j_*n2;const
j_**pc;int
h0a;}l;struct{int
t3b;}c;}u;}m0;
#define Y1a (1<<0)
#define c7 (1<<1)
#define P9 (1<<2)
#define f3 (1<<3)
#define D8 (1<<4)
#define Z0a(ci) (D2((ci)->k_-1))
typedef
struct
v4{k8
f7;u_*g5a;u_*A6;u_*r6;m6
p_;k2
O5;k2
b7;q0
l_b;E
r4b;E
T0b;struct
a*w9;M3
d4[1];A_*u5a[x9b];}v4;struct
a{w4;t_
X;t_
k_;v4*l_G;m0*ci;t_
x5;t_
l_;int
H2;m0*S7a;m0*O0;unsigned
short
X3;unsigned
short
k6;T_
J6;T_
f4;T_
s3a;int
w8;int
t5a;F8
D6;E
_gt;u_*w6;u_*n5;struct
L_a*N8;ptrdiff_t
p4;};
#define G(L) (L->l_G)
union
u_{i0b
E3;union
A_
ts;union
C_a
u;union
C2
cl;struct
p0
h;struct
E_
p;struct
Q_a
uv;struct
a
th;};
#define d6a(o) F1((o)->E3.tt==u1,&((o)->ts))
#define k1a(o) F1((o)->E3.tt==f1,&((o)->u))
#define G8a(o) F1((o)->E3.tt==e0,&((o)->cl))
#define M4a(o) F1((o)->E3.tt==H_,&((o)->h))
#define K0b(o) F1((o)->E3.tt==E9,&((o)->p))
#define v8a(o) F1((o)->E3.tt==z9,&((o)->uv))
#define G_b(o) F1((o)==NULL||(o)->E3.tt==z9,&((o)->uv))
#define Z2a(o) F1((o)->E3.tt==c3,&((o)->th))
#define Q4(v) (g_(u_*,(v)))
a*i3a(a*L);void
A2a(a*L,a*L1);
#endif
#define s_b(pc,p) (g_(int,(pc)-(p)->q1)-1)
#define S5a(f,pc) (((f)->n4)?(f)->n4[pc]:0)
#define i_a(L) (L->t5a=L->w8)
void
o3a(a*L);void
j5(a*L,const
E*o,const
char*D0c);void
t1a(a*L,t_
p1,t_
p2);void
n9(a*L,const
E*p1,const
E*p2);int
G5(a*L,const
E*p1,const
E*p2);void
q_(a*L,const
char*S6,...);void
v0a(a*L);int
L7(const
E_*pt);
#endif
#ifndef o_c
#define o_c
#ifndef q8b
#define x4(x) {}
#else
#define x4(x) x
#endif
#define N2(L,n) if((char*)L->x5-(char*)L->X<=(n)*(int)sizeof(E))p3a(L,n);else x4(Y3(L,L->H2));
#define W3(L) {N2(L,1);L->X++;}
#define A4(L,p) ((char*)(p)-(char*)L->l_)
#define a3(L,n) ((E*)((char*)L->l_+(n)))
#define K9b(L,p) ((char*)(p)-(char*)L->O0)
#define B4b(L,n) ((m0*)((char*)L->O0+(n)))
typedef
void(*y_b)(a*L,void*ud);void
G2b(a*L);int
l9(a*L,h9*z,int
bin);void
N4(a*L,int
S2,int
X_);t_
q7(a*L,t_
a0);void
A5(a*L,t_
a0,int
c0b);int
Q3a(a*L,y_b
a0,void*u,ptrdiff_t
q8,ptrdiff_t
ef);void
i6(a*L,int
w7a,t_
E0);void
g5(a*L,int
T1);void
Y3(a*L,int
T1);void
p3a(a*L,int
n);void
K5(a*L,int
a6a);int
g3(a*L,y_b
f,void*ud);
#endif
#ifndef f8b
#define f8b
E_*u0a(a*L);C2*I8(a*L,int
W9);C2*M8(a*L,int
W9,E*e);Q_a*W2a(a*L,t_
z_);void
Y4(a*L,t_
z_);void
U2a(a*L,E_*f);void
U1a(a*L,C2*c);const
char*U4(const
E_*a0,int
q1a,int
pc);
#endif
#ifndef c_c
#define c_c
#define B1(L) {H(!(L->ci->h0&P9));if(G(L)->b7>=G(L)->O5)c_a(L);}
size_t
v7(a*L);void
s0a(a*L);void
S3a(a*L,int
M2);void
c_a(a*L);void
n7(a*L,u_*o,T_
tt);
#endif
#ifndef a9b
#define a9b
#define F9a "not enough memory"
void*m5(a*L,void*t0c,k2
q4,k2
W);void*X4a(a*L,void*N_,int*W,int
b0c,int
Q2,const
char*Q0b);
#define f2a(L,b,s) m5(L,(b),(s),0)
#define s9(L,b) m5(L,(b),sizeof(*(b)),0)
#define x1(L,b,n,t) m5(L,(b),g_(k2,n)*g_(k2,sizeof(t)),0)
#define Z5(L,t) m5(L,NULL,0,(t))
#define K3a(L,t) g_(t*,Z5(L,sizeof(t)))
#define F2(L,n,t) g_(t*,Z5(L,g_(k2,n)*g_(k2,sizeof(t))))
#define G4(L,v,W9,W,t,Q2,e) if(((W9)+1)>(W))((v)=g_(t*,X4a(L,v,&(W),sizeof(t),Q2,e)))
#define H0(L,v,i0c,n,t) ((v)=g_(t*,m5(L,v,g_(k2,i0c)*g_(k2,sizeof(t)),g_(k2,n)*g_(k2,sizeof(t)))))
#endif
#ifndef a5b
#define a5b
#define v7a(l) (g_(k2,sizeof(union A_))+(g_(k2,l)+1)*sizeof(char))
#define E5a(l) (g_(k2,sizeof(union C_a))+(l))
#define T5(L,s) (W2(L,s,strlen(s)))
#define k2a(L,s) (W2(L,""s,(sizeof(s)/sizeof(char))-1))
#define U6a(s) ((s)->x6.Y2|=(1<<4))
void
H_a(a*L,int
T1);C_a*w4a(a*L,size_t
s);void
w5a(a*L);A_*W2(a*L,const
char*str,size_t
l);
#endif
#ifndef W6b
#define W6b
#define r5(t,i) (&(t)->h3[i])
#define l4(n) (&(n)->E_c)
#define D4(n) (&(n)->w_c)
const
E*x_a(p0*t,int
x_);E*r8(a*L,p0*t,int
x_);const
E*t4(p0*t,A_*x_);const
E*x7(p0*t,const
E*x_);E*s_a(a*L,p0*t,const
E*x_);p0*E7(a*L,int
H5,int
h4b);void
J9a(a*L,p0*t);int
n9a(a*L,p0*t,t_
x_);M3*Z3(const
p0*t,const
E*x_);
#endif
#ifndef H4b
#define H4b
E_*r6a(a*L,h9*Z,m6*p_);int
b_a(void);void
H9a(a*L,const
E_*O6b,D5
w,void*e3);void
h_c(const
E_*O6b);
#define u8 "\033Lua"
#define S8a 0x50
#define Z_b 0x50
#define q6a ((U)3.14159265358979323846E7)
#endif
#ifndef Q_c
#define Q_c
#define V6a(L,o) ((V0(o)==u1)||(w5(L,o)))
#define v1a(o,n) (V0(o)==P1||(((o)=P6(o,n))!=NULL))
#define L0b(L,o1,o2) (V0(o1)==V0(o2)&&m4a(L,o1,o2))
int
A0a(a*L,const
E*l,const
E*r);int
m4a(a*L,const
E*t1,const
E*t2);const
E*P6(const
E*U1,E*n);int
w5(a*L,t_
U1);const
E*x8(a*L,const
E*t,E*x_,int
X4);void
z8(a*L,const
E*t,E*x_,t_
y6);t_
v6(a*L);void
F_a(a*L,int
K0a,int
L2);
#endif
const
char
c0c[]="$Lua: "g8" "v4a" $\n""$Authors: "k1b" $\n""$URL: www.lua.org $\n";
#ifndef m2
#define m2(L,o)
#endif
#define a1(L,n) m2(L,(n)<=(L->X-L->k_))
#define S0(L) {m2(L,L->X<L->ci->X);L->X++;}
static
E*n0b(a*L,int
F_){if(F_>L_){m2(L,F_!=0&&-F_<=L->X-L->k_);return
L->X+F_;}else
switch(F_){case
L_:return
a6(L);case
b0:return
gt(L);default:{E*a0=(L->k_-1);F_=b0-F_;H(N_a(a0));return(F_<=D2(a0)->c.h4)?&D2(a0)->c.J4[F_-1]:NULL;}}}static
E*W1(a*L,int
F_){if(F_>0){m2(L,F_<=L->X-L->k_);return
L->k_+F_-1;}else{E*o=n0b(L,F_);m2(L,o!=NULL);return
o;}}static
E*v_(a*L,int
F_){if(F_>0){E*o=L->k_+(F_-1);m2(L,F_<=L->x5-L->k_);if(o>=L->X)return
NULL;else
return
o;}else
return
n0b(L,F_);}void
H4(a*L,const
E*o){l0(L->X,o);W3(L);}K
int
I7(a*L,int
W){int
i0;n_(L);if((L->X-L->k_+W)>g4a)i0=0;else{N2(L,W);if(L->ci->X<L->X+W)L->ci->X=L->X+W;i0=1;}f_(L);return
i0;}K
void
j0a(a*W0,a*to,int
n){int
i;n_(to);a1(W0,n);W0->X-=n;for(i=0;i<n;i++){l0(to->X,W0->X+i);S0(to);}f_(to);}K
q0
m6a(a*L,q0
t5b){q0
old;n_(L);old=G(L)->l_b;G(L)->l_b=t5b;f_(L);return
old;}K
a*D0a(a*L){a*L1;n_(L);B1(L);L1=i3a(L);H2b(L->X,L1);S0(L);f_(L);S4(L1);return
L1;}K
int
D_(a*L){return(L->X-L->k_);}K
void
J0(a*L,int
F_){n_(L);if(F_>=0){m2(L,F_<=L->x5-L->k_);while(L->X<L->k_+F_)S_(L->X++);L->X=L->k_+F_;}else{m2(L,-(F_+1)<=(L->X-L->k_));L->X+=F_+1;}f_(L);}K
void
F5(a*L,int
F_){t_
p;n_(L);p=W1(L,F_);while(++p<L->X)i1(p-1,p);L->X--;f_(L);}K
void
C1(a*L,int
F_){t_
p;t_
q;n_(L);p=W1(L,F_);for(q=L->X;q>p;q--)i1(q,q-1);i1(p,L->X);f_(L);}K
void
X5(a*L,int
F_){n_(L);a1(L,1);O9(W1(L,F_),L->X-1);L->X--;f_(L);}K
void
Y(a*L,int
F_){n_(L);l0(L->X,W1(L,F_));S0(L);f_(L);}K
int
f2(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL)?k0a:V0(o);}K
const
char*o7(a*L,int
t){P2a(L);return(t==k0a)?"no value":g6[t];}K
int
O3(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL)?0:N_a(o);}K
int
x2(a*L,int
F_){E
n;const
E*o=v_(L,F_);return(o!=NULL&&v1a(o,&n));}K
int
Z1(a*L,int
F_){int
t=f2(L,F_);return(t==u1||t==P1);}K
int
Y2a(a*L,int
F_){const
E*o=v_(L,F_);return(o!=NULL&&(f5a(o)||G0a(o)));}K
int
x5a(a*L,int
H5a,int
F5a){t_
o1=v_(L,H5a);t_
o2=v_(L,F5a);return(o1==NULL||o2==NULL)?0:y3(o1,o2);}K
int
k9a(a*L,int
H5a,int
F5a){t_
o1,o2;int
i;n_(L);o1=v_(L,H5a);o2=v_(L,F5a);i=(o1==NULL||o2==NULL)?0:L0b(L,o1,o2);f_(L);return
i;}K
int
O1a(a*L,int
H5a,int
F5a){t_
o1,o2;int
i;n_(L);o1=v_(L,H5a);o2=v_(L,F5a);i=(o1==NULL||o2==NULL)?0:A0a(L,o1,o2);f_(L);return
i;}K
U
F0(a*L,int
F_){E
n;const
E*o=v_(L,F_);if(o!=NULL&&v1a(o,&n))return
s0(o);else
return
0;}K
int
Y1(a*L,int
F_){const
E*o=v_(L,F_);return(o!=NULL)&&!p0a(o);}K
const
char*o_(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;else
if(r1(o))return
r9(o);else{const
char*s;n_(L);s=(w5(L,o)?r9(o):NULL);B1(L);f_(L);return
s;}}K
size_t
S3(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
0;else
if(r1(o))return
q2(o)->x6.G1;else{size_t
l;n_(L);l=(w5(L,o)?q2(o)->x6.G1:0);f_(L);return
l;}}K
q0
n2a(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL||!N_a(o))?NULL:D2(o)->c.f;}K
void*b2(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;switch(V0(o)){case
f1:return(f0a(o)+1);case
K1:return
S2a(o);default:return
NULL;}}K
a*q6(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL||!o8a(o))?NULL:h2b(o);}K
const
void*r0a(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;else{switch(V0(o)){case
H_:return
m1(o);case
e0:return
D2(o);case
c3:return
h2b(o);case
f1:case
K1:return
b2(L,F_);default:return
NULL;}}}K
void
w_(a*L){n_(L);S_(L->X);S0(L);f_(L);}K
void
N(a*L,U
n){n_(L);N1(L->X,n);S0(L);f_(L);}K
void
b1(a*L,const
char*s,size_t
G1){n_(L);B1(L);G3(L->X,W2(L,s,G1));S0(L);f_(L);}K
void
I(a*L,const
char*s){if(s==NULL)w_(L);else
b1(L,s,strlen(s));}K
const
char*j1a(a*L,const
char*S6,va_list
a5){const
char*ret;n_(L);B1(L);ret=T4(L,S6,a5);f_(L);return
ret;}K
const
char*P_(a*L,const
char*S6,...){const
char*ret;va_list
a5;n_(L);B1(L);va_start(a5,S6);ret=T4(L,S6,a5);va_end(a5);f_(L);return
ret;}K
void
A1(a*L,q0
fn,int
n){C2*cl;n_(L);B1(L);a1(L,n);cl=I8(L,n);cl->c.f=fn;L->X-=n;while(n--)B3a(&cl->c.J4[n],L->X+n);J0a(L->X,cl);S0(L);f_(L);}K
void
o0(a*L,int
b){n_(L);l2a(L->X,(b!=0));S0(L);f_(L);}K
void
E1(a*L,void*p){n_(L);g9a(L->X,p);S0(L);f_(L);}K
void
s6(a*L,int
F_){t_
t;n_(L);t=W1(L,F_);l0(L->X-1,x8(L,t,L->X-1,0));f_(L);}K
void
z0(a*L,int
F_){t_
t;n_(L);t=W1(L,F_);m2(L,I2(t));l0(L->X-1,x7(m1(t),L->X-1));f_(L);}K
void
d0(a*L,int
F_,int
n){t_
o;n_(L);o=W1(L,F_);m2(L,I2(o));l0(L->X,x_a(m1(o),n));S0(L);f_(L);}K
void
U0(a*L){n_(L);B1(L);z6(L->X,E7(L,0,0));S0(L);f_(L);}K
int
X2(a*L,int
I1a){const
E*U1;p0*mt=NULL;int
i0;n_(L);U1=v_(L,I1a);if(U1!=NULL){switch(V0(U1)){case
H_:mt=m1(U1)->r_;break;case
f1:mt=f0a(U1)->uv.r_;break;}}if(mt==NULL||mt==m1(F3(L)))i0=0;else{z6(L->X,mt);S0(L);i0=1;}f_(L);return
i0;}K
void
E6a(a*L,int
F_){t_
o;n_(L);o=W1(L,F_);l0(L->X,J2a(o)?&D2(o)->l.g:gt(L));S0(L);f_(L);}K
void
Q0(a*L,int
F_){t_
t;n_(L);a1(L,2);t=W1(L,F_);z8(L,t,L->X-2,L->X-1);L->X-=2;f_(L);}K
void
G0(a*L,int
F_){t_
t;n_(L);a1(L,2);t=W1(L,F_);m2(L,I2(t));C1a(s_a(L,m1(t),L->X-2),L->X-1);L->X-=2;f_(L);}K
void
G2(a*L,int
F_,int
n){t_
o;n_(L);a1(L,1);o=W1(L,F_);m2(L,I2(o));C1a(r8(L,m1(o),n),L->X-1);L->X--;f_(L);}K
int
Z2(a*L,int
I1a){E*U1,*mt;int
i0=1;n_(L);a1(L,1);U1=W1(L,I1a);mt=(!I0(L->X-1))?L->X-1:F3(L);m2(L,I2(mt));switch(V0(U1)){case
H_:{m1(U1)->r_=m1(mt);break;}case
f1:{f0a(U1)->uv.r_=m1(mt);break;}default:{i0=0;break;}}L->X--;f_(L);return
i0;}K
int
t6a(a*L,int
F_){t_
o;int
i0=0;n_(L);a1(L,1);o=W1(L,F_);L->X--;m2(L,I2(L->X));if(J2a(o)){i0=1;D2(o)->l.g=*(L->X);}f_(L);return
i0;}K
void
j4(a*L,int
Z4,int
A0){t_
a0;n_(L);a1(L,Z4+1);a0=L->X-(Z4+1);A5(L,a0,A0);f_(L);}struct
I2b{t_
a0;int
A0;};static
void
b4b(a*L,void*ud){struct
I2b*c=g_(struct
I2b*,ud);A5(L,c->a0,c->A0);}K
int
B4(a*L,int
Z4,int
A0,int
p4){struct
I2b
c;int
T;ptrdiff_t
a0;n_(L);a0=(p4==0)?0:A4(L,W1(L,p4));c.a0=L->X-(Z4+1);c.A0=A0;T=Q3a(L,b4b,&c,A4(L,c.a0),a0);f_(L);return
T;}struct
a0b{q0
a0;void*ud;};static
void
v2b(a*L,void*ud){struct
a0b*c=g_(struct
a0b*,ud);C2*cl;cl=I8(L,0);cl->c.f=c->a0;J0a(L->X,cl);W3(L);g9a(L->X,c->ud);W3(L);A5(L,L->X-2,0);}K
int
N7a(a*L,q0
a0,void*ud){struct
a0b
c;int
T;n_(L);c.a0=a0;c.ud=ud;T=Q3a(L,v2b,&c,A4(L,L->X),0);f_(L);return
T;}K
int
J1a(a*L,J5
m0a,void*e3,const
char*V8){h9
z;int
T;int
c;n_(L);if(!V8)V8="?";p9a(&z,m0a,e3,V8);c=a3a(&z);T=l9(L,&z,(c==u8[0]));f_(L);return
T;}K
int
a1b(a*L,D5
Q7a,void*e3){int
T;E*o;n_(L);a1(L,1);o=L->X-1;if(J2a(o)&&D2(o)->l.h4==0){H9a(L,D2(o)->l.p,Q7a,e3);T=1;}else
T=0;f_(L);return
T;}
#define H_b(x) ((x)>>10)
#define a2b(x) (g_(int,H_b(x)))
#define N5b(x) (g_(k2,x)<<10)
K
int
n0a(a*L){int
Y4a;n_(L);Y4a=a2b(G(L)->O5);f_(L);return
Y4a;}K
int
X2a(a*L){int
z1;n_(L);z1=a2b(G(L)->b7);f_(L);return
z1;}K
void
T_a(a*L,int
T1a){n_(L);if(g_(k2,T1a)>H_b(f9a))G(L)->O5=f9a;else
G(L)->O5=N5b(T1a);B1(L);f_(L);}K
const
char*E1b(void){return
g8;}K
int
X8(a*L){n_(L);a1(L,1);v0a(L);f_(L);return
0;}K
int
W3a(a*L,int
F_){t_
t;int
p5;n_(L);t=W1(L,F_);m2(L,I2(t));p5=n9a(L,m1(t),L->X-1);if(p5){S0(L);}else
L->X-=1;f_(L);return
p5;}K
void
T3(a*L,int
n){n_(L);B1(L);a1(L,n);if(n>=2){F_a(L,n,L->X-L->k_-1);L->X-=(n-1);}else
if(n==0){G3(L->X,W2(L,NULL,0));S0(L);}f_(L);}K
void*E5(a*L,size_t
W){C_a*u;n_(L);B1(L);u=w4a(L,W);b5a(L->X,u);S0(L);f_(L);return
u+1;}K
int
H8(a*L){C2*a0;int
n,i;n_(L);m2(L,N_a(L->k_-1));a0=D2(L->k_-1);n=a0->c.h4;N2(L,n+N3);for(i=0;i<n;i++){l0(L->X,&a0->c.J4[i]);L->X++;}f_(L);return
n;}static
const
char*F6a(a*L,int
p7,int
n,E**y6){C2*f;t_
fi=W1(L,p7);if(!a2(fi))return
NULL;f=D2(fi);if(f->c.isC){if(n>f->c.h4)return
NULL;*y6=&f->c.J4[n-1];return"";}else{E_*p=f->l.p;if(n>p->K3)return
NULL;*y6=f->l.d2a[n-1]->v;return
I5(p->k0[n-1]);}}K
const
char*t_a(a*L,int
p7,int
n){const
char*b_;E*y6;n_(L);b_=F6a(L,p7,n,&y6);if(b_){l0(L->X,y6);S0(L);}f_(L);return
b_;}K
const
char*h_a(a*L,int
p7,int
n){const
char*b_;E*y6;n_(L);a1(L,1);b_=F6a(L,p7,n,&y6);if(b_){L->X--;O9(y6,L->X);}f_(L);return
b_;}
#define X_c
#ifndef M5b
#define M5b
#ifndef P
#define P K
#endif
typedef
struct
k3{const
char*b_;q0
a0;}k3;P
void
y2(a*L,const
char*W5a,const
k3*l,int
nup);P
int
f6(a*L,int
U1,const
char*e);P
int
u4a(a*L,int
U1,const
char*e);P
int
v5(a*L,int
Q1,const
char*T7);P
int
g1(a*L,int
g4b,const
char*x1a);P
const
char*y_(a*L,int
x4b,size_t*l);P
const
char*h7(a*L,int
x4b,const
char*def,size_t*l);P
U
d1(a*L,int
x4b);P
U
C3(a*L,int
O0c,U
def);P
void
F4(a*L,int
sz,const
char*W6);P
void
G_(a*L,int
Q1,int
t);P
void
B0(a*L,int
Q1);P
int
F0a(a*L,const
char*T7);P
void
H0a(a*L,const
char*T7);P
void*y9(a*L,int
ud,const
char*T7);P
void
V0a(a*L,int
lvl);P
int
s_(a*L,const
char*S6,...);P
int
i7(const
char*st,const
char*const
lst[]);P
int
k0b(a*L,int
t);P
void
g8a(a*L,int
t,int
j7);P
int
S8(a*L,int
t);P
void
Y8(a*L,int
t,int
n);P
int
O4(a*L,const
char*Q_);P
int
l3(a*L,const
char*p_,size_t
sz,const
char*b_);
#define f0(L,j6,g4b,x1a) if(!(j6))g1(L,g4b,x1a)
#define Q(L,n) (y_(L,(n),NULL))
#define K0(L,n,d) (h7(L,(n),(d),NULL))
#define Y_(L,n) ((int)d1(L,n))
#define b3a(L,n) ((long)d1(L,n))
#define c1(L,n,d) ((int)C3(L,n,(U)(d)))
#define F7(L,n,d) ((long)C3(L,n,(U)(d)))
#ifndef m3
#define m3 BUFSIZ
#endif
typedef
struct
I_{char*p;int
lvl;a*L;char
c0[m3];}I_;
#define n1(B,c) ((void)((B)->p<((B)->c0+m3)||k7(B)),(*(B)->p++=(char)(c)))
#define n1a(B,n) ((B)->p+=(n))
P
void
X1(a*L,I_*B);P
char*k7(I_*B);P
void
o3(I_*B,const
char*s,size_t
l);P
void
i5(I_*B,const
char*s);P
void
V6(I_*B);P
void
Z0(I_*B);P
int
o7a(a*L,const
char*Q_);P
int
B1a(a*L,const
char*str);P
int
l5a(a*L,const
char*p_,size_t
sz,const
char*n);
#define A7b y_
#define U8b h7
#define P5b d1
#define t7b C3
#define W7b f0
#define O5b Q
#define k7b K0
#define N7b Y_
#define F7b b3a
#define v9b c1
#define T8b F7
#endif
#define C4a 2
#define z4 1
#define z4a 2
#define U_a(L,i) ((i)>0||(i)<=L_?(i):D_(L)+(i)+1)
P
int
g1(a*L,int
Q1,const
char*x1a){D0
ar;T2(L,0,&ar);S5(L,"n",&ar);if(strcmp(ar.z7,"method")==0){Q1--;if(Q1==0)return
s_(L,"calling `%s' on bad self (%s)",ar.b_,x1a);}if(ar.b_==NULL)ar.b_="?";return
s_(L,"bad argument #%d to `%s' (%s)",Q1,ar.b_,x1a);}P
int
v5(a*L,int
Q1,const
char*T7){const
char*W6=P_(L,"%s expected, got %s",T7,o7(L,f2(L,Q1)));return
g1(L,Q1,W6);}static
void
c5a(a*L,int
Q1,int
tag){v5(L,Q1,o7(L,tag));}P
void
V0a(a*L,int
z_){D0
ar;if(T2(L,z_,&ar)){S5(L,"Snl",&ar);if(ar.A2>0){P_(L,"%s:%d: ",ar.d9,ar.A2);return;}}e_(L,"");}P
int
s_(a*L,const
char*S6,...){va_list
a5;va_start(a5,S6);V0a(L,1);j1a(L,S6,a5);va_end(a5);T3(L,2);return
X8(L);}P
int
i7(const
char*b_,const
char*const
g0[]){int
i;for(i=0;g0[i];i++)if(strcmp(g0[i],b_)==0)return
i;return-1;}P
int
F0a(a*L,const
char*T7){I(L,T7);z0(L,L_);if(!q3(L,-1))return
0;V_(L,1);U0(L);I(L,T7);Y(L,-2);G0(L,L_);Y(L,-1);I(L,T7);G0(L,L_);return
1;}P
void
H0a(a*L,const
char*T7){I(L,T7);z0(L,L_);}P
void*y9(a*L,int
ud,const
char*T7){const
char*tn;if(!X2(L,ud))return
NULL;z0(L,L_);tn=o_(L,-1);if(tn&&(strcmp(tn,T7)==0)){V_(L,1);return
b2(L,ud);}else{V_(L,1);return
NULL;}}P
void
F4(a*L,int
N0a,const
char*mes){if(!I7(L,N0a))s_(L,"stack overflow (%s)",mes);}P
void
G_(a*L,int
Q1,int
t){if(f2(L,Q1)!=t)c5a(L,Q1,t);}P
void
B0(a*L,int
Q1){if(f2(L,Q1)==k0a)g1(L,Q1,"value expected");}P
const
char*y_(a*L,int
Q1,size_t*G1){const
char*s=o_(L,Q1);if(!s)c5a(L,Q1,u1);if(G1)*G1=S3(L,Q1);return
s;}P
const
char*h7(a*L,int
Q1,const
char*def,size_t*G1){if(M1(L,Q1)){if(G1)*G1=(def?strlen(def):0);return
def;}else
return
y_(L,Q1,G1);}P
U
d1(a*L,int
Q1){U
d=F0(L,Q1);if(d==0&&!x2(L,Q1))c5a(L,Q1,P1);return
d;}P
U
C3(a*L,int
Q1,U
def){if(M1(L,Q1))return
def;else
return
d1(L,Q1);}P
int
f6(a*L,int
U1,const
char*S2){if(!X2(L,U1))return
0;I(L,S2);z0(L,-2);if(q3(L,-1)){V_(L,2);return
0;}else{F5(L,-2);return
1;}}P
int
u4a(a*L,int
U1,const
char*S2){U1=U_a(L,U1);if(!f6(L,U1,S2))return
0;Y(L,U1);j4(L,1,1);return
1;}P
void
y2(a*L,const
char*W5a,const
k3*l,int
nup){if(W5a){I(L,W5a);s6(L,b0);if(q3(L,-1)){V_(L,1);U0(L);I(L,W5a);Y(L,-2);Q0(L,b0);}C1(L,-(nup+1));}for(;l->b_;l++){int
i;I(L,l->b_);for(i=0;i<nup;i++)Y(L,-(nup+1));A1(L,l->a0,nup);Q0(L,-(nup+3));}V_(L,nup);}static
int
Y6a(a*L,int
M_c){int
n=(int)F0(L,-1);if(n==0&&!x2(L,-1))n=-1;V_(L,M_c);return
n;}static
void
r0b(a*L){d0(L,L_,z4a);if(q3(L,-1)){V_(L,1);U0(L);Y(L,-1);Z2(L,-2);e_(L,"__mode");e_(L,"k");G0(L,-3);Y(L,-1);G2(L,L_,z4a);}}void
Y8(a*L,int
t,int
n){t=U_a(L,t);e_(L,"n");z0(L,t);if(Y6a(L,1)>=0){e_(L,"n");N(L,(U)n);G0(L,t);}else{r0b(L);Y(L,t);N(L,(U)n);G0(L,-3);V_(L,1);}}int
S8(a*L,int
t){int
n;t=U_a(L,t);e_(L,"n");z0(L,t);if((n=Y6a(L,1))>=0)return
n;r0b(L);Y(L,t);z0(L,-2);if((n=Y6a(L,2))>=0)return
n;for(n=1;;n++){d0(L,t,n);if(q3(L,-1))break;V_(L,1);}V_(L,1);return
n-1;}
#define n6(B) ((B)->p-(B)->c0)
#define e6b(B) ((size_t)(m3-n6(B)))
#define f_c (N3/2)
static
int
K2a(I_*B){size_t
l=n6(B);if(l==0)return
0;else{b1(B->L,B->c0,l);B->p=B->c0;B->lvl++;return
1;}}static
void
H6a(I_*B){if(B->lvl>1){a*L=B->L;int
T5a=1;size_t
V3b=S3(L,-1);do{size_t
l=S3(L,-(T5a+1));if(B->lvl-T5a+1>=f_c||V3b>l){V3b+=l;T5a++;}else
break;}while(T5a<B->lvl);T3(L,T5a);B->lvl=B->lvl-T5a+1;}}P
char*k7(I_*B){if(K2a(B))H6a(B);return
B->c0;}P
void
o3(I_*B,const
char*s,size_t
l){while(l--)n1(B,*s++);}P
void
i5(I_*B,const
char*s){o3(B,s,strlen(s));}P
void
Z0(I_*B){K2a(B);T3(B->L,B->lvl);B->lvl=1;}P
void
V6(I_*B){a*L=B->L;size_t
vl=S3(L,-1);if(vl<=e6b(B)){memcpy(B->p,o_(L,-1),vl);B->p+=vl;V_(L,1);}else{if(K2a(B))C1(L,-2);B->lvl++;H6a(B);}}P
void
X1(a*L,I_*B){B->L=L;B->p=B->c0;B->lvl=0;}P
int
k0b(a*L,int
t){int
j7;t=U_a(L,t);if(q3(L,-1)){V_(L,1);return
N2b;}d0(L,t,z4);j7=(int)F0(L,-1);V_(L,1);if(j7!=0){d0(L,t,j7);G2(L,t,z4);}else{j7=S8(L,t);if(j7<C4a)j7=C4a;j7++;Y8(L,t,j7);}G2(L,t,j7);return
j7;}P
void
g8a(a*L,int
t,int
j7){if(j7>=0){t=U_a(L,t);d0(L,t,z4);G2(L,t,j7);N(L,(U)j7);G2(L,t,z4);}}typedef
struct
w_b{FILE*f;char
p_[m3];}w_b;static
const
char*e0c(a*L,void*ud,size_t*W){w_b*lf=(w_b*)ud;(void)L;if(feof(lf->f))return
NULL;*W=fread(lf->p_,1,m3,lf->f);return(*W>0)?lf->p_:NULL;}static
int
O8a(a*L,int
C5){const
char*Q_=o_(L,C5)+1;P_(L,"cannot read %s: %s",Q_,strerror(errno));F5(L,C5);return
M_a;}P
int
O4(a*L,const
char*Q_){w_b
lf;int
T,U7a;int
c;int
C5=D_(L)+1;if(Q_==NULL){e_(L,"=stdin");lf.f=stdin;}else{P_(L,"@%s",Q_);lf.f=fopen(Q_,"r");}if(lf.f==NULL)return
O8a(L,C5);c=ungetc(getc(lf.f),lf.f);if(!(isspace(c)||isprint(c))&&lf.f!=stdin){fclose(lf.f);lf.f=fopen(Q_,"rb");if(lf.f==NULL)return
O8a(L,C5);}T=J1a(L,e0c,&lf,o_(L,-1));U7a=ferror(lf.f);if(lf.f!=stdin)fclose(lf.f);if(U7a){J0(L,C5);return
O8a(L,C5);}F5(L,C5);return
T;}typedef
struct
q_b{const
char*s;size_t
W;}q_b;static
const
char*s0c(a*L,void*ud,size_t*W){q_b*O=(q_b*)ud;(void)L;if(O->W==0)return
NULL;*W=O->W;O->W=0;return
O->s;}P
int
l3(a*L,const
char*p_,size_t
W,const
char*b_){q_b
O;O.s=p_;O.W=W;return
J1a(L,s0c,&O,b_);}static
void
g5b(a*L,int
T){if(T!=0){t5(L,"_ALERT");if(g2(L,-1)){C1(L,-2);j4(L,1,0);}else{fprintf(stderr,"%s\n",o_(L,-2));V_(L,2);}}}static
int
t4b(a*L,int
T){if(T==0){T=B4(L,0,B2,0);}g5b(L,T);return
T;}P
int
o7a(a*L,const
char*Q_){return
t4b(L,O4(L,Q_));}P
int
l5a(a*L,const
char*p_,size_t
W,const
char*b_){return
t4b(L,l3(L,p_,W,b_));}P
int
B1a(a*L,const
char*str){return
l5a(L,str,strlen(str),str);}
#define n_c
#ifndef Z5b
#define Z5b
#ifndef P
#define P K
#endif
#define V9a "coroutine"
P
int
A9(a*L);
#define W8a "table"
P
int
v8(a*L);
#define M9a "io"
#define T9a "os"
P
int
O0a(a*L);
#define J8a "string"
P
int
S7(a*L);
#define w7b "math"
P
int
c2a(a*L);
#define W9a "debug"
P
int
t8(a*L);P
int
r2a(a*L);
#ifndef H
#define H(c)
#endif
#define E7b A9
#define V7b v8
#define V8b O0a
#define Q8b S7
#define p7b c2a
#define S8b t8
#endif
static
int
C3b(a*L){int
n=D_(L);int
i;t5(L,"tostring");for(i=1;i<=n;i++){const
char*s;Y(L,-1);Y(L,i);j4(L,1,1);s=o_(L,-1);if(s==NULL)return
s_(L,"`tostring' must return a string to `print'");if(i>1)fputs("\t",stdout);fputs(s,stdout);V_(L,1);}fputs("\n",stdout);return
0;}static
int
O9a(a*L){int
k_=c1(L,2,10);if(k_==10){B0(L,1);if(x2(L,1)){N(L,F0(L,1));return
1;}}else{const
char*s1=Q(L,1);char*s2;unsigned
long
n;f0(L,2<=k_&&k_<=36,2,"base out of range");n=strtoul(s1,&s2,k_);if(s1!=s2){while(isspace((unsigned
char)(*s2)))s2++;if(*s2=='\0'){N(L,(U)n);return
1;}}}w_(L);return
1;}static
int
G3b(a*L){int
z_=c1(L,2,1);B0(L,1);if(!Z1(L,1)||z_==0)Y(L,1);else{V0a(L,z_);Y(L,1);T3(L,2);}return
X8(L);}static
int
i6a(a*L){B0(L,1);if(!X2(L,1)){w_(L);return
1;}f6(L,1,"__metatable");return
1;}static
int
h6a(a*L){int
t=f2(L,2);G_(L,1,H_);f0(L,t==W5||t==H_,2,"nil or table expected");if(f6(L,1,"__metatable"))s_(L,"cannot change a protected metatable");J0(L,2);Z2(L,1);return
1;}static
void
q2b(a*L){if(g2(L,1))Y(L,1);else{D0
ar;int
z_=c1(L,1,1);f0(L,z_>=0,1,"level must be non-negative");if(T2(L,z_,&ar)==0)g1(L,1,"invalid level");S5(L,"f",&ar);if(q3(L,-1))s_(L,"no function environment for tail call at level %d",z_);}}static
int
p6a(a*L){E6a(L,-1);e_(L,"__fenv");z0(L,-2);return!q3(L,-1);}static
int
o0b(a*L){q2b(L);if(!p6a(L))V_(L,1);return
1;}static
int
V0b(a*L){G_(L,2,H_);q2b(L);if(p6a(L))s_(L,"`setfenv' cannot change a protected environment");else
V_(L,2);Y(L,2);if(x2(L,1)&&F0(L,1)==0)X5(L,b0);else
if(t6a(L,-2)==0)s_(L,"`setfenv' cannot change environment of given function");return
0;}static
int
h_b(a*L){B0(L,1);B0(L,2);o0(L,x5a(L,1,2));return
1;}static
int
r1b(a*L){G_(L,1,H_);B0(L,2);z0(L,1);return
1;}static
int
T1b(a*L){G_(L,1,H_);B0(L,2);B0(L,3);G0(L,1);return
1;}static
int
u1b(a*L){N(L,(U)X2a(L));N(L,(U)n0a(L));return
2;}static
int
D4a(a*L){T_a(L,c1(L,1,0));return
0;}static
int
G5b(a*L){B0(L,1);I(L,o7(L,f2(L,1)));return
1;}static
int
z5b(a*L){G_(L,1,H_);J0(L,2);if(W3a(L,1))return
2;else{w_(L);return
1;}}static
int
A3b(a*L){G_(L,1,H_);e_(L,"next");z0(L,b0);Y(L,1);w_(L);return
3;}static
int
J1b(a*L){U
i=F0(L,2);G_(L,1,H_);if(i==0&&i3(L,2)){e_(L,"ipairs");z0(L,b0);Y(L,1);N(L,0);return
3;}else{i++;N(L,i);d0(L,1,(int)i);return(q3(L,-1))?0:2;}}static
int
V_b(a*L,int
T){if(T==0)return
1;else{w_(L);C1(L,-2);return
2;}}static
int
d8a(a*L){size_t
l;const
char*s=y_(L,1,&l);const
char*V8=K0(L,2,s);return
V_b(L,l3(L,s,l,V8));}static
int
L9a(a*L){const
char*y3b=K0(L,1,NULL);return
V_b(L,O4(L,y3b));}static
int
A1b(a*L){const
char*y3b=K0(L,1,NULL);int
n=D_(L);int
T=O4(L,y3b);if(T!=0)X8(L);j4(L,0,B2);return
D_(L)-n;}static
int
l1b(a*L){B0(L,1);if(!Y1(L,1))return
s_(L,"%s",K0(L,2,"assertion failed!"));J0(L,1);return
1;}static
int
H1b(a*L){int
n,i;G_(L,1,H_);n=S8(L,1);F4(L,n,"table too big to unpack");for(i=1;i<=n;i++)d0(L,1,i);return
n;}static
int
w3b(a*L){int
T;B0(L,1);T=B4(L,D_(L)-1,B2,0);o0(L,(T==0));C1(L,1);return
D_(L);}static
int
S1b(a*L){int
T;B0(L,2);J0(L,2);C1(L,1);T=B4(L,0,B2,1);o0(L,(T==0));X5(L,1);return
D_(L);}static
int
S9a(a*L){char
p_[128];B0(L,1);if(u4a(L,1,"__tostring"))return
1;switch(f2(L,1)){case
P1:I(L,o_(L,1));return
1;case
u1:Y(L,1);return
1;case
l5:I(L,(Y1(L,1)?"true":"false"));return
1;case
H_:sprintf(p_,"table: %p",r0a(L,1));break;case
e0:sprintf(p_,"function: %p",r0a(L,1));break;case
f1:case
K1:sprintf(p_,"userdata: %p",b2(L,1));break;case
c3:sprintf(p_,"thread: %p",(void*)q6(L,1));break;case
W5:e_(L,"nil");return
1;}I(L,p_);return
1;}static
int
a_b(a*L){J0(L,1);E5(L,0);if(Y1(L,1)==0)return
1;else
if(f_b(L,1)){U0(L);Y(L,-1);o0(L,1);G0(L,O_(1));}else{int
p7a=0;if(X2(L,1)){z0(L,O_(1));p7a=Y1(L,-1);V_(L,1);}f0(L,p7a,1,"boolean or proxy expected");X2(L,1);}Z2(L,2);return
1;}
#define B_b "_LOADED"
#define N0b "LUA_PATH"
#ifndef y1a
#define y1a ';'
#endif
#ifndef f4a
#define f4a '?'
#endif
#ifndef A1a
#define A1a "?;?.lua"
#endif
static
const
char*b2b(a*L){const
char*B_;t5(L,N0b);B_=o_(L,-1);V_(L,1);if(B_)return
B_;B_=getenv(N0b);if(B_)return
B_;return
A1a;}static
const
char*S0b(a*L,const
char*B_){const
char*l;if(*B_=='\0')return
NULL;if(*B_==y1a)B_++;l=strchr(B_,y1a);if(l==NULL)l=B_+strlen(B_);b1(L,B_,l-B_);return
l;}static
void
p8a(a*L){const
char*B_=o_(L,-1);const
char*Z6b;int
n=1;while((Z6b=strchr(B_,f4a))!=NULL){F4(L,3,"too many marks in a path component");b1(L,B_,Z6b-B_);Y(L,1);B_=Z6b+1;n+=2;}I(L,B_);T3(L,n);}static
int
u0b(a*L){const
char*B_;int
T=M_a;Q(L,1);J0(L,1);t5(L,B_b);if(!z6a(L,2))return
s_(L,"`"B_b"' is not a table");B_=b2b(L);Y(L,1);z0(L,2);if(Y1(L,-1))return
1;else{while(T==M_a){J0(L,3);if((B_=S0b(L,B_))==NULL)break;p8a(L);T=O4(L,o_(L,-1));}}switch(T){case
0:{t5(L,"_REQUIREDNAME");C1(L,-2);Y(L,1);B8(L,"_REQUIREDNAME");j4(L,0,1);C1(L,-2);B8(L,"_REQUIREDNAME");if(q3(L,-1)){o0(L,1);X5(L,-2);}Y(L,1);Y(L,-2);G0(L,2);return
1;}case
M_a:{return
s_(L,"could not load package `%s' from path `%s'",o_(L,1),b2b(L));}default:{return
s_(L,"error loading package `%s' (%s)",o_(L,1),o_(L,-1));}}}static
const
k3
Y2b[]={{"error",G3b},{"getmetatable",i6a},{"setmetatable",h6a},{"getfenv",o0b},{"setfenv",V0b},{"next",z5b},{"ipairs",J1b},{"pairs",A3b},{"print",C3b},{"tonumber",O9a},{"tostring",S9a},{"type",G5b},{"assert",l1b},{"unpack",H1b},{"rawequal",h_b},{"rawget",r1b},{"rawset",T1b},{"pcall",w3b},{"xpcall",S1b},{"collectgarbage",D4a},{"gcinfo",u1b},{"loadfile",L9a},{"dofile",A1b},{"loadstring",d8a},{"require",u0b},{NULL,NULL}};static
int
E9a(a*L,a*co,int
Q1){int
T;if(!I7(co,Q1))s_(L,"too many arguments to resume");j0a(L,co,Q1);T=z3a(co,Q1);if(T==0){int
n7a=D_(co);if(!I7(L,n7a))s_(L,"too many results to resume");j0a(co,L,n7a);return
n7a;}else{j0a(co,L,1);return-1;}}static
int
Y9a(a*L){a*co=q6(L,1);int
r;f0(L,co,1,"coroutine expected");r=E9a(L,co,D_(L)-1);if(r<0){o0(L,0);C1(L,-2);return
2;}else{o0(L,1);C1(L,-(r+1));return
r+1;}}static
int
P_b(a*L){a*co=q6(L,O_(1));int
r=E9a(L,co,D_(L));if(r<0){if(Z1(L,-1)){V0a(L,1);C1(L,-2);T3(L,2);}X8(L);}return
r;}static
int
x4a(a*L){a*NL=D0a(L);f0(L,g2(L,1)&&!O3(L,1),1,"Lua function expected");Y(L,1);j0a(L,NL,1);return
1;}static
int
w1b(a*L){x4a(L);A1(L,P_b,1);return
1;}static
int
m3b(a*L){return
O4a(L,D_(L));}static
int
e_b(a*L){a*co=q6(L,1);f0(L,co,1,"coroutine expected");if(L==co)e_(L,"running");else{D0
ar;if(T2(co,0,&ar)==0&&D_(co)==0)e_(L,"dead");else
e_(L,"suspended");}return
1;}static
const
k3
l6b[]={{"create",x4a},{"wrap",w1b},{"resume",Y9a},{"yield",m3b},{"status",e_b},{NULL,NULL}};static
void
G4b(a*L){e_(L,"_G");Y(L,b0);y2(L,NULL,Y2b,0);e_(L,"_VERSION");e_(L,g8);G0(L,-3);e_(L,"newproxy");U0(L);Y(L,-1);Z2(L,-2);e_(L,"__mode");e_(L,"k");G0(L,-3);A1(L,a_b,1);G0(L,-3);G0(L,-1);}P
int
A9(a*L){G4b(L);y2(L,V9a,l6b,0);U0(L);B8(L,B_b);return
0;}
#define z0c
#ifndef H8b
#define H8b
#ifndef b9b
#define b9b
#define o6 257
#define D4b (sizeof("function")/sizeof(char))
enum
E6b{Q9b=o6,Q6b,n_b,l2b,q9a,j3a,S5b,i4b,z_a,C7b,D7b,Y5b,H9b,p9b,z_c,a9a,y4b,U7b,i8b,W_b,g7a,p_a,y9a,o2b,i7b,j7b,q7b,z7b,U8,B6,f8};
#define F0b (g_(int,g7a-o6+1))
typedef
union{U
r;A_*ts;}c1a;typedef
struct
H3b{int
U_;c1a
H1;}H3b;typedef
struct
c_{int
i_;int
u2;int
X1a;H3b
t;H3b
b5;struct
M*J;struct
a*L;h9*z;m6*p_;A_*n0;int
q2a;}c_;void
h9a(a*L);void
h4a(a*L,c_*LS,h9*z,A_*n0);int
d7a(c_*LS,c1a*H1);void
Q3(c_*O,int
y6,int
Q2,const
char*W6);void
u0(c_*O,const
char*s);void
o_a(c_*O,const
char*s,const
char*U_,int
X_);const
char*h5(c_*O,int
U_);
#endif
#ifndef s3b
#define s3b
enum
h9b{U3,N3a,c6a};
#define X_a 9
#define e0a 9
#define n3a (X_a+e0a)
#define C5a 8
#define e3a 6
#define y3a e3a
#define Y5a (y3a+X_a)
#define y5a y3a
#define P5a (Y5a+e0a)
#if n3a<BITS_INT-1
#define W_a ((1<<n3a)-1)
#define m9 (W_a>>1)
#else
#define W_a J7
#define m9 J7
#endif
#define c6b ((1<<C5a)-1)
#define w0c ((1<<e0a)-1)
#define F_b ((1<<X_a)-1)
#define W0a(n,p) ((~((~(j_)0)<<n))<<p)
#define u7a(n,p) (~W0a(n,p))
#define W_(i) (g_(h6,(i)&W0a(e3a,0)))
#define B3b(i,o) ((i)=(((i)&u7a(e3a,0))|g_(j_,o)))
#define A3(i) (g_(int,(i)>>P5a))
#define h7a(i,u) ((i)=(((i)&u7a(C5a,P5a))|((g_(j_,u)<<P5a)&W0a(C5a,P5a))))
#define d2(i) (g_(int,((i)>>Y5a)&W0a(e0a,0)))
#define Z6a(i,b) ((i)=(((i)&u7a(e0a,Y5a))|((g_(j_,b)<<Y5a)&W0a(e0a,Y5a))))
#define b3(i) (g_(int,((i)>>y3a)&W0a(X_a,0)))
#define E_b(i,b) ((i)=(((i)&u7a(X_a,y3a))|((g_(j_,b)<<y3a)&W0a(X_a,y3a))))
#define D7(i) (g_(int,((i)>>y5a)&W0a(n3a,0)))
#define Q3b(i,b) ((i)=(((i)&u7a(n3a,y5a))|((g_(j_,b)<<y5a)&W0a(n3a,y5a))))
#define V3(i) (D7(i)-m9)
#define i3b(i,b) Q3b((i),g_(unsigned int,(b)+m9))
#define Z2b(o,a,b,c) (g_(j_,o)|(g_(j_,a)<<P5a)|(g_(j_,b)<<Y5a)|(g_(j_,c)<<y3a))
#define u3b(o,a,bc) (g_(j_,o)|(g_(j_,a)<<P5a)|(g_(j_,bc)<<y5a))
#define M6 c6b
typedef
enum{c9,c4a,o8,F9,P5,H7,I_a,U9,A_a,O_a,H2a,Q2a,H0b,t0b,T4b,c4b,q4b,Y0b,d5a,d0a,I5a,x_b,p_b,r_b,w_a,I4,c5,d5,X0a,J_a,M2a,I6,j8,Y3a,V9}h6;
#define I6a (g_(int,V9+1))
enum
d_c{J7a=2,z9a,Z8a,b8a,d2b,Z5a};extern
const
T_
m1a[I6a];
#define V_a(m) (g_(enum h9b,m1a[m]&3))
#define B5(m,b) (m1a[m]&(1<<(b)))
#ifdef L1b
extern
const
char*const
o5a[];
#endif
#define V4 32
#endif
#ifndef S3b
#define S3b
typedef
enum{E_a,z8a,t2a,E1a,VK,M1a,P7a,Q5a,z1a,b7a,j3,c4,j2a}t2b;typedef
struct
d_{t2b
k;int
C_,B9;int
t;int
f;}d_;struct
k4;typedef
struct
M{E_*f;p0*h;struct
M*e5a;struct
c_*O;struct
a*L;struct
k4*bl;int
pc;int
U3a;int
jpc;int
x0;int
nk;int
np;int
q_a;int
N0;d_
k0[S_a];int
l4b[g6a];}M;E_*w6a(a*L,h9*z,m6*p_);
#endif
#define C0 (-1)
typedef
enum
l8{e2b,O7b,S6b,n8b,g2b,F3a,q7a,s9b,F9b,S9b,c5b,P9b,Y8a,L_b,Z4a}l8;
#define Z9b(op) ((op)>=q7a)
typedef
enum
a8a{r9a,K7b,D6a}a8a;
#define M7(J,e) ((J)->f->q1[(e)->C_])
#define q0a(J,o,A,sBx) w3(J,o,A,(sBx)+m9)
int
B2a(M*J,j_
i,int
X_);int
w3(M*J,h6
o,int
A,unsigned
int
Bx);int
K_(M*J,h6
o,int
A,int
B,int
C);void
Z9(M*J,int
X_);void
O6a(M*J,int
W0,int
n);void
S1(M*J,int
n);void
x9(M*J,int
n);int
o1a(M*J,A_*s);int
X9(M*J,U
r);void
T0(M*J,d_*e);int
h2(M*J,d_*e);void
L0(M*J,d_*e);void
s7(M*J,d_*e);int
H3(M*J,d_*e);void
l9a(M*J,d_*e,d_*x_);void
F1a(M*J,d_*t,d_*k);void
z0a(M*J,d_*e);void
a8(M*J,d_*e);void
Q6(M*J,d_*g9,d_*e);void
V1(M*J,d_*g9,int
A0);int
y4(M*J);void
Q7(M*J,int
g0,int
k9);void
M0(M*J,int
g0);void
z2(M*J,int*l1,int
l2);int
b4(M*J);void
x6a(M*J,a8a
op,d_*v);void
h8a(M*J,l8
op,d_*v);void
l6a(M*J,l8
op,d_*v1,d_*v2);
#endif
#define T6a(e) ((e)->t!=(e)->f)
void
O6a(M*J,int
W0,int
n){j_*Z_;if(J->pc>J->U3a&&W_(*(Z_=&J->f->q1[J->pc-1]))==F9){int
t_c=A3(*Z_);int
pto=d2(*Z_);if(t_c<=W0&&W0<=pto+1){if(W0+n-1>pto)Z6a(*Z_,W0+n-1);return;}}K_(J,F9,W0,W0+n-1,0);}int
y4(M*J){int
jpc=J->jpc;int
j;J->jpc=C0;j=q0a(J,I5a,0,C0);z2(J,&j,jpc);return
j;}static
int
B0a(M*J,h6
op,int
A,int
B,int
C){K_(J,op,A,B,C);return
y4(J);}static
void
Y9(M*J,int
pc,int
L6a){j_*jmp=&J->f->q1[pc];int
b0a=L6a-(pc+1);H(L6a!=C0);if(abs(b0a)>m9)u0(J->O,"control structure too long");i3b(*jmp,b0a);}int
b4(M*J){J->U3a=J->pc;return
J->pc;}static
int
s1a(M*J,int
pc){int
b0a=V3(J->f->q1[pc]);if(b0a==C0)return
C0;else
return(pc+1)+b0a;}static
j_*u_a(M*J,int
pc){j_*pi=&J->f->q1[pc];if(pc>=1&&B5(W_(*(pi-1)),Z5a))return
pi-1;else
return
pi;}static
int
m8a(M*J,int
g0,int
j6){for(;g0!=C0;g0=s1a(J,g0)){j_
i=*u_a(J,g0);if(W_(i)!=w_a||b3(i)!=j6)return
1;}return
0;}static
void
r5a(j_*i,int
g4){if(g4==M6)g4=d2(*i);h7a(*i,g4);}static
void
e6(M*J,int
g0,int
A2b,int
m0c,int
z2b,int
u0c,int
p2b){while(g0!=C0){int
h_=s1a(J,g0);j_*i=u_a(J,g0);if(W_(*i)!=w_a){H(p2b!=C0);Y9(J,g0,p2b);}else{if(b3(*i)){H(A2b!=C0);r5a(i,m0c);Y9(J,g0,A2b);}else{H(z2b!=C0);r5a(i,u0c);Y9(J,g0,z2b);}}g0=h_;}}static
void
k6a(M*J){e6(J,J->jpc,J->pc,M6,J->pc,M6,J->pc);J->jpc=C0;}void
Q7(M*J,int
g0,int
k9){if(k9==J->pc)M0(J,g0);else{H(k9<J->pc);e6(J,g0,k9,M6,k9,M6,k9);}}void
M0(M*J,int
g0){b4(J);z2(J,&J->jpc,g0);}void
z2(M*J,int*l1,int
l2){if(l2==C0)return;else
if(*l1==C0)*l1=l2;else{int
g0=*l1;int
h_;while((h_=s1a(J,g0))!=C0)g0=h_;Y9(J,g0,l2);}}void
x9(M*J,int
n){int
Q6a=J->x0+n;if(Q6a>J->f->c2){if(Q6a>=w2)u0(J->O,"function or expression too complex");J->f->c2=g_(T_,Q6a);}}void
S1(M*J,int
n){x9(J,n);J->x0+=n;}static
void
x0(M*J,int
g4){if(g4>=J->N0&&g4<w2){J->x0--;H(g4==J->x0);}}static
void
e5(M*J,d_*e){if(e->k==c4)x0(J,e->C_);}static
int
m6b(M*J,E*k,E*v){const
E*F_=x7(J->h,k);if(Y0(F_)){H(y3(&J->f->k[g_(int,s0(F_))],v));return
g_(int,s0(F_));}else{E_*f=J->f;G4(J->L,f->k,J->nk,f->j9,E,W_a,"constant table overflow");B3a(&f->k[J->nk],v);N1(s_a(J->L,J->h,k),g_(U,J->nk));return
J->nk++;}}int
o1a(M*J,A_*s){E
o;z2a(&o,s);return
m6b(J,&o,&o);}int
X9(M*J,U
r){E
o;N1(&o,r);return
m6b(J,&o,&o);}static
int
b1b(M*J){E
k,v;S_(&v);z6(&k,J->h);return
m6b(J,&k,&v);}void
V1(M*J,d_*e,int
A0){if(e->k==j2a){E_b(M7(J,e),A0+1);if(A0==1){e->k=c4;e->C_=A3(M7(J,e));}}}void
T0(M*J,d_*e){switch(e->k){case
M1a:{e->k=c4;break;}case
P7a:{e->C_=K_(J,P5,0,e->C_,0);e->k=j3;break;}case
Q5a:{e->C_=w3(J,H7,0,e->C_);e->k=j3;break;}case
z1a:{x0(J,e->B9);x0(J,e->C_);e->C_=K_(J,I_a,0,e->C_,e->B9);e->k=j3;break;}case
j2a:{V1(J,e,1);break;}default:break;}}static
int
G7a(M*J,int
A,int
b,int
M4){b4(J);return
K_(J,o8,A,b,M4);}static
void
s4a(M*J,d_*e,int
g4){T0(J,e);switch(e->k){case
z8a:{O6a(J,g4,1);break;}case
E1a:case
t2a:{K_(J,o8,g4,e->k==t2a,0);break;}case
VK:{w3(J,c4a,g4,e->C_);break;}case
j3:{j_*pc=&M7(J,e);h7a(*pc,g4);break;}case
c4:{if(g4!=e->C_)K_(J,c9,g4,e->C_,0);break;}default:{H(e->k==E_a||e->k==b7a);return;}}e->C_=g4;e->k=c4;}static
void
i1a(M*J,d_*e){if(e->k!=c4){S1(J,1);s4a(J,e,J->x0-1);}}static
void
K1a(M*J,d_*e,int
g4){s4a(J,e,g4);if(e->k==b7a)z2(J,&e->t,e->C_);if(T6a(e)){int
O3a;int
p_f=C0;int
p_t=C0;if(m8a(J,e->t,1)||m8a(J,e->f,0)){int
fj=C0;if(e->k!=b7a)fj=y4(J);p_f=G7a(J,g4,0,1);p_t=G7a(J,g4,1,0);M0(J,fj);}O3a=b4(J);e6(J,e->f,p_f,M6,O3a,g4,p_f);e6(J,e->t,O3a,g4,p_t,M6,p_t);}e->f=e->t=C0;e->C_=g4;e->k=c4;}void
L0(M*J,d_*e){T0(J,e);e5(J,e);S1(J,1);K1a(J,e,J->x0-1);}int
h2(M*J,d_*e){T0(J,e);if(e->k==c4){if(!T6a(e))return
e->C_;if(e->C_>=J->N0){K1a(J,e,e->C_);return
e->C_;}}L0(J,e);return
e->C_;}void
s7(M*J,d_*e){if(T6a(e))h2(J,e);else
T0(J,e);}int
H3(M*J,d_*e){s7(J,e);switch(e->k){case
z8a:{if(J->nk+w2<=F_b){e->C_=b1b(J);e->k=VK;return
e->C_+w2;}else
break;}case
VK:{if(e->C_+w2<=F_b)return
e->C_+w2;else
break;}default:break;}return
h2(J,e);}void
Q6(M*J,d_*g9,d_*exp){switch(g9->k){case
M1a:{e5(J,exp);K1a(J,exp,g9->C_);return;}case
P7a:{int
e=h2(J,exp);K_(J,A_a,e,g9->C_,0);break;}case
Q5a:{int
e=h2(J,exp);w3(J,U9,e,g9->C_);break;}case
z1a:{int
e=H3(J,exp);K_(J,O_a,g9->C_,g9->B9,e);break;}default:{H(0);break;}}e5(J,exp);}void
l9a(M*J,d_*e,d_*x_){int
a0;h2(J,e);e5(J,e);a0=J->x0;S1(J,2);K_(J,Q2a,a0,e->C_,H3(J,x_));e5(J,x_);e->C_=a0;e->k=c4;}static
void
q8a(M*J,d_*e){j_*pc=u_a(J,e->C_);H(B5(W_(*pc),Z5a)&&W_(*pc)!=w_a);h7a(*pc,!(A3(*pc)));}static
int
e8a(M*J,d_*e,int
j6){if(e->k==j3){j_
ie=M7(J,e);if(W_(ie)==d5a){J->pc--;return
B0a(J,w_a,M6,d2(ie),!j6);}}i1a(J,e);e5(J,e);return
B0a(J,w_a,M6,e->C_,j6);}void
z0a(M*J,d_*e){int
pc;T0(J,e);switch(e->k){case
VK:case
t2a:{pc=C0;break;}case
E1a:{pc=y4(J);break;}case
b7a:{q8a(J,e);pc=e->C_;break;}default:{pc=e8a(J,e,0);break;}}z2(J,&e->f,pc);}void
a8(M*J,d_*e){int
pc;T0(J,e);switch(e->k){case
z8a:case
E1a:{pc=C0;break;}case
t2a:{pc=y4(J);break;}case
b7a:{pc=e->C_;break;}default:{pc=e8a(J,e,1);break;}}z2(J,&e->t,pc);}static
void
L8b(M*J,d_*e){T0(J,e);switch(e->k){case
z8a:case
E1a:{e->k=t2a;break;}case
VK:case
t2a:{e->k=E1a;break;}case
b7a:{q8a(J,e);break;}case
j3:case
c4:{i1a(J,e);e5(J,e);e->C_=K_(J,d5a,0,e->C_,0);e->k=j3;break;}default:{H(0);break;}}{int
g7=e->f;e->f=e->t;e->t=g7;}}void
F1a(M*J,d_*t,d_*k){t->B9=H3(J,k);t->k=z1a;}void
x6a(M*J,a8a
op,d_*e){if(op==r9a){s7(J,e);if(e->k==VK&&Y0(&J->f->k[e->C_]))e->C_=X9(J,-s0(&J->f->k[e->C_]));else{h2(J,e);e5(J,e);e->C_=K_(J,Y0b,0,e->C_,0);e->k=j3;}}else
L8b(J,e);}void
h8a(M*J,l8
op,d_*v){switch(op){case
Y8a:{z0a(J,v);M0(J,v->t);v->t=C0;break;}case
L_b:{a8(J,v);M0(J,v->f);v->f=C0;break;}case
F3a:{L0(J,v);break;}default:{H3(J,v);break;}}}static
void
L5b(M*J,d_*i0,l8
op,int
o1,int
o2){if(op<=g2b){h6
opc=g_(h6,(op-e2b)+H0b);i0->C_=K_(J,opc,0,o1,o2);i0->k=j3;}else{static
const
h6
ops[]={x_b,x_b,p_b,r_b,p_b,r_b};int
j6=1;if(op>=c5b){int
g7;g7=o1;o1=o2;o2=g7;}else
if(op==q7a)j6=0;i0->C_=B0a(J,ops[op-q7a],j6,o1,o2);i0->k=b7a;}}void
l6a(M*J,l8
op,d_*e1,d_*e2){switch(op){case
Y8a:{H(e1->t==C0);T0(J,e2);z2(J,&e1->f,e2->f);e1->k=e2->k;e1->C_=e2->C_;e1->B9=e2->B9;e1->t=e2->t;break;}case
L_b:{H(e1->f==C0);T0(J,e2);z2(J,&e1->t,e2->t);e1->k=e2->k;e1->C_=e2->C_;e1->B9=e2->B9;e1->f=e2->f;break;}case
F3a:{s7(J,e2);if(e2->k==j3&&W_(M7(J,e2))==d0a){H(e1->C_==d2(M7(J,e2))-1);e5(J,e1);Z6a(M7(J,e2),e1->C_);e1->k=e2->k;e1->C_=e2->C_;}else{L0(J,e2);e5(J,e2);e5(J,e1);e1->C_=K_(J,d0a,0,e1->C_,e2->C_);e1->k=j3;}break;}default:{int
o1=H3(J,e1);int
o2=H3(J,e2);e5(J,e2);e5(J,e1);L5b(J,e1,op,o1,o2);}}}void
Z9(M*J,int
X_){J->f->n4[J->pc-1]=X_;}int
B2a(M*J,j_
i,int
X_){E_*f=J->f;k6a(J);G4(J->L,f->q1,J->pc,f->K2,j_,J7,"code size overflow");f->q1[J->pc]=i;G4(J->L,f->n4,J->pc,f->t3,int,J7,"code size overflow");f->n4[J->pc]=X_;return
J->pc++;}int
K_(M*J,h6
o,int
a,int
b,int
c){H(V_a(o)==U3);return
B2a(J,Z2b(o,a,b,c),J->O->X1a);}int
w3(M*J,h6
o,int
a,unsigned
int
bc){H(V_a(o)==N3a||V_a(o)==c6a);return
B2a(J,u3b(o,a,bc),J->O->X1a);}
#define x0c
static
void
w1a(a*L,const
char*i,const
char*v){I(L,i);I(L,v);G0(L,-3);}static
void
W6a(a*L,const
char*i,int
v){I(L,i);N(L,(U)v);G0(L,-3);}static
int
I7b(a*L){D0
ar;const
char*a1a=K0(L,2,"flnSu");if(x2(L,1)){if(!T2(L,(int)(F0(L,1)),&ar)){w_(L);return
1;}}else
if(g2(L,1)){P_(L,">%s",a1a);a1a=o_(L,-1);Y(L,1);}else
return
g1(L,1,"function or level expected");if(!S5(L,a1a,&ar))return
g1(L,2,"invalid option");U0(L);for(;*a1a;a1a++){switch(*a1a){case'S':w1a(L,"source",ar.n0);w1a(L,"short_src",ar.d9);W6a(L,"linedefined",ar.Y6);w1a(L,"what",ar.v3);break;case'l':W6a(L,"currentline",ar.A2);break;case'u':W6a(L,"nups",ar.k5);break;case'n':w1a(L,"name",ar.b_);w1a(L,"namewhat",ar.z7);break;case'f':e_(L,"func");Y(L,-3);G0(L,-3);break;}}return
1;}static
int
P6b(a*L){D0
ar;const
char*b_;if(!T2(L,Y_(L,1),&ar))return
g1(L,1,"level out of range");b_=U4a(L,&ar,Y_(L,2));if(b_){I(L,b_);Y(L,-2);return
2;}else{w_(L);return
1;}}static
int
v6b(a*L){D0
ar;if(!T2(L,Y_(L,1),&ar))return
g1(L,1,"level out of range");B0(L,3);I(L,G5a(L,&ar,Y_(L,2)));return
1;}static
int
I7a(a*L,int
n8){const
char*b_;int
n=Y_(L,2);G_(L,1,e0);if(O3(L,1))return
0;b_=n8?t_a(L,1,n):h_a(L,1,n);if(b_==NULL)return
0;I(L,b_);C1(L,-(n8+1));return
n8+1;}static
int
K3b(a*L){return
I7a(L,1);}static
int
U2b(a*L){B0(L,3);return
I7a(L,0);}static
const
char
k7a='h';static
void
v7b(a*L,D0*ar){static
const
char*const
e5b[]={"call","return","line","count","tail return"};E1(L,(void*)&k7a);z0(L,L_);if(g2(L,-1)){I(L,e5b[(int)ar->S2]);if(ar->A2>=0)N(L,(U)ar->A2);else
w_(L);H(S5(L,"lS",ar));j4(L,2,0);}else
V_(L,1);}static
int
y6b(const
char*Y7,int
z1){int
K4=0;if(strchr(Y7,'c'))K4|=y7;if(strchr(Y7,'r'))K4|=P_a;if(strchr(Y7,'l'))K4|=u6;if(z1>0)K4|=T6;return
K4;}static
char*d3b(int
K4,char*Y7){int
i=0;if(K4&y7)Y7[i++]='c';if(K4&P_a)Y7[i++]='r';if(K4&u6)Y7[i++]='l';Y7[i]='\0';return
Y7;}static
int
x8b(a*L){if(M1(L,1)){J0(L,1);Q5(L,NULL,0,0);}else{const
char*Y7=Q(L,2);int
z1=c1(L,3,0);G_(L,1,e0);Q5(L,v7b,y6b(Y7,z1),z1);}E1(L,(void*)&k7a);Y(L,1);G0(L,L_);return
0;}static
int
s8b(a*L){char
p_[5];int
K4=u2a(L);F8
D6=G6a(L);if(D6!=NULL&&D6!=v7b)e_(L,"external hook");else{E1(L,(void*)&k7a);z0(L,L_);}I(L,d3b(K4,p_));N(L,(U)h1a(L));return
3;}static
int
e6a(a*L){for(;;){char
c0[250];fputs("lua_debug> ",stderr);if(fgets(c0,sizeof(c0),stdin)==0||strcmp(c0,"cont\n")==0)return
0;B1a(L,c0);J0(L,0);}}
#define D8b 12
#define B8a 10
static
int
j2b(a*L){int
z_=1;int
s9a=1;D0
ar;if(D_(L)==0)e_(L,"");else
if(!Z1(L,1))return
1;else
e_(L,"\n");e_(L,"stack traceback:");while(T2(L,z_++,&ar)){if(z_>D8b&&s9a){if(!T2(L,z_+B8a,&ar))z_--;else{e_(L,"\n\t...");while(T2(L,z_+B8a,&ar))z_++;}s9a=0;continue;}e_(L,"\n\t");S5(L,"Snl",&ar);P_(L,"%s:",ar.d9);if(ar.A2>0)P_(L,"%d:",ar.A2);switch(*ar.z7){case'g':case'l':case'f':case'm':P_(L," in function `%s'",ar.b_);break;default:{if(*ar.v3=='m')P_(L," in main chunk");else
if(*ar.v3=='C'||*ar.v3=='t')e_(L," ?");else
P_(L," in function <%s:%d>",ar.d9,ar.Y6);}}T3(L,D_(L));}T3(L,D_(L));return
1;}static
const
k3
m_c[]={{"getlocal",P6b},{"getinfo",I7b},{"gethook",s8b},{"getupvalue",K3b},{"sethook",x8b},{"setlocal",v6b},{"setupvalue",U2b},{"debug",e6a},{"traceback",j2b},{NULL,NULL}};P
int
t8(a*L){y2(L,W9a,m_c,0);e_(L,"_TRACEBACK");e8(L,j2b);Q0(L,b0);return
1;}
#define j0c
static
const
char*J6a(m0*ci,const
char**b_);
#define X5a(ci) (!((ci)->h0&Y1a))
static
int
Q8(m0*ci){if(!X5a(ci))return-1;if(ci->h0&c7)ci->u.l.n2=*ci->u.l.pc;return
s_b(ci->u.l.n2,Z0a(ci)->l.p);}static
int
A2(m0*ci){int
pc=Q8(ci);if(pc<0)return-1;else
return
S5a(Z0a(ci)->l.p,pc);}void
o3a(a*L){m0*ci;for(ci=L->ci;ci!=L->O0;ci--)Q8(ci);L->s3a=1;}K
int
Q5(a*L,F8
a0,int
K4,int
z1){if(a0==NULL||K4==0){K4=0;a0=NULL;}L->D6=a0;L->w8=z1;i_a(L);L->J6=g_(T_,K4);L->s3a=0;return
1;}K
F8
G6a(a*L){return
L->D6;}K
int
u2a(a*L){return
L->J6;}K
int
h1a(a*L){return
L->w8;}K
int
T2(a*L,int
z_,D0*ar){int
T;m0*ci;n_(L);for(ci=L->ci;z_>0&&ci>L->O0;ci--){z_--;if(!(ci->h0&Y1a))z_-=ci->u.l.h0a;}if(z_>0||ci==L->O0)T=0;else
if(z_<0){T=1;ar->s5a=0;}else{T=1;ar->s5a=ci-L->O0;}f_(L);return
T;}static
E_*F2a(m0*ci){return(X5a(ci)?Z0a(ci)->l.p:NULL);}K
const
char*U4a(a*L,const
D0*ar,int
n){const
char*b_;m0*ci;E_*fp;n_(L);b_=NULL;ci=L->O0+ar->s5a;fp=F2a(ci);if(fp){b_=U4(fp,n,Q8(ci));if(b_)H4(L,ci->k_+(n-1));}f_(L);return
b_;}K
const
char*G5a(a*L,const
D0*ar,int
n){const
char*b_;m0*ci;E_*fp;n_(L);b_=NULL;ci=L->O0+ar->s5a;fp=F2a(ci);L->X--;if(fp){b_=U4(fp,n,Q8(ci));if(!b_||b_[0]=='(')b_=NULL;else
i1(ci->k_+(n-1),L->X);}f_(L);return
b_;}static
void
h6b(D0*ar,t_
a0){C2*cl=D2(a0);if(cl->c.isC){ar->n0="=[C]";ar->Y6=-1;ar->v3="C";}else{ar->n0=I5(cl->l.p->n0);ar->Y6=cl->l.p->i8;ar->v3=(ar->Y6==0)?"main":"Lua";}G7(ar->d9,ar->n0,i9);}static
const
char*t1b(a*L,const
E*o){p0*g=m1(gt(L));int
i=q5(g);while(i--){M3*n=r5(g,i);if(y3(o,D4(n))&&r1(l4(n)))return
I5(q2(l4(n)));}return
NULL;}static
void
Z9a(a*L,D0*ar){ar->b_=ar->z7="";ar->v3="tail";ar->Y6=ar->A2=-1;ar->n0="=(tail call)";G7(ar->d9,ar->n0,i9);ar->k5=0;S_(L->X);}static
int
E7a(a*L,const
char*v3,D0*ar,t_
f,m0*ci){int
T=1;for(;*v3;v3++){switch(*v3){case'S':{h6b(ar,f);break;}case'l':{ar->A2=(ci)?A2(ci):-1;break;}case'u':{ar->k5=D2(f)->c.h4;break;}case'n':{ar->z7=(ci)?J6a(ci,&ar->b_):NULL;if(ar->z7==NULL){if((ar->b_=t1b(L,f))!=NULL)ar->z7="global";else
ar->z7="";}break;}case'f':{l0(L->X,f);break;}default:T=0;}}return
T;}K
int
S5(a*L,const
char*v3,D0*ar){int
T=1;n_(L);if(*v3=='>'){t_
f=L->X-1;if(!a2(f))q_(L,"value for `lua_getinfo' is not a function");T=E7a(L,v3+1,ar,f,NULL);L->X--;}else
if(ar->s5a!=0){m0*ci=L->O0+ar->s5a;H(a2(ci->k_-1));T=E7a(L,v3,ar,ci->k_-1,ci);}else
Z9a(L,ar);if(strchr(v3,'f'))W3(L);f_(L);return
T;}
#define J_(x) if(!(x))return 0;
#define A5b(pt,pc) J_(0<=pc&&pc<pt->K2)
#define c6(pt,g4) J_((g4)<(pt)->c2)
static
int
x6b(const
E_*pt){J_(pt->c2<=w2);J_(pt->t3==pt->K2||pt->t3==0);H(pt->l7+pt->T8<=pt->c2);J_(W_(pt->q1[pt->K2-1])==d5);return
1;}static
int
C1b(const
E_*pt,int
pc){j_
i=pt->q1[pc+1];switch(W_(i)){case
I4:case
c5:case
d5:{J_(d2(i)==0);return
1;}case
j8:return
1;default:return
0;}}static
int
E2b(const
E_*pt,int
r){return(r<pt->c2||(r>=w2&&r-w2<pt->j9));}static
j_
n4a(const
E_*pt,int
m0b,int
g4){int
pc;int
L2;L2=pt->K2-1;J_(x6b(pt));for(pc=0;pc<m0b;pc++){const
j_
i=pt->q1[pc];h6
op=W_(i);int
a=A3(i);int
b=0;int
c=0;c6(pt,a);switch(V_a(op)){case
U3:{b=d2(i);c=b3(i);if(B5(op,J7a)){c6(pt,b);}else
if(B5(op,z9a))J_(E2b(pt,b));if(B5(op,Z8a))J_(E2b(pt,c));break;}case
N3a:{b=D7(i);if(B5(op,d2b))J_(b<pt->j9);break;}case
c6a:{b=V3(i);break;}}if(B5(op,b8a)){if(a==g4)L2=pc;}if(B5(op,Z5a)){J_(pc+2<pt->K2);J_(W_(pt->q1[pc+1])==I5a);}switch(op){case
o8:{J_(c==0||pc+2<pt->K2);break;}case
F9:{if(a<=g4&&g4<=b)L2=pc;break;}case
P5:case
A_a:{J_(b<pt->k5);break;}case
H7:case
U9:{J_(r1(&pt->k[b]));break;}case
Q2a:{c6(pt,a+1);if(g4==a+1)L2=pc;break;}case
d0a:{J_(c<w2&&b<c);break;}case
J_a:c6(pt,a+c+5);if(g4>=a)L2=pc;case
X0a:c6(pt,a+2);case
I5a:{int
L6a=pc+1+b;J_(0<=L6a&&L6a<pt->K2);if(g4!=M6&&pc<L6a&&L6a<=m0b)pc+=b;break;}case
I4:case
c5:{if(b!=0){c6(pt,a+b-1);}c--;if(c==B2){J_(C1b(pt,pc));}else
if(c!=0)c6(pt,a+c-1);if(g4>=a)L2=pc;break;}case
d5:{b--;if(b>0)c6(pt,a+b-1);break;}case
I6:{c6(pt,a+(b&(V4-1))+1);break;}case
V9:{int
nup;J_(b<pt->Q0a);nup=pt->p[b]->k5;J_(pc+nup<pt->K2);for(;nup>0;nup--){h6
op1=W_(pt->q1[pc+nup]);J_(op1==P5||op1==c9);}break;}default:break;}}return
pt->q1[L2];}
#undef J_
#undef A5b
#undef c6
int
L7(const
E_*pt){return
n4a(pt,pt->K2,M6);}static
const
char*u7b(E_*p,int
c){c=c-w2;if(c>=0&&r1(&p->k[c]))return
r9(&p->k[c]);else
return"?";}static
const
char*A3a(m0*ci,int
Y_b,const
char**b_){if(X5a(ci)){E_*p=Z0a(ci)->l.p;int
pc=Q8(ci);j_
i;*b_=U4(p,Y_b+1,pc);if(*b_)return"local";i=n4a(p,pc,Y_b);H(pc!=-1);switch(W_(i)){case
H7:{int
g=D7(i);H(r1(&p->k[g]));*b_=r9(&p->k[g]);return"global";}case
c9:{int
a=A3(i);int
b=d2(i);if(b<a)return
A3a(ci,b,b_);break;}case
I_a:{int
k=b3(i);*b_=u7b(p,k);return"field";}case
Q2a:{int
k=b3(i);*b_=u7b(p,k);return"method";}default:break;}}return
NULL;}static
const
char*J6a(m0*ci,const
char**b_){j_
i;if((X5a(ci)&&ci->u.l.h0a>0)||!X5a(ci-1))return
NULL;ci--;i=Z0a(ci)->l.p->q1[Q8(ci)];if(W_(i)==I4||W_(i)==c5)return
A3a(ci,A3(i),b_);else
return
NULL;}static
int
C4b(m0*ci,const
E*o){t_
p;for(p=ci->k_;p<ci->X;p++)if(o==p)return
1;return
0;}void
j5(a*L,const
E*o,const
char*op){const
char*b_=NULL;const
char*t=g6[V0(o)];const
char*o3b=(C4b(L->ci,o))?A3a(L->ci,o-L->k_,&b_):NULL;if(o3b)q_(L,"attempt to %s %s `%s' (a %s value)",op,o3b,b_,t);else
q_(L,"attempt to %s a %s value",op,t);}void
t1a(a*L,t_
p1,t_
p2){if(r1(p1))p1=p2;H(!r1(p1));j5(L,p1,"concatenate");}void
n9(a*L,const
E*p1,const
E*p2){E
g7;if(P6(p1,&g7)==NULL)p2=p1;j5(L,p2,"perform arithmetic on");}int
G5(a*L,const
E*p1,const
E*p2){const
char*t1=g6[V0(p1)];const
char*t2=g6[V0(p2)];if(t1[2]==t2[2])q_(L,"attempt to compare two %s values",t1);else
q_(L,"attempt to compare %s with %s",t1,t2);return
0;}static
void
O8b(a*L,const
char*W6){m0*ci=L->ci;if(X5a(ci)){char
p_[i9];int
X_=A2(ci);G7(p_,I5(F2a(ci)->n0),i9);V2(L,"%s:%d: %s",p_,X_,W6);}}void
v0a(a*L){if(L->p4!=0){t_
p4=a3(L,L->p4);if(!a2(p4))K5(L,L0a);i1(L->X,L->X-1);i1(L->X-1,p4);W3(L);A5(L,L->X-2,1);}K5(L,v3a);}void
q_(a*L,const
char*S6,...){va_list
a5;va_start(a5,S6);O8b(L,T4(L,S6,a5));va_end(a5);v0a(L);}
#define J0c
struct
L_a{struct
L_a*Z_;jmp_buf
b;volatile
int
T;};static
void
E2a(a*L,int
a6a,t_
q8){switch(a6a){case
H3a:{G3(q8,T5(L,F9a));break;}case
L0a:{G3(q8,T5(L,"error in error handling"));break;}case
E0a:case
v3a:{i1(q8,L->X-1);break;}}L->X=q8+1;}void
K5(a*L,int
a6a){if(L->N8){L->N8->T=a6a;longjmp(L->N8->b,1);}else{G(L)->l_b(L);exit(EXIT_FAILURE);}}int
g3(a*L,y_b
f,void*ud){struct
L_a
lj;lj.T=0;lj.Z_=L->N8;L->N8=&lj;if(setjmp(lj.b)==0)(*f)(L,ud);L->N8=lj.Z_;return
lj.T;}static
void
d_a(a*L){L->x5=L->l_+L->H2-1;if(L->X3>t6){int
j_c=(L->ci-L->O0);if(j_c+1<t6)g5(L,t6);}}static
void
z0b(a*L,E*m_a){m0*ci;u_*up;L->X=(L->X-m_a)+L->l_;for(up=L->w6;up!=NULL;up=up->E3.h_)v8a(up)->v=(v8a(up)->v-m_a)+L->l_;for(ci=L->O0;ci<=L->ci;ci++){ci->X=(ci->X-m_a)+L->l_;ci->k_=(ci->k_-m_a)+L->l_;}L->k_=L->ci->k_;}void
Y3(a*L,int
T1){E*m_a=L->l_;H0(L,L->l_,L->H2,T1,E);L->H2=T1;L->x5=L->l_+T1-1-d7;z0b(L,m_a);}void
g5(a*L,int
T1){m0*v_c=L->O0;H0(L,L->O0,L->X3,T1,m0);L->X3=g_(unsigned
short,T1);L->ci=(L->ci-v_c)+L->O0;L->S7a=L->O0+L->X3;}void
p3a(a*L,int
n){if(n<=L->H2)Y3(L,2*L->H2);else
Y3(L,L->H2+n+d7);}static
void
j1b(a*L){if(L->X3>t6)K5(L,L0a);else{g5(L,2*L->X3);if(L->X3>t6)q_(L,"stack overflow");}}void
N4(a*L,int
S2,int
X_){F8
D6=L->D6;if(D6&&L->f4){ptrdiff_t
X=A4(L,L->X);ptrdiff_t
A9b=A4(L,L->ci->X);D0
ar;ar.S2=S2;ar.A2=X_;if(S2==s2a)ar.s5a=0;else
ar.s5a=L->ci-L->O0;N2(L,N3);L->ci->X=L->X+N3;L->f4=0;f_(L);(*D6)(L,&ar);n_(L);H(!L->f4);L->f4=1;L->ci->X=a3(L,A9b);L->X=a3(L,X);}}static
void
T8a(a*L,int
b4a,t_
k_){int
i;p0*L3b;E
r7b;int
L5=L->X-k_;if(L5<b4a){N2(L,b4a-L5);for(;L5<b4a;++L5)S_(L->X++);}L5-=b4a;L3b=E7(L,L5,1);for(i=0;i<L5;i++)B3a(r8(L,L3b,i+1),L->X-L5+i);z2a(&r7b,k2a(L,"n"));N1(s_a(L,L3b,&r7b),g_(U,L5));L->X-=L5;z6(L->X,L3b);W3(L);}static
t_
e4b(a*L,t_
a0){const
E*tm=n3(L,a0,Z7b);t_
p;ptrdiff_t
t_b=A4(L,a0);if(!a2(tm))j5(L,a0,"call");for(p=L->X;p>a0;p--)i1(p,p-1);W3(L);a0=a3(L,t_b);l0(a0,tm);return
a0;}t_
q7(a*L,t_
a0){P1a*cl;ptrdiff_t
t_b=A4(L,a0);if(!a2(a0))a0=e4b(L,a0);if(L->ci+1==L->S7a)j1b(L);else
x4(g5(L,L->X3));cl=&D2(a0)->l;if(!cl->isC){m0*ci;E_*p=cl->p;if(p->T8)T8a(L,p->l7,a0+1);N2(L,p->c2);ci=++L->ci;L->k_=L->ci->k_=a3(L,t_b)+1;ci->X=L->k_+p->c2;ci->u.l.n2=p->q1;ci->u.l.h0a=0;ci->h0=f3;while(L->X<ci->X)S_(L->X++);L->X=ci->X;return
NULL;}else{m0*ci;int
n;N2(L,N3);ci=++L->ci;L->k_=L->ci->k_=a3(L,t_b)+1;ci->X=L->X+N3;ci->h0=Y1a;if(L->J6&y7)N4(L,L1a,-1);f_(L);
#ifdef T3b
H8(L);
#endif
n=(*D2(L->k_-1)->c.f)(L);n_(L);return
L->X-n;}}static
t_
J0b(a*L,t_
E0){ptrdiff_t
fr=A4(L,E0);N4(L,v6a,-1);if(!(L->ci->h0&Y1a)){while(L->ci->u.l.h0a--)N4(L,s2a,-1);}return
a3(L,fr);}void
i6(a*L,int
w7a,t_
E0){t_
i0;if(L->J6&P_a)E0=J0b(L,E0);i0=L->k_-1;L->ci--;L->k_=L->ci->k_;while(w7a!=0&&E0<L->X){i1(i0++,E0++);w7a--;}while(w7a-->0)S_(i0++);L->X=i0;}void
A5(a*L,t_
a0,int
c0b){t_
E0;H(!(L->ci->h0&P9));if(++L->k6>=O6){if(L->k6==O6)q_(L,"C stack overflow");else
if(L->k6>=(O6+(O6>>3)))K5(L,L0a);}E0=q7(L,a0);if(E0==NULL)E0=v6(L);i6(L,c0b,E0);L->k6--;B1(L);}static
void
Y3b(a*L,void*ud){t_
E0;int
Z4=*g_(int*,ud);m0*ci=L->ci;if(ci==L->O0){H(Z4<L->X-L->k_);q7(L,L->X-(Z4+1));}else{H(ci->h0&D8);if(ci->h0&Y1a){int
A0;H((ci-1)->h0&f3);H(W_(*((ci-1)->u.l.n2-1))==I4||W_(*((ci-1)->u.l.n2-1))==c5);A0=b3(*((ci-1)->u.l.n2-1))-1;i6(L,A0,L->X-Z4);if(A0>=0)L->X=L->ci->X;}else{ci->h0&=~D8;}}E0=v6(L);if(E0!=NULL)i6(L,B2,E0);}static
int
Q4a(a*L,const
char*W6){L->X=L->ci->k_;G3(L->X,T5(L,W6));W3(L);f_(L);return
v3a;}K
int
z3a(a*L,int
Z4){int
T;T_
V7;n_(L);if(L->ci==L->O0){if(Z4>=L->X-L->k_)return
Q4a(L,"cannot resume dead coroutine");}else
if(!(L->ci->h0&D8))return
Q4a(L,"cannot resume non-suspended coroutine");V7=L->f4;H(L->p4==0&&L->k6==0);T=g3(L,Y3b,&Z4);if(T!=0){L->ci=L->O0;L->k_=L->ci->k_;L->k6=0;Y4(L,L->k_);E2a(L,T,L->k_);L->f4=V7;d_a(L);}f_(L);return
T;}K
int
O4a(a*L,int
A0){m0*ci;n_(L);ci=L->ci;if(L->k6>0)q_(L,"attempt to yield across metamethod/C-call boundary");if(ci->h0&Y1a){if((ci-1)->h0&Y1a)q_(L,"cannot yield a C function");if(L->X-A0>L->k_){int
i;for(i=0;i<A0;i++)i1(L->k_+i,L->X-A0+i);L->X=L->k_+A0;}}ci->h0|=D8;f_(L);return-1;}int
Q3a(a*L,y_b
a0,void*u,ptrdiff_t
A8b,ptrdiff_t
ef){int
T;unsigned
short
Q2b=L->k6;ptrdiff_t
r9b=K9b(L,L->ci);T_
V7=L->f4;ptrdiff_t
i1b=L->p4;L->p4=ef;T=g3(L,a0,u);if(T!=0){t_
q8=a3(L,A8b);Y4(L,q8);E2a(L,T,q8);L->k6=Q2b;L->ci=B4b(L,r9b);L->k_=L->ci->k_;L->f4=V7;d_a(L);}L->p4=i1b;return
T;}struct
u8a{h9*z;m6
p_;int
bin;};static
void
A0b(a*L,void*ud){struct
u8a*p;E_*tf;C2*cl;B1(L);p=g_(struct
u8a*,ud);tf=p->bin?r6a(L,p->z,&p->p_):w6a(L,p->z,&p->p_);cl=M8(L,0,gt(L));cl->l.p=tf;J0a(L->X,cl);W3(L);}int
l9(a*L,h9*z,int
bin){struct
u8a
p;int
T;ptrdiff_t
P8b=A4(L,L->X);p.z=z;p.bin=bin;w2a(L,&p.p_);T=g3(L,A0b,&p);p2a(L,&p.p_);if(T!=0){t_
q8=a3(L,P8b);E2a(L,T,q8);}return
T;}
#define A0c
#define n8a(b,n,W,D) A7(b,(n)*(W),D)
#define q1b(s,D) A7(""s,(sizeof(s))-1,D)
typedef
struct{a*L;D5
H6;void*e3;}U2;static
void
A7(const
void*b,size_t
W,U2*D){f_(D->L);(*D->H6)(D->L,b,W,D->e3);n_(D->L);}static
void
z3(int
y,U2*D){char
x=(char)y;A7(&x,sizeof(x),D);}static
void
O7(int
x,U2*D){A7(&x,sizeof(x),D);}static
void
b0b(size_t
x,U2*D){A7(&x,sizeof(x),D);}static
void
L7a(U
x,U2*D){A7(&x,sizeof(x),D);}static
void
T0a(A_*s,U2*D){if(s==NULL||I5(s)==NULL)b0b(0,D);else{size_t
W=s->x6.G1+1;b0b(W,D);A7(I5(s),W,D);}}static
void
W5b(const
E_*f,U2*D){O7(f->K2,D);n8a(f->q1,f->K2,sizeof(*f->q1),D);}static
void
p3b(const
E_*f,U2*D){int
i,n=f->r4;O7(n,D);for(i=0;i<n;i++){T0a(f->s3[i].O2,D);O7(f->s3[i].V2a,D);O7(f->s3[i].o_b,D);}}static
void
l5b(const
E_*f,U2*D){O7(f->t3,D);n8a(f->n4,f->t3,sizeof(*f->n4),D);}static
void
S_b(const
E_*f,U2*D){int
i,n=f->K3;O7(n,D);for(i=0;i<n;i++)T0a(f->k0[i],D);}static
void
a2a(const
E_*f,const
A_*p,U2*D);static
void
K9a(const
E_*f,U2*D){int
i,n;O7(n=f->j9,D);for(i=0;i<n;i++){const
E*o=&f->k[i];z3(V0(o),D);switch(V0(o)){case
P1:L7a(s0(o),D);break;case
u1:T0a(q2(o),D);break;case
W5:break;default:H(0);break;}}O7(n=f->Q0a,D);for(i=0;i<n;i++)a2a(f->p[i],f->n0,D);}static
void
a2a(const
E_*f,const
A_*p,U2*D){T0a((f->n0==p)?NULL:f->n0,D);O7(f->i8,D);z3(f->k5,D);z3(f->l7,D);z3(f->T8,D);z3(f->c2,D);l5b(f,D);p3b(f,D);S_b(f,D);K9a(f,D);W5b(f,D);}static
void
N3b(U2*D){q1b(u8,D);z3(S8a,D);z3(b_a(),D);z3(sizeof(int),D);z3(sizeof(size_t),D);z3(sizeof(j_),D);z3(e3a,D);z3(C5a,D);z3(e0a,D);z3(X_a,D);z3(sizeof(U),D);L7a(q6a,D);}void
H9a(a*L,const
E_*O6b,D5
w,void*e3){U2
D;D.L=L;D.H6=w;D.e3=e3;N3b(&D);a2a(O6b,NULL,&D);}
#define C0c
#define I4a(n) (g_(int,sizeof(f7a))+g_(int,sizeof(E)*((n)-1)))
#define L5a(n) (g_(int,sizeof(P1a))+g_(int,sizeof(E*)*((n)-1)))
C2*I8(a*L,int
W9){C2*c=g_(C2*,Z5(L,I4a(W9)));n7(L,Q4(c),e0);c->c.isC=1;c->c.h4=g_(T_,W9);return
c;}C2*M8(a*L,int
W9,E*e){C2*c=g_(C2*,Z5(L,L5a(W9)));n7(L,Q4(c),e0);c->l.isC=0;c->l.g=*e;c->l.h4=g_(T_,W9);return
c;}Q_a*W2a(a*L,t_
z_){u_**pp=&L->w6;Q_a*p;Q_a*v;while((p=G_b(*pp))!=NULL&&p->v>=z_){if(p->v==z_)return
p;pp=&p->h_;}v=K3a(L,Q_a);v->tt=z9;v->Y2=1;v->v=z_;v->h_=*pp;*pp=Q4(v);return
v;}void
Y4(a*L,t_
z_){Q_a*p;while((p=G_b(L->w6))!=NULL&&p->v>=z_){O9(&p->m_,p->v);p->v=&p->m_;L->w6=p->h_;n7(L,Q4(p),z9);}}E_*u0a(a*L){E_*f=K3a(L,E_);n7(L,Q4(f),E9);f->k=NULL;f->j9=0;f->p=NULL;f->Q0a=0;f->q1=NULL;f->K2=0;f->t3=0;f->K3=0;f->k5=0;f->k0=NULL;f->l7=0;f->T8=0;f->c2=0;f->n4=NULL;f->r4=0;f->s3=NULL;f->i8=0;f->n0=NULL;return
f;}void
U2a(a*L,E_*f){x1(L,f->q1,f->K2,j_);x1(L,f->p,f->Q0a,E_*);x1(L,f->k,f->j9,E);x1(L,f->n4,f->t3,int);x1(L,f->s3,f->r4,struct
d3a);x1(L,f->k0,f->K3,A_*);s9(L,f);}void
U1a(a*L,C2*c){int
W=(c->c.isC)?I4a(c->c.h4):L5a(c->l.h4);f2a(L,c,W);}const
char*U4(const
E_*f,int
q1a,int
pc){int
i;for(i=0;i<f->r4&&f->s3[i].V2a<=pc;i++){if(pc<f->s3[i].o_b){q1a--;if(q1a==0)return
I5(f->s3[i].O2);}}return
NULL;}
#define N0c
typedef
struct
X6{u_*W4;u_*wk;u_*wv;u_*wkv;v4*g;}X6;
#define u5b(x,b) ((x)|=(1<<(b)))
#define P0b(x,b) ((x)&=g_(T_,~(1<<(b))))
#define k2b(x,b) ((x)&(1<<(b)))
#define Q_b(x) P0b((x)->E3.Y2,0)
#define D1a(x) ((x)->E3.Y2&((1<<4)|1))
#define C9(s) u5b((s)->x6.Y2,0)
#define V1b(u) (!k2b((u)->uv.Y2,1))
#define l4a(u) P0b((u)->uv.Y2,1)
#define B7a 1
#define F4a 2
#define m2b (1<<B7a)
#define I9a (1<<F4a)
#define E6(st,o) {J8(o);if(P4(o)&&!D1a(P7(o)))L6(st,P7(o));}
#define T2a(st,o,c) {J8(o);if(P4(o)&&!D1a(P7(o))&&(c))L6(st,P7(o));}
#define W8(st,t) {if(!D1a(Q4(t)))L6(st,Q4(t));}
static
void
L6(X6*st,u_*o){H(!D1a(o));u5b(o->E3.Y2,0);switch(o->E3.tt){case
f1:{W8(st,k1a(o)->uv.r_);break;}case
e0:{G8a(o)->c.n5=st->W4;st->W4=o;break;}case
H_:{M4a(o)->n5=st->W4;st->W4=o;break;}case
c3:{Z2a(o)->n5=st->W4;st->W4=o;break;}case
E9:{K0b(o)->n5=st->W4;st->W4=o;break;}default:H(o->E3.tt==u1);}}static
void
B8b(X6*st){u_*u;for(u=st->g->r6;u;u=u->E3.h_){Q_b(u);L6(st,u);}}size_t
v7(a*L){size_t
Z7=0;u_**p=&G(L)->A6;u_*b6;u_*e4=NULL;u_**y0a=&e4;while((b6=*p)!=NULL){H(b6->E3.tt==f1);if(D1a(b6)||V1b(k1a(b6)))p=&b6->E3.h_;else
if(m3a(L,k1a(b6)->uv.r_,l7b)==NULL){l4a(k1a(b6));p=&b6->E3.h_;}else{Z7+=E5a(k1a(b6)->uv.G1);*p=b6->E3.h_;b6->E3.h_=NULL;*y0a=b6;y0a=&b6->E3.h_;}}*y0a=G(L)->r6;G(L)->r6=e4;return
Z7;}static
void
d9a(M3*n){S_(D4(n));if(P4(l4(n)))a7b(l4(n),k0a);}static
void
g_b(X6*st,p0*h){int
i;int
g1a=0;int
e9=0;const
E*v0;W8(st,h->r_);H(h->Z8||h->h3==st->g->d4);v0=f2b(st->g,h->r_,H7b);if(v0&&r1(v0)){g1a=(strchr(r9(v0),'k')!=NULL);e9=(strchr(r9(v0),'v')!=NULL);if(g1a||e9){u_**e7a;h->Y2&=~(m2b|I9a);h->Y2|=g_(T_,(g1a<<B7a)|(e9<<F4a));e7a=(g1a&&e9)?&st->wkv:(g1a)?&st->wk:&st->wv;h->n5=*e7a;*e7a=Q4(h);}}if(!e9){i=h->O1;while(i--)E6(st,&h->w0[i]);}i=q5(h);while(i--){M3*n=r5(h,i);if(!I0(D4(n))){H(!I0(l4(n)));T2a(st,l4(n),!g1a);T2a(st,D4(n),!e9);}}}static
void
d_b(X6*st,E_*f){int
i;C9(f->n0);for(i=0;i<f->j9;i++){if(r1(f->k+i))C9(q2(f->k+i));}for(i=0;i<f->K3;i++)C9(f->k0[i]);for(i=0;i<f->Q0a;i++)W8(st,f->p[i]);for(i=0;i<f->r4;i++)C9(f->s3[i].O2);H(L7(f));}static
void
V7a(X6*st,C2*cl){if(cl->c.isC){int
i;for(i=0;i<cl->c.h4;i++)E6(st,&cl->c.J4[i]);}else{int
i;H(cl->l.h4==cl->l.p->k5);W8(st,m1(&cl->l.g));W8(st,cl->l.p);for(i=0;i<cl->l.h4;i++){Q_a*u=cl->l.d2a[i];if(!u->Y2){E6(st,&u->m_);u->Y2=1;}}}}static
void
M7a(a*L,t_
max){int
u9=L->ci-L->O0;if(4*u9<L->X3&&2*w0a<L->X3)g5(L,L->X3/2);else
x4(g5(L,L->X3));u9=max-L->l_;if(4*u9<L->H2&&2*(E8+d7)<L->H2)Y3(L,L->H2/2);else
x4(Y3(L,L->H2));}static
void
t4a(X6*st,a*L1){t_
o,lim;m0*ci;E6(st,gt(L1));lim=L1->X;for(ci=L1->O0;ci<=L1->ci;ci++){H(ci->X<=L1->x5);H(ci->h0&(Y1a|c7|f3));if(lim<ci->X)lim=ci->X;}for(o=L1->l_;o<L1->X;o++)E6(st,o);for(;o<=lim;o++)S_(o);M7a(L1,lim);}static
void
g_a(X6*st){while(st->W4){switch(st->W4->E3.tt){case
H_:{p0*h=M4a(st->W4);st->W4=h->n5;g_b(st,h);break;}case
e0:{C2*cl=G8a(st->W4);st->W4=cl->c.n5;V7a(st,cl);break;}case
c3:{a*th=Z2a(st->W4);st->W4=th->n5;t4a(st,th);break;}case
E9:{E_*p=K0b(st->W4);st->W4=p->n5;d_b(st,p);break;}default:H(0);}}}static
int
L2a(const
E*o){if(r1(o))C9(q2(o));return!P4(o)||k2b(o->m_.gc->E3.Y2,0);}static
void
e_a(u_*l){while(l){p0*h=M4a(l);int
i=q5(h);H(h->Y2&m2b);while(i--){M3*n=r5(h,i);if(!L2a(l4(n)))d9a(n);}l=h->n5;}}static
void
G6(u_*l){while(l){p0*h=M4a(l);int
i=h->O1;H(h->Y2&I9a);while(i--){E*o=&h->w0[i];if(!L2a(o))S_(o);}i=q5(h);while(i--){M3*n=r5(h,i);if(!L2a(D4(n)))d9a(n);}l=h->n5;}}static
void
g8b(a*L,u_*o){switch(o->E3.tt){case
E9:U2a(L,K0b(o));break;case
e0:U1a(L,G8a(o));break;case
z9:s9(L,v8a(o));break;case
H_:J9a(L,M4a(o));break;case
c3:{H(Z2a(o)!=L&&Z2a(o)!=G(L)->w9);A2a(L,Z2a(o));break;}case
u1:{f2a(L,o,v7a(d6a(o)->x6.G1));break;}case
f1:{f2a(L,o,E5a(k1a(o)->uv.G1));break;}default:H(0);}}static
int
h5a(a*L,u_**p,int
Q2){u_*b6;int
z1=0;while((b6=*p)!=NULL){if(b6->E3.Y2>Q2){Q_b(b6);p=&b6->E3.h_;}else{z1++;*p=b6->E3.h_;g8b(L,b6);}}return
z1;}static
void
N_b(a*L,int
M2){int
i;for(i=0;i<G(L)->f7.W;i++){G(L)->f7.N6a-=h5a(L,&G(L)->f7.i2[i],M2);}}static
void
f3b(a*L,size_t
Z7){if(G(L)->f7.N6a<g_(I8a,G(L)->f7.W/4)&&G(L)->f7.W>t0a*2)H_a(L,G(L)->f7.W/2);if(L9(&G(L)->p_)>y8*2){size_t
T1=L9(&G(L)->p_)/2;I0a(L,&G(L)->p_,T1);}G(L)->O5=2*G(L)->b7-Z7;}static
void
X7b(a*L,C_a*E4){const
E*tm=m3a(L,E4->uv.r_,l7b);if(tm!=NULL){l0(L->X,tm);b5a(L->X+1,E4);L->X+=2;A5(L,L->X-2,0);}}void
s0a(a*L){T_
D_c=L->f4;L->f4=0;L->X++;while(G(L)->r6!=NULL){u_*o=G(L)->r6;C_a*E4=k1a(o);G(L)->r6=E4->uv.h_;E4->uv.h_=G(L)->A6;G(L)->A6=o;b5a(L->X-1,E4);Q_b(o);l4a(E4);X7b(L,E4);}L->X--;L->f4=D_c;}void
S3a(a*L,int
M2){if(M2)M2=256;h5a(L,&G(L)->A6,M2);N_b(L,M2);h5a(L,&G(L)->g5a,M2);}static
void
s6b(X6*st,a*L){v4*g=st->g;E6(st,F3(L));E6(st,a6(L));t4a(st,g->w9);if(L!=g->w9)W8(st,L);}static
size_t
B7(a*L){size_t
Z7;X6
st;u_*wkv;st.g=G(L);st.W4=NULL;st.wkv=st.wk=st.wv=NULL;s6b(&st,L);g_a(&st);G6(st.wkv);G6(st.wv);wkv=st.wkv;st.wkv=NULL;st.wv=NULL;Z7=v7(L);B8b(&st);g_a(&st);e_a(wkv);e_a(st.wk);G6(st.wv);e_a(st.wkv);G6(st.wkv);return
Z7;}void
c_a(a*L){size_t
Z7=B7(L);S3a(L,0);f3b(L,Z7);s0a(L);}void
n7(a*L,u_*o,T_
tt){o->E3.h_=G(L)->g5a;G(L)->g5a=o;o->E3.Y2=0;o->E3.tt=tt;}
#define p0c
#ifndef G2a
#ifdef __GNUC__
#define G2a 0
#else
#define G2a 1
#endif
#endif
#ifndef Z_a
#ifdef _POSIX_C_SOURCE
#if _POSIX_C_SOURCE>=2
#define Z_a 1
#endif
#endif
#endif
#ifndef Z_a
#define Z_a 0
#endif
#if!Z_a
#define pclose(f) (-1)
#endif
#define K9 "FILE*"
#define V3a "_input"
#define c0a "_output"
static
int
s4(a*L,int
i,const
char*Q_){if(i){o0(L,1);return
1;}else{w_(L);if(Q_)P_(L,"%s: %s",Q_,strerror(errno));else
P_(L,"%s",strerror(errno));N(L,errno);return
3;}}static
FILE**L8a(a*L,int
O7a){FILE**f=(FILE**)y9(L,O7a,K9);if(f==NULL)g1(L,O7a,"bad file");return
f;}static
int
T7b(a*L){FILE**f=(FILE**)y9(L,1,K9);if(f==NULL)w_(L);else
if(*f==NULL)e_(L,"closed file");else
e_(L,"file");return
1;}static
FILE*g0a(a*L,int
O7a){FILE**f=L8a(L,O7a);if(*f==NULL)s_(L,"attempt to use a closed file");return*f;}static
FILE**f1a(a*L){FILE**pf=(FILE**)E5(L,sizeof(FILE*));*pf=NULL;H0a(L,K9);Z2(L,-2);return
pf;}static
void
u1a(a*L,FILE*f,const
char*b_,const
char*w8a){I(L,b_);*f1a(L)=f;if(w8a){I(L,w8a);Y(L,-2);Q0(L,-6);}Q0(L,-3);}static
int
B5a(a*L){FILE*f=g0a(L,1);if(f==stdin||f==stdout||f==stderr)return
0;else{int
ok=(pclose(f)!=-1)||(fclose(f)==0);if(ok)*(FILE**)b2(L,1)=NULL;return
ok;}}static
int
T_b(a*L){if(i3(L,1)&&f2(L,O_(1))==H_){I(L,c0a);z0(L,O_(1));}return
s4(L,B5a(L),NULL);}static
int
A_c(a*L){FILE**f=L8a(L,1);if(*f!=NULL)B5a(L);return
0;}static
int
K1b(a*L){char
p_[128];FILE**f=L8a(L,1);if(*f==NULL)strcpy(p_,"closed");else
sprintf(p_,"%p",b2(L,1));P_(L,"file (%s)",p_);return
1;}static
int
G8b(a*L){const
char*Q_=Q(L,1);const
char*v0=K0(L,2,"r");FILE**pf=f1a(L);*pf=fopen(Q_,v0);return(*pf==NULL)?s4(L,0,Q_):1;}static
int
t6b(a*L){
#if!Z_a
s_(L,"`popen' not supported");return
0;
#else
const
char*Q_=Q(L,1);const
char*v0=K0(L,2,"r");FILE**pf=f1a(L);*pf=popen(Q_,v0);return(*pf==NULL)?s4(L,0,Q_):1;
#endif
}static
int
n3b(a*L){FILE**pf=f1a(L);*pf=tmpfile();return(*pf==NULL)?s4(L,0,NULL):1;}static
FILE*H4a(a*L,const
char*b_){I(L,b_);z0(L,O_(1));return
g0a(L,-1);}static
int
h0b(a*L,const
char*b_,const
char*v0){if(!M1(L,1)){const
char*Q_=o_(L,1);I(L,b_);if(Q_){FILE**pf=f1a(L);*pf=fopen(Q_,v0);if(*pf==NULL){P_(L,"%s: %s",Q_,strerror(errno));g1(L,1,o_(L,-1));}}else{g0a(L,1);Y(L,1);}G0(L,O_(1));}I(L,b_);z0(L,O_(1));return
1;}static
int
F6b(a*L){return
h0b(L,V3a,"r");}static
int
n5b(a*L){return
h0b(L,c0a,"w");}static
int
y6a(a*L);static
void
A9a(a*L,int
F_,int
close){e_(L,K9);z0(L,L_);Y(L,F_);o0(L,close);A1(L,y6a,3);}static
int
w2b(a*L){g0a(L,1);A9a(L,1,0);return
1;}static
int
V5b(a*L){if(M1(L,1)){I(L,V3a);z0(L,O_(1));return
w2b(L);}else{const
char*Q_=Q(L,1);FILE**pf=f1a(L);*pf=fopen(Q_,"r");f0(L,*pf,1,strerror(errno));A9a(L,D_(L),1);return
1;}}static
int
h1b(a*L,FILE*f){U
d;if(fscanf(f,a_a,&d)==1){N(L,d);return
1;}else
return
0;}static
int
U5b(a*L,FILE*f){int
c=getc(f);ungetc(c,f);b1(L,NULL,0);return(c!=EOF);}static
int
a5a(a*L,FILE*f){I_
b;X1(L,&b);for(;;){size_t
l;char*p=k7(&b);if(fgets(p,m3,f)==NULL){Z0(&b);return(S3(L,-1)>0);}l=strlen(p);if(p[l-1]!='\n')n1a(&b,l);else{n1a(&b,l-1);Z0(&b);return
1;}}}static
int
c8a(a*L,FILE*f,size_t
n){size_t
p0b;size_t
nr;I_
b;X1(L,&b);p0b=m3;do{char*p=k7(&b);if(p0b>n)p0b=n;nr=fread(p,sizeof(char),p0b,f);n1a(&b,nr);n-=nr;}while(n>0&&nr==p0b);Z0(&b);return(n==0||S3(L,-1)>0);}static
int
w5b(a*L,FILE*f,int
X0){int
Z4=D_(L)-1;int
K7;int
n;if(Z4==0){K7=a5a(L,f);n=X0+1;}else{F4(L,Z4+N3,"too many arguments");K7=1;for(n=X0;Z4--&&K7;n++){if(f2(L,n)==P1){size_t
l=(size_t)F0(L,n);K7=(l==0)?U5b(L,f):c8a(L,f,l);}else{const
char*p=o_(L,n);f0(L,p&&p[0]=='*',n,"invalid option");switch(p[1]){case'n':K7=h1b(L,f);break;case'l':K7=a5a(L,f);break;case'a':c8a(L,f,~((size_t)0));K7=1;break;case'w':return
s_(L,"obsolete option `*w' to `read'");default:return
g1(L,n,"invalid format");}}}}if(!K7){V_(L,1);w_(L);}return
n-X0;}static
int
r8b(a*L){return
w5b(L,H4a(L,V3a),1);}static
int
u9b(a*L){return
w5b(L,g0a(L,1),2);}static
int
y6a(a*L){FILE*f=*(FILE**)b2(L,O_(2));if(f==NULL)s_(L,"file is already closed");if(a5a(L,f))return
1;else{if(Y1(L,O_(3))){J0(L,0);Y(L,O_(2));B5a(L);}return
0;}}static
int
u2b(a*L,FILE*f,int
b8){int
Z4=D_(L)-1;int
T=1;for(;Z4--;b8++){if(f2(L,b8)==P1){T=T&&fprintf(f,U7,F0(L,b8))>0;}else{size_t
l;const
char*s=y_(L,b8,&l);T=T&&(fwrite(s,sizeof(char),l,f)==l);}}return
s4(L,T,NULL);}static
int
K6b(a*L){return
u2b(L,H4a(L,c0a),1);}static
int
Y7b(a*L){return
u2b(L,g0a(L,1),2);}static
int
C9b(a*L){static
const
int
v0[]={SEEK_SET,SEEK_CUR,SEEK_END};static
const
char*const
j5b[]={"set","cur","end",NULL};FILE*f=g0a(L,1);int
op=i7(K0(L,2,"cur"),j5b);long
b0a=F7(L,3,0);f0(L,op!=-1,2,"invalid mode");op=fseek(f,b0a,v0[op]);if(op)return
s4(L,0,NULL);else{N(L,ftell(f));return
1;}}static
int
u6b(a*L){return
s4(L,fflush(H4a(L,c0a))==0,NULL);}static
int
t8b(a*L){return
s4(L,fflush(g0a(L,1))==0,NULL);}static
const
k3
i_c[]={{"input",F6b},{"output",n5b},{"lines",V5b},{"close",T_b},{"flush",u6b},{"open",G8b},{"popen",t6b},{"read",r8b},{"tmpfile",n3b},{"type",T7b},{"write",K6b},{NULL,NULL}};static
const
k3
f0c[]={{"flush",t8b},{"read",u9b},{"lines",w2b},{"seek",C9b},{"write",Y7b},{"close",T_b},{"__gc",A_c},{"__tostring",K1b},{NULL,NULL}};static
void
P2b(a*L){F0a(L,K9);e_(L,"__index");Y(L,-2);G0(L,-3);y2(L,NULL,f0c,0);}static
int
V2b(a*L){N(L,system(Q(L,1)));return
1;}static
int
L4b(a*L){const
char*Q_=Q(L,1);return
s4(L,remove(Q_)==0,Q_);}static
int
x5b(a*L){const
char*f0b=Q(L,1);const
char*g9b=Q(L,2);return
s4(L,rename(f0b,g9b)==0,f0b);}static
int
v3b(a*L){
#if!G2a
s_(L,"`tmpname' not supported");return
0;
#else
char
p_[r0c];if(tmpnam(p_)!=p_)return
s_(L,"unable to generate a unique filename in `tmpname'");I(L,p_);return
1;
#endif
}static
int
J5b(a*L){I(L,getenv(Q(L,1)));return
1;}static
int
r6b(a*L){N(L,((U)clock())/(U)CLOCKS_PER_SEC);return
1;}static
void
C7(a*L,const
char*x_,int
m_){I(L,x_);N(L,m_);G0(L,-3);}static
void
v0b(a*L,const
char*x_,int
m_){I(L,x_);o0(L,m_);G0(L,-3);}static
int
s0b(a*L,const
char*x_){int
i0;I(L,x_);s6(L,-2);i0=Y1(L,-1);V_(L,1);return
i0;}static
int
v_a(a*L,const
char*x_,int
d){int
i0;I(L,x_);s6(L,-2);if(x2(L,-1))i0=(int)(F0(L,-1));else{if(d==-2)return
s_(L,"field `%s' missing in date table",x_);i0=d;}V_(L,1);return
i0;}static
int
a8b(a*L){const
char*s=K0(L,1,"%c");time_t
t=(time_t)(C3(L,2,-1));struct
tm*stm;if(t==(time_t)(-1))t=time(NULL);if(*s=='!'){stm=gmtime(&t);s++;}else
stm=localtime(&t);if(stm==NULL)w_(L);else
if(strcmp(s,"*t")==0){U0(L);C7(L,"sec",stm->tm_sec);C7(L,"min",stm->tm_min);C7(L,"hour",stm->tm_hour);C7(L,"day",stm->tm_mday);C7(L,"month",stm->tm_mon+1);C7(L,"year",stm->tm_year+1900);C7(L,"wday",stm->tm_wday+1);C7(L,"yday",stm->tm_yday+1);v0b(L,"isdst",stm->tm_isdst);}else{char
b[256];if(strftime(b,sizeof(b),s,stm))I(L,b);else
return
s_(L,"`date' format too long");}return
1;}static
int
w8b(a*L){if(M1(L,1))N(L,time(NULL));else{time_t
t;struct
tm
ts;G_(L,1,H_);J0(L,1);ts.tm_sec=v_a(L,"sec",0);ts.tm_min=v_a(L,"min",0);ts.tm_hour=v_a(L,"hour",12);ts.tm_mday=v_a(L,"day",-2);ts.tm_mon=v_a(L,"month",-2)-1;ts.tm_year=v_a(L,"year",-2)-1900;ts.tm_isdst=s0b(L,"isdst");t=mktime(&ts);if(t==(time_t)(-1))w_(L);else
N(L,t);}return
1;}static
int
P1b(a*L){N(L,difftime((time_t)(d1(L,1)),(time_t)(C3(L,2,0))));return
1;}static
int
f5b(a*L){static
const
int
cat[]={LC_ALL,LC_COLLATE,LC_CTYPE,LC_MONETARY,LC_NUMERIC,LC_TIME};static
const
char*const
Y6b[]={"all","collate","ctype","monetary","numeric","time",NULL};const
char*l=o_(L,1);int
op=i7(K0(L,2,"all"),Y6b);f0(L,l||M1(L,1),1,"string expected");f0(L,op!=-1,2,"invalid option");I(L,setlocale(cat[op],l));return
1;}static
int
b8b(a*L){exit(c1(L,1,EXIT_SUCCESS));return
0;}static
const
k3
W9b[]={{"clock",r6b},{"date",a8b},{"difftime",P1b},{"execute",V2b},{"exit",b8b},{"getenv",J5b},{"remove",L4b},{"rename",x5b},{"setlocale",f5b},{"time",w8b},{"tmpname",v3b},{NULL,NULL}};P
int
O0a(a*L){y2(L,T9a,W9b,0);P2b(L);Y(L,-1);y2(L,M9a,i_c,1);u1a(L,stdin,"stdin",V3a);u1a(L,stdout,"stdout",c0a);u1a(L,stderr,"stderr",NULL);return
1;}
#define I0c
#define h_(LS) (LS->i_=G7b(LS->z))
static
const
char*const
r1a[]={"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","*name","..","...","==",">=","<=","~=","*number","*string","<eof>"};void
h9a(a*L){int
i;for(i=0;i<F0b;i++){A_*ts=T5(L,r1a[i]);U6a(ts);H(strlen(r1a[i])+1<=D4b);ts->x6.B3=g_(T_,i+1);}}
#define I4b 80
void
Q3(c_*O,int
y6,int
Q2,const
char*W6){if(y6>Q2){W6=V2(O->L,"too many %s (limit=%d)",W6,Q2);u0(O,W6);}}void
o_a(c_*O,const
char*s,const
char*U_,int
X_){a*L=O->L;char
p_[I4b];G7(p_,I5(O->n0),I4b);V2(L,"%s:%d: %s near `%s'",p_,X_,s,U_);K5(L,E0a);}static
void
P0a(c_*O,const
char*s,const
char*U_){o_a(O,s,U_,O->u2);}void
u0(c_*O,const
char*W6){const
char*i2a;switch(O->t.U_){case
p_a:i2a=I5(O->t.H1.ts);break;case
B6:case
U8:i2a=U5(O->p_);break;default:i2a=h5(O,O->t.U_);break;}P0a(O,W6,i2a);}const
char*h5(c_*O,int
U_){if(U_<o6){H(U_==(unsigned
char)U_);return
V2(O->L,"%c",U_);}else
return
r1a[U_-o6];}static
void
u5(c_*O,const
char*s,int
U_){if(U_==f8)P0a(O,s,h5(O,U_));else
P0a(O,s,U5(O->p_));}static
void
A8(c_*LS){h_(LS);++LS->u2;Q3(LS,LS->u2,J7,"lines in a chunk");}void
h4a(a*L,c_*LS,h9*z,A_*n0){LS->L=L;LS->b5.U_=f8;LS->z=z;LS->J=NULL;LS->u2=1;LS->X1a=1;LS->n0=n0;h_(LS);if(LS->i_=='#'){do{h_(LS);}while(LS->i_!='\n'&&LS->i_!=EOZ);}}
#define F5b 32
#define r3b 5
#define I3(LS,G1) if(((G1)+r3b)*sizeof(char)>L9((LS)->p_))W7((LS)->L,(LS)->p_,(G1)+F5b)
#define J2(LS,c,l) (U5((LS)->p_)[l++]=g_(char,c))
#define r0(LS,l) (J2(LS,LS->i_,l),h_(LS))
static
size_t
j6b(c_*LS){size_t
l=0;I3(LS,l);do{I3(LS,l);r0(LS,l);}while(isalnum(LS->i_)||LS->i_=='_');J2(LS,'\0',l);return
l-1;}static
void
T4a(c_*LS,int
G_c,c1a*H1){size_t
l=0;I3(LS,l);if(G_c)J2(LS,'.',l);while(isdigit(LS->i_)){I3(LS,l);r0(LS,l);}if(LS->i_=='.'){r0(LS,l);if(LS->i_=='.'){r0(LS,l);J2(LS,'\0',l);u5(LS,"ambiguous syntax (decimal point x string concatenation)",U8);}}while(isdigit(LS->i_)){I3(LS,l);r0(LS,l);}if(LS->i_=='e'||LS->i_=='E'){r0(LS,l);if(LS->i_=='+'||LS->i_=='-')r0(LS,l);while(isdigit(LS->i_)){I3(LS,l);r0(LS,l);}}J2(LS,'\0',l);if(!P3a(U5(LS->p_),&H1->r))u5(LS,"malformed number",U8);}static
void
l1a(c_*LS,c1a*H1){int
X8a=0;size_t
l=0;I3(LS,l);J2(LS,'[',l);r0(LS,l);if(LS->i_=='\n')A8(LS);for(;;){I3(LS,l);switch(LS->i_){case
EOZ:J2(LS,'\0',l);u5(LS,(H1)?"unfinished long string":"unfinished long comment",f8);break;case'[':r0(LS,l);if(LS->i_=='['){X8a++;r0(LS,l);}continue;case']':r0(LS,l);if(LS->i_==']'){if(X8a==0)goto
E8a;X8a--;r0(LS,l);}continue;case'\n':J2(LS,'\n',l);A8(LS);if(!H1)l=0;continue;default:r0(LS,l);}}E8a:r0(LS,l);J2(LS,'\0',l);if(H1)H1->ts=W2(LS->L,U5(LS->p_)+2,l-5);}static
void
N1b(c_*LS,int
del,c1a*H1){size_t
l=0;I3(LS,l);r0(LS,l);while(LS->i_!=del){I3(LS,l);switch(LS->i_){case
EOZ:J2(LS,'\0',l);u5(LS,"unfinished string",f8);break;case'\n':J2(LS,'\0',l);u5(LS,"unfinished string",B6);break;case'\\':h_(LS);switch(LS->i_){case'a':J2(LS,'\a',l);h_(LS);break;case'b':J2(LS,'\b',l);h_(LS);break;case'f':J2(LS,'\f',l);h_(LS);break;case'n':J2(LS,'\n',l);h_(LS);break;case'r':J2(LS,'\r',l);h_(LS);break;case't':J2(LS,'\t',l);h_(LS);break;case'v':J2(LS,'\v',l);h_(LS);break;case'\n':J2(LS,'\n',l);A8(LS);break;case
EOZ:break;default:{if(!isdigit(LS->i_))r0(LS,l);else{int
c=0;int
i=0;do{c=10*c+(LS->i_-'0');h_(LS);}while(++i<3&&isdigit(LS->i_));if(c>UCHAR_MAX){J2(LS,'\0',l);u5(LS,"escape sequence too large",B6);}J2(LS,c,l);}}}break;default:r0(LS,l);}}r0(LS,l);J2(LS,'\0',l);H1->ts=W2(LS->L,U5(LS->p_)+1,l-3);}int
d7a(c_*LS,c1a*H1){for(;;){switch(LS->i_){case'\n':{A8(LS);continue;}case'-':{h_(LS);if(LS->i_!='-')return'-';h_(LS);if(LS->i_=='['&&(h_(LS),LS->i_=='['))l1a(LS,NULL);else
while(LS->i_!='\n'&&LS->i_!=EOZ)h_(LS);continue;}case'[':{h_(LS);if(LS->i_!='[')return'[';else{l1a(LS,H1);return
B6;}}case'=':{h_(LS);if(LS->i_!='=')return'=';else{h_(LS);return
i7b;}}case'<':{h_(LS);if(LS->i_!='=')return'<';else{h_(LS);return
q7b;}}case'>':{h_(LS);if(LS->i_!='=')return'>';else{h_(LS);return
j7b;}}case'~':{h_(LS);if(LS->i_!='=')return'~';else{h_(LS);return
z7b;}}case'"':case'\'':{N1b(LS,LS->i_,H1);return
B6;}case'.':{h_(LS);if(LS->i_=='.'){h_(LS);if(LS->i_=='.'){h_(LS);return
o2b;}else
return
y9a;}else
if(!isdigit(LS->i_))return'.';else{T4a(LS,1,H1);return
U8;}}case
EOZ:{return
f8;}default:{if(isspace(LS->i_)){h_(LS);continue;}else
if(isdigit(LS->i_)){T4a(LS,0,H1);return
U8;}else
if(isalpha(LS->i_)||LS->i_=='_'){size_t
l=j6b(LS);A_*ts=W2(LS->L,U5(LS->p_),l);if(ts->x6.B3>0)return
ts->x6.B3-1+o6;H1->ts=ts;return
p_a;}else{int
c=LS->i_;if(iscntrl(c))P0a(LS,"invalid control char",V2(LS->L,"char(%d)",c));h_(LS);return
c;}}}}}
#undef h_
#define H0c
#ifndef m5a
#define m5a(b,os,s) realloc(b,s)
#endif
#ifndef f4b
#define f4b(b,os) free(b)
#endif
#define G9 4
void*X4a(a*L,void*N_,int*W,int
H7a,int
Q2,const
char*Q0b){void*i4;int
T1=(*W)*2;if(T1<G9)T1=G9;else
if(*W>=Q2/2){if(*W<Q2-G9)T1=Q2;else
q_(L,Q0b);}i4=m5(L,N_,g_(k2,*W)*g_(k2,H7a),g_(k2,T1)*g_(k2,H7a));*W=T1;return
i4;}void*m5(a*L,void*N_,k2
q4,k2
W){H((q4==0)==(N_==NULL));if(W==0){if(N_!=NULL){f4b(N_,q4);N_=NULL;}else
return
NULL;}else
if(W>=i9a)q_(L,"memory allocation error: block too big");else{N_=m5a(N_,q4,W);if(N_==NULL){if(L)K5(L,H3a);else
return
NULL;}}if(L){H(G(L)!=NULL&&G(L)->b7>0);G(L)->b7-=q4;G(L)->b7+=W;}return
N_;}
#undef LOADLIB
#ifdef l3b
#define LOADLIB
#include<dlfcn.h>
static
int
a4(a*L){const
char*B_=Q(L,1);const
char*I1=Q(L,2);void*h8=dlopen(B_,g0c);if(h8!=NULL){q0
f=(q0)dlsym(h8,I1);if(f!=NULL){E1(L,h8);A1(L,f,1);return
1;}}w_(L);I(L,dlerror());I(L,(h8!=NULL)?"init":"open");if(h8!=NULL)dlclose(h8);return
3;}
#endif
#ifndef t8a
#ifdef _WIN32
#define t8a 1
#else
#define t8a 0
#endif
#endif
#if t8a
#define LOADLIB
#include<windows.h>
static
void
C4(a*L){int
k1=d9b();char
c0[128];if(X8b(s8a|N9a,0,k1,0,c0,sizeof(c0),0))I(L,c0);else
P_(L,"system error %d\n",k1);}static
int
a4(a*L){const
char*B_=Q(L,1);const
char*I1=Q(L,2);HINSTANCE
h8=b_c(B_);if(h8!=NULL){q0
f=(q0)Q7b(h8,I1);if(f!=NULL){E1(L,h8);A1(L,f,1);return
1;}}w_(L);C4(L);I(L,(h8!=NULL)?"init":"open");if(h8!=NULL)Y9b(h8);return
3;}
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
static
int
a4(a*L){w_(L);e_(L,LOADLIB);e_(L,"absent");return
3;}
#endif
P
int
r2a(a*L){x0b(L,"loadlib",a4);return
0;}
#define S_c
#ifndef h3a
#define h3a(s,p) strtod((s),(p))
#endif
const
E
E2={W5,{NULL}};int
I2a(unsigned
int
x){int
m=0;while(x>=(1<<3)){x=(x+1)>>1;m++;}return(m<<3)|g_(int,x);}int
l0a(unsigned
int
x){static
const
T_
v_b[255]={0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7};if(x>=0x00010000){if(x>=0x01000000)return
v_b[((x>>24)&0xff)-1]+24;else
return
v_b[((x>>16)&0xff)-1]+16;}else{if(x>=0x00000100)return
v_b[((x>>8)&0xff)-1]+8;else
if(x)return
v_b[(x&0xff)-1];return-1;}}int
y3(const
E*t1,const
E*t2){if(V0(t1)!=V0(t2))return
0;else
switch(V0(t1)){case
W5:return
1;case
P1:return
s0(t1)==s0(t2);case
l5:return
g3a(t1)==g3a(t2);case
K1:return
S2a(t1)==S2a(t2);default:H(P4(t1));return
P7(t1)==P7(t2);}}int
P3a(const
char*s,U*J1){char*q5a;U
i0=h3a(s,&q5a);if(q5a==s)return
0;while(isspace((unsigned
char)(*q5a)))q5a++;if(*q5a!='\0')return
0;*J1=i0;return
1;}static
void
r3a(a*L,const
char*str){G3(L->X,T5(L,str));W3(L);}const
char*T4(a*L,const
char*S6,va_list
a5){int
n=1;r3a(L,"");for(;;){const
char*e=strchr(S6,'%');if(e==NULL)break;G3(L->X,W2(L,S6,e-S6));W3(L);switch(*(e+1)){case's':r3a(L,va_arg(a5,char*));break;case'c':{char
p_[2];p_[0]=g_(char,va_arg(a5,int));p_[1]='\0';r3a(L,p_);break;}case'd':N1(L->X,g_(U,va_arg(a5,int)));W3(L);break;case'f':N1(L->X,g_(U,va_arg(a5,n6a)));W3(L);break;case'%':r3a(L,"%");break;default:H(0);}n+=2;S6=e+2;}r3a(L,S6);F_a(L,n+1,L->X-L->k_-1);L->X-=n;return
r9(L->X-1);}const
char*V2(a*L,const
char*S6,...){const
char*W6;va_list
a5;va_start(a5,S6);W6=T4(L,S6,a5);va_end(a5);return
W6;}void
G7(char*m7,const
char*n0,int
n6){if(*n0=='='){strncpy(m7,n0+1,n6);m7[n6-1]='\0';}else{if(*n0=='@'){int
l;n0++;n6-=sizeof(" `...' ");l=strlen(n0);strcpy(m7,"");if(l>n6){n0+=(l-n6);strcat(m7,"...");}strcat(m7,n0);}else{int
G1=strcspn(n0,"\n");n6-=sizeof(" [string \"...\"] ");if(G1>n6)G1=n6;strcpy(m7,"[string \"");if(n0[G1]!='\0'){strncat(m7,n0,G1);strcat(m7,"...");}else
strcat(m7,n0);strcat(m7,"\"]");}}}
#define F_c
#ifdef L1b
const
char*const
o5a[]={"MOVE","LOADK","LOADBOOL","LOADNIL","GETUPVAL","GETGLOBAL","GETTABLE","SETGLOBAL","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","DIV","POW","UNM","NOT","CONCAT","JMP","EQ","LT","LE","TEST","CALL","TAILCALL","RETURN","FORLOOP","TFORLOOP","TFORPREP","SETLIST","SETLISTO","CLOSE","CLOSURE"};
#endif
#define P0(t,b,bk,ck,sa,k,m) (((t)<<Z5a)|((b)<<J7a)|((bk)<<z9a)|((ck)<<Z8a)|((sa)<<b8a)|((k)<<d2b)|(m))
const
T_
m1a[I6a]={P0(0,1,0,0,1,0,U3),P0(0,0,0,0,1,1,N3a),P0(0,0,0,0,1,0,U3),P0(0,1,0,0,1,0,U3),P0(0,0,0,0,1,0,U3),P0(0,0,0,0,1,1,N3a),P0(0,1,0,1,1,0,U3),P0(0,0,0,0,0,1,N3a),P0(0,0,0,0,0,0,U3),P0(0,0,1,1,0,0,U3),P0(0,0,0,0,1,0,U3),P0(0,1,0,1,1,0,U3),P0(0,0,1,1,1,0,U3),P0(0,0,1,1,1,0,U3),P0(0,0,1,1,1,0,U3),P0(0,0,1,1,1,0,U3),P0(0,0,1,1,1,0,U3),P0(0,1,0,0,1,0,U3),P0(0,1,0,0,1,0,U3),P0(0,1,0,1,1,0,U3),P0(0,0,0,0,0,0,c6a),P0(1,0,1,1,0,0,U3),P0(1,0,1,1,0,0,U3),P0(1,0,1,1,0,0,U3),P0(1,1,0,0,1,0,U3),P0(0,0,0,0,0,0,U3),P0(0,0,0,0,0,0,U3),P0(0,0,0,0,0,0,U3),P0(0,0,0,0,0,0,c6a),P0(1,0,0,0,0,0,U3),P0(0,0,0,0,0,0,c6a),P0(0,0,0,0,0,0,N3a),P0(0,0,0,0,0,0,N3a),P0(0,0,0,0,0,0,U3),P0(0,0,0,0,1,0,N3a)};
#define Y_c
#define v2a(J,i) ((J)->f->s3[(J)->l4b[i]])
#define D7a(O) if(++(O)->q2a>Y_a)u0(O,"too many syntax levels");
#define K7a(O) ((O)->q2a--)
typedef
struct
k4{struct
k4*Z_;int
y2a;int
N0;int
x2a;int
B_a;}k4;static
void
s5(c_*O);static
void
J9(c_*O,d_*v);static
void
h_(c_*O){O->X1a=O->u2;if(O->b5.U_!=f8){O->t=O->b5;O->b5.U_=f8;}else
O->t.U_=d7a(O,&O->t.H1);}static
void
b5(c_*O){H(O->b5.U_==f8);O->b5.U_=d7a(O,&O->b5.H1);}static
void
k3a(c_*O,int
U_){u0(O,V2(O->L,"`%s' expected",h5(O,U_)));}static
int
P3(c_*O,int
c){if(O->t.U_==c){h_(O);return
1;}else
return
0;}static
void
J_(c_*O,int
c){if(!P3(O,c))k3a(O,c);}
#define D9(O,c,W6) {if(!(c))u0(O,W6);}
static
void
u4(c_*O,int
v3,int
who,int
g2a){if(!P3(O,v3)){if(g2a==O->u2)k3a(O,v3);else{u0(O,V2(O->L,"`%s' expected (to close `%s' at line %d)",h5(O,v3),h5(O,who),g2a));}}}static
A_*L4(c_*O){A_*ts;D9(O,(O->t.U_==p_a),"<name> expected");ts=O->t.H1.ts;h_(O);return
ts;}static
void
o4(d_*e,t2b
k,int
i){e->f=e->t=C0;e->k=k;e->C_=i;}static
void
x3a(c_*O,d_*e,A_*s){o4(e,VK,o1a(O->J,s));}static
void
z5a(c_*O,d_*e){x3a(O,e,L4(O));}static
int
f3a(c_*O,A_*O2){M*J=O->J;E_*f=J->f;G4(O->L,f->s3,J->q_a,f->r4,d3a,J7,"");f->s3[J->q_a].O2=O2;return
J->q_a++;}static
void
o5(c_*O,A_*b_,int
n){M*J=O->J;Q3(O,J->N0+n+1,g6a,"local variables");J->l4b[J->N0+n]=f3a(O,b_);}static
void
y5(c_*O,int
r3){M*J=O->J;J->N0+=r3;for(;r3;r3--){v2a(J,J->N0-r3).V2a=J->pc;}}static
void
Z7a(c_*O,int
j8b){M*J=O->J;while(J->N0>j8b)v2a(J,--J->N0).o_b=J->pc;}static
void
M5(c_*O,const
char*b_,int
n){o5(O,T5(O->L,b_),n);}static
void
n5a(c_*O,const
char*b_){M5(O,b_,0);y5(O,1);}static
int
C_b(M*J,A_*b_,d_*v){int
i;E_*f=J->f;for(i=0;i<f->k5;i++){if(J->k0[i].k==v->k&&J->k0[i].C_==v->C_){H(J->f->k0[i]==b_);return
i;}}Q3(J->O,f->k5+1,S_a,"upvalues");G4(J->L,J->f->k0,f->k5,J->f->K3,A_*,J7,"");J->f->k0[f->k5]=b_;J->k0[f->k5]=*v;return
f->k5++;}static
int
k4b(M*J,A_*n){int
i;for(i=J->N0-1;i>=0;i--){if(n==v2a(J,i).O2)return
i;}return-1;}static
void
v5b(M*J,int
z_){k4*bl=J->bl;while(bl&&bl->N0>z_)bl=bl->Z_;if(bl)bl->x2a=1;}static
void
A5a(M*J,A_*n,d_*g9,int
k_){if(J==NULL)o4(g9,Q5a,M6);else{int
v=k4b(J,n);if(v>=0){o4(g9,M1a,v);if(!k_)v5b(J,v);}else{A5a(J->e5a,n,g9,0);if(g9->k==Q5a){if(k_)g9->C_=o1a(J,n);}else{g9->C_=C_b(J,n,g9);g9->k=P7a;}}}}static
A_*D5a(c_*O,d_*g9,int
k_){A_*O2=L4(O);A5a(O->J,O2,g9,k_);return
O2;}static
void
C0a(c_*O,int
r3,int
T9,d_*e){M*J=O->J;int
x3=r3-T9;if(e->k==j2a){x3++;if(x3<=0)x3=0;else
S1(J,x3-1);V1(J,e,x3);}else{if(e->k!=E_a)L0(J,e);if(x3>0){int
g4=J->x0;S1(J,x3);O6a(J,g4,x3);}}}static
void
Q1b(c_*O,int
a9,int
N8a){M*J=O->J;y5(O,a9);Q3(O,J->N0,v5a,"parameters");J->f->l7=g_(T_,J->N0);J->f->T8=g_(T_,N8a);if(N8a)n5a(O,"arg");S1(J,J->N0);}static
void
N9(M*J,k4*bl,int
B_a){bl->y2a=C0;bl->B_a=B_a;bl->N0=J->N0;bl->x2a=0;bl->Z_=J->bl;J->bl=bl;H(J->x0==J->N0);}static
void
p9(M*J){k4*bl=J->bl;J->bl=bl->Z_;Z7a(J->O,bl->N0);if(bl->x2a)K_(J,Y3a,bl->N0,0,0);H(bl->N0==J->N0);J->x0=J->N0;M0(J,bl->y2a);}static
void
z1b(c_*O,M*a0,d_*v){M*J=O->J;E_*f=J->f;int
i;G4(O->L,f->p,J->np,f->Q0a,E_*,W_a,"constant table overflow");f->p[J->np++]=a0->f;o4(v,j3,w3(J,V9,0,J->np-1));for(i=0;i<a0->f->k5;i++){h6
o=(a0->k0[i].k==M1a)?c9:P5;K_(J,o,0,a0->k0[i].C_,0);}}static
void
u9a(c_*O,M*J){E_*f=u0a(O->L);J->f=f;J->e5a=O->J;J->O=O;J->L=O->L;O->J=J;J->pc=0;J->U3a=0;J->jpc=C0;J->x0=0;J->nk=0;J->h=E7(O->L,0,0);J->np=0;J->q_a=0;J->N0=0;J->bl=NULL;f->n0=O->n0;f->c2=2;}static
void
Y7a(c_*O){a*L=O->L;M*J=O->J;E_*f=J->f;Z7a(O,0);K_(J,d5,0,1,0);H0(L,f->q1,f->K2,J->pc,j_);f->K2=J->pc;H0(L,f->n4,f->t3,J->pc,int);f->t3=J->pc;H0(L,f->k,f->j9,J->nk,E);f->j9=J->nk;H0(L,f->p,f->Q0a,J->np,E_*);f->Q0a=J->np;H0(L,f->s3,f->r4,J->q_a,d3a);f->r4=J->q_a;H0(L,f->k0,f->K3,f->k5,A_*);f->K3=f->k5;H(L7(f));H(J->bl==NULL);O->J=J->e5a;}E_*w6a(a*L,h9*z,m6*p_){struct
c_
Y5;struct
M
e2a;Y5.p_=p_;Y5.q2a=0;h4a(L,&Y5,z,T5(L,m7b(z)));u9a(&Y5,&e2a);h_(&Y5);s5(&Y5);D9(&Y5,(Y5.t.U_==f8),"<eof> expected");Y7a(&Y5);H(e2a.e5a==NULL);H(e2a.f->k5==0);H(Y5.q2a==0);return
e2a.f;}static
void
T3a(c_*O,d_*v){M*J=O->J;d_
x_;h2(J,v);h_(O);z5a(O,&x_);F1a(J,v,&x_);}static
void
X7a(c_*O,d_*v){h_(O);J9(O,v);s7(O->J,v);J_(O,']');}struct
m8{d_
v;d_*t;int
nh;int
na;int
b1a;};static
void
w3a(c_*O,struct
m8*cc){M*J=O->J;int
g4=O->J->x0;d_
x_,y6;if(O->t.U_==p_a){Q3(O,cc->nh,J7,"items in a constructor");cc->nh++;z5a(O,&x_);}else
X7a(O,&x_);J_(O,'=');H3(J,&x_);J9(O,&y6);K_(J,O_a,cc->t->C_,H3(J,&x_),H3(J,&y6));J->x0=g4;}static
void
U8a(M*J,struct
m8*cc){if(cc->v.k==E_a)return;L0(J,&cc->v);cc->v.k=E_a;if(cc->b1a==V4){w3(J,I6,cc->t->C_,cc->na-1);cc->b1a=0;J->x0=cc->t->C_+1;}}static
void
b_b(M*J,struct
m8*cc){if(cc->b1a==0)return;if(cc->v.k==j2a){V1(J,&cc->v,B2);w3(J,j8,cc->t->C_,cc->na-1);}else{if(cc->v.k!=E_a)L0(J,&cc->v);w3(J,I6,cc->t->C_,cc->na-1);}J->x0=cc->t->C_+1;}static
void
p5a(c_*O,struct
m8*cc){J9(O,&cc->v);Q3(O,cc->na,W_a,"items in a constructor");cc->na++;cc->b1a++;}static
void
a7(c_*O,d_*t){M*J=O->J;int
X_=O->u2;int
pc=K_(J,H2a,0,0,0);struct
m8
cc;cc.na=cc.nh=cc.b1a=0;cc.t=t;o4(t,j3,pc);o4(&cc.v,E_a,0);L0(O->J,t);J_(O,'{');do{H(cc.v.k==E_a||cc.b1a>0);P3(O,';');if(O->t.U_=='}')break;U8a(J,&cc);switch(O->t.U_){case
p_a:{b5(O);if(O->b5.U_!='=')p5a(O,&cc);else
w3a(O,&cc);break;}case'[':{w3a(O,&cc);break;}default:{p5a(O,&cc);break;}}}while(P3(O,',')||P3(O,';'));u4(O,'}','{',X_);b_b(J,&cc);Z6a(J->f->q1[pc],I2a(cc.na));E_b(J->f->q1[pc],l0a(cc.nh)+1);}static
void
b6a(c_*O){int
a9=0;int
N8a=0;if(O->t.U_!=')'){do{switch(O->t.U_){case
o2b:N8a=1;h_(O);break;case
p_a:o5(O,L4(O),a9++);break;default:u0(O,"<name> or `...' expected");}}while(!N8a&&P3(O,','));}Q1b(O,a9,N8a);}static
void
I3a(c_*O,d_*e,int
G8,int
X_){M
l0b;u9a(O,&l0b);l0b.f->i8=X_;J_(O,'(');if(G8)n5a(O,"self");b6a(O);J_(O,')');s5(O);u4(O,j3a,z_a,X_);Y7a(O);z1b(O,&l0b,e);}static
int
V5(c_*O,d_*v){int
n=1;J9(O,v);while(P3(O,',')){L0(O->J,v);J9(O,v);n++;}return
n;}static
void
F6(c_*O,d_*f){M*J=O->J;d_
K8;int
k_,a9;int
X_=O->u2;switch(O->t.U_){case'(':{if(X_!=O->X1a)u0(O,"ambiguous syntax (function call x new statement)");h_(O);if(O->t.U_==')')K8.k=E_a;else{V5(O,&K8);V1(J,&K8,B2);}u4(O,')','(',X_);break;}case'{':{a7(O,&K8);break;}case
B6:{x3a(O,&K8,O->t.H1.ts);h_(O);break;}default:{u0(O,"function arguments expected");return;}}H(f->k==c4);k_=f->C_;if(K8.k==j2a)a9=B2;else{if(K8.k!=E_a)L0(J,&K8);a9=J->x0-(k_+1);}o4(f,j2a,K_(J,I4,k_,a9+1,2));Z9(J,X_);J->x0=k_+1;}static
void
P4a(c_*O,d_*v){switch(O->t.U_){case'(':{int
X_=O->u2;h_(O);J9(O,v);u4(O,')','(',X_);T0(O->J,v);return;}case
p_a:{D5a(O,v,1);return;}
#ifdef j4b
case'%':{A_*O2;int
X_=O->u2;h_(O);O2=D5a(O,v,1);if(v->k!=P7a)o_a(O,"global upvalues are obsolete",I5(O2),X_);return;}
#endif
default:{u0(O,"unexpected symbol");return;}}}static
void
N7(c_*O,d_*v){M*J=O->J;P4a(O,v);for(;;){switch(O->t.U_){case'.':{T3a(O,v);break;}case'[':{d_
x_;h2(J,v);X7a(O,&x_);F1a(J,v,&x_);break;}case':':{d_
x_;h_(O);z5a(O,&x_);l9a(J,v,&x_);F6(O,v);break;}case'(':case
B6:case'{':{L0(J,v);F6(O,v);break;}default:return;}}}static
void
x9a(c_*O,d_*v){switch(O->t.U_){case
U8:{o4(v,VK,X9(O->J,O->t.H1.r));h_(O);break;}case
B6:{x3a(O,v,O->t.H1.ts);h_(O);break;}case
H9b:{o4(v,z8a,0);h_(O);break;}case
i8b:{o4(v,t2a,0);h_(O);break;}case
S5b:{o4(v,E1a,0);h_(O);break;}case'{':{a7(O,v);break;}case
z_a:{h_(O);I3a(O,v,0,O->u2);break;}default:{N7(O,v);break;}}}static
a8a
d7b(int
op){switch(op){case
p9b:return
K7b;case'-':return
r9a;default:return
D6a;}}static
l8
E5b(int
op){switch(op){case'+':return
e2b;case'-':return
O7b;case'*':return
S6b;case'/':return
n8b;case'^':return
g2b;case
y9a:return
F3a;case
z7b:return
q7a;case
i7b:return
s9b;case'<':return
F9b;case
q7b:return
S9b;case'>':return
c5b;case
j7b:return
P9b;case
Q9b:return
Y8a;case
z_c:return
L_b;default:return
Z4a;}}static
const
struct{T_
A8a;T_
r8a;}C8[]={{6,6},{6,6},{7,7},{7,7},{10,9},{5,4},{3,3},{3,3},{3,3},{3,3},{3,3},{3,3},{2,2},{1,1}};
#define x8a 8
static
l8
d1a(c_*O,d_*v,int
Q2){l8
op;a8a
uop;D7a(O);uop=d7b(O->t.U_);if(uop!=D6a){h_(O);d1a(O,v,x8a);x6a(O->J,uop,v);}else
x9a(O,v);op=E5b(O->t.U_);while(op!=Z4a&&g_(int,C8[op].A8a)>Q2){d_
v2;l8
o5b;h_(O);h8a(O->J,op,v);o5b=d1a(O,&v2,g_(int,C8[op].r8a));l6a(O->J,op,v,&v2);op=o5b;}K7a(O);return
op;}static
void
J9(c_*O,d_*v){d1a(O,v,-1);}static
int
J4a(int
U_){switch(U_){case
l2b:case
q9a:case
j3a:case
W_b:case
f8:return
1;default:return
0;}}static
void
N_(c_*O){M*J=O->J;k4
bl;N9(J,&bl,0);s5(O);H(bl.y2a==C0);p9(J);}struct
v9{struct
v9*e5a;d_
v;};static
void
y8a(c_*O,struct
v9*lh,d_*v){M*J=O->J;int
x3=J->x0;int
p1a=0;for(;lh;lh=lh->e5a){if(lh->v.k==z1a){if(lh->v.C_==v->C_){p1a=1;lh->v.C_=x3;}if(lh->v.B9==v->C_){p1a=1;lh->v.B9=x3;}}}if(p1a){K_(J,c9,J->x0,v->C_,0);S1(J,1);}}static
void
r2(c_*O,struct
v9*lh,int
r3){d_
e;D9(O,M1a<=lh->v.k&&lh->v.k<=z1a,"syntax error");if(P3(O,',')){struct
v9
nv;nv.e5a=lh;N7(O,&nv.v);if(nv.v.k==M1a)y8a(O,lh,&nv.v);r2(O,&nv,r3+1);}else{int
T9;J_(O,'=');T9=V5(O,&e);if(T9!=r3){C0a(O,r3,T9,&e);if(T9>r3)O->J->x0-=T9-r3;}else{V1(O->J,&e,1);Q6(O->J,&lh->v,&e);return;}}o4(&e,c4,O->J->x0-1);Q6(O->J,&lh->v,&e);}static
void
j6(c_*O,d_*v){J9(O,v);if(v->k==z8a)v->k=E1a;z0a(O->J,v);M0(O->J,v->t);}
#ifndef D2a
#define D2a 100
#endif
#define f7b 5
static
void
G4a(c_*O,int
X_){j_
D2b[D2a+f7b];int
W1b;int
i;int
V5a;M*J=O->J;int
D9a,j9a,e1a;d_
v;k4
bl;h_(O);D9a=y4(J);e1a=b4(J);J9(O,&v);if(v.k==VK)v.k=t2a;W1b=O->u2;a8(J,&v);z2(J,&v.f,J->jpc);J->jpc=C0;V5a=J->pc-e1a;if(V5a>D2a)u0(O,"`while' condition too complex");for(i=0;i<V5a;i++)D2b[i]=J->f->q1[e1a+i];J->pc=e1a;N9(J,&bl,1);J_(O,n_b);j9a=b4(J);N_(O);M0(J,D9a);if(v.t!=C0)v.t+=J->pc-e1a;if(v.f!=C0)v.f+=J->pc-e1a;for(i=0;i<V5a;i++)B2a(J,D2b[i],W1b);u4(O,j3a,g7a,X_);p9(J);Q7(J,v.t,j9a);M0(J,v.f);}static
void
G3a(c_*O,int
X_){M*J=O->J;int
G1b=b4(J);d_
v;k4
bl;N9(J,&bl,1);h_(O);N_(O);u4(O,W_b,a9a,X_);j6(O,&v);Q7(J,v.f,G1b);p9(J);}static
int
J3a(c_*O){d_
e;int
k;J9(O,&e);k=e.k;L0(O->J,&e);return
k;}static
void
X1b(c_*O,int
k_,int
X_,int
r3,int
isnum){k4
bl;M*J=O->J;int
a6b,F4b;y5(O,r3);J_(O,n_b);N9(J,&bl,1);a6b=b4(J);N_(O);M0(J,a6b-1);F4b=(isnum)?q0a(J,X0a,k_,C0):K_(J,J_a,k_,0,r3-3);Z9(J,X_);Q7(J,(isnum)?F4b:y4(J),a6b);p9(J);}static
void
X0b(c_*O,A_*O2,int
X_){M*J=O->J;int
k_=J->x0;o5(O,O2,0);M5(O,"(for limit)",1);M5(O,"(for step)",2);J_(O,'=');J3a(O);J_(O,',');J3a(O);if(P3(O,','))J3a(O);else{w3(J,c4a,J->x0,X9(J,1));S1(J,1);}K_(J,t0b,J->x0-3,J->x0-3,J->x0-1);y4(J);X1b(O,k_,X_,3,1);}static
void
H8a(c_*O,A_*y5b){M*J=O->J;d_
e;int
r3=0;int
X_;int
k_=J->x0;M5(O,"(for generator)",r3++);M5(O,"(for state)",r3++);o5(O,y5b,r3++);while(P3(O,','))o5(O,L4(O),r3++);J_(O,D7b);X_=O->u2;C0a(O,r3,V5(O,&e),&e);x9(J,3);q0a(J,M2a,k_,C0);X1b(O,k_,X_,r3,0);}static
void
P8a(c_*O,int
X_){M*J=O->J;A_*O2;k4
bl;N9(J,&bl,0);h_(O);O2=L4(O);switch(O->t.U_){case'=':X0b(O,O2,X_);break;case',':case
D7b:H8a(O,O2);break;default:u0(O,"`=' or `in' expected");}u4(O,j3a,i4b,X_);p9(J);}static
void
I9(c_*O,d_*v){h_(O);j6(O,v);J_(O,U7b);N_(O);}static
void
e0b(c_*O,int
X_){M*J=O->J;d_
v;int
Y0a=C0;I9(O,&v);while(O->t.U_==q9a){z2(J,&Y0a,y4(J));M0(J,v.f);I9(O,&v);}if(O->t.U_==l2b){z2(J,&Y0a,y4(J));M0(J,v.f);h_(O);N_(O);}else
z2(J,&Y0a,v.f);M0(J,Y0a);u4(O,j3a,C7b,X_);}static
void
K4b(c_*O){d_
v,b;M*J=O->J;o5(O,L4(O),0);o4(&v,M1a,J->x0);S1(J,1);y5(O,1);I3a(O,&b,0,O->u2);Q6(J,&v,&b);v2a(J,J->N0-1).V2a=J->pc;}static
void
o9a(c_*O){int
r3=0;int
T9;d_
e;do{o5(O,L4(O),r3++);}while(P3(O,','));if(P3(O,'='))T9=V5(O,&e);else{e.k=E_a;T9=0;}C0a(O,r3,T9,&e);y5(O,r3);}static
int
a7a(c_*O,d_*v){int
G8=0;D5a(O,v,1);while(O->t.U_=='.')T3a(O,v);if(O->t.U_==':'){G8=1;T3a(O,v);}return
G8;}static
void
S6a(c_*O,int
X_){int
G8;d_
v,b;h_(O);G8=a7a(O,&v);I3a(O,&b,G8,X_);Q6(O->J,&v,&b);Z9(O->J,X_);}static
void
h7b(c_*O){M*J=O->J;struct
v9
v;N7(O,&v.v);if(v.v.k==j2a){V1(J,&v.v,0);}else{v.e5a=NULL;r2(O,&v,1);}}static
void
y2b(c_*O){M*J=O->J;d_
e;int
X0,j7a;h_(O);if(J4a(O->t.U_)||O->t.U_==';')X0=j7a=0;else{j7a=V5(O,&e);if(e.k==j2a){V1(J,&e,B2);if(j7a==1){B3b(M7(J,&e),c5);H(A3(M7(J,&e))==J->N0);}X0=J->N0;j7a=B2;}else{if(j7a==1)X0=h2(J,&e);else{L0(J,&e);X0=J->N0;H(j7a==J->x0-X0);}}}K_(J,d5,X0,j7a+1,0);}static
void
B9a(c_*O){M*J=O->J;k4*bl=J->bl;int
x2a=0;h_(O);while(bl&&!bl->B_a){x2a|=bl->x2a;bl=bl->Z_;}if(!bl)u0(O,"no loop to break");if(x2a)K_(J,Y3a,bl->N0,0,0);z2(J,&bl->y2a,y4(J));}static
int
o0a(c_*O){int
X_=O->u2;switch(O->t.U_){case
C7b:{e0b(O,X_);return
0;}case
g7a:{G4a(O,X_);return
0;}case
n_b:{h_(O);N_(O);u4(O,j3a,n_b,X_);return
0;}case
i4b:{P8a(O,X_);return
0;}case
a9a:{G3a(O,X_);return
0;}case
z_a:{S6a(O,X_);return
0;}case
Y5b:{h_(O);if(P3(O,z_a))K4b(O);else
o9a(O);return
0;}case
y4b:{y2b(O);return
1;}case
Q6b:{B9a(O);return
1;}default:{h7b(O);return
0;}}}static
void
s5(c_*O){int
b5b=0;D7a(O);while(!b5b&&!J4a(O->t.U_)){b5b=o0a(O);P3(O,';');H(O->J->x0>=O->J->N0);O->J->x0=O->J->N0;}K7a(O);}
#define Y4b "posix"
#define B5b Y4b" library for "g8" / Nov 2003"
#ifndef c7a
#define c7a 512
#endif
struct
C3a{char
rwx;mode_t
l6;};typedef
struct
C3a
C3a;static
C3a
c3a[]={{'r',S_IRUSR},{'w',S_IWUSR},{'x',S_IXUSR},{'r',S_IRGRP},{'w',S_IWGRP},{'x',S_IXGRP},{'r',S_IROTH},{'w',S_IWOTH},{'x',S_IXOTH},{0,(mode_t)-1}};static
int
O5a(mode_t*v0,const
char*p){int
z1;mode_t
k_a=*v0;k_a&=~(S_ISUID|S_ISGID);for(z1=0;z1<9;z1++){if(*p==c3a[z1].rwx)k_a|=c3a[z1].l6;else
if(*p=='-')k_a&=~c3a[z1].l6;else
if(*p=='s')switch(z1){case
2:k_a|=S_ISUID|S_IXUSR;break;case
5:k_a|=S_ISGID|S_IXGRP;break;default:return-4;break;}p++;}*v0=k_a;return
0;}static
void
D_a(mode_t
v0,char*p){int
z1;char*pp;pp=p;for(z1=0;z1<9;z1++){if(v0&c3a[z1].l6)*p=c3a[z1].rwx;else*p='-';p++;}*p=0;if(v0&S_ISUID)pp[2]=(v0&S_IXUSR)?'s':'S';if(v0&S_ISGID)pp[5]=(v0&S_IXGRP)?'s':'S';}static
int
C7a(mode_t*v0,const
char*p){char
op=0;mode_t
d3,Z6;int
P6a=0;
#ifdef DEBUG
char
tmp[10];
#endif
#ifdef DEBUG
D_a(*v0,tmp);printf("modemuncher: got base mode = %s\n",tmp);
#endif
while(!P6a){d3=0;Z6=0;
#ifdef DEBUG
printf("modemuncher step 1\n");
#endif
if(*p=='r'||*p=='-')return
O5a(v0,p);for(;;p++)switch(*p){case'u':d3|=04700;break;case'g':d3|=02070;break;case'o':d3|=01007;break;case'a':d3|=07777;break;case' ':break;default:goto
M6a;}M6a:if(d3==0)d3=07777;
#ifdef DEBUG
printf("modemuncher step 2 (*p='%c')\n",*p);
#endif
switch(*p){case'+':case'-':case'=':op=*p;break;case' ':break;default:return-1;}
#ifdef DEBUG
printf("modemuncher step 3\n");
#endif
for(p++;*p!=0;p++)switch(*p){case'r':Z6|=00444;break;case'w':Z6|=00222;break;case'x':Z6|=00111;break;case's':Z6|=06000;break;case' ':break;default:goto
K2b;}K2b:
#ifdef DEBUG
printf("modemuncher step 4\n");
#endif
if(*p!=',')P6a=1;if(*p!=0&&*p!=' '&&*p!=','){
#ifdef DEBUG
printf("modemuncher: comma error!\n");printf("modemuncher: doneflag = %u\n",P6a);
#endif
return-2;}p++;if(Z6)switch(op){case'+':*v0=*v0|=Z6&d3;break;case'-':*v0=*v0&=~(Z6&d3);break;case'=':*v0=Z6&d3;break;default:return-3;}}
#ifdef DEBUG
D_a(*v0,tmp);printf("modemuncher: returning mode = %s\n",tmp);
#endif
return
0;}
#ifdef __CYGWIN__
#define _SC_STREAM_MAX 0
#endif
static
const
char*X_b(mode_t
m){if(S_ISREG(m))return"regular";else
if(S_ISLNK(m))return"link";else
if(S_ISDIR(m))return"directory";else
if(S_ISCHR(m))return"character device";else
if(S_ISBLK(m))return"block device";else
if(S_ISFIFO(m))return"fifo";
#ifdef S_ISSOCK
else
if(S_ISSOCK(m))return"socket";
#endif
else
return"?";}typedef
int(*p6b)(a*L,int
i,const
void*e3);static
int
e7(a*L,int
i,const
char*const
S[],p6b
F,const
void*e3){if(i3(L,i)){U0(L);for(i=0;S[i]!=NULL;i++){I(L,S[i]);F(L,i,e3);Q0(L,-3);}return
1;}else{int
j=i7(Q(L,i),S);if(j==-1)g1(L,i,"unknown selector");return
F(L,j,e3);}}static
void
t7a(a*L,int
i,const
char*m_){I(L,m_);G2(L,-2,i);}static
void
B1b(a*L,const
char*b_,const
char*m_){I(L,b_);I(L,m_);Q0(L,-3);}static
void
B6a(a*L,const
char*b_,U
m_){I(L,b_);N(L,m_);Q0(L,-3);}static
int
C4(a*L,const
char*C_){w_(L);if(C_==NULL)I(L,strerror(errno));else
P_(L,"%s: %s",C_,strerror(errno));N(L,errno);return
3;}static
int
M_(a*L,int
i,const
char*C_){if(i!=-1){N(L,i);return
1;}else
return
C4(L,C_);}static
void
m9a(a*L,int
i,const
char*v3,int
M5a){g1(L,2,P_(L,"unknown %s option `%c'",v3,M5a));}static
uid_t
U0b(a*L,int
i){if(i3(L,i))return-1;else
if(x2(L,i))return(uid_t)F0(L,i);else
if(Z1(L,i)){struct
passwd*p=getpwnam(o_(L,i));return(p==NULL)?-1:p->pw_uid;}else
return
v5(L,i,"string or number");}static
gid_t
W0b(a*L,int
i){if(i3(L,i))return-1;else
if(x2(L,i))return(gid_t)F0(L,i);else
if(Z1(L,i)){struct
group*g=getgrnam(o_(L,i));return(g==NULL)?-1:g->gr_gid;}else
return
v5(L,i,"string or number");}static
int
q9b(a*L){I(L,strerror(errno));N(L,errno);return
2;}static
int
y0c(a*L){const
char*B_=K0(L,1,".");DIR*d=opendir(B_);if(d==NULL)return
C4(L,B_);else{int
i;struct
dirent*K6;U0(L);for(i=1;(K6=readdir(d))!=NULL;i++)t7a(L,i,K6->d_name);closedir(d);return
1;}}static
int
U3b(a*L){DIR*d=b2(L,O_(1));struct
dirent*K6;if(d==NULL)s_(L,"attempt to use closed dir");K6=readdir(d);if(K6==NULL){closedir(d);w_(L);X5(L,O_(1));w_(L);}else{I(L,K6->d_name);
#if 0
#ifdef P3b
I(L,X_b(DTTOIF(K6->d_type)));return
2;
#endif
#endif
}return
1;}static
int
c9b(a*L){const
char*B_=K0(L,1,".");DIR*d=opendir(B_);if(d==NULL)return
C4(L,B_);else{E1(L,d);A1(L,U3b,1);return
1;}}static
int
E8b(a*L){char
buf[c7a];if(getcwd(buf,sizeof(buf))==NULL)return
C4(L,".");else{I(L,buf);return
1;}}static
int
Y8b(a*L){const
char*B_=Q(L,1);return
M_(L,mkdir(B_,0777),B_);}static
int
i9b(a*L){const
char*B_=Q(L,1);return
M_(L,chdir(B_),B_);}static
int
l9b(a*L){const
char*B_=Q(L,1);return
M_(L,rmdir(B_),B_);}static
int
u8b(a*L){const
char*B_=Q(L,1);return
M_(L,unlink(B_),B_);}static
int
O_c(a*L){const
char*q3a=Q(L,1);const
char*O2a=Q(L,2);return
M_(L,link(q3a,O2a),NULL);}static
int
i6b(a*L){const
char*q3a=Q(L,1);const
char*O2a=Q(L,2);return
M_(L,symlink(q3a,O2a),NULL);}static
int
w4b(a*L){char
buf[c7a];const
char*B_=Q(L,1);int
n=readlink(B_,buf,sizeof(buf));if(n==-1)return
C4(L,B_);b1(L,buf,n);return
1;}static
int
m8b(a*L){int
v0=F_OK;const
char*B_=Q(L,1);const
char*s;for(s=K0(L,2,"f");*s!=0;s++)switch(*s){case' ':break;case'r':v0|=R_OK;break;case'w':v0|=W_OK;break;case'x':v0|=X_OK;break;case'f':v0|=F_OK;break;default:m9a(L,2,"mode",*s);break;}return
M_(L,access(B_,v0),B_);}static
int
J8b(a*L){const
char*B_=Q(L,1);return
M_(L,mkfifo(B_,0777),B_);}static
int
x_c(a*L){const
char*B_=Q(L,1);int
i,n=D_(L);char**u3=malloc((n+1)*sizeof(char*));if(u3==NULL)s_(L,"not enough memory");u3[0]=(char*)B_;for(i=1;i<n;i++)u3[i]=(char*)Q(L,i+1);u3[i]=NULL;execvp(B_,u3);return
C4(L,B_);}static
int
P_c(a*L){return
M_(L,fork(),NULL);}static
int
K_c(a*L){pid_t
pid=c1(L,1,-1);return
M_(L,waitpid(pid,NULL,0),NULL);}static
int
C_c(a*L){pid_t
pid=Y_(L,1);int
sig=c1(L,2,SIGTERM);return
M_(L,kill(pid,sig),NULL);}static
int
k9b(a*L){unsigned
int
B2b=Y_(L,1);N(L,sleep(B2b));return
1;}static
int
M7b(a*L){size_t
l;const
char*s=y_(L,1,&l);char*e=malloc(++l);return
M_(L,(e==NULL)?-1:putenv(memcpy(e,s,l)),s);}
#ifdef linux
static
int
C8b(a*L){const
char*b_=Q(L,1);const
char*m_=Q(L,2);int
Z4b=M1(L,3)||Y1(L,3);return
M_(L,setenv(b_,m_,Z4b),b_);}static
int
m4b(a*L){const
char*b_=Q(L,1);unsetenv(b_);return
0;}
#endif
static
int
v8b(a*L){if(i3(L,1)){extern
char**environ;char**e;if(*environ==NULL)w_(L);else
U0(L);for(e=environ;*e!=NULL;e++){char*s=*e;char*eq=strchr(s,'=');if(eq==NULL){I(L,s);o0(L,0);}else{b1(L,s,eq-s);I(L,eq+1);}Q0(L,-3);}}else
I(L,getenv(Q(L,1)));return
1;}static
int
O9b(a*L){char
m[10];mode_t
v0;umask(v0=umask(0));v0=(~v0)&0777;if(!i3(L,1)){if(C7a(&v0,Q(L,1))){w_(L);return
1;}v0&=0777;umask(~v0);}D_a(v0,m);I(L,m);return
1;}static
int
M9b(a*L){mode_t
v0;struct
stat
s;const
char*B_=Q(L,1);const
char*J7b=Q(L,2);if(stat(B_,&s))return
C4(L,B_);v0=s.st_mode;if(C7a(&v0,J7b))g1(L,2,"bad mode");return
M_(L,chmod(B_,v0),B_);}static
int
z9b(a*L){const
char*B_=Q(L,1);uid_t
uid=U0b(L,2);gid_t
gid=W0b(L,3);return
M_(L,chown(B_,uid,gid),B_);}static
int
V9b(a*L){struct
utimbuf
times;time_t
K_b=time(NULL);const
char*B_=Q(L,1);times.modtime=C3(L,2,K_b);times.actime=C3(L,3,K_b);return
M_(L,utime(B_,&times),B_);}static
int
t9b(a*L,int
i,const
void*e3){switch(i){case
0:N(L,getegid());break;case
1:N(L,geteuid());break;case
2:N(L,getgid());break;case
3:N(L,getuid());break;case
4:N(L,getpgrp());break;case
5:N(L,getpid());break;case
6:N(L,getppid());break;}return
1;}static
const
char*const
D9b[]={"egid","euid","gid","uid","pgrp","pid","ppid",NULL};static
int
Q9a(a*L){return
e7(L,1,D9b,t9b,NULL);}static
int
Q5b(a*L){int
fd=c1(L,1,0);I(L,ttyname(fd));return
1;}
#if defined L_ctermid
static
int
T6b(a*L){char
b[L_ctermid];I(L,ctermid(b));return
1;}
#endif
static
int
n4b(a*L){I(L,getlogin());return
1;}static
int
W2b(a*L,int
i,const
void*e3){const
struct
passwd*p=e3;switch(i){case
0:I(L,p->pw_name);break;case
1:N(L,p->pw_uid);break;case
2:N(L,p->pw_gid);break;case
3:I(L,p->pw_dir);break;case
4:I(L,p->pw_shell);break;case
5:I(L,p->pw_gecos);break;case
6:I(L,p->pw_passwd);break;}return
1;}static
const
char*const
F3b[]={"name","uid","gid","dir","shell","gecos","passwd",NULL};static
int
I3b(a*L){struct
passwd*p=NULL;if(M1(L,1))p=getpwuid(geteuid());else
if(x2(L,1))p=getpwuid((uid_t)F0(L,1));else
if(Z1(L,1))p=getpwnam(o_(L,1));else
v5(L,1,"string or number");if(p==NULL)w_(L);else
e7(L,2,F3b,W2b,p);return
1;}static
int
o4b(a*L){struct
group*g=NULL;if(x2(L,1))g=getgrgid((gid_t)F0(L,1));else
if(Z1(L,1))g=getgrnam(o_(L,1));else
v5(L,1,"string or number");if(g==NULL)w_(L);else{int
i;U0(L);B1b(L,"name",g->gr_name);B6a(L,"gid",g->gr_gid);for(i=0;g->gr_mem[i]!=NULL;i++)t7a(L,i+1,g->gr_mem[i]);}return
1;}static
int
p8b(a*L){return
M_(L,setuid(U0b(L,1)),NULL);}static
int
L7b(a*L){return
M_(L,setgid(W0b(L,1)),NULL);}struct
r2b{struct
tms
t;clock_t
s2b;};
#define H1a(L,x) N(L,((U)x)/CLOCKS_PER_SEC)
static
int
I9b(a*L,int
i,const
void*e3){const
struct
r2b*t=e3;switch(i){case
0:H1a(L,t->t.tms_utime);break;case
1:H1a(L,t->t.tms_stime);break;case
2:H1a(L,t->t.tms_cutime);break;case
3:H1a(L,t->t.tms_cstime);break;case
4:H1a(L,t->s2b);break;}return
1;}static
const
char*const
B9b[]={"utime","stime","cutime","cstime","elapsed",NULL};
#define V_c(L,b_,x) B6a(L,b_,(U)x/CLK_TCK)
static
int
J9b(a*L){struct
r2b
t;t.s2b=times(&t.t);return
e7(L,1,B9b,I9b,&t);}struct
s4b{struct
stat
s;char
v0[10];const
char*N4a;};static
int
N_c(a*L,int
i,const
void*e3){const
struct
s4b*s=e3;switch(i){case
0:I(L,s->v0);break;case
1:N(L,s->s.st_ino);break;case
2:N(L,s->s.st_dev);break;case
3:N(L,s->s.st_nlink);break;case
4:N(L,s->s.st_uid);break;case
5:N(L,s->s.st_gid);break;case
6:N(L,s->s.st_size);break;case
7:N(L,s->s.st_atime);break;case
8:N(L,s->s.st_mtime);break;case
9:N(L,s->s.st_ctime);break;case
10:I(L,s->N4a);break;case
11:N(L,s->s.st_mode);break;}return
1;}static
const
char*const
k_c[]={"mode","ino","dev","nlink","uid","gid","size","atime","mtime","ctime","type","_mode",NULL};static
int
u_c(a*L){struct
s4b
s;const
char*B_=Q(L,1);if(stat(B_,&s.s)==-1)return
C4(L,B_);s.N4a=X_b(s.s.st_mode);D_a(s.s.st_mode,s.v0);return
e7(L,2,k_c,N_c,&s);}static
int
e9b(a*L){struct
utsname
u;I_
b;const
char*s;if(uname(&u)==-1)return
C4(L,NULL);X1(L,&b);for(s=K0(L,1,"%s %n %r %v %m");*s;s++)if(*s!='%')n1(&b,*s);else
switch(*++s){case'%':n1(&b,*s);break;case'm':i5(&b,u.machine);break;case'n':i5(&b,u.nodename);break;case'r':i5(&b,u.release);break;case's':i5(&b,u.sysname);break;case'v':i5(&b,u.version);break;default:m9a(L,2,"format",*s);break;}Z0(&b);return
1;}static
const
int
Q4b[]={_PC_LINK_MAX,_PC_MAX_CANON,_PC_MAX_INPUT,_PC_NAME_MAX,_PC_PATH_MAX,_PC_PIPE_BUF,_PC_CHOWN_RESTRICTED,_PC_NO_TRUNC,_PC_VDISABLE,-1};static
int
p5b(a*L,int
i,const
void*e3){const
char*B_=e3;N(L,pathconf(B_,Q4b[i]));return
1;}static
const
char*const
u4b[]={"link_max","max_canon","max_input","name_max","path_max","pipe_buf","chown_restricted","no_trunc","vdisable",NULL};static
int
U4b(a*L){const
char*B_=Q(L,1);return
e7(L,2,u4b,p5b,B_);}static
const
int
z6b[]={_SC_ARG_MAX,_SC_CHILD_MAX,_SC_CLK_TCK,_SC_NGROUPS_MAX,_SC_STREAM_MAX,_SC_TZNAME_MAX,_SC_OPEN_MAX,_SC_JOB_CONTROL,_SC_SAVED_IDS,_SC_VERSION,-1};static
int
q6b(a*L,int
i,const
void*e3){N(L,sysconf(z6b[i]));return
1;}static
const
char*const
e7b[]={"arg_max","child_max","clk_tck","ngroups_max","stream_max","tzname_max","open_max","job_control","saved_ids","version",NULL};static
int
H6b(a*L){return
e7(L,1,e7b,q6b,NULL);}static
const
k3
R[]={{"access",m8b},{"chdir",i9b},{"chmod",M9b},{"chown",z9b},
#if defined L_ctermid
{"ctermid",T6b},
#endif
{"dir",y0c},{"errno",q9b},{"exec",x_c},{"files",c9b},{"fork",P_c},{"getcwd",E8b},{"getenv",v8b},{"getgroup",o4b},{"getlogin",n4b},{"getpasswd",I3b},{"getprocessid",Q9a},{"kill",C_c},{"link",O_c},{"mkdir",Y8b},{"mkfifo",J8b},{"pathconf",U4b},{"putenv",M7b},{"readlink",w4b},{"rmdir",l9b},{"setgid",L7b},{"setuid",p8b},{"sleep",k9b},{"stat",u_c},{"symlink",i6b},{"sysconf",H6b},{"times",J9b},{"ttyname",Q5b},{"umask",O9b},{"uname",e9b},{"unlink",u8b},{"utime",V9b},{"wait",K_c},
#ifdef linux
{"setenv",C8b},{"unsetenv",m4b},
#endif
{NULL,NULL}};P
int
A4a(a*L){y2(L,Y4b,R,0);e_(L,"version");e_(L,B5b);Q0(L,-3);return
1;}
#define d0c
#ifndef i_b
#define q9 0
#else
union
x1b{p8
a;i_b
b;};
#define q9 (sizeof(union x1b))
#endif
static
int
X9a(a*L){P2a(L);return
0;}static
a*C6a(a*L){T_*N_=(T_*)Z5(L,sizeof(a)+q9);if(N_==NULL)return
NULL;else{N_+=q9;return
g_(a*,N_);}}static
void
w9a(a*L,a*L1){f2a(L,g_(T_*,L1)-q9,sizeof(a)+q9);}static
void
F7a(a*L1,a*L){L1->l_=F2(L,E8+d7,E);L1->H2=E8+d7;L1->X=L1->l_;L1->x5=L1->l_+(L1->H2-d7)-1;L1->O0=F2(L,w0a,m0);L1->ci=L1->O0;L1->ci->h0=Y1a;S_(L1->X++);L1->k_=L1->ci->k_=L1->X;L1->ci->X=L1->X+N3;L1->X3=w0a;L1->S7a=L1->O0+L1->X3;}static
void
G9a(a*L,a*L1){x1(L,L1->O0,L1->X3,m0);x1(L,L1->l_,L1->H2,E);}static
void
d4b(a*L,void*ud){v4*g=K3a(NULL,v4);P2a(ud);if(g==NULL)K5(L,H3a);L->l_G=g;g->w9=L;g->O5=0;g->f7.W=0;g->f7.N6a=0;g->f7.i2=NULL;S_(F3(L));S_(a6(L));w2a(L,&g->p_);g->l_b=X9a;g->g5a=NULL;g->A6=NULL;g->r6=NULL;S_(l4(g->d4));S_(D4(g->d4));g->d4->h_=NULL;g->b7=sizeof(a)+sizeof(v4);F7a(L,L);F3(L)->tt=H_;z6(F3(L),E7(L,0,0));m1(F3(L))->r_=m1(F3(L));z6(gt(L),E7(L,0,4));z6(a6(L),E7(L,4,4));H_a(L,t0a);v9a(L);h9a(L);U6a(k2a(L,F9a));g->O5=4*G(L)->b7;}static
void
d4a(a*L){L->l_=NULL;L->H2=0;L->N8=NULL;L->D6=NULL;L->J6=L->s3a=0;L->w8=0;L->f4=1;i_a(L);L->w6=NULL;L->X3=0;L->k6=0;L->O0=L->ci=NULL;L->p4=0;S_(gt(L));}static
void
o6a(a*L){Y4(L,L->l_);if(G(L)){S3a(L,1);H(G(L)->g5a==NULL);H(G(L)->A6==NULL);w5a(L);p2a(L,&G(L)->p_);}G9a(L,L);if(G(L)){H(G(L)->b7==sizeof(a)+sizeof(v4));s9(NULL,G(L));}w9a(NULL,L);}a*i3a(a*L){a*L1=C6a(L);n7(L,Q4(L1),c3);d4a(L1);L1->l_G=L->l_G;F7a(L1,L);B3a(gt(L1),gt(L));return
L1;}void
A2a(a*L,a*L1){Y4(L1,L1->l_);H(L1->w6==NULL);G9a(L,L1);w9a(L,L1);}K
a*i7a(void){a*L=C6a(NULL);if(L){L->tt=c3;L->Y2=0;L->h_=L->n5=NULL;d4a(L);L->l_G=NULL;if(g3(L,d4b,NULL)!=0){o6a(L);L=NULL;}}S4(L);return
L;}static
void
M1b(a*L,void*ud){P2a(ud);s0a(L);}K
void
h2a(a*L){n_(L);L=G(L)->w9;Y4(L,L->l_);v7(L);L->p4=0;do{L->ci=L->O0;L->k_=L->X=L->ci->k_;L->k6=0;}while(g3(L,M1b,NULL)!=0);H(G(L)->r6==NULL);o6a(L);}
#define T_c
void
w5a(a*L){H(G(L)->f7.N6a==0);x1(L,G(L)->f7.i2,G(L)->f7.W,A_*);}void
H_a(a*L,int
T1){u_**f6a=F2(L,T1,u_*);k8*tb=&G(L)->f7;int
i;for(i=0;i<T1;i++)f6a[i]=NULL;for(i=0;i<tb->W;i++){u_*p=tb->i2[i];while(p){u_*h_=p->E3.h_;f_a
h=d6a(p)->x6.i2;int
h1=z_b(h,T1);H(g_(int,h%T1)==z_b(h,T1));p->E3.h_=f6a[h1];f6a[h1]=p;p=h_;}}x1(L,tb->i2,tb->W,A_*);tb->W=T1;tb->i2=f6a;}static
A_*N8b(a*L,const
char*str,size_t
l,f_a
h){A_*ts=g_(A_*,Z5(L,v7a(l)));k8*tb;ts->x6.G1=l;ts->x6.i2=h;ts->x6.Y2=0;ts->x6.tt=u1;ts->x6.B3=0;memcpy(ts+1,str,l*sizeof(char));((char*)(ts+1))[l]='\0';tb=&G(L)->f7;h=z_b(h,tb->W);ts->x6.h_=tb->i2[h];tb->i2[h]=Q4(ts);tb->N6a++;if(tb->N6a>g_(I8a,tb->W)&&tb->W<=J7/2)H_a(L,tb->W*2);return
ts;}A_*W2(a*L,const
char*str,size_t
l){u_*o;f_a
h=(f_a)l;size_t
o9=(l>>5)+1;size_t
l1;for(l1=l;l1>=o9;l1-=o9)h=h^((h<<5)+(h>>2)+(unsigned
char)(str[l1-1]));for(o=G(L)->f7.i2[z_b(h,G(L)->f7.W)];o!=NULL;o=o->E3.h_){A_*ts=d6a(o);if(ts->x6.G1==l&&(memcmp(str,I5(ts),l)==0))return
ts;}return
N8b(L,str,l,h);}C_a*w4a(a*L,size_t
s){C_a*u;u=g_(C_a*,Z5(L,E5a(s)));u->uv.Y2=(1<<1);u->uv.tt=f1;u->uv.G1=s;u->uv.r_=m1(F3(L));u->uv.h_=G(L)->A6;G(L)->A6=Q4(u);return
u;}
#define U_c
#ifndef L3
#define L3(c) ((unsigned char)(c))
#endif
typedef
long
U6;static
int
F8b(a*L){size_t
l;y_(L,1,&l);N(L,(U)l);return
1;}static
U6
L3a(U6
N6,size_t
G1){return(N6>=0)?N6:(U6)G1+N6+1;}static
int
z8b(a*L){size_t
l;const
char*s=y_(L,1,&l);U6
G_a=L3a(b3a(L,2),l);U6
t7=L3a(F7(L,3,-1),l);if(G_a<1)G_a=1;if(t7>(U6)l)t7=(U6)l;if(G_a<=t7)b1(L,s+G_a-1,t7-G_a+1);else
e_(L,"");return
1;}static
int
W3b(a*L){size_t
l;size_t
i;I_
b;const
char*s=y_(L,1,&l);X1(L,&b);for(i=0;i<l;i++)n1(&b,tolower(L3(s[i])));Z0(&b);return
1;}static
int
Z3b(a*L){size_t
l;size_t
i;I_
b;const
char*s=y_(L,1,&l);X1(L,&b);for(i=0;i<l;i++)n1(&b,toupper(L3(s[i])));Z0(&b);return
1;}static
int
k8b(a*L){size_t
l;I_
b;const
char*s=y_(L,1,&l);int
n=Y_(L,2);X1(L,&b);while(n-->0)o3(&b,s,l);Z0(&b);return
1;}static
int
M6b(a*L){size_t
l;const
char*s=y_(L,1,&l);U6
N6=L3a(F7(L,2,1),l);if(N6<=0||(size_t)(N6)>l)return
0;N(L,L3(s[N6-1]));return
1;}static
int
T5b(a*L){int
n=D_(L);int
i;I_
b;X1(L,&b);for(i=1;i<=n;i++){int
c=Y_(L,i);f0(L,L3(c)==c,i,"invalid value");n1(&b,L3(c));}Z0(&b);return
1;}static
int
Q7a(a*L,const
void*b,size_t
W,void*B){(void)L;o3((I_*)B,(const
char*)b,W);return
1;}static
int
G6b(a*L){I_
b;G_(L,1,e0);X1(L,&b);if(!a1b(L,Q7a,&b))s_(L,"unable to dump given function");Z0(&b);return
1;}
#ifndef Q1a
#define Q1a 32
#endif
#define p6 (-1)
#define S4a (-2)
typedef
struct
D1{const
char*V1a;const
char*f5;a*L;int
z_;struct{const
char*I1;U6
G1;}P2[Q1a];}D1;
#define ESC '%'
#define w6b "^$*+?.([%-"
static
int
p4a(D1*ms,int
l){l-='1';if(l<0||l>=ms->z_||ms->P2[l].G1==p6)return
s_(ms->L,"invalid capture index");return
l;}static
int
m7a(D1*ms){int
z_=ms->z_;for(z_--;z_>=0;z_--)if(ms->P2[z_].G1==p6)return
z_;return
s_(ms->L,"invalid pattern capture");}static
const
char*B4a(D1*ms,const
char*p){switch(*p++){case
ESC:{if(*p=='\0')s_(ms->L,"malformed pattern (ends with `%')");return
p+1;}case'[':{if(*p=='^')p++;do{if(*p=='\0')s_(ms->L,"malformed pattern (missing `]')");if(*(p++)==ESC&&*p!='\0')p++;}while(*p!=']');return
p+1;}default:{return
p;}}}static
int
u6a(int
c,int
cl){int
i0;switch(tolower(cl)){case'a':i0=isalpha(c);break;case'c':i0=iscntrl(c);break;case'd':i0=isdigit(c);break;case'l':i0=islower(c);break;case'p':i0=ispunct(c);break;case's':i0=isspace(c);break;case'u':i0=isupper(c);break;case'w':i0=isalnum(c);break;case'x':i0=isxdigit(c);break;case'z':i0=(c==0);break;default:return(cl==c);}return(islower(cl)?i0:!i0);}static
int
c8(int
c,const
char*p,const
char*ec){int
sig=1;if(*(p+1)=='^'){sig=0;p++;}while(++p<ec){if(*p==ESC){p++;if(u6a(c,*p))return
sig;}else
if((*(p+1)=='-')&&(p+2<ec)){p+=2;if(L3(*(p-2))<=c&&c<=L3(*p))return
sig;}else
if(L3(*p)==c)return
sig;}return!sig;}static
int
L8(int
c,const
char*p,const
char*ep){switch(*p){case'.':return
1;case
ESC:return
u6a(c,*(p+1));case'[':return
c8(c,p,ep-1);default:return(L3(*p)==c);}}static
const
char*J3(D1*ms,const
char*s,const
char*p);static
const
char*O_b(D1*ms,const
char*s,const
char*p){if(*p==0||*(p+1)==0)s_(ms->L,"unbalanced pattern");if(*s!=*p)return
NULL;else{int
b=*p;int
e=*(p+1);int
X8a=1;while(++s<ms->f5){if(*s==e){if(--X8a==0)return
s+1;}else
if(*s==b)X8a++;}}return
NULL;}static
const
char*k8a(D1*ms,const
char*s,const
char*p,const
char*ep){U6
i=0;while((s+i)<ms->f5&&L8(L3(*(s+i)),p,ep))i++;while(i>=0){const
char*i0=J3(ms,(s+i),ep+1);if(i0)return
i0;i--;}return
NULL;}static
const
char*E3b(D1*ms,const
char*s,const
char*p,const
char*ep){for(;;){const
char*i0=J3(ms,s,ep+1);if(i0!=NULL)return
i0;else
if(s<ms->f5&&L8(L3(*s),p,ep))s++;else
return
NULL;}}static
const
char*e4a(D1*ms,const
char*s,const
char*p,int
v3){const
char*i0;int
z_=ms->z_;if(z_>=Q1a)s_(ms->L,"too many captures");ms->P2[z_].I1=s;ms->P2[z_].G1=v3;ms->z_=z_+1;if((i0=J3(ms,s,p))==NULL)ms->z_--;return
i0;}static
const
char*p1b(D1*ms,const
char*s,const
char*p){int
l=m7a(ms);const
char*i0;ms->P2[l].G1=s-ms->P2[l].I1;if((i0=J3(ms,s,p))==NULL)ms->P2[l].G1=p6;return
i0;}static
const
char*k_b(D1*ms,const
char*s,int
l){size_t
G1;l=p4a(ms,l);G1=ms->P2[l].G1;if((size_t)(ms->f5-s)>=G1&&memcmp(ms->P2[l].I1,s,G1)==0)return
s+G1;else
return
NULL;}static
const
char*J3(D1*ms,const
char*s,const
char*p){I1:switch(*p){case'(':{if(*(p+1)==')')return
e4a(ms,s,p+2,S4a);else
return
e4a(ms,s,p+1,p6);}case')':{return
p1b(ms,s,p+1);}case
ESC:{switch(*(p+1)){case'b':{s=O_b(ms,s,p+2);if(s==NULL)return
NULL;p+=4;goto
I1;}case'f':{const
char*ep;char
Z_;p+=2;if(*p!='[')s_(ms->L,"missing `[' after `%%f' in pattern");ep=B4a(ms,p);Z_=(s==ms->V1a)?'\0':*(s-1);if(c8(L3(Z_),p,ep-1)||!c8(L3(*s),p,ep-1))return
NULL;p=ep;goto
I1;}default:{if(isdigit(L3(*(p+1)))){s=k_b(ms,s,*(p+1));if(s==NULL)return
NULL;p+=2;goto
I1;}goto
U9b;}}}case'\0':{return
s;}case'$':{if(*(p+1)=='\0')return(s==ms->f5)?s:NULL;else
goto
U9b;}default:U9b:{const
char*ep=B4a(ms,p);int
m=s<ms->f5&&L8(L3(*s),p,ep);switch(*ep){case'?':{const
char*i0;if(m&&((i0=J3(ms,s+1,ep+1))!=NULL))return
i0;p=ep+1;goto
I1;}case'*':{return
k8a(ms,s,p,ep);}case'+':{return(m?k8a(ms,s+1,p,ep):NULL);}case'-':{return
E3b(ms,s,p,ep);}default:{if(!m)return
NULL;s++;p=ep;goto
I1;}}}}}static
const
char*N6b(const
char*s1,size_t
l1,const
char*s2,size_t
l2){if(l2==0)return
s1;else
if(l2>l1)return
NULL;else{const
char*I1;l2--;l1=l1-l2;while(l1>0&&(I1=(const
char*)memchr(s1,*s2,l1))!=NULL){I1++;if(memcmp(I1,s2+1,l2)==0)return
I1-1;else{l1-=I1-s1;s1=I1;}}return
NULL;}}static
void
m2a(D1*ms,int
i){int
l=ms->P2[i].G1;if(l==p6)s_(ms->L,"unfinished capture");if(l==S4a)N(ms->L,(U)(ms->P2[i].I1-ms->V1a+1));else
b1(ms->L,ms->P2[i].I1,l);}static
int
x0a(D1*ms,const
char*s,const
char*e){int
i;F4(ms->L,ms->z_,"too many captures");if(ms->z_==0&&s){b1(ms->L,s,e-s);return
1;}else{for(i=0;i<ms->z_;i++)m2a(ms,i);return
ms->z_;}}static
int
g7b(a*L){size_t
l1,l2;const
char*s=y_(L,1,&l1);const
char*p=y_(L,2,&l2);U6
I1=L3a(F7(L,3,1),l1)-1;if(I1<0)I1=0;else
if((size_t)(I1)>l1)I1=(U6)l1;if(Y1(L,4)||strpbrk(p,w6b)==NULL){const
char*s2=N6b(s+I1,l1-I1,p,l2);if(s2){N(L,(U)(s2-s+1));N(L,(U)(s2-s+l2));return
2;}}else{D1
ms;int
e1b=(*p=='^')?(p++,1):0;const
char*s1=s+I1;ms.L=L;ms.V1a=s;ms.f5=s+l1;do{const
char*i0;ms.z_=0;if((i0=J3(&ms,s1,p))!=NULL){N(L,(U)(s1-s+1));N(L,(U)(i0-s));return
x0a(&ms,NULL,0)+2;}}while(s1++<ms.f5&&!e1b);}w_(L);return
1;}static
int
E4b(a*L){D1
ms;const
char*s=o_(L,O_(1));size_t
O=S3(L,O_(1));const
char*p=o_(L,O_(2));const
char*src;ms.L=L;ms.V1a=s;ms.f5=s+O;for(src=s+(size_t)F0(L,O_(3));src<=ms.f5;src++){const
char*e;ms.z_=0;if((e=J3(&ms,src,p))!=NULL){int
d1b=e-s;if(e==src)d1b++;N(L,(U)d1b);X5(L,O_(3));return
x0a(&ms,src,e);}}return
0;}static
int
g_c(a*L){Q(L,1);Q(L,2);J0(L,2);N(L,0);A1(L,E4b,3);return
1;}static
void
y_c(D1*ms,I_*b,const
char*s,const
char*e){a*L=ms->L;if(Z1(L,3)){const
char*c1b=o_(L,3);size_t
l=S3(L,3);size_t
i;for(i=0;i<l;i++){if(c1b[i]!=ESC)n1(b,c1b[i]);else{i++;if(!isdigit(L3(c1b[i])))n1(b,c1b[i]);else{int
z_=p4a(ms,c1b[i]);m2a(ms,z_);V6(b);}}}}else{int
n;Y(L,3);n=x0a(ms,s,e);j4(L,n,1);if(Z1(L,-1))V6(b);else
V_(L,1);}}static
int
C6b(a*L){size_t
c7b;const
char*src=y_(L,1,&c7b);const
char*p=Q(L,2);int
p_c=c1(L,4,c7b+1);int
e1b=(*p=='^')?(p++,1):0;int
n=0;D1
ms;I_
b;f0(L,D_(L)>=3&&(Z1(L,3)||g2(L,3)),3,"string or function expected");X1(L,&b);ms.L=L;ms.V1a=src;ms.f5=src+c7b;while(n<p_c){const
char*e;ms.z_=0;e=J3(&ms,src,p);if(e){n++;y_c(&ms,&b,src,e);}if(e&&e>src)src=e;else
if(src<ms.f5)n1(&b,*src++);else
break;if(e1b)break;}o3(&b,src,ms.f5-src);Z0(&b);N(L,(U)n);return
2;}
#define b7b 512
#define W7a 20
static
void
M8a(a*L,I_*b,int
b8){size_t
l;const
char*s=y_(L,b8,&l);n1(b,'"');while(l--){switch(*s){case'"':case'\\':case'\n':{n1(b,'\\');n1(b,*s);break;}case'\0':{o3(b,"\\000",4);break;}default:{n1(b,*s);break;}}s++;}n1(b,'"');}static
const
char*X2b(a*L,const
char*D3,char*N1a,int*H9){const
char*p=D3;while(strchr("-+ #0",*p))p++;if(isdigit(L3(*p)))p++;if(isdigit(L3(*p)))p++;if(*p=='.'){p++;*H9=1;if(isdigit(L3(*p)))p++;if(isdigit(L3(*p)))p++;}if(isdigit(L3(*p)))s_(L,"invalid format (width or precision too long)");if(p-D3+2>W7a)s_(L,"invalid format (too long)");N1a[0]='%';strncpy(N1a+1,D3,p-D3+1);N1a[p-D3+2]=0;return
p;}static
int
q3b(a*L){int
b8=1;size_t
sfl;const
char*D3=y_(L,b8,&sfl);const
char*D1b=D3+sfl;I_
b;X1(L,&b);while(D3<D1b){if(*D3!='%')n1(&b,*D3++);else
if(*++D3=='%')n1(&b,*D3++);else{char
N1a[W7a];char
p_[b7b];int
H9=0;if(isdigit(L3(*D3))&&*(D3+1)=='$')return
s_(L,"obsolete option (d$) to `format'");b8++;D3=X2b(L,D3,N1a,&H9);switch(*D3++){case'c':case'd':case'i':{sprintf(p_,N1a,Y_(L,b8));break;}case'o':case'u':case'x':case'X':{sprintf(p_,N1a,(unsigned
int)(d1(L,b8)));break;}case'e':case'E':case'f':case'g':case'G':{sprintf(p_,N1a,d1(L,b8));break;}case'q':{M8a(L,&b,b8);continue;}case's':{size_t
l;const
char*s=y_(L,b8,&l);if(!H9&&l>=100){Y(L,b8);V6(&b);continue;}else{sprintf(p_,N1a,s);break;}}default:{return
s_(L,"invalid option to `format'");}}o3(&b,p_,strlen(p_));}}Z0(&b);return
1;}static
const
k3
f9b[]={{"len",F8b},{"sub",z8b},{"lower",W3b},{"upper",Z3b},{"char",T5b},{"rep",k8b},{"byte",M6b},{"format",q3b},{"dump",G6b},{"find",g7b},{"gfind",g_c},{"gsub",C6b},{NULL,NULL}};P
int
S7(a*L){y2(L,J8a,f9b,0);return
1;}
#define q0c
#if BITS_INT>26
#define b9 24
#else
#define b9 (BITS_INT-2)
#endif
#define o9b(x) ((((x)-1)>>b9)!=0)
#ifndef j_a
#define j_a(i,n) ((i)=(int)(n))
#endif
#define j0b(t,n) (r5(t,z_b((n),q5(t))))
#define c2b(t,str) j0b(t,(str)->x6.i2)
#define I1b(t,p) j0b(t,p)
#define Z1b(t,n) (r5(t,((n)%((q5(t)-1)|1))))
#define s6a(t,p) Z1b(t,d6b(p))
#define n2b g_(int,sizeof(U)/sizeof(int))
static
M3*i2b(const
p0*t,U
n){unsigned
int
a[n2b];int
i;n+=1;H(sizeof(a)<=sizeof(n));memcpy(a,&n,sizeof(a));for(i=1;i<n2b;i++)a[0]+=a[i];return
Z1b(t,g_(f_a,a[0]));}M3*Z3(const
p0*t,const
E*x_){switch(V0(x_)){case
P1:return
i2b(t,s0(x_));case
u1:return
c2b(t,q2(x_));case
l5:return
I1b(t,g3a(x_));case
K1:return
s6a(t,S2a(x_));default:return
s6a(t,P7(x_));}}static
int
j8a(const
E*x_){if(Y0(x_)){int
k;j_a(k,(s0(x_)));if(g_(U,k)==s0(x_)&&k>=1&&!o9b(k))return
k;}return-1;}static
int
b3b(a*L,p0*t,t_
x_){int
i;if(I0(x_))return-1;i=j8a(x_);if(0<=i&&i<=t->O1){return
i-1;}else{const
E*v=x7(t,x_);if(v==&E2)q_(L,"invalid key for `next'");i=g_(int,(g_(const
T_*,v)-g_(const
T_*,D4(r5(t,0))))/sizeof(M3));return
i+t->O1;}}int
n9a(a*L,p0*t,t_
x_){int
i=b3b(L,t,x_);for(i++;i<t->O1;i++){if(!I0(&t->w0[i])){N1(x_,g_(U,i+1));l0(x_+1,&t->w0[i]);return
1;}}for(i-=t->O1;i<q5(t);i++){if(!I0(D4(r5(t,i)))){l0(x_,l4(r5(t,i)));l0(x_+1,D4(r5(t,i)));return
1;}}return
0;}static
void
g0b(int
Z3a[],int
K5b,int*H5,int*g3b){int
i;int
a=Z3a[0];int
na=a;int
n=(na==0)?-1:0;for(i=1;a<*H5&&*H5>=o2a(i-1);i++){if(Z3a[i]>0){a+=Z3a[i];if(a>=o2a(i-1)){n=i;na=a;}}}H(na<=*H5&&*H5<=K5b);*g3b=K5b-na;*H5=(n==-1)?0:o2a(n);H(na<=*H5&&na>=*H5/2);}static
void
y9b(const
p0*t,int*H5,int*g3b){int
Z3a[b9+1];int
i,lg;int
M3a=0;for(i=0,lg=0;lg<=b9;lg++){int
x3b=o2a(lg);if(x3b>t->O1){x3b=t->O1;if(i>=x3b)break;}Z3a[lg]=0;for(;i<x3b;i++){if(!I0(&t->w0[i])){Z3a[lg]++;M3a++;}}}for(;lg<=b9;lg++)Z3a[lg]=0;*H5=M3a;i=q5(t);while(i--){M3*n=&t->h3[i];if(!I0(D4(n))){int
k=j8a(l4(n));if(k>=0){Z3a[l0a(k-1)+1]++;(*H5)++;}M3a++;}}g0b(Z3a,M3a,H5,g3b);}static
void
l3a(a*L,p0*t,int
W){int
i;H0(L,t->w0,t->O1,W,E);for(i=t->O1;i<W;i++)S_(&t->w0[i]);t->O1=W;}static
void
o4a(a*L,p0*t,int
u_b){int
i;int
W=o2a(u_b);if(u_b>b9)q_(L,"table overflow");if(u_b==0){t->h3=G(L)->d4;H(I0(l4(t->h3)));H(I0(D4(t->h3)));H(t->h3->h_==NULL);}else{t->h3=F2(L,W,M3);for(i=0;i<W;i++){t->h3[i].h_=NULL;S_(l4(r5(t,i)));S_(D4(r5(t,i)));}}t->Z8=g_(T_,u_b);t->w7=r5(t,W-1);}static
void
E9b(a*L,p0*t,int
S9,int
r7a){int
i;int
u3a=t->O1;int
X3a=t->Z8;M3*h3b;M3
g7[1];if(X3a)h3b=t->h3;else{H(t->h3==G(L)->d4);g7[0]=t->h3[0];h3b=g7;S_(l4(G(L)->d4));S_(D4(G(L)->d4));H(G(L)->d4->h_==NULL);}if(S9>u3a)l3a(L,t,S9);o4a(L,t,r7a);if(S9<u3a){t->O1=S9;for(i=S9;i<u3a;i++){if(!I0(&t->w0[i]))C9a(r8(L,t,i+1),&t->w0[i]);}H0(L,t->w0,u3a,S9,E);}for(i=o2a(X3a)-1;i>=0;i--){M3*old=h3b+i;if(!I0(D4(old)))C9a(s_a(L,t,l4(old)),D4(old));}if(X3a)x1(L,h3b,o2a(X3a),M3);}static
void
X3b(a*L,p0*t){int
S9,r7a;y9b(t,&S9,&r7a);E9b(L,t,S9,l0a(r7a)+1);}p0*E7(a*L,int
H5,int
h4b){p0*t=K3a(L,p0);n7(L,Q4(t),H_);t->r_=m1(F3(L));t->E3a=g_(T_,~0);t->w0=NULL;t->O1=0;t->Z8=0;t->h3=NULL;l3a(L,t,H5);o4a(L,t,h4b);return
t;}void
J9a(a*L,p0*t){if(t->Z8)x1(L,t->h3,q5(t),M3);x1(L,t->w0,t->O1,E);s9(L,t);}
#if 0
void
a_c(p0*t,M3*e){M3*mp=Z3(t,l4(e));if(e!=mp){while(mp->h_!=e)mp=mp->h_;mp->h_=e->h_;}else{if(e->h_!=NULL)??}H(I0(D4(h3)));S_(l4(e));e->h_=NULL;}
#endif
static
E*I5b(a*L,p0*t,const
E*x_){E*y6;M3*mp=Z3(t,x_);if(!I0(D4(mp))){M3*j5a=Z3(t,l4(mp));M3*n=t->w7;if(j5a!=mp){while(j5a->h_!=mp)j5a=j5a->h_;j5a->h_=n;*n=*mp;mp->h_=NULL;S_(D4(mp));}else{n->h_=mp->h_;mp->h_=n;mp=n;}}C1a(l4(mp),x_);H(I0(D4(mp)));for(;;){if(I0(l4(t->w7)))return
D4(mp);else
if(t->w7==t->h3)break;else(t->w7)--;}l2a(D4(mp),0);X3b(L,t);y6=g_(E*,x7(t,x_));H(N2a(y6));S_(y6);return
y6;}static
const
E*F1b(p0*t,const
E*x_){if(I0(x_))return&E2;else{M3*n=Z3(t,x_);do{if(y3(l4(n),x_))return
D4(n);else
n=n->h_;}while(n);return&E2;}}const
E*x_a(p0*t,int
x_){if(1<=x_&&x_<=t->O1)return&t->w0[x_-1];else{U
nk=g_(U,x_);M3*n=i2b(t,nk);do{if(Y0(l4(n))&&s0(l4(n))==nk)return
D4(n);else
n=n->h_;}while(n);return&E2;}}const
E*t4(p0*t,A_*x_){M3*n=c2b(t,x_);do{if(r1(l4(n))&&q2(l4(n))==x_)return
D4(n);else
n=n->h_;}while(n);return&E2;}const
E*x7(p0*t,const
E*x_){switch(V0(x_)){case
u1:return
t4(t,q2(x_));case
P1:{int
k;j_a(k,(s0(x_)));if(g_(U,k)==s0(x_))return
x_a(t,k);}default:return
F1b(t,x_);}}E*s_a(a*L,p0*t,const
E*x_){const
E*p=x7(t,x_);t->E3a=0;if(p!=&E2)return
g_(E*,p);else{if(I0(x_))q_(L,"table index is nil");else
if(Y0(x_)&&s0(x_)!=s0(x_))q_(L,"table index is NaN");return
I5b(L,t,x_);}}E*r8(a*L,p0*t,int
x_){const
E*p=x_a(t,x_);if(p!=&E2)return
g_(E*,p);else{E
k;N1(&k,g_(U,x_));return
I5b(L,t,&k);}}
#define a0c
#define Z1a(L,n) (G_(L,n,H_),S8(L,n))
static
int
c_b(a*L){int
i;int
n=Z1a(L,1);G_(L,2,e0);for(i=1;i<=n;i++){Y(L,2);N(L,(U)i);d0(L,1,i);j4(L,2,1);if(!q3(L,-1))return
1;V_(L,1);}return
0;}static
int
C0b(a*L){G_(L,1,H_);G_(L,2,e0);w_(L);for(;;){if(W3a(L,1)==0)return
0;Y(L,2);Y(L,-3);Y(L,-3);j4(L,2,1);if(!q3(L,-1))return
1;V_(L,2);}}static
int
i5b(a*L){N(L,(U)Z1a(L,1));return
1;}static
int
H5b(a*L){G_(L,1,H_);Y8(L,1,Y_(L,2));return
0;}static
int
D0b(a*L){int
v=D_(L);int
n=Z1a(L,1)+1;int
N6;if(v==2)N6=n;else{N6=Y_(L,2);if(N6>n)n=N6;v=3;}Y8(L,1,n);while(--n>=N6){d0(L,1,n);G2(L,1,n+1);}Y(L,v);G2(L,1,N6);return
0;}static
int
G0b(a*L){int
n=Z1a(L,1);int
N6=c1(L,2,n);if(n<=0)return
0;Y8(L,1,n-1);d0(L,1,N6);for(;N6<n;N6++){d0(L,1,N6+1);G2(L,1,N6);}w_(L);G2(L,1,n);return
1;}static
int
S2b(a*L){I_
b;size_t
Z8b;const
char*sep=h7(L,2,"",&Z8b);int
i=c1(L,3,1);int
n=c1(L,4,0);G_(L,1,H_);if(n==0)n=S8(L,1);X1(L,&b);for(;i<=n;i++){d0(L,1,i);f0(L,Z1(L,-1),1,"table contains non-strings");V6(&b);if(i!=n)o3(&b,sep,Z8b);}Z0(&b);return
1;}static
void
V8a(a*L,int
i,int
j){G2(L,1,i);G2(L,1,j);}static
int
i0a(a*L,int
a,int
b){if(!q3(L,2)){int
i0;Y(L,2);Y(L,a-1);Y(L,b-2);j4(L,2,1);i0=Y1(L,-1);V_(L,1);return
i0;}else
return
O1a(L,a,b);}static
void
C2b(a*L,int
l,int
u){while(l<u){int
i,j;d0(L,1,l);d0(L,1,u);if(i0a(L,-1,-2))V8a(L,l,u);else
V_(L,2);if(u-l==1)break;i=(l+u)/2;d0(L,1,i);d0(L,1,l);if(i0a(L,-2,-1))V8a(L,i,l);else{V_(L,1);d0(L,1,u);if(i0a(L,-1,-2))V8a(L,i,u);else
V_(L,2);}if(u-l==2)break;d0(L,1,i);Y(L,-1);d0(L,1,u-1);V8a(L,i,u-1);i=l;j=u-1;for(;;){while(d0(L,1,++i),i0a(L,-1,-2)){if(i>u)s_(L,"invalid order function for sorting");V_(L,1);}while(d0(L,1,--j),i0a(L,-3,-1)){if(j<l)s_(L,"invalid order function for sorting");V_(L,1);}if(j<i){V_(L,3);break;}V8a(L,i,j);}d0(L,1,u-1);d0(L,1,i);V8a(L,u-1,i);if(i-l<u-i){j=l;i=i-1;l=i+2;}else{j=i+1;i=u;u=j-2;}C2b(L,j,i);}}static
int
N4b(a*L){int
n=Z1a(L,1);F4(L,40,"");if(!M1(L,2))G_(L,2,e0);J0(L,2);C2b(L,1,n);return
0;}static
const
k3
M4b[]={{"concat",S2b},{"foreach",C0b},{"foreachi",c_b},{"getn",i5b},{"setn",H5b},{"sort",N4b},{"insert",D0b},{"remove",G0b},{NULL,NULL}};P
int
v8(a*L){y2(L,W8a,M4b,0);return
1;}
#define h0c
#ifdef X4b
#define a_(L,i) N(L,g_(U,(i)))
static
a*c9a=NULL;int
D6b=0;
#define n_a(L,k) (L->ci->k_+(k)-1)
static
void
z5(a*L,const
char*b_,int
y6){I(L,b_);a_(L,y6);Q0(L,-3);}
#define E0b 0x55
#ifndef EXTERNMEMCHECK
#define s8 (sizeof(p8))
#define G1a 16
#define J5a(b) (g_(char*,b)-s8)
#define Y1b(i4,W) (*g_(size_t*,i4)=W)
#define l_a(b,W) (W==(*g_(size_t*,J5a(b))))
#define C8a(mem,W) memset(mem,-E0b,W)
#else
#define s8 0
#define G1a 0
#define J5a(b) (b)
#define Y1b(i4,W)
#define l_a(b,W) (1)
#define C8a(mem,W)
#endif
unsigned
long
N5=0;unsigned
long
m4=0;unsigned
long
M9=0;unsigned
long
d8=ULONG_MAX;static
void*O3b(void*N_,size_t
W){void*b=J5a(N_);int
i;for(i=0;i<G1a;i++)H(*(g_(char*,b)+s8+W+i)==E0b+i);return
b;}static
void
e9a(void*N_,size_t
W){if(N_){H(l_a(N_,W));N_=O3b(N_,W);C8a(N_,W+s8+G1a);free(N_);N5--;m4-=W;}}void*W8b(void*N_,size_t
q4,size_t
W){H(q4==0||l_a(N_,q4));H(N_!=NULL||W>0);if(W==0){e9a(N_,q4);return
NULL;}else
if(W>q4&&m4+W-q4>d8)return
NULL;else{void*i4;int
i;size_t
A_b=s8+W+G1a;size_t
D3a=(q4<W)?q4:W;if(A_b<W)return
NULL;i4=malloc(A_b);if(i4==NULL)return
NULL;if(N_){memcpy(g_(char*,i4)+s8,N_,D3a);e9a(N_,q4);}C8a(g_(char*,i4)+s8+D3a,W-D3a);m4+=W;if(m4>M9)M9=m4;N5++;Y1b(i4,W);for(i=0;i<G1a;i++)*(g_(char*,i4)+s8+W+i)=g_(char,E0b+i);return
g_(char*,i4)+s8;}}static
char*x2b(E_*p,int
pc,char*p_){j_
i=p->q1[pc];h6
o=W_(i);const
char*b_=o5a[o];int
X_=S5a(p,pc);sprintf(p_,"(%4d) %4d - ",X_,pc);switch(V_a(o)){case
U3:sprintf(p_+strlen(p_),"%-12s%4d %4d %4d",b_,A3(i),d2(i),b3(i));break;case
N3a:sprintf(p_+strlen(p_),"%-12s%4d %4d",b_,A3(i),D7(i));break;case
c6a:sprintf(p_+strlen(p_),"%-12s%4d %4d",b_,A3(i),V3(i));break;}return
p_;}
#if 0
void
K8b(E_*pt,int
W){int
pc;for(pc=0;pc<W;pc++){char
p_[100];printf("%s\n",x2b(pt,pc,p_));}printf("-------\n");}
#endif
static
int
I6b(a*L){int
pc;E_*p;f0(L,g2(L,1)&&!O3(L,1),1,"Lua function expected");p=D2(n_a(L,1))->l.p;U0(L);z5(L,"maxstack",p->c2);z5(L,"numparams",p->l7);for(pc=0;pc<p->K2;pc++){char
p_[100];a_(L,pc+1);I(L,x2b(p,pc,p_));Q0(L,-3);}return
1;}static
int
q_c(a*L){E_*p;int
i;f0(L,g2(L,1)&&!O3(L,1),1,"Lua function expected");p=D2(n_a(L,1))->l.p;U0(L);for(i=0;i<p->j9;i++){a_(L,i+1);H4(L,p->k+i);Q0(L,-3);}return
1;}static
int
M3b(a*L){E_*p;int
pc=Y_(L,2)-1;int
i=0;const
char*b_;f0(L,g2(L,1)&&!O3(L,1),1,"Lua function expected");p=D2(n_a(L,1))->l.p;while((b_=U4(p,++i,pc))!=NULL)I(L,b_);return
i-1;}static
int
J2b(a*L){U0(L);z5(L,"BITS_INT",BITS_INT);z5(L,"LFPF",V4);z5(L,"MAXVARS",g6a);z5(L,"MAXPARAMS",v5a);z5(L,"MAXSTACK",w2);z5(L,"MAXUPVALUES",S_a);return
1;}static
int
C5b(a*L){if(i3(L,1)){a_(L,m4);a_(L,N5);a_(L,M9);return
3;}else{d8=Y_(L,1);return
0;}}static
int
e3b(a*L){if(i3(L,2)){f0(L,f2(L,1)==u1,1,"string expected");a_(L,q2(n_a(L,1))->x6.i2);}else{E*o=n_a(L,1);p0*t;G_(L,2,H_);t=m1(n_a(L,2));a_(L,Z3(t,o)-t->h3);}return
1;}static
int
J3b(a*L){unsigned
long
a=0;a_(L,(int)(L->X-L->l_));a_(L,(int)(L->x5-L->l_));a_(L,(int)(L->ci-L->O0));a_(L,(int)(L->S7a-L->O0));a_(L,(unsigned
long)&a);return
5;}static
int
U1b(a*L){const
p0*t;int
i=c1(L,2,-1);G_(L,1,H_);t=m1(n_a(L,1));if(i==-1){a_(L,t->O1);a_(L,q5(t));a_(L,t->w7-t->h3);}else
if(i<t->O1){a_(L,i);H4(L,&t->w0[i]);w_(L);}else
if((i-=t->O1)<q5(t)){if(!I0(D4(r5(t,i)))||I0(l4(r5(t,i)))||Y0(l4(r5(t,i)))){H4(L,l4(r5(t,i)));}else
I(L,"<undef>");H4(L,D4(r5(t,i)));if(t->h3[i].h_)a_(L,t->h3[i].h_-t->h3);else
w_(L);}return
3;}static
int
I_b(a*L){k8*tb=&G(L)->f7;int
s=c1(L,2,0)-1;if(s==-1){a_(L,tb->N6a);a_(L,tb->W);return
2;}else
if(s<tb->W){u_*ts;int
n=0;for(ts=tb->i2[s];ts;ts=ts->E3.h_){G3(L->X,d6a(ts));W3(L);n++;}return
n;}return
0;}static
int
v0c(a*L){int
z_=D_(L);int
q0b=c1(L,2,1);B0(L,1);Y(L,1);a_(L,d8b(L,q0b));assert(D_(L)==z_+1);return
1;}static
int
G9b(a*L){int
z_=D_(L);L2b(L,Y_(L,1));assert(D_(L)==z_+1);return
1;}static
int
H_c(a*L){int
z_=D_(L);q5b(L,Y_(L,1));assert(D_(L)==z_);return
0;}static
int
r_(a*L){B0(L,1);if(i3(L,2)){if(X2(L,1)==0)w_(L);}else{J0(L,2);G_(L,2,H_);Z2(L,1);}return
1;}static
int
J4(a*L){int
n=Y_(L,2);G_(L,1,e0);if(i3(L,3)){const
char*b_=t_a(L,1,n);if(b_==NULL)return
0;I(L,b_);return
2;}else{const
char*b_=h_a(L,1,n);I(L,b_);return
1;}}static
int
g1b(a*L){size_t
W=Y_(L,1);char*p=g_(char*,E5(L,W));while(W--)*p++='\0';return
1;}static
int
Z0b(a*L){E1(L,g_(void*,Y_(L,1)));return
1;}static
int
g6b(a*L){a_(L,g_(int,b2(L,1)));return
1;}static
int
I0b(a*L){a*L1=D0a(L);size_t
l;const
char*s=y_(L,1,&l);int
T=l3(L1,s,l,s);if(T==0)T=B4(L1,0,0,0);a_(L,T);return
1;}static
int
s2d(a*L){N(L,*g_(const
double*,Q(L,1)));return
1;}static
int
d2s(a*L){double
d=d1(L,1);b1(L,g_(char*,&d),sizeof(d));return
1;}static
int
L6b(a*L){a*L1=i7a();if(L1){S4(L1);a_(L,(unsigned
long)L1);}else
w_(L);return
1;}static
int
a4(a*L){static
const
k3
k0c[]={{"mathlibopen",c2a},{"strlibopen",S7},{"iolibopen",O0a},{"tablibopen",v8},{"dblibopen",t8},{"baselibopen",A9},{NULL,NULL}};a*L1=g_(a*,g_(unsigned
long,d1(L,1)));Y(L1,b0);y2(L1,NULL,k0c,0);return
0;}static
int
k3b(a*L){a*L1=g_(a*,g_(unsigned
long,d1(L,1)));h2a(L1);f_(L);return
0;}static
int
X6b(a*L){a*L1=g_(a*,g_(unsigned
long,d1(L,1)));size_t
m_b;const
char*q1=y_(L,2,&m_b);int
T;J0(L1,0);T=l3(L1,q1,m_b,q1);if(T==0)T=B4(L1,0,B2,0);if(T!=0){w_(L);a_(L,T);I(L,o_(L1,-1));return
3;}else{int
i=0;while(!i3(L1,++i))I(L,o_(L1,i));V_(L1,i-1);return
i-1;}}static
int
J6b(a*L){a_(L,l0a(Y_(L,1)));return
1;}static
int
T2b(a*L){int
b=I2a(Y_(L,1));a_(L,b);a_(L,S4b(b));return
2;}static
int
M8b(a*L){const
char*p=Q(L,1);if(*p=='@')o7a(L,p+1);else
B1a(L,p);return
D_(L);}static
const
char*const
w0b=" \t\n,;";static
void
j2(const
char**pc){while(**pc!='\0'&&strchr(w0b,**pc))(*pc)++;}static
int
O2b(a*L,const
char**pc){int
i0=0;int
sig=1;j2(pc);if(**pc=='.'){i0=g_(int,F0(L,-1));V_(L,1);(*pc)++;return
i0;}else
if(**pc=='-'){sig=-1;(*pc)++;}while(isdigit(g_(int,**pc)))i0=i0*10+(*(*pc)++)-'0';return
sig*i0;}static
const
char*o1b(char*p_,const
char**pc){int
i=0;j2(pc);while(**pc!='\0'&&!strchr(w0b,**pc))p_[i++]=*(*pc)++;p_[i]='\0';return
p_;}
#define EQ(s1) (strcmp(s1,n0c)==0)
#define t0 (O2b(L,&pc))
#define e8b (o1b(p_,&pc))
static
int
o7b(a*L){char
p_[30];const
char*pc=Q(L,1);for(;;){const
char*n0c=e8b;if
EQ("")return
0;else
if
EQ("isnumber"){a_(L,x2(L,t0));}else
if
EQ("isstring"){a_(L,Z1(L,t0));}else
if
EQ("istable"){a_(L,z6a(L,t0));}else
if
EQ("iscfunction"){a_(L,O3(L,t0));}else
if
EQ("isfunction"){a_(L,g2(L,t0));}else
if
EQ("isuserdata"){a_(L,Y2a(L,t0));}else
if
EQ("isudataval"){a_(L,E4a(L,t0));}else
if
EQ("isnil"){a_(L,q3(L,t0));}else
if
EQ("isnull"){a_(L,i3(L,t0));}else
if
EQ("tonumber"){N(L,F0(L,t0));}else
if
EQ("tostring"){const
char*s=o_(L,t0);I(L,s);}else
if
EQ("strlen"){a_(L,S3(L,t0));}else
if
EQ("tocfunction"){e8(L,n2a(L,t0));}else
if
EQ("return"){return
t0;}else
if
EQ("gettop"){a_(L,D_(L));}else
if
EQ("settop"){J0(L,t0);}else
if
EQ("pop"){V_(L,t0);}else
if
EQ("pushnum"){a_(L,t0);}else
if
EQ("pushnil"){w_(L);}else
if
EQ("pushbool"){o0(L,t0);}else
if
EQ("tobool"){a_(L,Y1(L,t0));}else
if
EQ("pushvalue"){Y(L,t0);}else
if
EQ("pushcclosure"){A1(L,o7b,t0);}else
if
EQ("pushupvalues"){H8(L);}else
if
EQ("remove"){F5(L,t0);}else
if
EQ("insert"){C1(L,t0);}else
if
EQ("replace"){X5(L,t0);}else
if
EQ("gettable"){s6(L,t0);}else
if
EQ("settable"){Q0(L,t0);}else
if
EQ("next"){W3a(L,-2);}else
if
EQ("concat"){T3(L,t0);}else
if
EQ("lessthan"){int
a=t0;o0(L,O1a(L,a,t0));}else
if
EQ("equal"){int
a=t0;o0(L,k9a(L,a,t0));}else
if
EQ("rawcall"){int
Q1=t0;int
n7a=t0;j4(L,Q1,n7a);}else
if
EQ("call"){int
Q1=t0;int
n7a=t0;B4(L,Q1,n7a,0);}else
if
EQ("loadstring"){size_t
sl;const
char*s=y_(L,t0,&sl);l3(L,s,sl,s);}else
if
EQ("loadfile"){O4(L,Q(L,t0));}else
if
EQ("setmetatable"){Z2(L,t0);}else
if
EQ("getmetatable"){if(X2(L,t0)==0)w_(L);}else
if
EQ("type"){I(L,o7(L,f2(L,t0)));}else
if
EQ("getn"){int
i=t0;a_(L,S8(L,i));}else
if
EQ("setn"){int
i=t0;int
n=g_(int,F0(L,-1));Y8(L,i,n);V_(L,1);}else
s_(L,"unknown instruction %s",p_);}return
0;}static
void
N9b(a*L,D0*ar){O4a(L,0);}static
int
B6b(a*L){if(M1(L,1))Q5(L,NULL,0,0);else{const
char*Y7=Q(L,1);int
z1=c1(L,2,0);int
K4=0;if(strchr(Y7,'l'))K4|=u6;if(z1>0)K4|=T6;Q5(L,N9b,K4,z1);}return
0;}static
int
A6b(a*L){int
T;a*co=q6(L,1);f0(L,co,1,"coroutine expected");T=z3a(co,0);if(T!=0){o0(L,0);C1(L,-2);return
2;}else{o0(L,1);return
1;}}static
const
struct
k3
s1b[]={{"hash",e3b},{"limits",J2b},{"listcode",I6b},{"listk",q_c},{"listlocals",M3b},{"loadlib",a4},{"stacklevel",J3b},{"querystr",I_b},{"querytab",U1b},{"doit",M8b},{"testC",o7b},{"ref",v0c},{"getref",G9b},{"unref",H_c},{"d2s",d2s},{"s2d",s2d},{"metatable",r_},{"upvalue",J4},{"newuserdata",g1b},{"pushuserdata",Z0b},{"udataval",g6b},{"doonnewstack",I0b},{"newstate",L6b},{"closestate",k3b},{"doremote",X6b},{"log2",J6b},{"int2fb",T2b},{"totalmem",C5b},{"resume",A6b},{"setyhook",B6b},{NULL,NULL}};static
void
fim(void){if(!D6b)h2a(c9a);H(N5==0);H(m4==0);}static
int
h8b(a*L){P2a(L);fprintf(stderr,"unable to recover; exiting\n");return
0;}int
y8b(a*L){m6a(L,h8b);S4(L);c9a=L;y2(L,"T",s1b,0);atexit(fim);return
0;}
#undef main
int
main(int
J_b,char*u3[]){char*Q2=getenv("MEMLIMIT");if(Q2)d8=strtoul(Q2,NULL,10);E0c(J_b,u3);return
0;}
#endif
#define M0c
const
char*const
g6[]={"nil","boolean","userdata","number","string","table","function","userdata","thread"};void
v9a(a*L){static
const
char*const
K8a[]={"__index","__newindex","__gc","__mode","__eq","__add","__sub","__mul","__div","__pow","__unm","__lt","__le","__concat","__call"};int
i;for(i=0;i<x9b;i++){G(L)->u5a[i]=T5(L,K8a[i]);U6a(G(L)->u5a[i]);}}const
E*l8a(p0*M_b,TMS
S2,A_*y7a){const
E*tm=t4(M_b,y7a);H(S2<=a3b);if(I0(tm)){M_b->E3a|=g_(T_,1u<<S2);return
NULL;}else
return
tm;}const
E*n3(a*L,const
E*o,TMS
S2){A_*y7a=G(L)->u5a[S2];switch(V0(o)){case
H_:return
t4(m1(o)->r_,y7a);case
f1:return
t4(f0a(o)->uv.r_,y7a);default:return&E2;}}
#define L0c
#ifdef P7b
#include P7b
#endif
#ifdef _POSIX_C_SOURCE
#define L4a() isatty(0)
#else
#define L4a() 1
#endif
#ifndef s5b
#define s5b "> "
#endif
#ifndef F2b
#define F2b ">> "
#endif
#ifndef f1b
#define f1b "lua"
#endif
#ifndef W4a
#define W4a(L) m1b(L)
#endif
#ifndef r4a
#define r4a
#endif
static
a*L=NULL;static
const
char*C6=f1b;P
int
A4a(a*L);static
const
k3
c8b[]={{"base",A9},{"table",v8},{"io",O0a},{"string",S7},{"debug",t8},{"loadlib",r2a},{"posix",A4a},r4a{NULL,NULL}};static
void
y7b(a*l,D0*ar){(void)ar;Q5(l,NULL,0,0);s_(l,"interrupted!");}static
void
I8b(int
i){signal(i,SIG_DFL);Q5(L,y7b,y7|P_a|T6,1);}static
void
y_a(void){fprintf(stderr,"usage: %s [options] [script [args]].\n""Available options are:\n""  -        execute stdin as a file\n""  -e stat  execute string `stat'\n""  -i       enter interactive mode after executing `script'\n""  -l name  load and run library `name'\n""  -v       show version information\n""  --       stop handling options\n",C6);}static
void
P8(const
char*s7b,const
char*W6){if(s7b)fprintf(stderr,"%s: ",s7b);fprintf(stderr,"%s\n",W6);}static
int
K4a(int
T){const
char*W6;if(T){W6=o_(L,-1);if(W6==NULL)W6="(error with no message)";P8(C6,W6);V_(L,1);}return
T;}static
int
M2b(int
Q1,int
S0a){int
T;int
k_=D_(L)-Q1;e_(L,"_TRACEBACK");z0(L,b0);C1(L,k_);signal(SIGINT,I8b);T=B4(L,Q1,(S0a?0:B2),k_);signal(SIGINT,SIG_DFL);F5(L,k_);return
T;}static
void
q4a(void){P8(NULL,g8"  "v4a);}static
void
S7b(char*u3[],int
n){int
i;U0(L);for(i=0;u3[i];i++){N(L,i-n);I(L,u3[i]);G0(L,-3);}e_(L,"n");N(L,i-n-1);G0(L,-3);}static
int
p4b(int
T){if(T==0)T=M2b(0,1);return
K4a(T);}static
int
Q9(const
char*b_){return
p4b(O4(L,b_));}static
int
U_b(const
char*s,const
char*b_){return
p4b(l3(L,s,strlen(s),b_));}static
int
V4b(const
char*b_){e_(L,"require");z0(L,b0);if(!g2(L,-1)){V_(L,1);return
Q9(b_);}else{I(L,b_);return
K4a(M2b(1,1));}}
#ifndef i5a
#define i5a(L,X_)
#endif
#ifndef b2a
#define b2a(L,N5a) U6b(L,N5a)
#ifndef D_b
#define D_b 512
#endif
static
int
U6b(a*l,const
char*N5a){static
char
c0[D_b];if(N5a){fputs(N5a,stdout);fflush(stdout);}if(fgets(c0,sizeof(c0),stdin)==NULL)return
0;else{I(l,c0);return
1;}}
#endif
static
const
char*x7a(int
t9a){const
char*p=NULL;I(L,t9a?"_PROMPT":"_PROMPT2");z0(L,b0);p=o_(L,-1);if(p==NULL)p=(t9a?s5b:F2b);V_(L,1);return
p;}static
int
j3b(int
T){if(T==E0a&&strstr(o_(L,-1),"near `<eof>'")!=NULL){V_(L,1);return
1;}else
return
0;}static
int
n1b(void){int
T;J0(L,0);if(b2a(L,x7a(1))==0)return-1;if(o_(L,-1)[0]=='='){P_(L,"return %s",o_(L,-1)+1);F5(L,-2);}for(;;){T=l3(L,o_(L,1),S3(L,1),"=stdin");if(!j3b(T))break;if(b2a(L,x7a(0))==0)return-1;T3(L,D_(L));}i5a(L,o_(L,1));F5(L,1);return
T;}static
void
k5a(void){int
T;const
char*O1b=C6;C6=NULL;while((T=n1b())!=-1){if(T==0)T=M2b(0,0);K4a(T);if(T==0&&D_(L)>0){t5(L,"print");C1(L,1);if(B4(L,D_(L)-1,0,0)!=0)P8(C6,P_(L,"error calling `print' (%s)",o_(L,-1)));}}J0(L,0);fputs("\n",stdout);C6=O1b;}static
int
v1b(char*u3[],int*K_a){if(u3[1]==NULL){if(L4a()){q4a();k5a();}else
Q9(NULL);}else{int
i;for(i=1;u3[i]!=NULL;i++){if(u3[i][0]!='-')break;switch(u3[i][1]){case'-':{if(u3[i][2]!='\0'){y_a();return
1;}i++;goto
E8a;}case'\0':{Q9(NULL);break;}case'i':{*K_a=1;break;}case'v':{q4a();break;}case'e':{const
char*s5=u3[i]+2;if(*s5=='\0')s5=u3[++i];if(s5==NULL){y_a();return
1;}if(U_b(s5,"=<command line>")!=0)return
1;break;}case'l':{const
char*Q_=u3[i]+2;if(*Q_=='\0')Q_=u3[++i];if(Q_==NULL){y_a();return
1;}if(V4b(Q_))return
1;break;}case'c':{P8(C6,"option `-c' is deprecated");break;}case's':{P8(C6,"option `-s' is deprecated");break;}default:{y_a();return
1;}}}E8a:if(u3[i]!=NULL){const
char*Q_=u3[i];S7b(u3,i);B8(L,"arg");if(strcmp(Q_,"/dev/stdin")==0)Q_=NULL;return
Q9(Q_);}}return
0;}static
void
m1b(a*l){const
k3*h8=c8b;for(;h8->a0;h8++){h8->a0(l);J0(l,0);}}static
int
Q8a(void){const
char*I1=getenv("LUA_INIT");if(I1==NULL)return
0;else
if(I1[0]=='@')return
Q9(I1+1);else
return
U_b(I1,"=LUA_INIT");}struct
z3b{int
J_b;char**u3;int
T;};static
int
s_c(a*l){struct
z3b*s=(struct
z3b*)b2(l,1);int
T;int
K_a=0;if(s->u3[0]&&s->u3[0][0])C6=s->u3[0];L=l;W4a(l);T=Q8a();if(T==0){T=v1b(s->u3,&K_a);if(T==0&&K_a)k5a();}s->T=T;return
0;}int
main(int
J_b,char*u3[]){int
T;struct
z3b
s;a*l=i7a();if(l==NULL){P8(u3[0],"cannot create state: not enough memory");return
EXIT_FAILURE;}s.J_b=J_b;s.u3=u3;T=N7a(l,&s_c,&s);K4a(T);h2a(l);return(T||s.T)?EXIT_FAILURE:EXIT_SUCCESS;}
#define W_c
#define u7 (T_)i8a
typedef
struct{a*L;h9*Z;m6*b;int
D8a;const
char*b_;}w1;static
void
i4a(w1*S){q_(S->L,"unexpected end of file in %s",S->b_);}static
int
i8a(w1*S){int
c=G7b(S->Z);if(c==EOZ)i4a(S);return
c;}static
void
O0b(w1*S,void*b,int
n){int
r=b9a(S->Z,b,n);if(r!=0)i4a(S);}static
void
K5a(w1*S,void*b,size_t
W){if(S->D8a){char*p=(char*)b+W-1;int
n=W;while(n--)*p--=(char)i8a(S);}else
O0b(S,b,W);}static
void
T7a(w1*S,void*b,int
m,size_t
W){if(S->D8a){char*q=(char*)b;while(m--){char*p=q+W-1;int
n=W;while(n--)*p--=(char)i8a(S);q+=W;}}else
O0b(S,b,m*W);}static
int
X7(w1*S){int
x;K5a(S,&x,sizeof(x));if(x<0)q_(S->L,"bad integer in %s",S->b_);return
x;}static
size_t
X5b(w1*S){size_t
x;K5a(S,&x,sizeof(x));return
x;}static
U
s7a(w1*S){U
x;K5a(S,&x,sizeof(x));return
x;}static
A_*U0a(w1*S){size_t
W=X5b(S);if(W==0)return
NULL;else{char*s=W7(S->L,S->b,W);O0b(S,s,W);return
W2(S->L,s,W-1);}}static
void
f6b(w1*S,E_*f){int
W=X7(S);f->q1=F2(S->L,W,j_);f->K2=W;T7a(S,f->q1,W,sizeof(*f->q1));}static
void
c3b(w1*S,E_*f){int
i,n;n=X7(S);f->s3=F2(S->L,n,d3a);f->r4=n;for(i=0;i<n;i++){f->s3[i].O2=U0a(S);f->s3[i].V2a=X7(S);f->s3[i].o_b=X7(S);}}static
void
D5b(w1*S,E_*f){int
W=X7(S);f->n4=F2(S->L,W,int);f->t3=W;T7a(S,f->n4,W,sizeof(*f->n4));}static
void
y0b(w1*S,E_*f){int
i,n;n=X7(S);if(n!=0&&n!=f->k5)q_(S->L,"bad nupvalues in %s: read %d; expected %d",S->b_,n,f->k5);f->k0=F2(S->L,n,A_*);f->K3=n;for(i=0;i<n;i++)f->k0[i]=U0a(S);}static
E_*W1a(w1*S,A_*p);static
void
j_b(w1*S,E_*f){int
i,n;n=X7(S);f->k=F2(S->L,n,E);f->j9=n;for(i=0;i<n;i++){E*o=&f->k[i];int
t=u7(S);switch(t){case
P1:N1(o,s7a(S));break;case
u1:y1b(o,U0a(S));break;case
W5:S_(o);break;default:q_(S->L,"bad constant type (%d) in %s",t,S->b_);break;}}n=X7(S);f->p=F2(S->L,n,E_*);f->Q0a=n;for(i=0;i<n;i++)f->p[i]=W1a(S,f->n0);}static
E_*W1a(w1*S,A_*p){E_*f=u0a(S->L);f->n0=U0a(S);if(f->n0==NULL)f->n0=p;f->i8=X7(S);f->k5=u7(S);f->l7=u7(S);f->T8=u7(S);f->c2=u7(S);D5b(S,f);c3b(S,f);y0b(S,f);j_b(S,f);f6b(S,f);
#ifndef o8b
if(!L7(f))q_(S->L,"bad code in %s",S->b_);
#endif
return
f;}static
void
U9a(w1*S){const
char*s=u8;while(*s!=0&&i8a(S)==*s)++s;if(*s!=0)q_(S->L,"bad signature in %s",S->b_);}static
void
b6b(w1*S,int
s,const
char*v3){int
r=u7(S);if(r!=s)q_(S->L,"virtual machine mismatch in %s: ""size of %s is %d but read %d",S->b_,v3,s,r);}
#define r7(s,w) b6b(S,s,w)
#define V(v) v/16,v%16
static
void
D3b(w1*S){int
version;U
x,tx=q6a;U9a(S);version=u7(S);if(version>S8a)q_(S->L,"%s too new: ""read version %d.%d; expected at most %d.%d",S->b_,V(version),V(S8a));if(version<Z_b)q_(S->L,"%s too old: ""read version %d.%d; expected at least %d.%d",S->b_,V(version),V(Z_b));S->D8a=(b_a()!=u7(S));r7(sizeof(int),"int");r7(sizeof(size_t),"size_t");r7(sizeof(j_),"Instruction");r7(e3a,"OP");r7(C5a,"A");r7(e0a,"B");r7(X_a,"C");r7(sizeof(U),"number");x=s7a(S);if((long)x!=(long)tx)q_(S->L,"unknown number format in %s",S->b_);}static
E_*W4b(w1*S){D3b(S);return
W1a(S,NULL);}E_*r6a(a*L,h9*Z,m6*p_){w1
S;const
char*s=m7b(Z);if(*s=='@'||*s=='=')S.b_=s+1;else
if(*s==u8[0])S.b_="binary string";else
S.b_=s;S.L=L;S.Z=Z;S.b=p_;return
W4b(&S);}int
b_a(void){int
x=1;return*(char*)&x;}
#define K0c
#ifndef r_a
#define r_a(s,n) sprintf((s),U7,(n))
#endif
#define A7a 100
const
E*P6(const
E*U1,E*n){U
num;if(Y0(U1))return
U1;if(r1(U1)&&P3a(r9(U1),&num)){N1(n,num);return
n;}else
return
NULL;}int
w5(a*L,t_
U1){if(!Y0(U1))return
0;else{char
s[32];r_a(s,s0(U1));G3(U1,T5(L,s));return
1;}}static
void
m5b(a*L){T_
K4=L->J6;if(K4&T6){if(L->t5a==0){i_a(L);N4(L,j4a,-1);return;}}if(K4&u6){m0*ci=L->ci;E_*p=Z0a(ci)->l.p;int
U5a=S5a(p,s_b(*ci->u.l.pc,p));if(!L->s3a){o3a(L);return;}H(ci->h0&c7);if(s_b(*ci->u.l.pc,p)==0)ci->u.l.n2=*ci->u.l.pc;if(*ci->u.l.pc<=ci->u.l.n2||U5a!=S5a(p,s_b(ci->u.l.n2,p))){N4(L,V4a,U5a);ci=L->ci;}ci->u.l.n2=*ci->u.l.pc;}}static
void
f9(a*L,const
E*f,const
E*p1,const
E*p2){l0(L->X,f);l0(L->X+1,p1);l0(L->X+2,p2);N2(L,3);L->X+=3;A5(L,L->X-3,1);L->X--;}static
void
L9b(a*L,const
E*f,const
E*p1,const
E*p2,const
E*p3){l0(L->X,f);l0(L->X+1,p1);l0(L->X+2,p2);l0(L->X+3,p3);N2(L,4);L->X+=4;A5(L,L->X-4,0);}static
const
E*M0a(a*L,const
E*t,E*x_,int
X4){const
E*tm=m3a(L,m1(t)->r_,M0b);if(tm==NULL)return&E2;if(a2(tm)){f9(L,tm,t,x_);return
L->X;}else
return
x8(L,tm,x_,X4);}static
const
E*t9(a*L,const
E*t,E*x_,int
X4){const
E*tm=n3(L,t,M0b);if(I0(tm))j5(L,t,"index");if(a2(tm)){f9(L,tm,t,x_);return
L->X;}else
return
x8(L,tm,x_,X4);}const
E*x8(a*L,const
E*t,E*x_,int
X4){if(X4>A7a)q_(L,"loop in gettable");if(I2(t)){p0*h=m1(t);const
E*v=x7(h,x_);if(!I0(v))return
v;else
return
M0a(L,t,x_,X4+1);}else
return
t9(L,t,x_,X4+1);}void
z8(a*L,const
E*t,E*x_,t_
y6){const
E*tm;int
X4=0;do{if(I2(t)){p0*h=m1(t);E*d5b=s_a(L,h,x_);if(!I0(d5b)||(tm=m3a(L,h->r_,A6a))==NULL){C1a(d5b,y6);return;}}else
if(I0(tm=n3(L,t,A6a)))j5(L,t,"index");if(a2(tm)){L9b(L,tm,t,x_,y6);return;}t=tm;}while(++X4<=A7a);q_(L,"loop in settable");}static
int
t3a(a*L,const
E*p1,const
E*p2,t_
i0,TMS
S2){ptrdiff_t
J1=A4(L,i0);const
E*tm=n3(L,p1,S2);if(I0(tm))tm=n3(L,p2,S2);if(!a2(tm))return
0;f9(L,tm,p1,p2);i0=a3(L,J1);i1(i0,L->X);return
1;}static
const
E*f8a(a*L,p0*mt1,p0*mt2,TMS
S2){const
E*tm1=m3a(L,mt1,S2);const
E*tm2;if(tm1==NULL)return
NULL;if(mt1==mt2)return
tm1;tm2=m3a(L,mt2,S2);if(tm2==NULL)return
NULL;if(y3(tm1,tm2))return
tm1;return
NULL;}static
int
S1a(a*L,const
E*p1,const
E*p2,TMS
S2){const
E*tm1=n3(L,p1,S2);const
E*tm2;if(I0(tm1))return-1;tm2=n3(L,p2,S2);if(!y3(tm1,tm2))return-1;f9(L,tm1,p1,p2);return!p0a(L->X);}static
int
K6a(const
A_*O,const
A_*rs){const
char*l=I5(O);size_t
ll=O->x6.G1;const
char*r=I5(rs);size_t
lr=rs->x6.G1;for(;;){int
g7=strcoll(l,r);if(g7!=0)return
g7;else{size_t
G1=strlen(l);if(G1==lr)return(G1==ll)?0:1;else
if(G1==ll)return-1;G1++;l+=G1;ll-=G1;r+=G1;lr-=G1;}}}int
A0a(a*L,const
E*l,const
E*r){int
i0;if(V0(l)!=V0(r))return
G5(L,l,r);else
if(Y0(l))return
s0(l)<s0(r);else
if(r1(l))return
K6a(q2(l),q2(r))<0;else
if((i0=S1a(L,l,r,B7b))!=-1)return
i0;return
G5(L,l,r);}static
int
F8a(a*L,const
E*l,const
E*r){int
i0;if(V0(l)!=V0(r))return
G5(L,l,r);else
if(Y0(l))return
s0(l)<=s0(r);else
if(r1(l))return
K6a(q2(l),q2(r))<=0;else
if((i0=S1a(L,l,r,r_c))!=-1)return
i0;else
if((i0=S1a(L,r,l,B7b))!=-1)return!i0;return
G5(L,l,r);}int
m4a(a*L,const
E*t1,const
E*t2){const
E*tm;H(V0(t1)==V0(t2));switch(V0(t1)){case
W5:return
1;case
P1:return
s0(t1)==s0(t2);case
l5:return
g3a(t1)==g3a(t2);case
K1:return
S2a(t1)==S2a(t2);case
f1:{if(f0a(t1)==f0a(t2))return
1;tm=f8a(L,f0a(t1)->uv.r_,f0a(t2)->uv.r_,a3b);break;}case
H_:{if(m1(t1)==m1(t2))return
1;tm=f8a(L,m1(t1)->r_,m1(t2)->r_,a3b);break;}default:return
P7(t1)==P7(t2);}if(tm==NULL)return
0;f9(L,tm,t1,t2);return!p0a(L->X);}void
F_a(a*L,int
K0a,int
L2){do{t_
X=L->k_+L2+1;int
n=2;if(!V6a(L,X-2)||!V6a(L,X-1)){if(!t3a(L,X-2,X-1,X-2,J4b))t1a(L,X-2,X-1);}else
if(q2(X-1)->x6.G1>0){k2
tl=g_(k2,q2(X-1)->x6.G1)+g_(k2,q2(X-2)->x6.G1);char*c0;int
i;while(n<K0a&&V6a(L,X-n-1)){tl+=q2(X-n-1)->x6.G1;n++;}if(tl>i9a)q_(L,"string size overflow");c0=W7(L,&G(L)->p_,tl);tl=0;for(i=n;i>0;i--){size_t
l=q2(X-i)->x6.G1;memcpy(c0+tl,r9(X-i),l);tl+=l;}G3(X-n,W2(L,c0,tl));}K0a-=n-1;L2-=n-1;}while(K0a>1);}static
void
z7a(a*L,t_
ra,const
E*rb,const
E*rc,TMS
op){E
J_c,I_c;const
E*b,*c;if((b=P6(rb,&J_c))!=NULL&&(c=P6(rc,&I_c))!=NULL){switch(op){case
P4b:N1(ra,s0(b)+s0(c));break;case
k5b:N1(ra,s0(b)-s0(c));break;case
h5b:N1(ra,s0(b)*s0(c));break;case
A4b:N1(ra,s0(b)/s0(c));break;case
d0b:{const
E*f=t4(m1(gt(L)),G(L)->u5a[d0b]);ptrdiff_t
i0=A4(L,ra);if(!a2(f))q_(L,"`__pow' (`^' operator) is not a function");f9(L,f,b,c);ra=a3(L,i0);i1(ra,L->X);break;}default:H(0);break;}}else
if(!t3a(L,rb,rc,ra,op))n9(L,rb,rc);}
#define y4a(L,c) {if(!(c))return 0;}
#define RA(i) (k_+A3(i))
#define XRA(i) (L->k_+A3(i))
#define RB(i) (k_+d2(i))
#define RKB(i) ((d2(i)<w2)?RB(i):k+d2(i)-w2)
#define RC(i) (k_+b3(i))
#define RKC(i) ((b3(i)<w2)?RC(i):k+b3(i)-w2)
#define KBx(i) (k+D7(i))
#define a0a(pc,i) ((pc)+=(i))
t_
v6(a*L){P1a*cl;E*k;const
j_*pc;a4b:if(L->J6&y7){L->ci->u.l.pc=&pc;N4(L,L1a,-1);}V6b:L->ci->u.l.pc=&pc;H(L->ci->h0==f3||L->ci->h0==(f3|P9));L->ci->h0=c7;pc=L->ci->u.l.n2;cl=&D2(L->k_-1)->l;k=cl->p->k;for(;;){const
j_
i=*pc++;t_
k_,ra;if((L->J6&(u6|T6))&&(--L->t5a==0||L->J6&u6)){m5b(L);if(L->ci->h0&D8){L->ci->u.l.n2=pc-1;L->ci->h0=D8|f3;return
NULL;}}k_=L->k_;ra=RA(i);H(L->ci->h0&c7);H(k_==L->ci->k_);H(L->X<=L->l_+L->H2&&L->X>=k_);H(L->X==L->ci->X||W_(i)==I4||W_(i)==c5||W_(i)==d5||W_(i)==j8);switch(W_(i)){case
c9:{i1(ra,RB(i));break;}case
c4a:{l0(ra,KBx(i));break;}case
o8:{l2a(ra,d2(i));if(b3(i))pc++;break;}case
F9:{E*rb=RB(i);do{S_(rb--);}while(rb>=ra);break;}case
P5:{int
b=d2(i);l0(ra,cl->d2a[b]->v);break;}case
H7:{E*rb=KBx(i);const
E*v;H(r1(rb)&&I2(&cl->g));v=t4(m1(&cl->g),q2(rb));if(!I0(v)){l0(ra,v);}else
l0(XRA(i),M0a(L,&cl->g,rb,0));break;}case
I_a:{t_
rb=RB(i);E*rc=RKC(i);if(I2(rb)){const
E*v=x7(m1(rb),rc);if(!I0(v)){l0(ra,v);}else
l0(XRA(i),M0a(L,rb,rc,0));}else
l0(XRA(i),t9(L,rb,rc,0));break;}case
U9:{H(r1(KBx(i))&&I2(&cl->g));z8(L,&cl->g,KBx(i),ra);break;}case
A_a:{int
b=d2(i);O9(cl->d2a[b]->v,ra);break;}case
O_a:{z8(L,ra,RKB(i),RKC(i));break;}case
H2a:{int
b=d2(i);b=S4b(b);z6(ra,E7(L,b,b3(i)));B1(L);break;}case
Q2a:{t_
rb=RB(i);E*rc=RKC(i);y4a(L,r1(rc));i1(ra+1,rb);if(I2(rb)){const
E*v=t4(m1(rb),q2(rc));if(!I0(v)){l0(ra,v);}else
l0(XRA(i),M0a(L,rb,rc,0));}else
l0(XRA(i),t9(L,rb,rc,0));break;}case
H0b:{E*rb=RKB(i);E*rc=RKC(i);if(Y0(rb)&&Y0(rc)){N1(ra,s0(rb)+s0(rc));}else
z7a(L,ra,rb,rc,P4b);break;}case
t0b:{E*rb=RKB(i);E*rc=RKC(i);if(Y0(rb)&&Y0(rc)){N1(ra,s0(rb)-s0(rc));}else
z7a(L,ra,rb,rc,k5b);break;}case
T4b:{E*rb=RKB(i);E*rc=RKC(i);if(Y0(rb)&&Y0(rc)){N1(ra,s0(rb)*s0(rc));}else
z7a(L,ra,rb,rc,h5b);break;}case
c4b:{E*rb=RKB(i);E*rc=RKC(i);if(Y0(rb)&&Y0(rc)){N1(ra,s0(rb)/s0(rc));}else
z7a(L,ra,rb,rc,A4b);break;}case
q4b:{z7a(L,ra,RKB(i),RKC(i),d0b);break;}case
Y0b:{const
E*rb=RB(i);E
g7;if(v1a(rb,&g7)){N1(ra,-s0(rb));}else{S_(&g7);if(!t3a(L,RB(i),&g7,ra,T9b))n9(L,RB(i),&g7);}break;}case
d5a:{int
i0=p0a(RB(i));l2a(ra,i0);break;}case
d0a:{int
b=d2(i);int
c=b3(i);F_a(L,c-b+1,c);k_=L->k_;i1(RA(i),k_+b);B1(L);break;}case
I5a:{a0a(pc,V3(i));break;}case
x_b:{if(L0b(L,RKB(i),RKC(i))!=A3(i))pc++;else
a0a(pc,V3(*pc)+1);break;}case
p_b:{if(A0a(L,RKB(i),RKC(i))!=A3(i))pc++;else
a0a(pc,V3(*pc)+1);break;}case
r_b:{if(F8a(L,RKB(i),RKC(i))!=A3(i))pc++;else
a0a(pc,V3(*pc)+1);break;}case
w_a:{E*rb=RB(i);if(p0a(rb)==b3(i))pc++;else{i1(ra,rb);a0a(pc,V3(*pc)+1);}break;}case
I4:case
c5:{t_
E0;int
b=d2(i);int
A0;if(b!=0)L->X=ra+b;A0=b3(i)-1;E0=q7(L,ra);if(E0){if(E0>L->X){H(L->ci->h0==(Y1a|D8));(L->ci-1)->u.l.n2=pc;(L->ci-1)->h0=f3;return
NULL;}i6(L,A0,E0);if(A0>=0)L->X=L->ci->X;}else{if(W_(i)==I4){(L->ci-1)->u.l.n2=pc;(L->ci-1)->h0=(f3|P9);}else{int
B9;k_=(L->ci-1)->k_;ra=RA(i);if(L->w6)Y4(L,k_);for(B9=0;ra+B9<L->X;B9++)i1(k_+B9-1,ra+B9);(L->ci-1)->X=L->X=k_+B9;H(L->ci->h0&f3);(L->ci-1)->u.l.n2=L->ci->u.l.n2;(L->ci-1)->u.l.h0a++;(L->ci-1)->h0=f3;L->ci--;L->k_=L->ci->k_;}goto
a4b;}break;}case
d5:{m0*ci=L->ci-1;int
b=d2(i);if(b!=0)L->X=ra+b-1;H(L->ci->h0&c7);if(L->w6)Y4(L,k_);L->ci->h0=f3;L->ci->u.l.n2=pc;if(!(ci->h0&P9)){H((ci->h0&Y1a)||ci->u.l.pc!=&pc);return
ra;}else{int
A0;H(a2(ci->k_-1)&&(ci->h0&f3));H(W_(*(ci->u.l.n2-1))==I4);A0=b3(*(ci->u.l.n2-1))-1;i6(L,A0,ra);if(A0>=0)L->X=L->ci->X;goto
V6b;}}case
X0a:{U
o9,F_,Q2;const
E*O4b=ra+1;const
E*x7b=ra+2;if(!Y0(ra))q_(L,"`for' initial value must be a number");if(!v1a(O4b,ra+1))q_(L,"`for' limit must be a number");if(!v1a(x7b,ra+2))q_(L,"`for' step must be a number");o9=s0(x7b);F_=s0(ra)+o9;Q2=s0(O4b);if(o9>0?F_<=Q2:F_>=Q2){a0a(pc,V3(i));z4b(ra,F_);}break;}case
J_a:{int
X6a=b3(i)+1;t_
cb=ra+X6a+2;i1(cb,ra);i1(cb+1,ra+1);i1(cb+2,ra+2);L->X=cb+3;A5(L,cb,X6a);L->X=L->ci->X;ra=XRA(i)+2;cb=ra+X6a;do{X6a--;i1(ra+X6a,cb+X6a);}while(X6a>0);if(I0(ra))pc++;else
a0a(pc,V3(*pc)+1);break;}case
M2a:{if(I2(ra)){i1(ra+1,ra);l0(ra,t4(m1(gt(L)),T5(L,"next")));}a0a(pc,V3(i));break;}case
I6:case
j8:{int
bc;int
n;p0*h;y4a(L,I2(ra));h=m1(ra);bc=D7(i);if(W_(i)==I6)n=(bc&(V4-1))+1;else{n=L->X-ra-1;L->X=L->ci->X;}bc&=~(V4-1);for(;n>0;n--)C1a(r8(L,h,bc+n),ra+n);break;}case
Y3a:{Y4(L,ra);break;}case
V9:{E_*p;C2*ncl;int
nup,j;p=cl->p->p[D7(i)];nup=p->k5;ncl=M8(L,nup,&cl->g);ncl->l.p=p;for(j=0;j<nup;j++,pc++){if(W_(*pc)==P5)ncl->l.d2a[j]=cl->d2a[d2(*pc)];else{H(W_(*pc)==c9);ncl->l.d2a[j]=W2a(L,k_+d2(*pc));}}J0a(ra,ncl);B1(L);break;}}}}
#define F0c
int
C2a(h9*z){size_t
W;const
char*p_=z->m0a(NULL,z->e3,&W);if(p_==NULL||W==0)return
EOZ;z->n=W-1;z->p=p_;return
l7a(*(z->p++));}int
a3a(h9*z){if(z->n==0){int
c=C2a(z);if(c==EOZ)return
c;z->n++;z->p--;}return
l7a(*z->p);}void
p9a(h9*z,J5
m0a,void*e3,const
char*b_){z->m0a=m0a;z->e3=e3;z->b_=b_;z->n=0;z->p=NULL;}size_t
b9a(h9*z,void*b,size_t
n){while(n){size_t
m;if(z->n==0){if(C2a(z)==EOZ)return
n;else{++z->n;--z->p;}}m=(n<=z->n)?n:z->n;memcpy(b,z->p,m);z->n-=m;z->p+=m;b=(char*)b+m;n-=m;}return
0;}char*W7(a*L,m6*p_,size_t
n){if(n>p_->O8){if(n<y8)n=y8;H0(L,p_->c0,p_->O8,n,char);p_->O8=n;}return
p_->c0;}
