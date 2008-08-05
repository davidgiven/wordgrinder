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
	extract_section 1178   23145  | "$PMEXEC" /dev/stdin "$@"
	exit $?
fi

# Otherwise, compile it and restart.

echo "pm: bootstrapping..."

if [ -x "$(which gcc 2>/dev/null)" ]; then
	CC="gcc -O -s"
else
	CC="cc"
fi

extract_section 24323  157694 > /tmp/pm-$$.c
$CC $CFILE -o "$PMEXEC" && exec "$0" "$@"

echo "pm: bootstrap failed."
exit 1
#!/usr/bin/lua
local VERSION="0.1.4"
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
#define Y_c
#ifndef E9b
#define E9b
#define K3a int
#define P9 "%d"
#define L7 "%d"
#define X7 "Lua 5.0.2 (patched for Prime Mover)"
#define f4a "Copyright (C) 1994-2004 Tecgraf, PUC-Rio"
#define M0b "R. Ierusalimschy, L. H. de Figueiredo & W. Celes"
#define y2 (-1)
#define L_ (-10000)
#define a0 (-10001)
#define O_(i) (a0-(i))
#define g3a 1
#define B_a 2
#define s0a 3
#define s3a 4
#define z0a 5
typedef
struct
a
a;typedef
int(*p0)(a*L);typedef
const
char*(*D5)(a*L,void*ud,size_t*sz);typedef
int(*x5)(a*L,const
void*p,size_t
sz,void*ud);
#define Y_a (-1)
#define P5 0
#define f5 1
#define I1 2
#define N1 3
#define q1 4
#define H_ 5
#define d0 6
#define c1 7
#define Y2 8
#define J3 20
#ifdef x9b
#include x9b
#endif
#ifndef K3a
typedef
double
U;
#else
typedef
K3a
U;
#endif
#ifndef K
#define K extern
#endif
K
a*P6a(void);K
void
T1a(a*L);K
a*r0a(a*L);K
p0
U5a(a*L,p0
R4b);K
int
D_(a*L);K
void
I0(a*L,int
F_);K
void
Y(a*L,int
F_);K
void
z5(a*L,int
F_);K
void
A1(a*L,int
F_);K
void
Q5(a*L,int
F_);K
int
A7(a*L,int
sz);K
void
X_a(a*U0,a*to,int
n);K
int
r2(a*L,int
F_);K
int
W1(a*L,int
F_);K
int
K3(a*L,int
F_);K
int
J2a(a*L,int
F_);K
int
b2(a*L,int
F_);K
const
char*g7(a*L,int
tp);K
int
P8a(a*L,int
H8b,int
D8b);K
int
g5a(a*L,int
H8b,int
D8b);K
int
B1a(a*L,int
H8b,int
D8b);K
U
E0(a*L,int
F_);K
int
V1(a*L,int
F_);K
const
char*o_(a*L,int
F_);K
size_t
N3(a*L,int
F_);K
p0
Z1a(a*L,int
F_);K
void*Y1(a*L,int
F_);K
a*j6(a*L,int
F_);K
const
void*f0a(a*L,int
F_);K
void
w_(a*L);K
void
N(a*L,U
n);K
void
Z0(a*L,const
char*s,size_t
l);K
void
I(a*L,const
char*s);K
const
char*W0a(a*L,const
char*K6,va_list
U4);K
const
char*P_(a*L,const
char*K6,...);K
void
x1(a*L,p0
fn,int
n);K
void
n0(a*L,int
b);K
void
C1(a*L,void*p);K
void
l6(a*L,int
F_);K
void
x0(a*L,int
F_);K
void
c0(a*L,int
F_,int
n);K
void
S0(a*L);K
void*y5(a*L,size_t
sz);K
int
T2(a*L,int
v1a);K
void
m6a(a*L,int
F_);K
void
P0(a*L,int
F_);K
void
F0(a*L,int
F_);K
void
D2(a*L,int
F_,int
n);K
int
V2(a*L,int
v1a);K
int
b6a(a*L,int
F_);K
void
e4(a*L,int
T4,int
z0);K
int
w4(a*L,int
T4,int
z0,int
k4);K
int
u7a(a*L,p0
Z_,void*ud);K
int
w1a(a*L,D5
a0a,void*dt,const
char*L8);K
int
C0b(a*L,x5
x7a,void*a3);K
int
y4a(a*L,int
z0);K
int
k3a(a*L,int
O1);K
int
b0a(a*L);K
int
I2a(a*L);K
void
H_a(a*L,int
F1a);K
const
char*g1b(void);K
int
N8(a*L);K
int
G3a(a*L,int
F_);K
void
O3(a*L,int
n);
#define G7b(L,u) (*(void**)(y5(L,sizeof(void*)))=(u))
#define H5b(L,i) (*(void**)(Y1(L,i)))
#define U_(L,n) I0(L,-(n)-1)
#define a0b(L,n,f) (I(L,n),V7(L,f),P0(L,a0))
#define V7(L,f) x1(L,f,0)
#define c2(L,n) (b2(L,n)==d0)
#define h6a(L,n) (b2(L,n)==H_)
#define o4a(L,n) (b2(L,n)==I1)
#define l3(L,n) (b2(L,n)==P5)
#define J9a(L,n) (b2(L,n)==f5)
#define e3(L,n) (b2(L,n)==Y_a)
#define J1(L,n) (b2(L,n)<=0)
#define e_(L,s) Z0(L,""s,(sizeof(s)/sizeof(char))-1)
K
int
y8(a*L);
#define J6b(L) Y(L,L_)
#define s8(L,s) (I(L,s),A1(L,-2),P0(L,a0))
#define n5(L,s) (I(L,s),l6(L,a0))
#define r_c (-2)
#define o2b (-1)
#define y7b(L,T_b) ((T_b)?N_b(L,L_):(I(L,"unlocked references are obsolete"),N8(L),0))
#define O4b(L,b7) M7a(L,L_,(b7))
#define m2b(L,b7) c0(L,L_,b7)
#ifndef P9
#define P9 "%lf"
#endif
#ifndef L7
#define L7 "%.14g"
#endif
#define y1a 0
#define d6a 1
#define E4a 2
#define T3a 3
#define e2a 4
#define q7 (1<<y1a)
#define E_a (1<<d6a)
#define n6 (1<<E4a)
#define L6 (1<<T3a)
typedef
struct
C0
C0;typedef
void(*w8)(a*L,C0*ar);K
int
P2(a*L,int
z_,C0*ar);K
int
L5(a*L,const
char*r3,C0*ar);K
const
char*D4a(a*L,const
C0*ar,int
n);K
const
char*p5a(a*L,const
C0*ar,int
n);K
const
char*i_a(a*L,int
h7,int
n);K
const
char*W9(a*L,int
h7,int
n);K
int
K5(a*L,w8
Z_,int
F4,int
w1);K
w8
o6a(a*L);K
int
g2a(a*L);K
int
U0a(a*L);
#define Y8 60
struct
C0{int
O2;const
char*b_;const
char*r7;const
char*r3;const
char*m0;int
x2;int
e5;int
Q6;char
T8[Y8];int
b5a;};
#endif
#ifndef G8b
#define G8b
#ifndef P4b
#define P4b
#ifndef U3b
#define U3b
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
U9;typedef
int
T_c;typedef
unsigned
long
h2;
#define K8a ULONG_MAX
typedef
long
o8a;typedef
unsigned
char
S_;
#define N8a ((size_t)(~(size_t)0)-2)
#define B7 (INT_MAX-2)
#define A5b(p) ((U9)(p))
#ifndef R5a
typedef
union{double
u;void*s;long
l;}g8;
#else
typedef
R5a
g8;
#endif
#ifndef u9a
typedef
double
V5a;
#else
typedef
u9a
V5a;
#endif
#ifndef H
#define H(c)
#endif
#ifndef D1
#define D1(c,e) (e)
#endif
#ifndef B2a
#define B2a(x) ((void)(x))
#endif
#ifndef g_
#define g_(t,exp) ((t)(exp))
#endif
typedef
unsigned
long
j_;
#ifndef m6
#define m6 4096
#endif
#ifndef H6
#define H6 200
#endif
#ifndef Q3a
#define Q3a 2048
#endif
#define q2 250
#ifndef O5a
#define O5a 200
#endif
#ifndef G_a
#define G_a 32
#endif
#ifndef e5a
#define e5a 100
#endif
#ifndef h0a
#define h0a 32
#endif
#ifndef p8
#define p8 32
#endif
#ifndef M_a
#define M_a 200
#endif
#endif
#define e0b Y2
#define u9 (e0b+1)
#define p9 (e0b+2)
typedef
union
u_
u_;
#define r4 u_*h_;S_ tt;S_ U2
typedef
struct
L_b{r4;}L_b;typedef
union{u_*gc;void*p;U
n;int
b;}e_c;typedef
struct
q9b{int
tt;e_c
m_;}E;
#define H0(o) (T0(o)==P5)
#define W0(o) (T0(o)==N1)
#define n1(o) (T0(o)==q1)
#define F2(o) (T0(o)==H_)
#define X1(o) (T0(o)==d0)
#define z2a(o) (T0(o)==f5)
#define O4a(o) (T0(o)==c1)
#define U7a(o) (T0(o)==Y2)
#define u0a(o) (T0(o)==I1)
#define T0(o) ((o)->tt)
#define H7(o) D1(K4(o),(o)->m_.gc)
#define D2a(o) D1(u0a(o),(o)->m_.p)
#define r0(o) D1(W0(o),(o)->m_.n)
#define k2(o) D1(n1(o),&(o)->m_.gc->ts)
#define T_a(o) D1(O4a(o),&(o)->m_.gc->u)
#define A2(o) D1(X1(o),&(o)->m_.gc->cl)
#define i1(o) D1(F2(o),&(o)->m_.gc->h)
#define R2a(o) D1(z2a(o),(o)->m_.b)
#define I1b(o) D1(U7a(o),&(o)->m_.gc->th)
#define d0a(o) (H0(o)||(z2a(o)&&R2a(o)==0))
#define K1(R1,x) {E*W5=(R1);W5->tt=N1;W5->m_.n=(x);}
#define Y3b(R1,x) D1(T0(R1)==N1,(R1)->m_.n=(x))
#define L8a(R1,x) {E*W5=(R1);W5->tt=I1;W5->m_.p=(x);}
#define X1a(R1,x) {E*W5=(R1);W5->tt=f5;W5->m_.b=(x);}
#define l2a(R1,x) {E*W5=(R1);W5->tt=q1;W5->m_.gc=g_(u_*,(x));H(W5->m_.gc->A3.tt==q1);}
#define K4a(R1,x) {E*W5=(R1);W5->tt=c1;W5->m_.gc=g_(u_*,(x));H(W5->m_.gc->A3.tt==c1);}
#define i2b(R1,x) {E*W5=(R1);W5->tt=Y2;W5->m_.gc=g_(u_*,(x));H(W5->m_.gc->A3.tt==Y2);}
#define x0a(R1,x) {E*W5=(R1);W5->tt=d0;W5->m_.gc=g_(u_*,(x));H(W5->m_.gc->A3.tt==d0);}
#define s6(R1,x) {E*W5=(R1);W5->tt=H_;W5->m_.gc=g_(u_*,(x));H(W5->m_.gc->A3.tt==H_);}
#define R_(R1) ((R1)->tt=P5)
#define A8(R1) H(!K4(R1)||(T0(R1)==(R1)->m_.gc->A3.tt))
#define E9(D_c,G_c) {const E*o2=(G_c);E*o1=(D_c);A8(o2);o1->tt=o2->tt;o1->m_=o2->m_;}
#define f1 E9
#define k0 E9
#define C3 l2a
#define h9a E9
#define p1a E9
#define m3a E9
#define a1b l2a
#define w6b(R1,tt) (T0(R1)=(tt))
#define K4(o) (T0(o)>=q1)
typedef
E*t_;typedef
union
A_{g8
T2b;struct{r4;S_
x3;U9
f2;size_t
E1;}q6;}A_;
#define C5(ts) g_(const char*,(ts)+1)
#define h9(o) C5(k2(o))
typedef
union
r_a{g8
T2b;struct{r4;struct
o0*r_;size_t
E1;}uv;}r_a;typedef
struct
E_{r4;E*k;j_*m1;struct
E_**p;int*i4;struct
O2a*n3;A_**i0;A_*m0;int
G3;int
Z8;int
H2;int
o3;int
E0a;int
m4;int
Z7;u_*h5;S_
e5;S_
d7;S_
J8;S_
Z1;}E_;typedef
struct
O2a{A_*L2;int
G2a;int
S9a;}O2a;typedef
struct
F_a{r4;E*v;E
m_;}F_a;
#define U3a r4;S_ isC;S_ c4;u_*h5
typedef
struct
M6a{U3a;p0
f;E
E4[1];}M6a;typedef
struct
C1a{U3a;struct
E_*p;E
g;F_a*P1a[1];}C1a;typedef
union
z2{M6a
c;C1a
l;}z2;
#define C_a(o) (T0(o)==d0&&A2(o)->c.isC)
#define v2a(o) (T0(o)==d0&&!A2(o)->c.isC)
typedef
struct
I3{E
X9b;E
P9b;struct
I3*h_;}I3;typedef
struct
o0{r4;S_
p3a;S_
P8;struct
o0*r_;E*v0;I3*d3;I3*o7;u_*h5;int
M1;}o0;
#define d_b(s,W) D1((W&(W-1))==0,(g_(int,(s)&((W)-1))))
#define a2a(x) (1<<(x))
#define k5(t) (a2a((t)->P8))
extern
const
E
B2;int
Z_a(unsigned
int
x);int
u2a(unsigned
int
x);
#define q4b(x) (((x)&7)<<((x)>>3))
int
u3(const
E*t1,const
E*t2);int
A3a(const
char*s,U*H1);const
char*N4(a*L,const
char*K6,va_list
U4);const
char*R2(a*L,const
char*K6,...);void
y7(char*e7,const
char*m0,int
E1);
#endif
void
C4(a*L,const
E*o);
#endif
#ifndef L5b
#define L5b
#ifndef K5b
#define K5b
#ifndef U9b
#define U9b
typedef
enum{p0b,i6a,H6b,d7b,A2b,o4b,I4b,F4b,Z3b,G_b,m9b,X6b,K9b,i4b,u7b,R8b}TMS;
#define G1b(g,et,e) (((et)->p3a&(1u<<(e)))?NULL:R7a(et,e,(g)->d5a[e]))
#define X2a(l,et,e) G1b(G(l),et,e)
const
E*R7a(o0*q_b,TMS
O2,A_*f7a);const
E*j3(a*L,const
E*o,TMS
O2);void
a9a(a*L);extern
const
char*const
Z5[];
#endif
#ifndef Q8b
#define Q8b
#define EOZ (-1)
typedef
struct
Zio
X8;
#define S6a(c) g_(int,g_(unsigned char,(c)))
#define c7b(z) (((z)->n--)>0?S6a(*(z)->p++):o2a(z))
#define I6b(z) ((z)->b_)
void
U8a(X8*z,D5
a0a,void*a3,const
char*b_);size_t
G8a(X8*z,void*b,size_t
n);int
L2a(X8*z);typedef
struct
f6{char*b0;size_t
F8;}f6;char*N7(a*L,f6*p_,size_t
n);
#define i2a(L,p_) ((p_)->b0=NULL,(p_)->F8=0)
#define B9(p_) ((p_)->F8)
#define N5(p_) ((p_)->b0)
#define w0a(L,p_,W) (G0(L,(p_)->b0,(p_)->F8,W,char),(p_)->F8=W)
#define b2a(L,p_) w0a(L,p_,0)
struct
Zio{size_t
n;const
char*p;D5
a0a;void*a3;const
char*b_;};int
o2a(X8*z);
#endif
#ifndef n_
#define n_(L) ((void)0)
#endif
#ifndef f_
#define f_(L) ((void)0)
#endif
#ifndef M4
#define M4(l)
#endif
struct
A_a;
#define B3(L) (&G(L)->v0b)
#define gt(L) (&L->_gt)
#define T5(L) (&G(L)->Q3b)
#define V6 5
#define k0a 8
#define v8 (2*J3)
typedef
struct
b8{u_**f2;o8a
v6a;int
W;}b8;typedef
struct
l0{t_
k_;t_
X;int
g0;union{struct{const
j_*j2;const
j_**pc;int
V_a;}l;struct{int
T2b;}c;}u;}l0;
#define K1a (1<<0)
#define U6 (1<<1)
#define F9 (1<<2)
#define b3 (1<<3)
#define u8 (1<<4)
#define M0a(ci) (A2((ci)->k_-1))
typedef
struct
q4{b8
X6;u_*P4a;u_*t6;u_*k6;f6
p_;h2
I5;h2
T6;p0
P9a;E
Q3b;E
v0b;struct
a*m9;I3
Y3[1];A_*d5a[R8b];}q4;struct
a{r4;t_
X;t_
k_;q4*l_G;l0*ci;t_
r5;t_
l_;int
E2;l0*y7a;l0*N0;unsigned
short
S3;unsigned
short
d6;S_
C6;S_
a4;S_
d3a;int
n8;int
c5a;w8
w6;E
_gt;u_*p6;u_*h5;struct
A_a*E8;ptrdiff_t
k4;};
#define G(L) (L->l_G)
union
u_{L_b
A3;union
A_
ts;union
r_a
u;union
z2
cl;struct
o0
h;struct
E_
p;struct
F_a
uv;struct
a
th;};
#define L5a(o) D1((o)->A3.tt==q1,&((o)->ts))
#define X0a(o) D1((o)->A3.tt==c1,&((o)->u))
#define m8a(o) D1((o)->A3.tt==d0,&((o)->cl))
#define w4a(o) D1((o)->A3.tt==H_,&((o)->h))
#define n0b(o) D1((o)->A3.tt==u9,&((o)->p))
#define b8a(o) D1((o)->A3.tt==p9,&((o)->uv))
#define k_b(o) D1((o)==NULL||(o)->A3.tt==p9,&((o)->uv))
#define K2a(o) D1((o)->A3.tt==Y2,&((o)->th))
#define L4(v) (g_(u_*,(v)))
a*T2a(a*L);void
m2a(a*L,a*L1);
#endif
#define W9a(pc,p) (g_(int,(pc)-(p)->m1)-1)
#define A5a(f,pc) (((f)->i4)?(f)->i4[pc]:0)
#define X9(L) (L->c5a=L->n8)
void
Z2a(a*L);void
d5(a*L,const
E*o,const
char*V_c);void
g1a(a*L,t_
p1,t_
p2);void
d9(a*L,const
E*p1,const
E*p2);int
A5(a*L,const
E*p1,const
E*p2);void
q_(a*L,const
char*K6,...);void
j0a(a*L);int
D7(const
E_*pt);
#endif
#ifndef H9b
#define H9b
#ifndef L7b
#define s4(x) {}
#else
#define s4(x) x
#endif
#define K2(L,n) if((char*)L->r5-(char*)L->X<=(n)*(int)sizeof(E))a3a(L,n);else s4(T3(L,L->E2));
#define R3(L) {K2(L,1);L->X++;}
#define v4(L,p) ((char*)(p)-(char*)L->l_)
#define W2(L,n) ((E*)((char*)L->l_+(n)))
#define e9b(L,p) ((char*)(p)-(char*)L->N0)
#define a4b(L,n) ((l0*)((char*)L->N0+(n)))
typedef
void(*c_b)(a*L,void*ud);void
h2b(a*L);int
b9(a*L,X8*z,int
bin);void
I4(a*L,int
O2,int
W_);t_
i7(a*L,t_
Z_);void
u5(a*L,t_
Z_,int
F_b);int
B3a(a*L,c_b
Z_,void*u,ptrdiff_t
h8,ptrdiff_t
ef);void
b6(a*L,int
d7a,t_
D0);void
a5(a*L,int
Q1);void
T3(a*L,int
Q1);void
a3a(a*L,int
n);void
E5(a*L,int
I5a);int
c3(a*L,c_b
f,void*ud);
#endif
#ifndef A7b
#define A7b
E_*i0a(a*L);z2*z8(a*L,int
L9);z2*D8(a*L,int
L9,E*e);F_a*H2a(a*L,t_
z_);void
S4(a*L,t_
z_);void
F2a(a*L,E_*f);void
G1a(a*L,z2*c);const
char*O4(const
E_*Z_,int
d1a,int
pc);
#endif
#ifndef v9b
#define v9b
#define z1(L) {H(!(L->ci->g0&F9));if(G(L)->T6>=G(L)->I5)R9(L);}
size_t
n7(a*L);void
g0a(a*L);void
C3a(a*L,int
J2);void
R9(a*L);void
f7(a*L,u_*o,S_
tt);
#endif
#ifndef u8b
#define u8b
#define k9a "not enough memory"
void*g5(a*L,void*L_c,h2
l4,h2
W);void*G4a(a*L,void*N_,int*W,int
t_c,int
N2,const
char*t0b);
#define R1a(L,b,s) g5(L,(b),(s),0)
#define i9(L,b) g5(L,(b),sizeof(*(b)),0)
#define u1(L,b,n,t) g5(L,(b),g_(h2,n)*g_(h2,sizeof(t)),0)
#define S5(L,t) g5(L,NULL,0,(t))
#define v3a(L,t) g_(t*,S5(L,sizeof(t)))
#define C2(L,n,t) g_(t*,S5(L,g_(h2,n)*g_(h2,sizeof(t))))
#define B4(L,v,L9,W,t,N2,e) if(((L9)+1)>(W))((v)=g_(t*,G4a(L,v,&(W),sizeof(t),N2,e)))
#define G0(L,v,A_c,n,t) ((v)=g_(t*,g5(L,v,g_(h2,A_c)*g_(h2,sizeof(t)),g_(h2,n)*g_(h2,sizeof(t)))))
#endif
#ifndef y4b
#define y4b
#define c7a(l) (g_(h2,sizeof(union A_))+(g_(h2,l)+1)*sizeof(char))
#define n5a(l) (g_(h2,sizeof(union r_a))+(l))
#define M5(L,s) (S2(L,s,strlen(s)))
#define W1a(L,s) (S2(L,""s,(sizeof(s)/sizeof(char))-1))
#define B6a(s) ((s)->q6.U2|=(1<<4))
void
w_a(a*L,int
Q1);r_a*g4a(a*L,size_t
s);void
f5a(a*L);A_*S2(a*L,const
char*str,size_t
l);
#endif
#ifndef s6b
#define s6b
#define l5(t,i) (&(t)->d3[i])
#define g4(n) (&(n)->X9b)
#define y4(n) (&(n)->P9b)
const
E*m_a(o0*t,int
x_);E*i8(a*L,o0*t,int
x_);const
E*o4(o0*t,A_*x_);const
E*p7(o0*t,const
E*x_);E*h_a(a*L,o0*t,const
E*x_);o0*w7(a*L,int
B5,int
G3b);void
o9a(a*L,o0*t);int
S8a(a*L,o0*t,t_
x_);I3*U3(const
o0*t,const
E*x_);
#endif
#ifndef g4b
#define g4b
E_*Z5a(a*L,X8*Z,f6*p_);int
Q9(void);void
m9a(a*L,const
E_*l6b,x5
w,void*a3);void
A9b(const
E_*l6b);
#define l8 "\033Lua"
#define x8a 0x50
#define C_b 0x50
#define Y5a ((U)3.14159265358979323846E7)
#endif
#ifndef j_c
#define j_c
#define C6a(L,o) ((T0(o)==q1)||(q5(L,o)))
#define i1a(o,n) (T0(o)==N1||(((o)=I6(o,n))!=NULL))
#define o0b(L,o1,o2) (T0(o1)==T0(o2)&&W3a(L,o1,o2))
int
o0a(a*L,const
E*l,const
E*r);int
W3a(a*L,const
E*t1,const
E*t2);const
E*I6(const
E*R1,E*n);int
q5(a*L,t_
R1);const
E*o8(a*L,const
E*t,E*x_,int
R4);void
q8(a*L,const
E*t,E*x_,t_
r6);t_
o6(a*L);void
u_a(a*L,int
y0a,int
I2);
#endif
const
char
u_c[]="$Lua: "X7" "f4a" $\n""$Authors: "M0b" $\n""$URL: www.lua.org $\n";
#ifndef i2
#define i2(L,o)
#endif
#define Y0(L,n) i2(L,(n)<=(L->X-L->k_))
#define Q0(L) {i2(L,L->X<L->ci->X);L->X++;}
static
E*Q_b(a*L,int
F_){if(F_>L_){i2(L,F_!=0&&-F_<=L->X-L->k_);return
L->X+F_;}else
switch(F_){case
L_:return
T5(L);case
a0:return
gt(L);default:{E*Z_=(L->k_-1);F_=a0-F_;H(C_a(Z_));return(F_<=A2(Z_)->c.c4)?&A2(Z_)->c.E4[F_-1]:NULL;}}}static
E*T1(a*L,int
F_){if(F_>0){i2(L,F_<=L->X-L->k_);return
L->k_+F_-1;}else{E*o=Q_b(L,F_);i2(L,o!=NULL);return
o;}}static
E*v_(a*L,int
F_){if(F_>0){E*o=L->k_+(F_-1);i2(L,F_<=L->r5-L->k_);if(o>=L->X)return
NULL;else
return
o;}else
return
Q_b(L,F_);}void
C4(a*L,const
E*o){k0(L->X,o);R3(L);}K
int
A7(a*L,int
W){int
h0;n_(L);if((L->X-L->k_+W)>Q3a)h0=0;else{K2(L,W);if(L->ci->X<L->X+W)L->ci->X=L->X+W;h0=1;}f_(L);return
h0;}K
void
X_a(a*U0,a*to,int
n){int
i;n_(to);Y0(U0,n);U0->X-=n;for(i=0;i<n;i++){k0(to->X,U0->X+i);Q0(to);}f_(to);}K
p0
U5a(a*L,p0
R4b){p0
old;n_(L);old=G(L)->P9a;G(L)->P9a=R4b;f_(L);return
old;}K
a*r0a(a*L){a*L1;n_(L);z1(L);L1=T2a(L);i2b(L->X,L1);Q0(L);f_(L);M4(L1);return
L1;}K
int
D_(a*L){return(L->X-L->k_);}K
void
I0(a*L,int
F_){n_(L);if(F_>=0){i2(L,F_<=L->r5-L->k_);while(L->X<L->k_+F_)R_(L->X++);L->X=L->k_+F_;}else{i2(L,-(F_+1)<=(L->X-L->k_));L->X+=F_+1;}f_(L);}K
void
z5(a*L,int
F_){t_
p;n_(L);p=T1(L,F_);while(++p<L->X)f1(p-1,p);L->X--;f_(L);}K
void
A1(a*L,int
F_){t_
p;t_
q;n_(L);p=T1(L,F_);for(q=L->X;q>p;q--)f1(q,q-1);f1(p,L->X);f_(L);}K
void
Q5(a*L,int
F_){n_(L);Y0(L,1);E9(T1(L,F_),L->X-1);L->X--;f_(L);}K
void
Y(a*L,int
F_){n_(L);k0(L->X,T1(L,F_));Q0(L);f_(L);}K
int
b2(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL)?Y_a:T0(o);}K
const
char*g7(a*L,int
t){B2a(L);return(t==Y_a)?"no value":Z5[t];}K
int
K3(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL)?0:C_a(o);}K
int
r2(a*L,int
F_){E
n;const
E*o=v_(L,F_);return(o!=NULL&&i1a(o,&n));}K
int
W1(a*L,int
F_){int
t=b2(L,F_);return(t==q1||t==N1);}K
int
J2a(a*L,int
F_){const
E*o=v_(L,F_);return(o!=NULL&&(O4a(o)||u0a(o)));}K
int
g5a(a*L,int
q5a,int
o5a){t_
o1=v_(L,q5a);t_
o2=v_(L,o5a);return(o1==NULL||o2==NULL)?0:u3(o1,o2);}K
int
P8a(a*L,int
q5a,int
o5a){t_
o1,o2;int
i;n_(L);o1=v_(L,q5a);o2=v_(L,o5a);i=(o1==NULL||o2==NULL)?0:o0b(L,o1,o2);f_(L);return
i;}K
int
B1a(a*L,int
q5a,int
o5a){t_
o1,o2;int
i;n_(L);o1=v_(L,q5a);o2=v_(L,o5a);i=(o1==NULL||o2==NULL)?0:o0a(L,o1,o2);f_(L);return
i;}K
U
E0(a*L,int
F_){E
n;const
E*o=v_(L,F_);if(o!=NULL&&i1a(o,&n))return
r0(o);else
return
0;}K
int
V1(a*L,int
F_){const
E*o=v_(L,F_);return(o!=NULL)&&!d0a(o);}K
const
char*o_(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;else
if(n1(o))return
h9(o);else{const
char*s;n_(L);s=(q5(L,o)?h9(o):NULL);z1(L);f_(L);return
s;}}K
size_t
N3(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
0;else
if(n1(o))return
k2(o)->q6.E1;else{size_t
l;n_(L);l=(q5(L,o)?k2(o)->q6.E1:0);f_(L);return
l;}}K
p0
Z1a(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL||!C_a(o))?NULL:A2(o)->c.f;}K
void*Y1(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;switch(T0(o)){case
c1:return(T_a(o)+1);case
I1:return
D2a(o);default:return
NULL;}}K
a*j6(a*L,int
F_){t_
o=v_(L,F_);return(o==NULL||!U7a(o))?NULL:I1b(o);}K
const
void*f0a(a*L,int
F_){t_
o=v_(L,F_);if(o==NULL)return
NULL;else{switch(T0(o)){case
H_:return
i1(o);case
d0:return
A2(o);case
Y2:return
I1b(o);case
c1:case
I1:return
Y1(L,F_);default:return
NULL;}}}K
void
w_(a*L){n_(L);R_(L->X);Q0(L);f_(L);}K
void
N(a*L,U
n){n_(L);K1(L->X,n);Q0(L);f_(L);}K
void
Z0(a*L,const
char*s,size_t
E1){n_(L);z1(L);C3(L->X,S2(L,s,E1));Q0(L);f_(L);}K
void
I(a*L,const
char*s){if(s==NULL)w_(L);else
Z0(L,s,strlen(s));}K
const
char*W0a(a*L,const
char*K6,va_list
U4){const
char*ret;n_(L);z1(L);ret=N4(L,K6,U4);f_(L);return
ret;}K
const
char*P_(a*L,const
char*K6,...){const
char*ret;va_list
U4;n_(L);z1(L);va_start(U4,K6);ret=N4(L,K6,U4);va_end(U4);f_(L);return
ret;}K
void
x1(a*L,p0
fn,int
n){z2*cl;n_(L);z1(L);Y0(L,n);cl=z8(L,n);cl->c.f=fn;L->X-=n;while(n--)m3a(&cl->c.E4[n],L->X+n);x0a(L->X,cl);Q0(L);f_(L);}K
void
n0(a*L,int
b){n_(L);X1a(L->X,(b!=0));Q0(L);f_(L);}K
void
C1(a*L,void*p){n_(L);L8a(L->X,p);Q0(L);f_(L);}K
void
l6(a*L,int
F_){t_
t;n_(L);t=T1(L,F_);k0(L->X-1,o8(L,t,L->X-1,0));f_(L);}K
void
x0(a*L,int
F_){t_
t;n_(L);t=T1(L,F_);i2(L,F2(t));k0(L->X-1,p7(i1(t),L->X-1));f_(L);}K
void
c0(a*L,int
F_,int
n){t_
o;n_(L);o=T1(L,F_);i2(L,F2(o));k0(L->X,m_a(i1(o),n));Q0(L);f_(L);}K
void
S0(a*L){n_(L);z1(L);s6(L->X,w7(L,0,0));Q0(L);f_(L);}K
int
T2(a*L,int
v1a){const
E*R1;o0*mt=NULL;int
h0;n_(L);R1=v_(L,v1a);if(R1!=NULL){switch(T0(R1)){case
H_:mt=i1(R1)->r_;break;case
c1:mt=T_a(R1)->uv.r_;break;}}if(mt==NULL||mt==i1(B3(L)))h0=0;else{s6(L->X,mt);Q0(L);h0=1;}f_(L);return
h0;}K
void
m6a(a*L,int
F_){t_
o;n_(L);o=T1(L,F_);k0(L->X,v2a(o)?&A2(o)->l.g:gt(L));Q0(L);f_(L);}K
void
P0(a*L,int
F_){t_
t;n_(L);Y0(L,2);t=T1(L,F_);q8(L,t,L->X-2,L->X-1);L->X-=2;f_(L);}K
void
F0(a*L,int
F_){t_
t;n_(L);Y0(L,2);t=T1(L,F_);i2(L,F2(t));p1a(h_a(L,i1(t),L->X-2),L->X-1);L->X-=2;f_(L);}K
void
D2(a*L,int
F_,int
n){t_
o;n_(L);Y0(L,1);o=T1(L,F_);i2(L,F2(o));p1a(i8(L,i1(o),n),L->X-1);L->X--;f_(L);}K
int
V2(a*L,int
v1a){E*R1,*mt;int
h0=1;n_(L);Y0(L,1);R1=T1(L,v1a);mt=(!H0(L->X-1))?L->X-1:B3(L);i2(L,F2(mt));switch(T0(R1)){case
H_:{i1(R1)->r_=i1(mt);break;}case
c1:{T_a(R1)->uv.r_=i1(mt);break;}default:{h0=0;break;}}L->X--;f_(L);return
h0;}K
int
b6a(a*L,int
F_){t_
o;int
h0=0;n_(L);Y0(L,1);o=T1(L,F_);L->X--;i2(L,F2(L->X));if(v2a(o)){h0=1;A2(o)->l.g=*(L->X);}f_(L);return
h0;}K
void
e4(a*L,int
T4,int
z0){t_
Z_;n_(L);Y0(L,T4+1);Z_=L->X-(T4+1);u5(L,Z_,z0);f_(L);}struct
j2b{t_
Z_;int
z0;};static
void
A3b(a*L,void*ud){struct
j2b*c=g_(struct
j2b*,ud);u5(L,c->Z_,c->z0);}K
int
w4(a*L,int
T4,int
z0,int
k4){struct
j2b
c;int
T;ptrdiff_t
Z_;n_(L);Z_=(k4==0)?0:v4(L,T1(L,k4));c.Z_=L->X-(T4+1);c.z0=z0;T=B3a(L,A3b,&c,v4(L,c.Z_),Z_);f_(L);return
T;}struct
D_b{p0
Z_;void*ud;};static
void
W1b(a*L,void*ud){struct
D_b*c=g_(struct
D_b*,ud);z2*cl;cl=z8(L,0);cl->c.f=c->Z_;x0a(L->X,cl);R3(L);L8a(L->X,c->ud);R3(L);u5(L,L->X-2,0);}K
int
u7a(a*L,p0
Z_,void*ud){struct
D_b
c;int
T;n_(L);c.Z_=Z_;c.ud=ud;T=B3a(L,W1b,&c,v4(L,L->X),0);f_(L);return
T;}K
int
w1a(a*L,D5
a0a,void*a3,const
char*L8){X8
z;int
T;int
c;n_(L);if(!L8)L8="?";U8a(&z,a0a,a3,L8);c=L2a(&z);T=b9(L,&z,(c==l8[0]));f_(L);return
T;}K
int
C0b(a*L,x5
x7a,void*a3){int
T;E*o;n_(L);Y0(L,1);o=L->X-1;if(v2a(o)&&A2(o)->l.c4==0){m9a(L,A2(o)->l.p,x7a,a3);T=1;}else
T=0;f_(L);return
T;}
#define l_b(x) ((x)>>10)
#define B1b(x) (g_(int,l_b(x)))
#define l5b(x) (g_(h2,x)<<10)
K
int
b0a(a*L){int
H4a;n_(L);H4a=B1b(G(L)->I5);f_(L);return
H4a;}K
int
I2a(a*L){int
w1;n_(L);w1=B1b(G(L)->T6);f_(L);return
w1;}K
void
H_a(a*L,int
F1a){n_(L);if(g_(h2,F1a)>l_b(K8a))G(L)->I5=K8a;else
G(L)->I5=l5b(F1a);z1(L);f_(L);}K
const
char*g1b(void){return
X7;}K
int
N8(a*L){n_(L);Y0(L,1);j0a(L);f_(L);return
0;}K
int
G3a(a*L,int
F_){t_
t;int
j5;n_(L);t=T1(L,F_);i2(L,F2(t));j5=S8a(L,i1(t),L->X-1);if(j5){Q0(L);}else
L->X-=1;f_(L);return
j5;}K
void
O3(a*L,int
n){n_(L);z1(L);Y0(L,n);if(n>=2){u_a(L,n,L->X-L->k_-1);L->X-=(n-1);}else
if(n==0){C3(L->X,S2(L,NULL,0));Q0(L);}f_(L);}K
void*y5(a*L,size_t
W){r_a*u;n_(L);z1(L);u=g4a(L,W);K4a(L->X,u);Q0(L);f_(L);return
u+1;}K
int
y8(a*L){z2*Z_;int
n,i;n_(L);i2(L,C_a(L->k_-1));Z_=A2(L->k_-1);n=Z_->c.c4;K2(L,n+J3);for(i=0;i<n;i++){k0(L->X,&Z_->c.E4[i]);L->X++;}f_(L);return
n;}static
const
char*n6a(a*L,int
h7,int
n,E**r6){z2*f;t_
fi=T1(L,h7);if(!X1(fi))return
NULL;f=A2(fi);if(f->c.isC){if(n>f->c.c4)return
NULL;*r6=&f->c.E4[n-1];return"";}else{E_*p=f->l.p;if(n>p->G3)return
NULL;*r6=f->l.P1a[n-1]->v;return
C5(p->i0[n-1]);}}K
const
char*i_a(a*L,int
h7,int
n){const
char*b_;E*r6;n_(L);b_=n6a(L,h7,n,&r6);if(b_){k0(L->X,r6);Q0(L);}f_(L);return
b_;}K
const
char*W9(a*L,int
h7,int
n){const
char*b_;E*r6;n_(L);Y0(L,1);b_=n6a(L,h7,n,&r6);if(b_){L->X--;E9(r6,L->X);}f_(L);return
b_;}
#define p_c
#ifndef k5b
#define k5b
#ifndef P
#define P K
#endif
typedef
struct
g3{const
char*b_;p0
Z_;}g3;P
void
u2(a*L,const
char*E5a,const
g3*l,int
nup);P
int
Y5(a*L,int
R1,const
char*e);P
int
e4a(a*L,int
R1,const
char*e);P
int
p5(a*L,int
O1,const
char*K7);P
int
d1(a*L,int
F3b,const
char*k1a);P
const
char*y_(a*L,int
W3b,size_t*l);P
const
char*Z6(a*L,int
W3b,const
char*def,size_t*l);P
U
b1(a*L,int
W3b);P
U
y3(a*L,int
g0c,U
def);P
void
A4(a*L,int
sz,const
char*O6);P
void
G_(a*L,int
O1,int
t);P
void
A0(a*L,int
O1);P
int
t0a(a*L,const
char*K7);P
void
v0a(a*L,const
char*K7);P
void*o9(a*L,int
ud,const
char*K7);P
void
I0a(a*L,int
lvl);P
int
s_(a*L,const
char*K6,...);P
int
a7(const
char*st,const
char*const
lst[]);P
int
N_b(a*L,int
t);P
void
M7a(a*L,int
t,int
b7);P
int
I8(a*L,int
t);P
void
O8(a*L,int
t,int
n);P
int
J4(a*L,const
char*Q_);P
int
h3(a*L,const
char*p_,size_t
sz,const
char*b_);
#define e0(L,c6,F3b,k1a) if(!(c6))d1(L,F3b,k1a)
#define Q(L,n) (y_(L,(n),NULL))
#define J0(L,n,d) (Z6(L,(n),(d),NULL))
#define X_(L,n) ((int)b1(L,n))
#define M2a(L,n) ((long)b1(L,n))
#define a1(L,n,d) ((int)y3(L,n,(U)(d)))
#define x7(L,n,d) ((long)y3(L,n,(U)(d)))
#ifndef i3
#define i3 BUFSIZ
#endif
typedef
struct
I_{char*p;int
lvl;a*L;char
b0[i3];}I_;
#define k1(B,c) ((void)((B)->p<((B)->b0+i3)||c7(B)),(*(B)->p++=(char)(c)))
#define a1a(B,n) ((B)->p+=(n))
P
void
U1(a*L,I_*B);P
char*c7(I_*B);P
void
k3(I_*B,const
char*s,size_t
l);P
void
c5(I_*B,const
char*s);P
void
N6(I_*B);P
void
X0(I_*B);P
int
V6a(a*L,const
char*Q_);P
int
o1a(a*L,const
char*str);P
int
U4a(a*L,const
char*p_,size_t
sz,const
char*n);
#define W6b y_
#define o8b Z6
#define n5b b1
#define P6b y3
#define r7b e0
#define m5b Q
#define G6b J0
#define j7b X_
#define b7b M2a
#define P8b a1
#define n8b x7
#endif
#define m4a 2
#define u4 1
#define j4a 2
#define I_a(L,i) ((i)>0||(i)<=L_?(i):D_(L)+(i)+1)
P
int
d1(a*L,int
O1,const
char*k1a){C0
ar;P2(L,0,&ar);L5(L,"n",&ar);if(strcmp(ar.r7,"method")==0){O1--;if(O1==0)return
s_(L,"calling `%s' on bad self (%s)",ar.b_,k1a);}if(ar.b_==NULL)ar.b_="?";return
s_(L,"bad argument #%d to `%s' (%s)",O1,ar.b_,k1a);}P
int
p5(a*L,int
O1,const
char*K7){const
char*O6=P_(L,"%s expected, got %s",K7,g7(L,b2(L,O1)));return
d1(L,O1,O6);}static
void
L4a(a*L,int
O1,int
tag){p5(L,O1,g7(L,tag));}P
void
I0a(a*L,int
z_){C0
ar;if(P2(L,z_,&ar)){L5(L,"Snl",&ar);if(ar.x2>0){P_(L,"%s:%d: ",ar.T8,ar.x2);return;}}e_(L,"");}P
int
s_(a*L,const
char*K6,...){va_list
U4;va_start(U4,K6);I0a(L,1);W0a(L,K6,U4);va_end(U4);O3(L,2);return
N8(L);}P
int
a7(const
char*b_,const
char*const
f0[]){int
i;for(i=0;f0[i];i++)if(strcmp(f0[i],b_)==0)return
i;return-1;}P
int
t0a(a*L,const
char*K7){I(L,K7);x0(L,L_);if(!l3(L,-1))return
0;U_(L,1);S0(L);I(L,K7);Y(L,-2);F0(L,L_);Y(L,-1);I(L,K7);F0(L,L_);return
1;}P
void
v0a(a*L,const
char*K7){I(L,K7);x0(L,L_);}P
void*o9(a*L,int
ud,const
char*K7){const
char*tn;if(!T2(L,ud))return
NULL;x0(L,L_);tn=o_(L,-1);if(tn&&(strcmp(tn,K7)==0)){U_(L,1);return
Y1(L,ud);}else{U_(L,1);return
NULL;}}P
void
A4(a*L,int
B0a,const
char*mes){if(!A7(L,B0a))s_(L,"stack overflow (%s)",mes);}P
void
G_(a*L,int
O1,int
t){if(b2(L,O1)!=t)L4a(L,O1,t);}P
void
A0(a*L,int
O1){if(b2(L,O1)==Y_a)d1(L,O1,"value expected");}P
const
char*y_(a*L,int
O1,size_t*E1){const
char*s=o_(L,O1);if(!s)L4a(L,O1,q1);if(E1)*E1=N3(L,O1);return
s;}P
const
char*Z6(a*L,int
O1,const
char*def,size_t*E1){if(J1(L,O1)){if(E1)*E1=(def?strlen(def):0);return
def;}else
return
y_(L,O1,E1);}P
U
b1(a*L,int
O1){U
d=E0(L,O1);if(d==0&&!r2(L,O1))L4a(L,O1,N1);return
d;}P
U
y3(a*L,int
O1,U
def){if(J1(L,O1))return
def;else
return
b1(L,O1);}P
int
Y5(a*L,int
R1,const
char*O2){if(!T2(L,R1))return
0;I(L,O2);x0(L,-2);if(l3(L,-1)){U_(L,2);return
0;}else{z5(L,-2);return
1;}}P
int
e4a(a*L,int
R1,const
char*O2){R1=I_a(L,R1);if(!Y5(L,R1,O2))return
0;Y(L,R1);e4(L,1,1);return
1;}P
void
u2(a*L,const
char*E5a,const
g3*l,int
nup){if(E5a){I(L,E5a);l6(L,a0);if(l3(L,-1)){U_(L,1);S0(L);I(L,E5a);Y(L,-2);P0(L,a0);}A1(L,-(nup+1));}for(;l->b_;l++){int
i;I(L,l->b_);for(i=0;i<nup;i++)Y(L,-(nup+1));x1(L,l->Z_,nup);P0(L,-(nup+3));}U_(L,nup);}static
int
F6a(a*L,int
f_c){int
n=(int)E0(L,-1);if(n==0&&!r2(L,-1))n=-1;U_(L,f_c);return
n;}static
void
U_b(a*L){c0(L,L_,j4a);if(l3(L,-1)){U_(L,1);S0(L);Y(L,-1);V2(L,-2);e_(L,"__mode");e_(L,"k");F0(L,-3);Y(L,-1);D2(L,L_,j4a);}}void
O8(a*L,int
t,int
n){t=I_a(L,t);e_(L,"n");x0(L,t);if(F6a(L,1)>=0){e_(L,"n");N(L,(U)n);F0(L,t);}else{U_b(L);Y(L,t);N(L,(U)n);F0(L,-3);U_(L,1);}}int
I8(a*L,int
t){int
n;t=I_a(L,t);e_(L,"n");x0(L,t);if((n=F6a(L,1))>=0)return
n;U_b(L);Y(L,t);x0(L,-2);if((n=F6a(L,2))>=0)return
n;for(n=1;;n++){c0(L,t,n);if(l3(L,-1))break;U_(L,1);}U_(L,1);return
n-1;}
#define g6(B) ((B)->p-(B)->b0)
#define B5b(B) ((size_t)(i3-g6(B)))
#define y9b (J3/2)
static
int
w2a(I_*B){size_t
l=g6(B);if(l==0)return
0;else{Z0(B->L,B->b0,l);B->p=B->b0;B->lvl++;return
1;}}static
void
p6a(I_*B){if(B->lvl>1){a*L=B->L;int
B5a=1;size_t
u3b=N3(L,-1);do{size_t
l=N3(L,-(B5a+1));if(B->lvl-B5a+1>=y9b||u3b>l){u3b+=l;B5a++;}else
break;}while(B5a<B->lvl);O3(L,B5a);B->lvl=B->lvl-B5a+1;}}P
char*c7(I_*B){if(w2a(B))p6a(B);return
B->b0;}P
void
k3(I_*B,const
char*s,size_t
l){while(l--)k1(B,*s++);}P
void
c5(I_*B,const
char*s){k3(B,s,strlen(s));}P
void
X0(I_*B){w2a(B);O3(B->L,B->lvl);B->lvl=1;}P
void
N6(I_*B){a*L=B->L;size_t
vl=N3(L,-1);if(vl<=B5b(B)){memcpy(B->p,o_(L,-1),vl);B->p+=vl;U_(L,1);}else{if(w2a(B))A1(L,-2);B->lvl++;p6a(B);}}P
void
U1(a*L,I_*B){B->L=L;B->p=B->b0;B->lvl=0;}P
int
N_b(a*L,int
t){int
b7;t=I_a(L,t);if(l3(L,-1)){U_(L,1);return
o2b;}c0(L,t,u4);b7=(int)E0(L,-1);U_(L,1);if(b7!=0){c0(L,t,b7);D2(L,t,u4);}else{b7=I8(L,t);if(b7<m4a)b7=m4a;b7++;O8(L,t,b7);}D2(L,t,b7);return
b7;}P
void
M7a(a*L,int
t,int
b7){if(b7>=0){t=I_a(L,t);c0(L,t,u4);D2(L,t,b7);N(L,(U)b7);D2(L,t,u4);}}typedef
struct
a_b{FILE*f;char
p_[i3];}a_b;static
const
char*w_c(a*L,void*ud,size_t*W){a_b*lf=(a_b*)ud;(void)L;if(feof(lf->f))return
NULL;*W=fread(lf->p_,1,i3,lf->f);return(*W>0)?lf->p_:NULL;}static
int
u8a(a*L,int
w5){const
char*Q_=o_(L,w5)+1;P_(L,"cannot read %s: %s",Q_,strerror(errno));z5(L,w5);return
B_a;}P
int
J4(a*L,const
char*Q_){a_b
lf;int
T,A7a;int
c;int
w5=D_(L)+1;if(Q_==NULL){e_(L,"=stdin");lf.f=stdin;}else{P_(L,"@%s",Q_);lf.f=fopen(Q_,"r");}if(lf.f==NULL)return
u8a(L,w5);c=ungetc(getc(lf.f),lf.f);if(!(isspace(c)||isprint(c))&&lf.f!=stdin){fclose(lf.f);lf.f=fopen(Q_,"rb");if(lf.f==NULL)return
u8a(L,w5);}T=w1a(L,w_c,&lf,o_(L,-1));A7a=ferror(lf.f);if(lf.f!=stdin)fclose(lf.f);if(A7a){I0(L,w5);return
u8a(L,w5);}z5(L,w5);return
T;}typedef
struct
U9a{const
char*s;size_t
W;}U9a;static
const
char*K_c(a*L,void*ud,size_t*W){U9a*O=(U9a*)ud;(void)L;if(O->W==0)return
NULL;*W=O->W;O->W=0;return
O->s;}P
int
h3(a*L,const
char*p_,size_t
W,const
char*b_){U9a
O;O.s=p_;O.W=W;return
w1a(L,K_c,&O,b_);}static
void
E4b(a*L,int
T){if(T!=0){n5(L,"_ALERT");if(c2(L,-1)){A1(L,-2);e4(L,1,0);}else{fprintf(stderr,"%s\n",o_(L,-2));U_(L,2);}}}static
int
S3b(a*L,int
T){if(T==0){T=w4(L,0,y2,0);}E4b(L,T);return
T;}P
int
V6a(a*L,const
char*Q_){return
S3b(L,J4(L,Q_));}P
int
U4a(a*L,const
char*p_,size_t
W,const
char*b_){return
S3b(L,h3(L,p_,W,b_));}P
int
o1a(a*L,const
char*str){return
U4a(L,str,strlen(str),str);}
#define G9b
#ifndef w5b
#define w5b
#ifndef P
#define P K
#endif
#define z9a "coroutine"
P
int
q9(a*L);
#define B8a "table"
P
int
m8(a*L);
#define r9a "io"
#define x9a "os"
P
int
C0a(a*L);
#define p8a "string"
P
int
J7(a*L);
#define S6b "math"
P
int
O1a(a*L);
#define A9a "debug"
P
int
k8(a*L);P
int
d2a(a*L);
#ifndef H
#define H(c)
#endif
#define a7b q9
#define q7b m8
#define p8b C0a
#define l8b J7
#define L6b O1a
#define m8b k8
#endif
static
int
c3b(a*L){int
n=D_(L);int
i;n5(L,"tostring");for(i=1;i<=n;i++){const
char*s;Y(L,-1);Y(L,i);e4(L,1,1);s=o_(L,-1);if(s==NULL)return
s_(L,"`tostring' must return a string to `print'");if(i>1)fputs("\t",stdout);fputs(s,stdout);U_(L,1);}fputs("\n",stdout);return
0;}static
int
t9a(a*L){int
k_=a1(L,2,10);if(k_==10){A0(L,1);if(r2(L,1)){N(L,E0(L,1));return
1;}}else{const
char*s1=Q(L,1);char*s2;unsigned
long
n;e0(L,2<=k_&&k_<=36,2,"base out of range");n=strtoul(s1,&s2,k_);if(s1!=s2){while(isspace((unsigned
char)(*s2)))s2++;if(*s2=='\0'){N(L,(U)n);return
1;}}}w_(L);return
1;}static
int
g3b(a*L){int
z_=a1(L,2,1);A0(L,1);if(!W1(L,1)||z_==0)Y(L,1);else{I0a(L,z_);Y(L,1);O3(L,2);}return
N8(L);}static
int
Q5a(a*L){A0(L,1);if(!T2(L,1)){w_(L);return
1;}Y5(L,1,"__metatable");return
1;}static
int
P5a(a*L){int
t=b2(L,2);G_(L,1,H_);e0(L,t==P5||t==H_,2,"nil or table expected");if(Y5(L,1,"__metatable"))s_(L,"cannot change a protected metatable");I0(L,2);V2(L,1);return
1;}static
void
R1b(a*L){if(c2(L,1))Y(L,1);else{C0
ar;int
z_=a1(L,1,1);e0(L,z_>=0,1,"level must be non-negative");if(P2(L,z_,&ar)==0)d1(L,1,"invalid level");L5(L,"f",&ar);if(l3(L,-1))s_(L,"no function environment for tail call at level %d",z_);}}static
int
X5a(a*L){m6a(L,-1);e_(L,"__fenv");x0(L,-2);return!l3(L,-1);}static
int
R_b(a*L){R1b(L);if(!X5a(L))U_(L,1);return
1;}static
int
x0b(a*L){G_(L,2,H_);R1b(L);if(X5a(L))s_(L,"`setfenv' cannot change a protected environment");else
U_(L,2);Y(L,2);if(r2(L,1)&&E0(L,1)==0)Q5(L,a0);else
if(b6a(L,-2)==0)s_(L,"`setfenv' cannot change environment of given function");return
0;}static
int
L9a(a*L){A0(L,1);A0(L,2);n0(L,g5a(L,1,2));return
1;}static
int
T0b(a*L){G_(L,1,H_);A0(L,2);x0(L,1);return
1;}static
int
u1b(a*L){G_(L,1,H_);A0(L,2);A0(L,3);F0(L,1);return
1;}static
int
W0b(a*L){N(L,(U)I2a(L));N(L,(U)b0a(L));return
2;}static
int
n4a(a*L){H_a(L,a1(L,1,0));return
0;}static
int
e5b(a*L){A0(L,1);I(L,g7(L,b2(L,1)));return
1;}static
int
X4b(a*L){G_(L,1,H_);I0(L,2);if(G3a(L,1))return
2;else{w_(L);return
1;}}static
int
a3b(a*L){G_(L,1,H_);e_(L,"next");x0(L,a0);Y(L,1);w_(L);return
3;}static
int
l1b(a*L){U
i=E0(L,2);G_(L,1,H_);if(i==0&&e3(L,2)){e_(L,"ipairs");x0(L,a0);Y(L,1);N(L,0);return
3;}else{i++;N(L,i);c0(L,1,(int)i);return(l3(L,-1))?0:2;}}static
int
y_b(a*L,int
T){if(T==0)return
1;else{w_(L);A1(L,-2);return
2;}}static
int
J7a(a*L){size_t
l;const
char*s=y_(L,1,&l);const
char*L8=J0(L,2,s);return
y_b(L,h3(L,s,l,L8));}static
int
q9a(a*L){const
char*Y2b=J0(L,1,NULL);return
y_b(L,J4(L,Y2b));}static
int
c1b(a*L){const
char*Y2b=J0(L,1,NULL);int
n=D_(L);int
T=J4(L,Y2b);if(T!=0)N8(L);e4(L,0,y2);return
D_(L)-n;}static
int
N0b(a*L){A0(L,1);if(!V1(L,1))return
s_(L,"%s",J0(L,2,"assertion failed!"));I0(L,1);return
1;}static
int
j1b(a*L){int
n,i;G_(L,1,H_);n=I8(L,1);A4(L,n,"table too big to unpack");for(i=1;i<=n;i++)c0(L,1,i);return
n;}static
int
W2b(a*L){int
T;A0(L,1);T=w4(L,D_(L)-1,y2,0);n0(L,(T==0));A1(L,1);return
D_(L);}static
int
t1b(a*L){int
T;A0(L,2);I0(L,2);A1(L,1);T=w4(L,0,y2,1);n0(L,(T==0));Q5(L,1);return
D_(L);}static
int
w9a(a*L){char
p_[128];A0(L,1);if(e4a(L,1,"__tostring"))return
1;switch(b2(L,1)){case
N1:I(L,o_(L,1));return
1;case
q1:Y(L,1);return
1;case
f5:I(L,(V1(L,1)?"true":"false"));return
1;case
H_:sprintf(p_,"table: %p",f0a(L,1));break;case
d0:sprintf(p_,"function: %p",f0a(L,1));break;case
c1:case
I1:sprintf(p_,"userdata: %p",Y1(L,1));break;case
Y2:sprintf(p_,"thread: %p",(void*)j6(L,1));break;case
P5:e_(L,"nil");return
1;}I(L,p_);return
1;}static
int
E9a(a*L){I0(L,1);y5(L,0);if(V1(L,1)==0)return
1;else
if(J9a(L,1)){S0(L);Y(L,-1);n0(L,1);F0(L,O_(1));}else{int
W6a=0;if(T2(L,1)){x0(L,O_(1));W6a=V1(L,-1);U_(L,1);}e0(L,W6a,1,"boolean or proxy expected");T2(L,1);}V2(L,2);return
1;}
#define f_b "_LOADED"
#define q0b "LUA_PATH"
#ifndef l1a
#define l1a ';'
#endif
#ifndef P3a
#define P3a '?'
#endif
#ifndef n1a
#define n1a "?;?.lua"
#endif
static
const
char*C1b(a*L){const
char*B_;n5(L,q0b);B_=o_(L,-1);U_(L,1);if(B_)return
B_;B_=getenv(q0b);if(B_)return
B_;return
n1a;}static
const
char*u0b(a*L,const
char*B_){const
char*l;if(*B_=='\0')return
NULL;if(*B_==l1a)B_++;l=strchr(B_,l1a);if(l==NULL)l=B_+strlen(B_);Z0(L,B_,l-B_);return
l;}static
void
V7a(a*L){const
char*B_=o_(L,-1);const
char*v6b;int
n=1;while((v6b=strchr(B_,P3a))!=NULL){A4(L,3,"too many marks in a path component");Z0(L,B_,v6b-B_);Y(L,1);B_=v6b+1;n+=2;}I(L,B_);O3(L,n);}static
int
X_b(a*L){const
char*B_;int
T=B_a;Q(L,1);I0(L,1);n5(L,f_b);if(!h6a(L,2))return
s_(L,"`"f_b"' is not a table");B_=C1b(L);Y(L,1);x0(L,2);if(V1(L,-1))return
1;else{while(T==B_a){I0(L,3);if((B_=u0b(L,B_))==NULL)break;V7a(L);T=J4(L,o_(L,-1));}}switch(T){case
0:{n5(L,"_REQUIREDNAME");A1(L,-2);Y(L,1);s8(L,"_REQUIREDNAME");e4(L,0,1);A1(L,-2);s8(L,"_REQUIREDNAME");if(l3(L,-1)){n0(L,1);Q5(L,-2);}Y(L,1);Y(L,-2);F0(L,2);return
1;}case
B_a:{return
s_(L,"could not load package `%s' from path `%s'",o_(L,1),C1b(L));}default:{return
s_(L,"error loading package `%s' (%s)",o_(L,1),o_(L,-1));}}}static
const
g3
y2b[]={{"error",g3b},{"getmetatable",Q5a},{"setmetatable",P5a},{"getfenv",R_b},{"setfenv",x0b},{"next",X4b},{"ipairs",l1b},{"pairs",a3b},{"print",c3b},{"tonumber",t9a},{"tostring",w9a},{"type",e5b},{"assert",N0b},{"unpack",j1b},{"rawequal",L9a},{"rawget",T0b},{"rawset",u1b},{"pcall",W2b},{"xpcall",t1b},{"collectgarbage",n4a},{"gcinfo",W0b},{"loadfile",q9a},{"dofile",c1b},{"loadstring",J7a},{"require",X_b},{NULL,NULL}};static
int
j9a(a*L,a*co,int
O1){int
T;if(!A7(co,O1))s_(L,"too many arguments to resume");X_a(L,co,O1);T=k3a(co,O1);if(T==0){int
U6a=D_(co);if(!A7(L,U6a))s_(L,"too many results to resume");X_a(co,L,U6a);return
U6a;}else{X_a(co,L,1);return-1;}}static
int
C9a(a*L){a*co=j6(L,1);int
r;e0(L,co,1,"coroutine expected");r=j9a(L,co,D_(L)-1);if(r<0){n0(L,0);A1(L,-2);return
2;}else{n0(L,1);A1(L,-(r+1));return
r+1;}}static
int
t_b(a*L){a*co=j6(L,O_(1));int
r=j9a(L,co,D_(L));if(r<0){if(W1(L,-1)){I0a(L,1);A1(L,-2);O3(L,2);}N8(L);}return
r;}static
int
h4a(a*L){a*NL=r0a(L);e0(L,c2(L,1)&&!K3(L,1),1,"Lua function expected");Y(L,1);X_a(L,NL,1);return
1;}static
int
Y0b(a*L){h4a(L);x1(L,t_b,1);return
1;}static
int
M2b(a*L){return
y4a(L,D_(L));}static
int
I9a(a*L){a*co=j6(L,1);e0(L,co,1,"coroutine expected");if(L==co)e_(L,"running");else{C0
ar;if(P2(co,0,&ar)==0&&D_(co)==0)e_(L,"dead");else
e_(L,"suspended");}return
1;}static
const
g3
I5b[]={{"create",h4a},{"wrap",Y0b},{"resume",C9a},{"yield",M2b},{"status",I9a},{NULL,NULL}};static
void
f4b(a*L){e_(L,"_G");Y(L,a0);u2(L,NULL,y2b,0);e_(L,"_VERSION");e_(L,X7);F0(L,-3);e_(L,"newproxy");S0(L);Y(L,-1);V2(L,-2);e_(L,"__mode");e_(L,"k");F0(L,-3);x1(L,E9a,1);F0(L,-3);F0(L,-1);}P
int
q9(a*L){f4b(L);u2(L,z9a,I5b,0);S0(L);s8(L,f_b);return
0;}
#define R_c
#ifndef c8b
#define c8b
#ifndef v8b
#define v8b
#define h6 257
#define c4b (sizeof("function")/sizeof(char))
enum
b6b{k9b=h6,n6b,R9a,M1b,V8a,U2a,p5b,H3b,o_a,Y6b,Z6b,v5b,b9b,J8b,S9b,F8a,X3b,p7b,D7b,z_b,N6a,e_a,d9a,P1b,E6b,F6b,M6b,V6b,K8,u6,W7};
#define i0b (g_(int,N6a-h6+1))
typedef
union{U
r;A_*ts;}P0a;typedef
struct
h3b{int
T_;P0a
F1;}h3b;typedef
struct
c_{int
i_;int
n2;int
J1a;h3b
t;h3b
V4;struct
M*J;struct
a*L;X8*z;f6*p_;A_*m0;int
c2a;}c_;void
M8a(a*L);void
R3a(a*L,c_*LS,X8*z,A_*m0);int
K6a(c_*LS,P0a*F1);void
M3(c_*O,int
r6,int
N2,const
char*O6);void
t0(c_*O,const
char*s);void
d_a(c_*O,const
char*s,const
char*T_,int
W_);const
char*b5(c_*O,int
T_);
#endif
#ifndef S2b
#define S2b
enum
B8b{P3,y3a,K5a};
#define L_a 9
#define S_a 9
#define Y2a (L_a+S_a)
#define l5a 8
#define P2a 6
#define j3a P2a
#define G5a (j3a+L_a)
#define h5a j3a
#define y5a (G5a+S_a)
#if Y2a<BITS_INT-1
#define K_a ((1<<Y2a)-1)
#define c9 (K_a>>1)
#else
#define K_a B7
#define c9 B7
#endif
#define z5b ((1<<l5a)-1)
#define O_c ((1<<S_a)-1)
#define j_b ((1<<L_a)-1)
#define J0a(n,p) ((~((~(j_)0)<<n))<<p)
#define b7a(n,p) (~J0a(n,p))
#define V_(i) (g_(a6,(i)&J0a(P2a,0)))
#define b3b(i,o) ((i)=(((i)&b7a(P2a,0))|g_(j_,o)))
#define w3(i) (g_(int,(i)>>y5a))
#define O6a(i,u) ((i)=(((i)&b7a(l5a,y5a))|((g_(j_,u)<<y5a)&J0a(l5a,y5a))))
#define a2(i) (g_(int,((i)>>G5a)&J0a(S_a,0)))
#define G6a(i,b) ((i)=(((i)&b7a(S_a,G5a))|((g_(j_,b)<<G5a)&J0a(S_a,G5a))))
#define X2(i) (g_(int,((i)>>j3a)&J0a(L_a,0)))
#define i_b(i,b) ((i)=(((i)&b7a(L_a,j3a))|((g_(j_,b)<<j3a)&J0a(L_a,j3a))))
#define v7(i) (g_(int,((i)>>h5a)&J0a(Y2a,0)))
#define q3b(i,b) ((i)=(((i)&b7a(Y2a,h5a))|((g_(j_,b)<<h5a)&J0a(Y2a,h5a))))
#define Q3(i) (v7(i)-c9)
#define I2b(i,b) q3b((i),g_(unsigned int,(b)+c9))
#define z2b(o,a,b,c) (g_(j_,o)|(g_(j_,a)<<y5a)|(g_(j_,b)<<G5a)|(g_(j_,c)<<j3a))
#define U2b(o,a,bc) (g_(j_,o)|(g_(j_,a)<<y5a)|(g_(j_,bc)<<h5a))
#define F6 z5b
typedef
enum{S8,M3a,f8,v9,J5,z7,x_a,J9,p_a,D_a,t2a,C2a,k0b,W_b,r4b,B3b,P3b,A0b,M4a,R_a,r5a,b_b,T9a,V9a,l_a,D4,W4,X4,K0a,y_a,y2a,B6,a8,I3a,K9}a6;
#define q6a (g_(int,K9+1))
enum
w9b{q7a=2,e9a,E8a,H7a,E1b,H5a};extern
const
S_
Z0a[q6a];
#define J_a(m) (g_(enum B8b,Z0a[m]&3))
#define v5(m,b) (Z0a[m]&(1<<(b)))
#ifdef n1b
extern
const
char*const
X4a[];
#endif
#define P4 32
#endif
#ifndef r3b
#define r3b
typedef
enum{t_a,f8a,f2a,r1a,VK,z1a,w7a,z5a,m1a,I6a,f3,X3,V1a}U1b;typedef
struct
d_{U1b
k;int
C_,r9;int
t;int
f;}d_;struct
f4;typedef
struct
M{E_*f;o0*h;struct
M*N4a;struct
c_*O;struct
a*L;struct
f4*bl;int
pc;int
E3a;int
jpc;int
w0;int
nk;int
np;int
f_a;int
M0;d_
i0[G_a];int
K3b[O5a];}M;E_*e6a(a*L,X8*z,f6*p_);
#endif
#define B0 (-1)
typedef
enum
c8{F1b,k7b,o6b,I7b,H1b,q3a,X6a,M8b,Z8b,l9b,A4b,j9b,D8a,p_b,I4a}c8;
#define s9b(op) ((op)>=X6a)
typedef
enum
G7a{W8a,g7b,l6a}G7a;
#define E7(J,e) ((J)->f->m1[(e)->C_])
#define e0a(J,o,A,sBx) s3(J,o,A,(sBx)+c9)
int
n2a(M*J,j_
i,int
W_);int
s3(M*J,a6
o,int
A,unsigned
int
Bx);int
K_(M*J,a6
o,int
A,int
B,int
C);void
O9(M*J,int
W_);void
w6a(M*J,int
U0,int
n);void
P1(M*J,int
n);void
n9(M*J,int
n);int
b1a(M*J,A_*s);int
M9(M*J,U
r);void
R0(M*J,d_*e);int
d2(M*J,d_*e);void
K0(M*J,d_*e);void
k7(M*J,d_*e);int
D3(M*J,d_*e);void
Q8a(M*J,d_*e,d_*x_);void
s1a(M*J,d_*t,d_*k);void
n0a(M*J,d_*e);void
R7(M*J,d_*e);void
J6(M*J,d_*W8,d_*e);void
S1(M*J,d_*W8,int
z0);int
t4(M*J);void
I7(M*J,int
f0,int
a9);void
L0(M*J,int
f0);void
w2(M*J,int*l1,int
l2);int
W3(M*J);void
f6a(M*J,G7a
op,d_*v);void
N7a(M*J,c8
op,d_*v);void
T5a(M*J,c8
op,d_*v1,d_*v2);
#endif
#define A6a(e) ((e)->t!=(e)->f)
void
w6a(M*J,int
U0,int
n){j_*Y_;if(J->pc>J->E3a&&V_(*(Y_=&J->f->m1[J->pc-1]))==v9){int
M9b=w3(*Y_);int
pto=a2(*Y_);if(M9b<=U0&&U0<=pto+1){if(U0+n-1>pto)G6a(*Y_,U0+n-1);return;}}K_(J,v9,U0,U0+n-1,0);}int
t4(M*J){int
jpc=J->jpc;int
j;J->jpc=B0;j=e0a(J,r5a,0,B0);w2(J,&j,jpc);return
j;}static
int
p0a(M*J,a6
op,int
A,int
B,int
C){K_(J,op,A,B,C);return
t4(J);}static
void
N9(M*J,int
pc,int
t6a){j_*jmp=&J->f->m1[pc];int
P_a=t6a-(pc+1);H(t6a!=B0);if(abs(P_a)>c9)t0(J->O,"control structure too long");I2b(*jmp,P_a);}int
W3(M*J){J->E3a=J->pc;return
J->pc;}static
int
f1a(M*J,int
pc){int
P_a=Q3(J->f->m1[pc]);if(P_a==B0)return
B0;else
return(pc+1)+P_a;}static
j_*j_a(M*J,int
pc){j_*pi=&J->f->m1[pc];if(pc>=1&&v5(V_(*(pi-1)),H5a))return
pi-1;else
return
pi;}static
int
S7a(M*J,int
f0,int
c6){for(;f0!=B0;f0=f1a(J,f0)){j_
i=*j_a(J,f0);if(V_(i)!=l_a||X2(i)!=c6)return
1;}return
0;}static
void
a5a(j_*i,int
b4){if(b4==F6)b4=a2(*i);O6a(*i,b4);}static
void
X5(M*J,int
f0,int
b2b,int
E_c,int
a2b,int
M_c,int
Q1b){while(f0!=B0){int
h_=f1a(J,f0);j_*i=j_a(J,f0);if(V_(*i)!=l_a){H(Q1b!=B0);N9(J,f0,Q1b);}else{if(X2(*i)){H(b2b!=B0);a5a(i,E_c);N9(J,f0,b2b);}else{H(a2b!=B0);a5a(i,M_c);N9(J,f0,a2b);}}f0=h_;}}static
void
S5a(M*J){X5(J,J->jpc,J->pc,F6,J->pc,F6,J->pc);J->jpc=B0;}void
I7(M*J,int
f0,int
a9){if(a9==J->pc)L0(J,f0);else{H(a9<J->pc);X5(J,f0,a9,F6,a9,F6,a9);}}void
L0(M*J,int
f0){W3(J);w2(J,&J->jpc,f0);}void
w2(M*J,int*l1,int
l2){if(l2==B0)return;else
if(*l1==B0)*l1=l2;else{int
f0=*l1;int
h_;while((h_=f1a(J,f0))!=B0)f0=h_;N9(J,f0,l2);}}void
n9(M*J,int
n){int
y6a=J->w0+n;if(y6a>J->f->Z1){if(y6a>=q2)t0(J->O,"function or expression too complex");J->f->Z1=g_(S_,y6a);}}void
P1(M*J,int
n){n9(J,n);J->w0+=n;}static
void
w0(M*J,int
b4){if(b4>=J->M0&&b4<q2){J->w0--;H(b4==J->w0);}}static
void
Y4(M*J,d_*e){if(e->k==X3)w0(J,e->C_);}static
int
J5b(M*J,E*k,E*v){const
E*F_=p7(J->h,k);if(W0(F_)){H(u3(&J->f->k[g_(int,r0(F_))],v));return
g_(int,r0(F_));}else{E_*f=J->f;B4(J->L,f->k,J->nk,f->Z8,E,K_a,"constant table overflow");m3a(&f->k[J->nk],v);K1(h_a(J->L,J->h,k),g_(U,J->nk));return
J->nk++;}}int
b1a(M*J,A_*s){E
o;l2a(&o,s);return
J5b(J,&o,&o);}int
M9(M*J,U
r){E
o;K1(&o,r);return
J5b(J,&o,&o);}static
int
D0b(M*J){E
k,v;R_(&v);s6(&k,J->h);return
J5b(J,&k,&v);}void
S1(M*J,d_*e,int
z0){if(e->k==V1a){i_b(E7(J,e),z0+1);if(z0==1){e->k=X3;e->C_=w3(E7(J,e));}}}void
R0(M*J,d_*e){switch(e->k){case
z1a:{e->k=X3;break;}case
w7a:{e->C_=K_(J,J5,0,e->C_,0);e->k=f3;break;}case
z5a:{e->C_=s3(J,z7,0,e->C_);e->k=f3;break;}case
m1a:{w0(J,e->r9);w0(J,e->C_);e->C_=K_(J,x_a,0,e->C_,e->r9);e->k=f3;break;}case
V1a:{S1(J,e,1);break;}default:break;}}static
int
n7a(M*J,int
A,int
b,int
H4){W3(J);return
K_(J,f8,A,b,H4);}static
void
c4a(M*J,d_*e,int
b4){R0(J,e);switch(e->k){case
f8a:{w6a(J,b4,1);break;}case
r1a:case
f2a:{K_(J,f8,b4,e->k==f2a,0);break;}case
VK:{s3(J,M3a,b4,e->C_);break;}case
f3:{j_*pc=&E7(J,e);O6a(*pc,b4);break;}case
X3:{if(b4!=e->C_)K_(J,S8,b4,e->C_,0);break;}default:{H(e->k==t_a||e->k==I6a);return;}}e->C_=b4;e->k=X3;}static
void
V0a(M*J,d_*e){if(e->k!=X3){P1(J,1);c4a(J,e,J->w0-1);}}static
void
x1a(M*J,d_*e,int
b4){c4a(J,e,b4);if(e->k==I6a)w2(J,&e->t,e->C_);if(A6a(e)){int
z3a;int
p_f=B0;int
p_t=B0;if(S7a(J,e->t,1)||S7a(J,e->f,0)){int
fj=B0;if(e->k!=I6a)fj=t4(J);p_f=n7a(J,b4,0,1);p_t=n7a(J,b4,1,0);L0(J,fj);}z3a=W3(J);X5(J,e->f,p_f,F6,z3a,b4,p_f);X5(J,e->t,z3a,b4,p_t,F6,p_t);}e->f=e->t=B0;e->C_=b4;e->k=X3;}void
K0(M*J,d_*e){R0(J,e);Y4(J,e);P1(J,1);x1a(J,e,J->w0-1);}int
d2(M*J,d_*e){R0(J,e);if(e->k==X3){if(!A6a(e))return
e->C_;if(e->C_>=J->M0){x1a(J,e,e->C_);return
e->C_;}}K0(J,e);return
e->C_;}void
k7(M*J,d_*e){if(A6a(e))d2(J,e);else
R0(J,e);}int
D3(M*J,d_*e){k7(J,e);switch(e->k){case
f8a:{if(J->nk+q2<=j_b){e->C_=D0b(J);e->k=VK;return
e->C_+q2;}else
break;}case
VK:{if(e->C_+q2<=j_b)return
e->C_+q2;else
break;}default:break;}return
d2(J,e);}void
J6(M*J,d_*W8,d_*exp){switch(W8->k){case
z1a:{Y4(J,exp);x1a(J,exp,W8->C_);return;}case
w7a:{int
e=d2(J,exp);K_(J,p_a,e,W8->C_,0);break;}case
z5a:{int
e=d2(J,exp);s3(J,J9,e,W8->C_);break;}case
m1a:{int
e=D3(J,exp);K_(J,D_a,W8->C_,W8->r9,e);break;}default:{H(0);break;}}Y4(J,exp);}void
Q8a(M*J,d_*e,d_*x_){int
Z_;d2(J,e);Y4(J,e);Z_=J->w0;P1(J,2);K_(J,C2a,Z_,e->C_,D3(J,x_));Y4(J,x_);e->C_=Z_;e->k=X3;}static
void
W7a(M*J,d_*e){j_*pc=j_a(J,e->C_);H(v5(V_(*pc),H5a)&&V_(*pc)!=l_a);O6a(*pc,!(w3(*pc)));}static
int
K7a(M*J,d_*e,int
c6){if(e->k==f3){j_
ie=E7(J,e);if(V_(ie)==M4a){J->pc--;return
p0a(J,l_a,F6,a2(ie),!c6);}}V0a(J,e);Y4(J,e);return
p0a(J,l_a,F6,e->C_,c6);}void
n0a(M*J,d_*e){int
pc;R0(J,e);switch(e->k){case
VK:case
f2a:{pc=B0;break;}case
r1a:{pc=t4(J);break;}case
I6a:{W7a(J,e);pc=e->C_;break;}default:{pc=K7a(J,e,0);break;}}w2(J,&e->f,pc);}void
R7(M*J,d_*e){int
pc;R0(J,e);switch(e->k){case
f8a:case
r1a:{pc=B0;break;}case
f2a:{pc=t4(J);break;}case
I6a:{pc=e->C_;break;}default:{pc=K7a(J,e,1);break;}}w2(J,&e->t,pc);}static
void
g8b(M*J,d_*e){R0(J,e);switch(e->k){case
f8a:case
r1a:{e->k=f2a;break;}case
VK:case
f2a:{e->k=r1a;break;}case
I6a:{W7a(J,e);break;}case
f3:case
X3:{V0a(J,e);Y4(J,e);e->C_=K_(J,M4a,0,e->C_,0);e->k=f3;break;}default:{H(0);break;}}{int
Y6=e->f;e->f=e->t;e->t=Y6;}}void
s1a(M*J,d_*t,d_*k){t->r9=D3(J,k);t->k=m1a;}void
f6a(M*J,G7a
op,d_*e){if(op==W8a){k7(J,e);if(e->k==VK&&W0(&J->f->k[e->C_]))e->C_=M9(J,-r0(&J->f->k[e->C_]));else{d2(J,e);Y4(J,e);e->C_=K_(J,A0b,0,e->C_,0);e->k=f3;}}else
g8b(J,e);}void
N7a(M*J,c8
op,d_*v){switch(op){case
D8a:{n0a(J,v);L0(J,v->t);v->t=B0;break;}case
p_b:{R7(J,v);L0(J,v->f);v->f=B0;break;}case
q3a:{K0(J,v);break;}default:{D3(J,v);break;}}}static
void
j5b(M*J,d_*h0,c8
op,int
o1,int
o2){if(op<=H1b){a6
opc=g_(a6,(op-F1b)+k0b);h0->C_=K_(J,opc,0,o1,o2);h0->k=f3;}else{static
const
a6
ops[]={b_b,b_b,T9a,V9a,T9a,V9a};int
c6=1;if(op>=A4b){int
Y6;Y6=o1;o1=o2;o2=Y6;}else
if(op==X6a)c6=0;h0->C_=p0a(J,ops[op-X6a],c6,o1,o2);h0->k=I6a;}}void
T5a(M*J,c8
op,d_*e1,d_*e2){switch(op){case
D8a:{H(e1->t==B0);R0(J,e2);w2(J,&e1->f,e2->f);e1->k=e2->k;e1->C_=e2->C_;e1->r9=e2->r9;e1->t=e2->t;break;}case
p_b:{H(e1->f==B0);R0(J,e2);w2(J,&e1->t,e2->t);e1->k=e2->k;e1->C_=e2->C_;e1->r9=e2->r9;e1->f=e2->f;break;}case
q3a:{k7(J,e2);if(e2->k==f3&&V_(E7(J,e2))==R_a){H(e1->C_==a2(E7(J,e2))-1);Y4(J,e1);G6a(E7(J,e2),e1->C_);e1->k=e2->k;e1->C_=e2->C_;}else{K0(J,e2);Y4(J,e2);Y4(J,e1);e1->C_=K_(J,R_a,0,e1->C_,e2->C_);e1->k=f3;}break;}default:{int
o1=D3(J,e1);int
o2=D3(J,e2);Y4(J,e2);Y4(J,e1);j5b(J,e1,op,o1,o2);}}}void
O9(M*J,int
W_){J->f->i4[J->pc-1]=W_;}int
n2a(M*J,j_
i,int
W_){E_*f=J->f;S5a(J);B4(J->L,f->m1,J->pc,f->H2,j_,B7,"code size overflow");f->m1[J->pc]=i;B4(J->L,f->i4,J->pc,f->o3,int,B7,"code size overflow");f->i4[J->pc]=W_;return
J->pc++;}int
K_(M*J,a6
o,int
a,int
b,int
c){H(J_a(o)==P3);return
n2a(J,z2b(o,a,b,c),J->O->J1a);}int
s3(M*J,a6
o,int
a,unsigned
int
bc){H(J_a(o)==y3a||J_a(o)==K5a);return
n2a(J,U2b(o,a,bc),J->O->J1a);}
#define P_c
static
void
j1a(a*L,const
char*i,const
char*v){I(L,i);I(L,v);F0(L,-3);}static
void
D6a(a*L,const
char*i,int
v){I(L,i);N(L,(U)v);F0(L,-3);}static
int
e7b(a*L){C0
ar;const
char*N0a=J0(L,2,"flnSu");if(r2(L,1)){if(!P2(L,(int)(E0(L,1)),&ar)){w_(L);return
1;}}else
if(c2(L,1)){P_(L,">%s",N0a);N0a=o_(L,-1);Y(L,1);}else
return
d1(L,1,"function or level expected");if(!L5(L,N0a,&ar))return
d1(L,2,"invalid option");S0(L);for(;*N0a;N0a++){switch(*N0a){case'S':j1a(L,"source",ar.m0);j1a(L,"short_src",ar.T8);D6a(L,"linedefined",ar.Q6);j1a(L,"what",ar.r3);break;case'l':D6a(L,"currentline",ar.x2);break;case'u':D6a(L,"nups",ar.e5);break;case'n':j1a(L,"name",ar.b_);j1a(L,"namewhat",ar.r7);break;case'f':e_(L,"func");Y(L,-3);F0(L,-3);break;}}return
1;}static
int
m6b(a*L){C0
ar;const
char*b_;if(!P2(L,X_(L,1),&ar))return
d1(L,1,"level out of range");b_=D4a(L,&ar,X_(L,2));if(b_){I(L,b_);Y(L,-2);return
2;}else{w_(L);return
1;}}static
int
S5b(a*L){C0
ar;if(!P2(L,X_(L,1),&ar))return
d1(L,1,"level out of range");A0(L,3);I(L,p5a(L,&ar,X_(L,2)));return
1;}static
int
p7a(a*L,int
e8){const
char*b_;int
n=X_(L,2);G_(L,1,d0);if(K3(L,1))return
0;b_=e8?i_a(L,1,n):W9(L,1,n);if(b_==NULL)return
0;I(L,b_);A1(L,-(e8+1));return
e8+1;}static
int
k3b(a*L){return
p7a(L,1);}static
int
u2b(a*L){A0(L,3);return
p7a(L,0);}static
const
char
R6a='h';static
void
R6b(a*L,C0*ar){static
const
char*const
C4b[]={"call","return","line","count","tail return"};C1(L,(void*)&R6a);x0(L,L_);if(c2(L,-1)){I(L,C4b[(int)ar->O2]);if(ar->x2>=0)N(L,(U)ar->x2);else
w_(L);H(L5(L,"lS",ar));e4(L,2,0);}else
U_(L,1);}static
int
V5b(const
char*P7,int
w1){int
F4=0;if(strchr(P7,'c'))F4|=q7;if(strchr(P7,'r'))F4|=E_a;if(strchr(P7,'l'))F4|=n6;if(w1>0)F4|=L6;return
F4;}static
char*D2b(int
F4,char*P7){int
i=0;if(F4&q7)P7[i++]='c';if(F4&E_a)P7[i++]='r';if(F4&n6)P7[i++]='l';P7[i]='\0';return
P7;}static
int
S7b(a*L){if(J1(L,1)){I0(L,1);K5(L,NULL,0,0);}else{const
char*P7=Q(L,2);int
w1=a1(L,3,0);G_(L,1,d0);K5(L,R6b,V5b(P7,w1),w1);}C1(L,(void*)&R6a);Y(L,1);F0(L,L_);return
0;}static
int
N7b(a*L){char
p_[5];int
F4=g2a(L);w8
w6=o6a(L);if(w6!=NULL&&w6!=R6b)e_(L,"external hook");else{C1(L,(void*)&R6a);x0(L,L_);}I(L,D2b(F4,p_));N(L,(U)U0a(L));return
3;}static
int
M5a(a*L){for(;;){char
b0[250];fputs("lua_debug> ",stderr);if(fgets(b0,sizeof(b0),stdin)==0||strcmp(b0,"cont\n")==0)return
0;o1a(L,b0);I0(L,0);}}
#define Y7b 12
#define h8a 10
static
int
K1b(a*L){int
z_=1;int
X8a=1;C0
ar;if(D_(L)==0)e_(L,"");else
if(!W1(L,1))return
1;else
e_(L,"\n");e_(L,"stack traceback:");while(P2(L,z_++,&ar)){if(z_>Y7b&&X8a){if(!P2(L,z_+h8a,&ar))z_--;else{e_(L,"\n\t...");while(P2(L,z_+h8a,&ar))z_++;}X8a=0;continue;}e_(L,"\n\t");L5(L,"Snl",&ar);P_(L,"%s:",ar.T8);if(ar.x2>0)P_(L,"%d:",ar.x2);switch(*ar.r7){case'g':case'l':case'f':case'm':P_(L," in function `%s'",ar.b_);break;default:{if(*ar.r3=='m')P_(L," in main chunk");else
if(*ar.r3=='C'||*ar.r3=='t')e_(L," ?");else
P_(L," in function <%s:%d>",ar.T8,ar.Q6);}}O3(L,D_(L));}O3(L,D_(L));return
1;}static
const
g3
F9b[]={{"getlocal",m6b},{"getinfo",e7b},{"gethook",N7b},{"getupvalue",k3b},{"sethook",S7b},{"setlocal",S5b},{"setupvalue",u2b},{"debug",M5a},{"traceback",K1b},{NULL,NULL}};P
int
k8(a*L){u2(L,A9a,F9b,0);e_(L,"_TRACEBACK");V7(L,K1b);P0(L,a0);return
1;}
#define B_c
static
const
char*r6a(l0*ci,const
char**b_);
#define F5a(ci) (!((ci)->g0&K1a))
static
int
H8(l0*ci){if(!F5a(ci))return-1;if(ci->g0&U6)ci->u.l.j2=*ci->u.l.pc;return
W9a(ci->u.l.j2,M0a(ci)->l.p);}static
int
x2(l0*ci){int
pc=H8(ci);if(pc<0)return-1;else
return
A5a(M0a(ci)->l.p,pc);}void
Z2a(a*L){l0*ci;for(ci=L->ci;ci!=L->N0;ci--)H8(ci);L->d3a=1;}K
int
K5(a*L,w8
Z_,int
F4,int
w1){if(Z_==NULL||F4==0){F4=0;Z_=NULL;}L->w6=Z_;L->n8=w1;X9(L);L->C6=g_(S_,F4);L->d3a=0;return
1;}K
w8
o6a(a*L){return
L->w6;}K
int
g2a(a*L){return
L->C6;}K
int
U0a(a*L){return
L->n8;}K
int
P2(a*L,int
z_,C0*ar){int
T;l0*ci;n_(L);for(ci=L->ci;z_>0&&ci>L->N0;ci--){z_--;if(!(ci->g0&K1a))z_-=ci->u.l.V_a;}if(z_>0||ci==L->N0)T=0;else
if(z_<0){T=1;ar->b5a=0;}else{T=1;ar->b5a=ci-L->N0;}f_(L);return
T;}static
E_*r2a(l0*ci){return(F5a(ci)?M0a(ci)->l.p:NULL);}K
const
char*D4a(a*L,const
C0*ar,int
n){const
char*b_;l0*ci;E_*fp;n_(L);b_=NULL;ci=L->N0+ar->b5a;fp=r2a(ci);if(fp){b_=O4(fp,n,H8(ci));if(b_)C4(L,ci->k_+(n-1));}f_(L);return
b_;}K
const
char*p5a(a*L,const
C0*ar,int
n){const
char*b_;l0*ci;E_*fp;n_(L);b_=NULL;ci=L->N0+ar->b5a;fp=r2a(ci);L->X--;if(fp){b_=O4(fp,n,H8(ci));if(!b_||b_[0]=='(')b_=NULL;else
f1(ci->k_+(n-1),L->X);}f_(L);return
b_;}static
void
E5b(C0*ar,t_
Z_){z2*cl=A2(Z_);if(cl->c.isC){ar->m0="=[C]";ar->Q6=-1;ar->r3="C";}else{ar->m0=C5(cl->l.p->m0);ar->Q6=cl->l.p->Z7;ar->r3=(ar->Q6==0)?"main":"Lua";}y7(ar->T8,ar->m0,Y8);}static
const
char*V0b(a*L,const
E*o){o0*g=i1(gt(L));int
i=k5(g);while(i--){I3*n=l5(g,i);if(u3(o,y4(n))&&n1(g4(n)))return
C5(k2(g4(n)));}return
NULL;}static
void
D9a(a*L,C0*ar){ar->b_=ar->r7="";ar->r3="tail";ar->Q6=ar->x2=-1;ar->m0="=(tail call)";y7(ar->T8,ar->m0,Y8);ar->e5=0;R_(L->X);}static
int
l7a(a*L,const
char*r3,C0*ar,t_
f,l0*ci){int
T=1;for(;*r3;r3++){switch(*r3){case'S':{E5b(ar,f);break;}case'l':{ar->x2=(ci)?x2(ci):-1;break;}case'u':{ar->e5=A2(f)->c.c4;break;}case'n':{ar->r7=(ci)?r6a(ci,&ar->b_):NULL;if(ar->r7==NULL){if((ar->b_=V0b(L,f))!=NULL)ar->r7="global";else
ar->r7="";}break;}case'f':{k0(L->X,f);break;}default:T=0;}}return
T;}K
int
L5(a*L,const
char*r3,C0*ar){int
T=1;n_(L);if(*r3=='>'){t_
f=L->X-1;if(!X1(f))q_(L,"value for `lua_getinfo' is not a function");T=l7a(L,r3+1,ar,f,NULL);L->X--;}else
if(ar->b5a!=0){l0*ci=L->N0+ar->b5a;H(X1(ci->k_-1));T=l7a(L,r3,ar,ci->k_-1,ci);}else
D9a(L,ar);if(strchr(r3,'f'))R3(L);f_(L);return
T;}
#define J_(x) if(!(x))return 0;
#define Y4b(pt,pc) J_(0<=pc&&pc<pt->H2)
#define V5(pt,b4) J_((b4)<(pt)->Z1)
static
int
U5b(const
E_*pt){J_(pt->Z1<=q2);J_(pt->o3==pt->H2||pt->o3==0);H(pt->d7+pt->J8<=pt->Z1);J_(V_(pt->m1[pt->H2-1])==X4);return
1;}static
int
e1b(const
E_*pt,int
pc){j_
i=pt->m1[pc+1];switch(V_(i)){case
D4:case
W4:case
X4:{J_(a2(i)==0);return
1;}case
a8:return
1;default:return
0;}}static
int
f2b(const
E_*pt,int
r){return(r<pt->Z1||(r>=q2&&r-q2<pt->Z8));}static
j_
X3a(const
E_*pt,int
P_b,int
b4){int
pc;int
I2;I2=pt->H2-1;J_(U5b(pt));for(pc=0;pc<P_b;pc++){const
j_
i=pt->m1[pc];a6
op=V_(i);int
a=w3(i);int
b=0;int
c=0;V5(pt,a);switch(J_a(op)){case
P3:{b=a2(i);c=X2(i);if(v5(op,q7a)){V5(pt,b);}else
if(v5(op,e9a))J_(f2b(pt,b));if(v5(op,E8a))J_(f2b(pt,c));break;}case
y3a:{b=v7(i);if(v5(op,E1b))J_(b<pt->Z8);break;}case
K5a:{b=Q3(i);break;}}if(v5(op,H7a)){if(a==b4)I2=pc;}if(v5(op,H5a)){J_(pc+2<pt->H2);J_(V_(pt->m1[pc+1])==r5a);}switch(op){case
f8:{J_(c==0||pc+2<pt->H2);break;}case
v9:{if(a<=b4&&b4<=b)I2=pc;break;}case
J5:case
p_a:{J_(b<pt->e5);break;}case
z7:case
J9:{J_(n1(&pt->k[b]));break;}case
C2a:{V5(pt,a+1);if(b4==a+1)I2=pc;break;}case
R_a:{J_(c<q2&&b<c);break;}case
y_a:V5(pt,a+c+5);if(b4>=a)I2=pc;case
K0a:V5(pt,a+2);case
r5a:{int
t6a=pc+1+b;J_(0<=t6a&&t6a<pt->H2);if(b4!=F6&&pc<t6a&&t6a<=P_b)pc+=b;break;}case
D4:case
W4:{if(b!=0){V5(pt,a+b-1);}c--;if(c==y2){J_(e1b(pt,pc));}else
if(c!=0)V5(pt,a+c-1);if(b4>=a)I2=pc;break;}case
X4:{b--;if(b>0)V5(pt,a+b-1);break;}case
B6:{V5(pt,a+(b&(P4-1))+1);break;}case
K9:{int
nup;J_(b<pt->E0a);nup=pt->p[b]->e5;J_(pc+nup<pt->H2);for(;nup>0;nup--){a6
op1=V_(pt->m1[pc+nup]);J_(op1==J5||op1==S8);}break;}default:break;}}return
pt->m1[I2];}
#undef J_
#undef Y4b
#undef V5
int
D7(const
E_*pt){return
X3a(pt,pt->H2,F6);}static
const
char*Q6b(E_*p,int
c){c=c-q2;if(c>=0&&n1(&p->k[c]))return
h9(&p->k[c]);else
return"?";}static
const
char*l3a(l0*ci,int
B_b,const
char**b_){if(F5a(ci)){E_*p=M0a(ci)->l.p;int
pc=H8(ci);j_
i;*b_=O4(p,B_b+1,pc);if(*b_)return"local";i=X3a(p,pc,B_b);H(pc!=-1);switch(V_(i)){case
z7:{int
g=v7(i);H(n1(&p->k[g]));*b_=h9(&p->k[g]);return"global";}case
S8:{int
a=w3(i);int
b=a2(i);if(b<a)return
l3a(ci,b,b_);break;}case
x_a:{int
k=X2(i);*b_=Q6b(p,k);return"field";}case
C2a:{int
k=X2(i);*b_=Q6b(p,k);return"method";}default:break;}}return
NULL;}static
const
char*r6a(l0*ci,const
char**b_){j_
i;if((F5a(ci)&&ci->u.l.V_a>0)||!F5a(ci-1))return
NULL;ci--;i=M0a(ci)->l.p->m1[H8(ci)];if(V_(i)==D4||V_(i)==W4)return
l3a(ci,w3(i),b_);else
return
NULL;}static
int
b4b(l0*ci,const
E*o){t_
p;for(p=ci->k_;p<ci->X;p++)if(o==p)return
1;return
0;}void
d5(a*L,const
E*o,const
char*op){const
char*b_=NULL;const
char*t=Z5[T0(o)];const
char*O2b=(b4b(L->ci,o))?l3a(L->ci,o-L->k_,&b_):NULL;if(O2b)q_(L,"attempt to %s %s `%s' (a %s value)",op,O2b,b_,t);else
q_(L,"attempt to %s a %s value",op,t);}void
g1a(a*L,t_
p1,t_
p2){if(n1(p1))p1=p2;H(!n1(p1));d5(L,p1,"concatenate");}void
d9(a*L,const
E*p1,const
E*p2){E
Y6;if(I6(p1,&Y6)==NULL)p2=p1;d5(L,p2,"perform arithmetic on");}int
A5(a*L,const
E*p1,const
E*p2){const
char*t1=Z5[T0(p1)];const
char*t2=Z5[T0(p2)];if(t1[2]==t2[2])q_(L,"attempt to compare two %s values",t1);else
q_(L,"attempt to compare %s with %s",t1,t2);return
0;}static
void
j8b(a*L,const
char*O6){l0*ci=L->ci;if(F5a(ci)){char
p_[Y8];int
W_=x2(ci);y7(p_,C5(r2a(ci)->m0),Y8);R2(L,"%s:%d: %s",p_,W_,O6);}}void
j0a(a*L){if(L->k4!=0){t_
k4=W2(L,L->k4);if(!X1(k4))E5(L,z0a);f1(L->X,L->X-1);f1(L->X-1,k4);R3(L);u5(L,L->X-2,1);}E5(L,g3a);}void
q_(a*L,const
char*K6,...){va_list
U4;va_start(U4,K6);j8b(L,N4(L,K6,U4));va_end(U4);j0a(L);}
#define b0c
struct
A_a{struct
A_a*Y_;jmp_buf
b;volatile
int
T;};static
void
q2a(a*L,int
I5a,t_
h8){switch(I5a){case
s3a:{C3(h8,M5(L,k9a));break;}case
z0a:{C3(h8,M5(L,"error in error handling"));break;}case
s0a:case
g3a:{f1(h8,L->X-1);break;}}L->X=h8+1;}void
E5(a*L,int
I5a){if(L->E8){L->E8->T=I5a;longjmp(L->E8->b,1);}else{G(L)->P9a(L);exit(EXIT_FAILURE);}}int
c3(a*L,c_b
f,void*ud){struct
A_a
lj;lj.T=0;lj.Y_=L->E8;L->E8=&lj;if(setjmp(lj.b)==0)(*f)(L,ud);L->E8=lj.Y_;return
lj.T;}static
void
S9(a*L){L->r5=L->l_+L->E2-1;if(L->S3>m6){int
C9b=(L->ci-L->N0);if(C9b+1<m6)a5(L,m6);}}static
void
c0b(a*L,E*b_a){l0*ci;u_*up;L->X=(L->X-b_a)+L->l_;for(up=L->p6;up!=NULL;up=up->A3.h_)b8a(up)->v=(b8a(up)->v-b_a)+L->l_;for(ci=L->N0;ci<=L->ci;ci++){ci->X=(ci->X-b_a)+L->l_;ci->k_=(ci->k_-b_a)+L->l_;}L->k_=L->ci->k_;}void
T3(a*L,int
Q1){E*b_a=L->l_;G0(L,L->l_,L->E2,Q1,E);L->E2=Q1;L->r5=L->l_+Q1-1-V6;c0b(L,b_a);}void
a5(a*L,int
Q1){l0*O9b=L->N0;G0(L,L->N0,L->S3,Q1,l0);L->S3=g_(unsigned
short,Q1);L->ci=(L->ci-O9b)+L->N0;L->y7a=L->N0+L->S3;}void
a3a(a*L,int
n){if(n<=L->E2)T3(L,2*L->E2);else
T3(L,L->E2+n+V6);}static
void
L0b(a*L){if(L->S3>m6)E5(L,z0a);else{a5(L,2*L->S3);if(L->S3>m6)q_(L,"stack overflow");}}void
I4(a*L,int
O2,int
W_){w8
w6=L->w6;if(w6&&L->a4){ptrdiff_t
X=v4(L,L->X);ptrdiff_t
U8b=v4(L,L->ci->X);C0
ar;ar.O2=O2;ar.x2=W_;if(O2==e2a)ar.b5a=0;else
ar.b5a=L->ci-L->N0;K2(L,J3);L->ci->X=L->X+J3;L->a4=0;f_(L);(*w6)(L,&ar);n_(L);H(!L->a4);L->a4=1;L->ci->X=W2(L,U8b);L->X=W2(L,X);}}static
void
y8a(a*L,int
L3a,t_
k_){int
i;o0*l3b;E
N6b;int
F5=L->X-k_;if(F5<L3a){K2(L,L3a-F5);for(;F5<L3a;++F5)R_(L->X++);}F5-=L3a;l3b=w7(L,F5,1);for(i=0;i<F5;i++)m3a(i8(L,l3b,i+1),L->X-F5+i);l2a(&N6b,W1a(L,"n"));K1(h_a(L,l3b,&N6b),g_(U,F5));L->X-=F5;s6(L->X,l3b);R3(L);}static
t_
D3b(a*L,t_
Z_){const
E*tm=j3(L,Z_,u7b);t_
p;ptrdiff_t
X9a=v4(L,Z_);if(!X1(tm))d5(L,Z_,"call");for(p=L->X;p>Z_;p--)f1(p,p-1);R3(L);Z_=W2(L,X9a);k0(Z_,tm);return
Z_;}t_
i7(a*L,t_
Z_){C1a*cl;ptrdiff_t
X9a=v4(L,Z_);if(!X1(Z_))Z_=D3b(L,Z_);if(L->ci+1==L->y7a)L0b(L);else
s4(a5(L,L->S3));cl=&A2(Z_)->l;if(!cl->isC){l0*ci;E_*p=cl->p;if(p->J8)y8a(L,p->d7,Z_+1);K2(L,p->Z1);ci=++L->ci;L->k_=L->ci->k_=W2(L,X9a)+1;ci->X=L->k_+p->Z1;ci->u.l.j2=p->m1;ci->u.l.V_a=0;ci->g0=b3;while(L->X<ci->X)R_(L->X++);L->X=ci->X;return
NULL;}else{l0*ci;int
n;K2(L,J3);ci=++L->ci;L->k_=L->ci->k_=W2(L,X9a)+1;ci->X=L->X+J3;ci->g0=K1a;if(L->C6&q7)I4(L,y1a,-1);f_(L);
#ifdef s3b
y8(L);
#endif
n=(*A2(L->k_-1)->c.f)(L);n_(L);return
L->X-n;}}static
t_
m0b(a*L,t_
D0){ptrdiff_t
fr=v4(L,D0);I4(L,d6a,-1);if(!(L->ci->g0&K1a)){while(L->ci->u.l.V_a--)I4(L,e2a,-1);}return
W2(L,fr);}void
b6(a*L,int
d7a,t_
D0){t_
h0;if(L->C6&E_a)D0=m0b(L,D0);h0=L->k_-1;L->ci--;L->k_=L->ci->k_;while(d7a!=0&&D0<L->X){f1(h0++,D0++);d7a--;}while(d7a-->0)R_(h0++);L->X=h0;}void
u5(a*L,t_
Z_,int
F_b){t_
D0;H(!(L->ci->g0&F9));if(++L->d6>=H6){if(L->d6==H6)q_(L,"C stack overflow");else
if(L->d6>=(H6+(H6>>3)))E5(L,z0a);}D0=i7(L,Z_);if(D0==NULL)D0=o6(L);b6(L,F_b,D0);L->d6--;z1(L);}static
void
x3b(a*L,void*ud){t_
D0;int
T4=*g_(int*,ud);l0*ci=L->ci;if(ci==L->N0){H(T4<L->X-L->k_);i7(L,L->X-(T4+1));}else{H(ci->g0&u8);if(ci->g0&K1a){int
z0;H((ci-1)->g0&b3);H(V_(*((ci-1)->u.l.j2-1))==D4||V_(*((ci-1)->u.l.j2-1))==W4);z0=X2(*((ci-1)->u.l.j2-1))-1;b6(L,z0,L->X-T4);if(z0>=0)L->X=L->ci->X;}else{ci->g0&=~u8;}}D0=o6(L);if(D0!=NULL)b6(L,y2,D0);}static
int
A4a(a*L,const
char*O6){L->X=L->ci->k_;C3(L->X,M5(L,O6));R3(L);f_(L);return
g3a;}K
int
k3a(a*L,int
T4){int
T;S_
M7;n_(L);if(L->ci==L->N0){if(T4>=L->X-L->k_)return
A4a(L,"cannot resume dead coroutine");}else
if(!(L->ci->g0&u8))return
A4a(L,"cannot resume non-suspended coroutine");M7=L->a4;H(L->k4==0&&L->d6==0);T=c3(L,x3b,&T4);if(T!=0){L->ci=L->N0;L->k_=L->ci->k_;L->d6=0;S4(L,L->k_);q2a(L,T,L->k_);L->a4=M7;S9(L);}f_(L);return
T;}K
int
y4a(a*L,int
z0){l0*ci;n_(L);ci=L->ci;if(L->d6>0)q_(L,"attempt to yield across metamethod/C-call boundary");if(ci->g0&K1a){if((ci-1)->g0&K1a)q_(L,"cannot yield a C function");if(L->X-z0>L->k_){int
i;for(i=0;i<z0;i++)f1(L->k_+i,L->X-z0+i);L->X=L->k_+z0;}}ci->g0|=u8;f_(L);return-1;}int
B3a(a*L,c_b
Z_,void*u,ptrdiff_t
V7b,ptrdiff_t
ef){int
T;unsigned
short
r2b=L->d6;ptrdiff_t
L8b=e9b(L,L->ci);S_
M7=L->a4;ptrdiff_t
K0b=L->k4;L->k4=ef;T=c3(L,Z_,u);if(T!=0){t_
h8=W2(L,V7b);S4(L,h8);q2a(L,T,h8);L->d6=r2b;L->ci=a4b(L,L8b);L->k_=L->ci->k_;L->a4=M7;S9(L);}L->k4=K0b;return
T;}struct
a8a{X8*z;f6
p_;int
bin;};static
void
d0b(a*L,void*ud){struct
a8a*p;E_*tf;z2*cl;z1(L);p=g_(struct
a8a*,ud);tf=p->bin?Z5a(L,p->z,&p->p_):e6a(L,p->z,&p->p_);cl=D8(L,0,gt(L));cl->l.p=tf;x0a(L->X,cl);R3(L);}int
b9(a*L,X8*z,int
bin){struct
a8a
p;int
T;ptrdiff_t
k8b=v4(L,L->X);p.z=z;p.bin=bin;i2a(L,&p.p_);T=c3(L,d0b,&p);b2a(L,&p.p_);if(T!=0){t_
h8=W2(L,k8b);q2a(L,T,h8);}return
T;}
#define S_c
#define T7a(b,n,W,D) s7(b,(n)*(W),D)
#define S0b(s,D) s7(""s,(sizeof(s))-1,D)
typedef
struct{a*L;x5
A6;void*a3;}Q2;static
void
s7(const
void*b,size_t
W,Q2*D){f_(D->L);(*D->A6)(D->L,b,W,D->a3);n_(D->L);}static
void
v3(int
y,Q2*D){char
x=(char)y;s7(&x,sizeof(x),D);}static
void
G7(int
x,Q2*D){s7(&x,sizeof(x),D);}static
void
E_b(size_t
x,Q2*D){s7(&x,sizeof(x),D);}static
void
s7a(U
x,Q2*D){s7(&x,sizeof(x),D);}static
void
G0a(A_*s,Q2*D){if(s==NULL||C5(s)==NULL)E_b(0,D);else{size_t
W=s->q6.E1+1;E_b(W,D);s7(C5(s),W,D);}}static
void
t5b(const
E_*f,Q2*D){G7(f->H2,D);T7a(f->m1,f->H2,sizeof(*f->m1),D);}static
void
P2b(const
E_*f,Q2*D){int
i,n=f->m4;G7(n,D);for(i=0;i<n;i++){G0a(f->n3[i].L2,D);G7(f->n3[i].G2a,D);G7(f->n3[i].S9a,D);}}static
void
J4b(const
E_*f,Q2*D){G7(f->o3,D);T7a(f->i4,f->o3,sizeof(*f->i4),D);}static
void
v_b(const
E_*f,Q2*D){int
i,n=f->G3;G7(n,D);for(i=0;i<n;i++)G0a(f->i0[i],D);}static
void
M1a(const
E_*f,const
A_*p,Q2*D);static
void
p9a(const
E_*f,Q2*D){int
i,n;G7(n=f->Z8,D);for(i=0;i<n;i++){const
E*o=&f->k[i];v3(T0(o),D);switch(T0(o)){case
N1:s7a(r0(o),D);break;case
q1:G0a(k2(o),D);break;case
P5:break;default:H(0);break;}}G7(n=f->E0a,D);for(i=0;i<n;i++)M1a(f->p[i],f->m0,D);}static
void
M1a(const
E_*f,const
A_*p,Q2*D){G0a((f->m0==p)?NULL:f->m0,D);G7(f->Z7,D);v3(f->e5,D);v3(f->d7,D);v3(f->J8,D);v3(f->Z1,D);J4b(f,D);P2b(f,D);v_b(f,D);p9a(f,D);t5b(f,D);}static
void
n3b(Q2*D){S0b(l8,D);v3(x8a,D);v3(Q9(),D);v3(sizeof(int),D);v3(sizeof(size_t),D);v3(sizeof(j_),D);v3(P2a,D);v3(l5a,D);v3(S_a,D);v3(L_a,D);v3(sizeof(U),D);s7a(Y5a,D);}void
m9a(a*L,const
E_*l6b,x5
w,void*a3){Q2
D;D.L=L;D.A6=w;D.a3=a3;n3b(&D);M1a(l6b,NULL,&D);}
#define U_c
#define s4a(n) (g_(int,sizeof(M6a))+g_(int,sizeof(E)*((n)-1)))
#define u5a(n) (g_(int,sizeof(C1a))+g_(int,sizeof(E*)*((n)-1)))
z2*z8(a*L,int
L9){z2*c=g_(z2*,S5(L,s4a(L9)));f7(L,L4(c),d0);c->c.isC=1;c->c.c4=g_(S_,L9);return
c;}z2*D8(a*L,int
L9,E*e){z2*c=g_(z2*,S5(L,u5a(L9)));f7(L,L4(c),d0);c->l.isC=0;c->l.g=*e;c->l.c4=g_(S_,L9);return
c;}F_a*H2a(a*L,t_
z_){u_**pp=&L->p6;F_a*p;F_a*v;while((p=k_b(*pp))!=NULL&&p->v>=z_){if(p->v==z_)return
p;pp=&p->h_;}v=v3a(L,F_a);v->tt=p9;v->U2=1;v->v=z_;v->h_=*pp;*pp=L4(v);return
v;}void
S4(a*L,t_
z_){F_a*p;while((p=k_b(L->p6))!=NULL&&p->v>=z_){E9(&p->m_,p->v);p->v=&p->m_;L->p6=p->h_;f7(L,L4(p),p9);}}E_*i0a(a*L){E_*f=v3a(L,E_);f7(L,L4(f),u9);f->k=NULL;f->Z8=0;f->p=NULL;f->E0a=0;f->m1=NULL;f->H2=0;f->o3=0;f->G3=0;f->e5=0;f->i0=NULL;f->d7=0;f->J8=0;f->Z1=0;f->i4=NULL;f->m4=0;f->n3=NULL;f->Z7=0;f->m0=NULL;return
f;}void
F2a(a*L,E_*f){u1(L,f->m1,f->H2,j_);u1(L,f->p,f->E0a,E_*);u1(L,f->k,f->Z8,E);u1(L,f->i4,f->o3,int);u1(L,f->n3,f->m4,struct
O2a);u1(L,f->i0,f->G3,A_*);i9(L,f);}void
G1a(a*L,z2*c){int
W=(c->c.isC)?s4a(c->c.c4):u5a(c->l.c4);R1a(L,c,W);}const
char*O4(const
E_*f,int
d1a,int
pc){int
i;for(i=0;i<f->m4&&f->n3[i].G2a<=pc;i++){if(pc<f->n3[i].S9a){d1a--;if(d1a==0)return
C5(f->n3[i].L2);}}return
NULL;}
#define f0c
typedef
struct
P6{u_*Q4;u_*wk;u_*wv;u_*wkv;q4*g;}P6;
#define S4b(x,b) ((x)|=(1<<(b)))
#define s0b(x,b) ((x)&=g_(S_,~(1<<(b))))
#define L1b(x,b) ((x)&(1<<(b)))
#define u_b(x) s0b((x)->A3.U2,0)
#define q1a(x) ((x)->A3.U2&((1<<4)|1))
#define s9(s) S4b((s)->q6.U2,0)
#define w1b(u) (!L1b((u)->uv.U2,1))
#define V3a(u) s0b((u)->uv.U2,1)
#define i7a 1
#define p4a 2
#define N1b (1<<i7a)
#define n9a (1<<p4a)
#define x6(st,o) {A8(o);if(K4(o)&&!q1a(H7(o)))E6(st,H7(o));}
#define E2a(st,o,c) {A8(o);if(K4(o)&&!q1a(H7(o))&&(c))E6(st,H7(o));}
#define M8(st,t) {if(!q1a(L4(t)))E6(st,L4(t));}
static
void
E6(P6*st,u_*o){H(!q1a(o));S4b(o->A3.U2,0);switch(o->A3.tt){case
c1:{M8(st,X0a(o)->uv.r_);break;}case
d0:{m8a(o)->c.h5=st->Q4;st->Q4=o;break;}case
H_:{w4a(o)->h5=st->Q4;st->Q4=o;break;}case
Y2:{K2a(o)->h5=st->Q4;st->Q4=o;break;}case
u9:{n0b(o)->h5=st->Q4;st->Q4=o;break;}default:H(o->A3.tt==q1);}}static
void
W7b(P6*st){u_*u;for(u=st->g->k6;u;u=u->A3.h_){u_b(u);E6(st,u);}}size_t
n7(a*L){size_t
Q7=0;u_**p=&G(L)->t6;u_*U5;u_*Z3=NULL;u_**m0a=&Z3;while((U5=*p)!=NULL){H(U5->A3.tt==c1);if(q1a(U5)||w1b(X0a(U5)))p=&U5->A3.h_;else
if(X2a(L,X0a(U5)->uv.r_,H6b)==NULL){V3a(X0a(U5));p=&U5->A3.h_;}else{Q7+=n5a(X0a(U5)->uv.E1);*p=U5->A3.h_;U5->A3.h_=NULL;*m0a=U5;m0a=&U5->A3.h_;}}*m0a=G(L)->k6;G(L)->k6=Z3;return
Q7;}static
void
I8a(I3*n){R_(y4(n));if(K4(g4(n)))w6b(g4(n),Y_a);}static
void
K9a(P6*st,o0*h){int
i;int
T0a=0;int
U8=0;const
E*u0;M8(st,h->r_);H(h->P8||h->d3==st->g->Y3);u0=G1b(st->g,h->r_,d7b);if(u0&&n1(u0)){T0a=(strchr(h9(u0),'k')!=NULL);U8=(strchr(h9(u0),'v')!=NULL);if(T0a||U8){u_**L6a;h->U2&=~(N1b|n9a);h->U2|=g_(S_,(T0a<<i7a)|(U8<<p4a));L6a=(T0a&&U8)?&st->wkv:(T0a)?&st->wk:&st->wv;h->h5=*L6a;*L6a=L4(h);}}if(!U8){i=h->M1;while(i--)x6(st,&h->v0[i]);}i=k5(h);while(i--){I3*n=l5(h,i);if(!H0(y4(n))){H(!H0(g4(n)));E2a(st,g4(n),!T0a);E2a(st,y4(n),!U8);}}}static
void
H9a(P6*st,E_*f){int
i;s9(f->m0);for(i=0;i<f->Z8;i++){if(n1(f->k+i))s9(k2(f->k+i));}for(i=0;i<f->G3;i++)s9(f->i0[i]);for(i=0;i<f->E0a;i++)M8(st,f->p[i]);for(i=0;i<f->m4;i++)s9(f->n3[i].L2);H(D7(f));}static
void
B7a(P6*st,z2*cl){if(cl->c.isC){int
i;for(i=0;i<cl->c.c4;i++)x6(st,&cl->c.E4[i]);}else{int
i;H(cl->l.c4==cl->l.p->e5);M8(st,i1(&cl->l.g));M8(st,cl->l.p);for(i=0;i<cl->l.c4;i++){F_a*u=cl->l.P1a[i];if(!u->U2){x6(st,&u->m_);u->U2=1;}}}}static
void
t7a(a*L,t_
max){int
k9=L->ci-L->N0;if(4*k9<L->S3&&2*k0a<L->S3)a5(L,L->S3/2);else
s4(a5(L,L->S3));k9=max-L->l_;if(4*k9<L->E2&&2*(v8+V6)<L->E2)T3(L,L->E2/2);else
s4(T3(L,L->E2));}static
void
d4a(P6*st,a*L1){t_
o,lim;l0*ci;x6(st,gt(L1));lim=L1->X;for(ci=L1->N0;ci<=L1->ci;ci++){H(ci->X<=L1->r5);H(ci->g0&(K1a|U6|b3));if(lim<ci->X)lim=ci->X;}for(o=L1->l_;o<L1->X;o++)x6(st,o);for(;o<=lim;o++)R_(o);t7a(L1,lim);}static
void
V9(P6*st){while(st->Q4){switch(st->Q4->A3.tt){case
H_:{o0*h=w4a(st->Q4);st->Q4=h->h5;K9a(st,h);break;}case
d0:{z2*cl=m8a(st->Q4);st->Q4=cl->c.h5;B7a(st,cl);break;}case
Y2:{a*th=K2a(st->Q4);st->Q4=th->h5;d4a(st,th);break;}case
u9:{E_*p=n0b(st->Q4);st->Q4=p->h5;H9a(st,p);break;}default:H(0);}}}static
int
x2a(const
E*o){if(n1(o))s9(k2(o));return!K4(o)||L1b(o->m_.gc->A3.U2,0);}static
void
T9(u_*l){while(l){o0*h=w4a(l);int
i=k5(h);H(h->U2&N1b);while(i--){I3*n=l5(h,i);if(!x2a(g4(n)))I8a(n);}l=h->h5;}}static
void
z6(u_*l){while(l){o0*h=w4a(l);int
i=h->M1;H(h->U2&n9a);while(i--){E*o=&h->v0[i];if(!x2a(o))R_(o);}i=k5(h);while(i--){I3*n=l5(h,i);if(!x2a(y4(n)))I8a(n);}l=h->h5;}}static
void
B7b(a*L,u_*o){switch(o->A3.tt){case
u9:F2a(L,n0b(o));break;case
d0:G1a(L,m8a(o));break;case
p9:i9(L,b8a(o));break;case
H_:o9a(L,w4a(o));break;case
Y2:{H(K2a(o)!=L&&K2a(o)!=G(L)->m9);m2a(L,K2a(o));break;}case
q1:{R1a(L,o,c7a(L5a(o)->q6.E1));break;}case
c1:{R1a(L,o,n5a(X0a(o)->uv.E1));break;}default:H(0);}}static
int
Q4a(a*L,u_**p,int
N2){u_*U5;int
w1=0;while((U5=*p)!=NULL){if(U5->A3.U2>N2){u_b(U5);p=&U5->A3.h_;}else{w1++;*p=U5->A3.h_;B7b(L,U5);}}return
w1;}static
void
r_b(a*L,int
J2){int
i;for(i=0;i<G(L)->X6.W;i++){G(L)->X6.v6a-=Q4a(L,&G(L)->X6.f2[i],J2);}}static
void
F2b(a*L,size_t
Q7){if(G(L)->X6.v6a<g_(o8a,G(L)->X6.W/4)&&G(L)->X6.W>h0a*2)w_a(L,G(L)->X6.W/2);if(B9(&G(L)->p_)>p8*2){size_t
Q1=B9(&G(L)->p_)/2;w0a(L,&G(L)->p_,Q1);}G(L)->I5=2*G(L)->T6-Q7;}static
void
s7b(a*L,r_a*z4){const
E*tm=X2a(L,z4->uv.r_,H6b);if(tm!=NULL){k0(L->X,tm);K4a(L->X+1,z4);L->X+=2;u5(L,L->X-2,0);}}void
g0a(a*L){S_
W9b=L->a4;L->a4=0;L->X++;while(G(L)->k6!=NULL){u_*o=G(L)->k6;r_a*z4=X0a(o);G(L)->k6=z4->uv.h_;z4->uv.h_=G(L)->t6;G(L)->t6=o;K4a(L->X-1,z4);u_b(o);V3a(z4);s7b(L,z4);}L->X--;L->a4=W9b;}void
C3a(a*L,int
J2){if(J2)J2=256;Q4a(L,&G(L)->t6,J2);r_b(L,J2);Q4a(L,&G(L)->P4a,J2);}static
void
P5b(P6*st,a*L){q4*g=st->g;x6(st,B3(L));x6(st,T5(L));d4a(st,g->m9);if(L!=g->m9)M8(st,L);}static
size_t
t7(a*L){size_t
Q7;P6
st;u_*wkv;st.g=G(L);st.Q4=NULL;st.wkv=st.wk=st.wv=NULL;P5b(&st,L);V9(&st);z6(st.wkv);z6(st.wv);wkv=st.wkv;st.wkv=NULL;st.wv=NULL;Q7=n7(L);W7b(&st);V9(&st);T9(wkv);T9(st.wk);z6(st.wv);T9(st.wkv);z6(st.wkv);return
Q7;}void
R9(a*L){size_t
Q7=t7(L);C3a(L,0);F2b(L,Q7);g0a(L);}void
f7(a*L,u_*o,S_
tt){o->A3.h_=G(L)->P4a;G(L)->P4a=o;o->A3.U2=0;o->A3.tt=tt;}
#define H_c
#ifndef s2a
#ifdef __GNUC__
#define s2a 0
#else
#define s2a 1
#endif
#endif
#ifndef N_a
#ifdef _POSIX_C_SOURCE
#if _POSIX_C_SOURCE>=2
#define N_a 1
#endif
#endif
#endif
#ifndef N_a
#define N_a 0
#endif
#if!N_a
#define pclose(f) (-1)
#endif
#define A9 "FILE*"
#define F3a "_input"
#define Q_a "_output"
static
int
n4(a*L,int
i,const
char*Q_){if(i){n0(L,1);return
1;}else{w_(L);if(Q_)P_(L,"%s: %s",Q_,strerror(errno));else
P_(L,"%s",strerror(errno));N(L,errno);return
3;}}static
FILE**r8a(a*L,int
v7a){FILE**f=(FILE**)o9(L,v7a,A9);if(f==NULL)d1(L,v7a,"bad file");return
f;}static
int
o7b(a*L){FILE**f=(FILE**)o9(L,1,A9);if(f==NULL)w_(L);else
if(*f==NULL)e_(L,"closed file");else
e_(L,"file");return
1;}static
FILE*U_a(a*L,int
v7a){FILE**f=r8a(L,v7a);if(*f==NULL)s_(L,"attempt to use a closed file");return*f;}static
FILE**S0a(a*L){FILE**pf=(FILE**)y5(L,sizeof(FILE*));*pf=NULL;v0a(L,A9);V2(L,-2);return
pf;}static
void
h1a(a*L,FILE*f,const
char*b_,const
char*c8a){I(L,b_);*S0a(L)=f;if(c8a){I(L,c8a);Y(L,-2);P0(L,-6);}P0(L,-3);}static
int
k5a(a*L){FILE*f=U_a(L,1);if(f==stdin||f==stdout||f==stderr)return
0;else{int
ok=(pclose(f)!=-1)||(fclose(f)==0);if(ok)*(FILE**)Y1(L,1)=NULL;return
ok;}}static
int
w_b(a*L){if(e3(L,1)&&b2(L,O_(1))==H_){I(L,Q_a);x0(L,O_(1));}return
n4(L,k5a(L),NULL);}static
int
T9b(a*L){FILE**f=r8a(L,1);if(*f!=NULL)k5a(L);return
0;}static
int
m1b(a*L){char
p_[128];FILE**f=r8a(L,1);if(*f==NULL)strcpy(p_,"closed");else
sprintf(p_,"%p",Y1(L,1));P_(L,"file (%s)",p_);return
1;}static
int
b8b(a*L){const
char*Q_=Q(L,1);const
char*u0=J0(L,2,"r");FILE**pf=S0a(L);*pf=fopen(Q_,u0);return(*pf==NULL)?n4(L,0,Q_):1;}static
int
Q5b(a*L){
#if!N_a
s_(L,"`popen' not supported");return
0;
#else
const
char*Q_=Q(L,1);const
char*u0=J0(L,2,"r");FILE**pf=S0a(L);*pf=popen(Q_,u0);return(*pf==NULL)?n4(L,0,Q_):1;
#endif
}static
int
N2b(a*L){FILE**pf=S0a(L);*pf=tmpfile();return(*pf==NULL)?n4(L,0,NULL):1;}static
FILE*r4a(a*L,const
char*b_){I(L,b_);x0(L,O_(1));return
U_a(L,-1);}static
int
K_b(a*L,const
char*b_,const
char*u0){if(!J1(L,1)){const
char*Q_=o_(L,1);I(L,b_);if(Q_){FILE**pf=S0a(L);*pf=fopen(Q_,u0);if(*pf==NULL){P_(L,"%s: %s",Q_,strerror(errno));d1(L,1,o_(L,-1));}}else{U_a(L,1);Y(L,1);}F0(L,O_(1));}I(L,b_);x0(L,O_(1));return
1;}static
int
c6b(a*L){return
K_b(L,F3a,"r");}static
int
L4b(a*L){return
K_b(L,Q_a,"w");}static
int
g6a(a*L);static
void
f9a(a*L,int
F_,int
close){e_(L,A9);x0(L,L_);Y(L,F_);n0(L,close);x1(L,g6a,3);}static
int
X1b(a*L){U_a(L,1);f9a(L,1,0);return
1;}static
int
s5b(a*L){if(J1(L,1)){I(L,F3a);x0(L,O_(1));return
X1b(L);}else{const
char*Q_=Q(L,1);FILE**pf=S0a(L);*pf=fopen(Q_,"r");e0(L,*pf,1,strerror(errno));f9a(L,D_(L),1);return
1;}}static
int
J0b(a*L,FILE*f){U
d;if(fscanf(f,P9,&d)==1){N(L,d);return
1;}else
return
0;}static
int
r5b(a*L,FILE*f){int
c=getc(f);ungetc(c,f);Z0(L,NULL,0);return(c!=EOF);}static
int
J4a(a*L,FILE*f){I_
b;U1(L,&b);for(;;){size_t
l;char*p=c7(&b);if(fgets(p,i3,f)==NULL){X0(&b);return(N3(L,-1)>0);}l=strlen(p);if(p[l-1]!='\n')a1a(&b,l);else{a1a(&b,l-1);X0(&b);return
1;}}}static
int
I7a(a*L,FILE*f,size_t
n){size_t
S_b;size_t
nr;I_
b;U1(L,&b);S_b=i3;do{char*p=c7(&b);if(S_b>n)S_b=n;nr=fread(p,sizeof(char),S_b,f);a1a(&b,nr);n-=nr;}while(n>0&&nr==S_b);X0(&b);return(n==0||N3(L,-1)>0);}static
int
U4b(a*L,FILE*f,int
V0){int
T4=D_(L)-1;int
C7;int
n;if(T4==0){C7=J4a(L,f);n=V0+1;}else{A4(L,T4+J3,"too many arguments");C7=1;for(n=V0;T4--&&C7;n++){if(b2(L,n)==N1){size_t
l=(size_t)E0(L,n);C7=(l==0)?r5b(L,f):I7a(L,f,l);}else{const
char*p=o_(L,n);e0(L,p&&p[0]=='*',n,"invalid option");switch(p[1]){case'n':C7=J0b(L,f);break;case'l':C7=J4a(L,f);break;case'a':I7a(L,f,~((size_t)0));C7=1;break;case'w':return
s_(L,"obsolete option `*w' to `read'");default:return
d1(L,n,"invalid format");}}}}if(!C7){U_(L,1);w_(L);}return
n-V0;}static
int
M7b(a*L){return
U4b(L,r4a(L,F3a),1);}static
int
O8b(a*L){return
U4b(L,U_a(L,1),2);}static
int
g6a(a*L){FILE*f=*(FILE**)Y1(L,O_(2));if(f==NULL)s_(L,"file is already closed");if(J4a(L,f))return
1;else{if(V1(L,O_(3))){I0(L,0);Y(L,O_(2));k5a(L);}return
0;}}static
int
V1b(a*L,FILE*f,int
S7){int
T4=D_(L)-1;int
T=1;for(;T4--;S7++){if(b2(L,S7)==N1){T=T&&fprintf(f,L7,E0(L,S7))>0;}else{size_t
l;const
char*s=y_(L,S7,&l);T=T&&(fwrite(s,sizeof(char),l,f)==l);}}return
n4(L,T,NULL);}static
int
h6b(a*L){return
V1b(L,r4a(L,Q_a),1);}static
int
t7b(a*L){return
V1b(L,U_a(L,1),2);}static
int
W8b(a*L){static
const
int
u0[]={SEEK_SET,SEEK_CUR,SEEK_END};static
const
char*const
H4b[]={"set","cur","end",NULL};FILE*f=U_a(L,1);int
op=a7(J0(L,2,"cur"),H4b);long
P_a=x7(L,3,0);e0(L,op!=-1,2,"invalid mode");op=fseek(f,P_a,u0[op]);if(op)return
n4(L,0,NULL);else{N(L,ftell(f));return
1;}}static
int
R5b(a*L){return
n4(L,fflush(r4a(L,Q_a))==0,NULL);}static
int
O7b(a*L){return
n4(L,fflush(U_a(L,1))==0,NULL);}static
const
g3
B9b[]={{"input",c6b},{"output",L4b},{"lines",s5b},{"close",w_b},{"flush",R5b},{"open",b8b},{"popen",Q5b},{"read",M7b},{"tmpfile",N2b},{"type",o7b},{"write",h6b},{NULL,NULL}};static
const
g3
x_c[]={{"flush",O7b},{"read",O8b},{"lines",X1b},{"seek",W8b},{"write",t7b},{"close",w_b},{"__gc",T9b},{"__tostring",m1b},{NULL,NULL}};static
void
q2b(a*L){t0a(L,A9);e_(L,"__index");Y(L,-2);F0(L,-3);u2(L,NULL,x_c,0);}static
int
v2b(a*L){N(L,system(Q(L,1)));return
1;}static
int
k4b(a*L){const
char*Q_=Q(L,1);return
n4(L,remove(Q_)==0,Q_);}static
int
V4b(a*L){const
char*I_b=Q(L,1);const
char*A8b=Q(L,2);return
n4(L,rename(I_b,A8b)==0,I_b);}static
int
V2b(a*L){
#if!s2a
s_(L,"`tmpname' not supported");return
0;
#else
char
p_[J_c];if(tmpnam(p_)!=p_)return
s_(L,"unable to generate a unique filename in `tmpname'");I(L,p_);return
1;
#endif
}static
int
h5b(a*L){I(L,getenv(Q(L,1)));return
1;}static
int
O5b(a*L){N(L,((U)clock())/(U)CLOCKS_PER_SEC);return
1;}static
void
u7(a*L,const
char*x_,int
m_){I(L,x_);N(L,m_);F0(L,-3);}static
void
Y_b(a*L,const
char*x_,int
m_){I(L,x_);n0(L,m_);F0(L,-3);}static
int
V_b(a*L,const
char*x_){int
h0;I(L,x_);l6(L,-2);h0=V1(L,-1);U_(L,1);return
h0;}static
int
k_a(a*L,const
char*x_,int
d){int
h0;I(L,x_);l6(L,-2);if(r2(L,-1))h0=(int)(E0(L,-1));else{if(d==-2)return
s_(L,"field `%s' missing in date table",x_);h0=d;}U_(L,1);return
h0;}static
int
v7b(a*L){const
char*s=J0(L,1,"%c");time_t
t=(time_t)(y3(L,2,-1));struct
tm*stm;if(t==(time_t)(-1))t=time(NULL);if(*s=='!'){stm=gmtime(&t);s++;}else
stm=localtime(&t);if(stm==NULL)w_(L);else
if(strcmp(s,"*t")==0){S0(L);u7(L,"sec",stm->tm_sec);u7(L,"min",stm->tm_min);u7(L,"hour",stm->tm_hour);u7(L,"day",stm->tm_mday);u7(L,"month",stm->tm_mon+1);u7(L,"year",stm->tm_year+1900);u7(L,"wday",stm->tm_wday+1);u7(L,"yday",stm->tm_yday+1);Y_b(L,"isdst",stm->tm_isdst);}else{char
b[256];if(strftime(b,sizeof(b),s,stm))I(L,b);else
return
s_(L,"`date' format too long");}return
1;}static
int
R7b(a*L){if(J1(L,1))N(L,time(NULL));else{time_t
t;struct
tm
ts;G_(L,1,H_);I0(L,1);ts.tm_sec=k_a(L,"sec",0);ts.tm_min=k_a(L,"min",0);ts.tm_hour=k_a(L,"hour",12);ts.tm_mday=k_a(L,"day",-2);ts.tm_mon=k_a(L,"month",-2)-1;ts.tm_year=k_a(L,"year",-2)-1900;ts.tm_isdst=V_b(L,"isdst");t=mktime(&ts);if(t==(time_t)(-1))w_(L);else
N(L,t);}return
1;}static
int
r1b(a*L){N(L,difftime((time_t)(b1(L,1)),(time_t)(y3(L,2,0))));return
1;}static
int
D4b(a*L){static
const
int
cat[]={LC_ALL,LC_COLLATE,LC_CTYPE,LC_MONETARY,LC_NUMERIC,LC_TIME};static
const
char*const
u6b[]={"all","collate","ctype","monetary","numeric","time",NULL};const
char*l=o_(L,1);int
op=a7(J0(L,2,"all"),u6b);e0(L,l||J1(L,1),1,"string expected");e0(L,op!=-1,2,"invalid option");I(L,setlocale(cat[op],l));return
1;}static
int
w7b(a*L){exit(a1(L,1,EXIT_SUCCESS));return
0;}static
const
g3
p9b[]={{"clock",O5b},{"date",v7b},{"difftime",r1b},{"execute",v2b},{"exit",w7b},{"getenv",h5b},{"remove",k4b},{"rename",V4b},{"setlocale",D4b},{"time",R7b},{"tmpname",V2b},{NULL,NULL}};P
int
C0a(a*L){u2(L,x9a,p9b,0);q2b(L);Y(L,-1);u2(L,r9a,B9b,1);h1a(L,stdin,"stdin",F3a);h1a(L,stdout,"stdout",Q_a);h1a(L,stderr,"stderr",NULL);return
1;}
#define a0c
#define h_(LS) (LS->i_=c7b(LS->z))
static
const
char*const
e1a[]={"and","break","do","else","elseif","end","false","for","function","if","in","local","nil","not","or","repeat","return","then","true","until","while","*name","..","...","==",">=","<=","~=","*number","*string","<eof>"};void
M8a(a*L){int
i;for(i=0;i<i0b;i++){A_*ts=M5(L,e1a[i]);B6a(ts);H(strlen(e1a[i])+1<=c4b);ts->q6.x3=g_(S_,i+1);}}
#define h4b 80
void
M3(c_*O,int
r6,int
N2,const
char*O6){if(r6>N2){O6=R2(O->L,"too many %s (limit=%d)",O6,N2);t0(O,O6);}}void
d_a(c_*O,const
char*s,const
char*T_,int
W_){a*L=O->L;char
p_[h4b];y7(p_,C5(O->m0),h4b);R2(L,"%s:%d: %s near `%s'",p_,W_,s,T_);E5(L,s0a);}static
void
D0a(c_*O,const
char*s,const
char*T_){d_a(O,s,T_,O->n2);}void
t0(c_*O,const
char*O6){const
char*U1a;switch(O->t.T_){case
e_a:U1a=C5(O->t.F1.ts);break;case
u6:case
K8:U1a=N5(O->p_);break;default:U1a=b5(O,O->t.T_);break;}D0a(O,O6,U1a);}const
char*b5(c_*O,int
T_){if(T_<h6){H(T_==(unsigned
char)T_);return
R2(O->L,"%c",T_);}else
return
e1a[T_-h6];}static
void
o5(c_*O,const
char*s,int
T_){if(T_==W7)D0a(O,s,b5(O,T_));else
D0a(O,s,N5(O->p_));}static
void
r8(c_*LS){h_(LS);++LS->n2;M3(LS,LS->n2,B7,"lines in a chunk");}void
R3a(a*L,c_*LS,X8*z,A_*m0){LS->L=L;LS->V4.T_=W7;LS->z=z;LS->J=NULL;LS->n2=1;LS->J1a=1;LS->m0=m0;h_(LS);if(LS->i_=='#'){do{h_(LS);}while(LS->i_!='\n'&&LS->i_!=EOZ);}}
#define d5b 32
#define R2b 5
#define E3(LS,E1) if(((E1)+R2b)*sizeof(char)>B9((LS)->p_))N7((LS)->L,(LS)->p_,(E1)+d5b)
#define G2(LS,c,l) (N5((LS)->p_)[l++]=g_(char,c))
#define q0(LS,l) (G2(LS,LS->i_,l),h_(LS))
static
size_t
G5b(c_*LS){size_t
l=0;E3(LS,l);do{E3(LS,l);q0(LS,l);}while(isalnum(LS->i_)||LS->i_=='_');G2(LS,'\0',l);return
l-1;}static
void
C4a(c_*LS,int
Z9b,P0a*F1){size_t
l=0;E3(LS,l);if(Z9b)G2(LS,'.',l);while(isdigit(LS->i_)){E3(LS,l);q0(LS,l);}if(LS->i_=='.'){q0(LS,l);if(LS->i_=='.'){q0(LS,l);G2(LS,'\0',l);o5(LS,"ambiguous syntax (decimal point x string concatenation)",K8);}}while(isdigit(LS->i_)){E3(LS,l);q0(LS,l);}if(LS->i_=='e'||LS->i_=='E'){q0(LS,l);if(LS->i_=='+'||LS->i_=='-')q0(LS,l);while(isdigit(LS->i_)){E3(LS,l);q0(LS,l);}}G2(LS,'\0',l);if(!A3a(N5(LS->p_),&F1->r))o5(LS,"malformed number",K8);}static
void
Y0a(c_*LS,P0a*F1){int
C8a=0;size_t
l=0;E3(LS,l);G2(LS,'[',l);q0(LS,l);if(LS->i_=='\n')r8(LS);for(;;){E3(LS,l);switch(LS->i_){case
EOZ:G2(LS,'\0',l);o5(LS,(F1)?"unfinished long string":"unfinished long comment",W7);break;case'[':q0(LS,l);if(LS->i_=='['){C8a++;q0(LS,l);}continue;case']':q0(LS,l);if(LS->i_==']'){if(C8a==0)goto
k8a;C8a--;q0(LS,l);}continue;case'\n':G2(LS,'\n',l);r8(LS);if(!F1)l=0;continue;default:q0(LS,l);}}k8a:q0(LS,l);G2(LS,'\0',l);if(F1)F1->ts=S2(LS->L,N5(LS->p_)+2,l-5);}static
void
p1b(c_*LS,int
del,P0a*F1){size_t
l=0;E3(LS,l);q0(LS,l);while(LS->i_!=del){E3(LS,l);switch(LS->i_){case
EOZ:G2(LS,'\0',l);o5(LS,"unfinished string",W7);break;case'\n':G2(LS,'\0',l);o5(LS,"unfinished string",u6);break;case'\\':h_(LS);switch(LS->i_){case'a':G2(LS,'\a',l);h_(LS);break;case'b':G2(LS,'\b',l);h_(LS);break;case'f':G2(LS,'\f',l);h_(LS);break;case'n':G2(LS,'\n',l);h_(LS);break;case'r':G2(LS,'\r',l);h_(LS);break;case't':G2(LS,'\t',l);h_(LS);break;case'v':G2(LS,'\v',l);h_(LS);break;case'\n':G2(LS,'\n',l);r8(LS);break;case
EOZ:break;default:{if(!isdigit(LS->i_))q0(LS,l);else{int
c=0;int
i=0;do{c=10*c+(LS->i_-'0');h_(LS);}while(++i<3&&isdigit(LS->i_));if(c>UCHAR_MAX){G2(LS,'\0',l);o5(LS,"escape sequence too large",u6);}G2(LS,c,l);}}}break;default:q0(LS,l);}}q0(LS,l);G2(LS,'\0',l);F1->ts=S2(LS->L,N5(LS->p_)+1,l-3);}int
K6a(c_*LS,P0a*F1){for(;;){switch(LS->i_){case'\n':{r8(LS);continue;}case'-':{h_(LS);if(LS->i_!='-')return'-';h_(LS);if(LS->i_=='['&&(h_(LS),LS->i_=='['))Y0a(LS,NULL);else
while(LS->i_!='\n'&&LS->i_!=EOZ)h_(LS);continue;}case'[':{h_(LS);if(LS->i_!='[')return'[';else{Y0a(LS,F1);return
u6;}}case'=':{h_(LS);if(LS->i_!='=')return'=';else{h_(LS);return
E6b;}}case'<':{h_(LS);if(LS->i_!='=')return'<';else{h_(LS);return
M6b;}}case'>':{h_(LS);if(LS->i_!='=')return'>';else{h_(LS);return
F6b;}}case'~':{h_(LS);if(LS->i_!='=')return'~';else{h_(LS);return
V6b;}}case'"':case'\'':{p1b(LS,LS->i_,F1);return
u6;}case'.':{h_(LS);if(LS->i_=='.'){h_(LS);if(LS->i_=='.'){h_(LS);return
P1b;}else
return
d9a;}else
if(!isdigit(LS->i_))return'.';else{C4a(LS,1,F1);return
K8;}}case
EOZ:{return
W7;}default:{if(isspace(LS->i_)){h_(LS);continue;}else
if(isdigit(LS->i_)){C4a(LS,0,F1);return
K8;}else
if(isalpha(LS->i_)||LS->i_=='_'){size_t
l=G5b(LS);A_*ts=S2(LS->L,N5(LS->p_),l);if(ts->q6.x3>0)return
ts->q6.x3-1+h6;F1->ts=ts;return
e_a;}else{int
c=LS->i_;if(iscntrl(c))D0a(LS,"invalid control char",R2(LS->L,"char(%d)",c));h_(LS);return
c;}}}}}
#undef h_
#define Z_c
#ifndef V4a
#define V4a(b,os,s) realloc(b,s)
#endif
#ifndef E3b
#define E3b(b,os) free(b)
#endif
#define w9 4
void*G4a(a*L,void*N_,int*W,int
o7a,int
N2,const
char*t0b){void*d4;int
Q1=(*W)*2;if(Q1<w9)Q1=w9;else
if(*W>=N2/2){if(*W<N2-w9)Q1=N2;else
q_(L,t0b);}d4=g5(L,N_,g_(h2,*W)*g_(h2,o7a),g_(h2,Q1)*g_(h2,o7a));*W=Q1;return
d4;}void*g5(a*L,void*N_,h2
l4,h2
W){H((l4==0)==(N_==NULL));if(W==0){if(N_!=NULL){E3b(N_,l4);N_=NULL;}else
return
NULL;}else
if(W>=N8a)q_(L,"memory allocation error: block too big");else{N_=V4a(N_,l4,W);if(N_==NULL){if(L)E5(L,s3a);else
return
NULL;}}if(L){H(G(L)!=NULL&&G(L)->T6>0);G(L)->T6-=l4;G(L)->T6+=W;}return
N_;}
#undef LOADLIB
#ifdef L2b
#define LOADLIB
#include<dlfcn.h>
static
int
V3(a*L){const
char*B_=Q(L,1);const
char*G1=Q(L,2);void*Y7=dlopen(B_,y_c);if(Y7!=NULL){p0
f=(p0)dlsym(Y7,G1);if(f!=NULL){C1(L,Y7);x1(L,f,1);return
1;}}w_(L);I(L,dlerror());I(L,(Y7!=NULL)?"init":"open");if(Y7!=NULL)dlclose(Y7);return
3;}
#endif
#ifndef Z7a
#ifdef _WIN32
#define Z7a 1
#else
#define Z7a 0
#endif
#endif
#if Z7a
#define LOADLIB
#include<windows.h>
static
void
x4(a*L){int
g1=x8b();char
b0[128];if(r8b(Y7a|s9a,0,g1,0,b0,sizeof(b0),0))I(L,b0);else
P_(L,"system error %d\n",g1);}static
int
V3(a*L){const
char*B_=Q(L,1);const
char*G1=Q(L,2);HINSTANCE
Y7=u9b(B_);if(Y7!=NULL){p0
f=(p0)m7b(Y7,G1);if(f!=NULL){C1(L,Y7);x1(L,f,1);return
1;}}w_(L);x4(L);I(L,(Y7!=NULL)?"init":"open");if(Y7!=NULL)r9b(Y7);return
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
V3(a*L){w_(L);e_(L,LOADLIB);e_(L,"absent");return
3;}
#endif
P
int
d2a(a*L){a0b(L,"loadlib",V3);return
0;}
#define k_c
#ifndef S2a
#define S2a(s,p) strtod((s),(p))
#endif
const
E
B2={P5,{NULL}};int
u2a(unsigned
int
x){int
m=0;while(x>=(1<<3)){x=(x+1)>>1;m++;}return(m<<3)|g_(int,x);}int
Z_a(unsigned
int
x){static
const
S_
Z9a[255]={0,1,1,2,2,2,2,3,3,3,3,3,3,3,3,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7};if(x>=0x00010000){if(x>=0x01000000)return
Z9a[((x>>24)&0xff)-1]+24;else
return
Z9a[((x>>16)&0xff)-1]+16;}else{if(x>=0x00000100)return
Z9a[((x>>8)&0xff)-1]+8;else
if(x)return
Z9a[(x&0xff)-1];return-1;}}int
u3(const
E*t1,const
E*t2){if(T0(t1)!=T0(t2))return
0;else
switch(T0(t1)){case
P5:return
1;case
N1:return
r0(t1)==r0(t2);case
f5:return
R2a(t1)==R2a(t2);case
I1:return
D2a(t1)==D2a(t2);default:H(K4(t1));return
H7(t1)==H7(t2);}}int
A3a(const
char*s,U*H1){char*Z4a;U
h0=S2a(s,&Z4a);if(Z4a==s)return
0;while(isspace((unsigned
char)(*Z4a)))Z4a++;if(*Z4a!='\0')return
0;*H1=h0;return
1;}static
void
c3a(a*L,const
char*str){C3(L->X,M5(L,str));R3(L);}const
char*N4(a*L,const
char*K6,va_list
U4){int
n=1;c3a(L,"");for(;;){const
char*e=strchr(K6,'%');if(e==NULL)break;C3(L->X,S2(L,K6,e-K6));R3(L);switch(*(e+1)){case's':c3a(L,va_arg(U4,char*));break;case'c':{char
p_[2];p_[0]=g_(char,va_arg(U4,int));p_[1]='\0';c3a(L,p_);break;}case'd':K1(L->X,g_(U,va_arg(U4,int)));R3(L);break;case'f':K1(L->X,g_(U,va_arg(U4,V5a)));R3(L);break;case'%':c3a(L,"%");break;default:H(0);}n+=2;K6=e+2;}c3a(L,K6);u_a(L,n+1,L->X-L->k_-1);L->X-=n;return
h9(L->X-1);}const
char*R2(a*L,const
char*K6,...){const
char*O6;va_list
U4;va_start(U4,K6);O6=N4(L,K6,U4);va_end(U4);return
O6;}void
y7(char*e7,const
char*m0,int
g6){if(*m0=='='){strncpy(e7,m0+1,g6);e7[g6-1]='\0';}else{if(*m0=='@'){int
l;m0++;g6-=sizeof(" `...' ");l=strlen(m0);strcpy(e7,"");if(l>g6){m0+=(l-g6);strcat(e7,"...");}strcat(e7,m0);}else{int
E1=strcspn(m0,"\n");g6-=sizeof(" [string \"...\"] ");if(E1>g6)E1=g6;strcpy(e7,"[string \"");if(m0[E1]!='\0'){strncat(e7,m0,E1);strcat(e7,"...");}else
strcat(e7,m0);strcat(e7,"\"]");}}}
#define Y9b
#ifdef n1b
const
char*const
X4a[]={"MOVE","LOADK","LOADBOOL","LOADNIL","GETUPVAL","GETGLOBAL","GETTABLE","SETGLOBAL","SETUPVAL","SETTABLE","NEWTABLE","SELF","ADD","SUB","MUL","DIV","POW","UNM","NOT","CONCAT","JMP","EQ","LT","LE","TEST","CALL","TAILCALL","RETURN","FORLOOP","TFORLOOP","TFORPREP","SETLIST","SETLISTO","CLOSE","CLOSURE"};
#endif
#define O0(t,b,bk,ck,sa,k,m) (((t)<<H5a)|((b)<<q7a)|((bk)<<e9a)|((ck)<<E8a)|((sa)<<H7a)|((k)<<E1b)|(m))
const
S_
Z0a[q6a]={O0(0,1,0,0,1,0,P3),O0(0,0,0,0,1,1,y3a),O0(0,0,0,0,1,0,P3),O0(0,1,0,0,1,0,P3),O0(0,0,0,0,1,0,P3),O0(0,0,0,0,1,1,y3a),O0(0,1,0,1,1,0,P3),O0(0,0,0,0,0,1,y3a),O0(0,0,0,0,0,0,P3),O0(0,0,1,1,0,0,P3),O0(0,0,0,0,1,0,P3),O0(0,1,0,1,1,0,P3),O0(0,0,1,1,1,0,P3),O0(0,0,1,1,1,0,P3),O0(0,0,1,1,1,0,P3),O0(0,0,1,1,1,0,P3),O0(0,0,1,1,1,0,P3),O0(0,1,0,0,1,0,P3),O0(0,1,0,0,1,0,P3),O0(0,1,0,1,1,0,P3),O0(0,0,0,0,0,0,K5a),O0(1,0,1,1,0,0,P3),O0(1,0,1,1,0,0,P3),O0(1,0,1,1,0,0,P3),O0(1,1,0,0,1,0,P3),O0(0,0,0,0,0,0,P3),O0(0,0,0,0,0,0,P3),O0(0,0,0,0,0,0,P3),O0(0,0,0,0,0,0,K5a),O0(1,0,0,0,0,0,P3),O0(0,0,0,0,0,0,K5a),O0(0,0,0,0,0,0,y3a),O0(0,0,0,0,0,0,y3a),O0(0,0,0,0,0,0,P3),O0(0,0,0,0,1,0,y3a)};
#define q_c
#define h2a(J,i) ((J)->f->n3[(J)->K3b[i]])
#define k7a(O) if(++(O)->c2a>M_a)t0(O,"too many syntax levels");
#define r7a(O) ((O)->c2a--)
typedef
struct
f4{struct
f4*Y_;int
k2a;int
M0;int
j2a;int
q_a;}f4;static
void
m5(c_*O);static
void
z9(c_*O,d_*v);static
void
h_(c_*O){O->J1a=O->n2;if(O->V4.T_!=W7){O->t=O->V4;O->V4.T_=W7;}else
O->t.T_=K6a(O,&O->t.F1);}static
void
V4(c_*O){H(O->V4.T_==W7);O->V4.T_=K6a(O,&O->V4.F1);}static
void
V2a(c_*O,int
T_){t0(O,R2(O->L,"`%s' expected",b5(O,T_)));}static
int
L3(c_*O,int
c){if(O->t.T_==c){h_(O);return
1;}else
return
0;}static
void
J_(c_*O,int
c){if(!L3(O,c))V2a(O,c);}
#define t9(O,c,O6) {if(!(c))t0(O,O6);}
static
void
p4(c_*O,int
r3,int
who,int
S1a){if(!L3(O,r3)){if(S1a==O->n2)V2a(O,r3);else{t0(O,R2(O->L,"`%s' expected (to close `%s' at line %d)",b5(O,r3),b5(O,who),S1a));}}}static
A_*G4(c_*O){A_*ts;t9(O,(O->t.T_==e_a),"<name> expected");ts=O->t.F1.ts;h_(O);return
ts;}static
void
j4(d_*e,U1b
k,int
i){e->f=e->t=B0;e->k=k;e->C_=i;}static
void
i3a(c_*O,d_*e,A_*s){j4(e,VK,b1a(O->J,s));}static
void
i5a(c_*O,d_*e){i3a(O,e,G4(O));}static
int
Q2a(c_*O,A_*L2){M*J=O->J;E_*f=J->f;B4(O->L,f->n3,J->f_a,f->m4,O2a,B7,"");f->n3[J->f_a].L2=L2;return
J->f_a++;}static
void
i5(c_*O,A_*b_,int
n){M*J=O->J;M3(O,J->M0+n+1,O5a,"local variables");J->K3b[J->M0+n]=Q2a(O,b_);}static
void
s5(c_*O,int
m3){M*J=O->J;J->M0+=m3;for(;m3;m3--){h2a(J,J->M0-m3).G2a=J->pc;}}static
void
F7a(c_*O,int
E7b){M*J=O->J;while(J->M0>E7b)h2a(J,--J->M0).S9a=J->pc;}static
void
G5(c_*O,const
char*b_,int
n){i5(O,M5(O->L,b_),n);}static
void
W4a(c_*O,const
char*b_){G5(O,b_,0);s5(O,1);}static
int
g_b(M*J,A_*b_,d_*v){int
i;E_*f=J->f;for(i=0;i<f->e5;i++){if(J->i0[i].k==v->k&&J->i0[i].C_==v->C_){H(J->f->i0[i]==b_);return
i;}}M3(J->O,f->e5+1,G_a,"upvalues");B4(J->L,J->f->i0,f->e5,J->f->G3,A_*,B7,"");J->f->i0[f->e5]=b_;J->i0[f->e5]=*v;return
f->e5++;}static
int
J3b(M*J,A_*n){int
i;for(i=J->M0-1;i>=0;i--){if(n==h2a(J,i).L2)return
i;}return-1;}static
void
T4b(M*J,int
z_){f4*bl=J->bl;while(bl&&bl->M0>z_)bl=bl->Y_;if(bl)bl->j2a=1;}static
void
j5a(M*J,A_*n,d_*W8,int
k_){if(J==NULL)j4(W8,z5a,F6);else{int
v=J3b(J,n);if(v>=0){j4(W8,z1a,v);if(!k_)T4b(J,v);}else{j5a(J->N4a,n,W8,0);if(W8->k==z5a){if(k_)W8->C_=b1a(J,n);}else{W8->C_=g_b(J,n,W8);W8->k=w7a;}}}}static
A_*m5a(c_*O,d_*W8,int
k_){A_*L2=G4(O);j5a(O->J,L2,W8,k_);return
L2;}static
void
q0a(c_*O,int
m3,int
I9,d_*e){M*J=O->J;int
t3=m3-I9;if(e->k==V1a){t3++;if(t3<=0)t3=0;else
P1(J,t3-1);S1(J,e,t3);}else{if(e->k!=t_a)K0(J,e);if(t3>0){int
b4=J->w0;P1(J,t3);w6a(J,b4,t3);}}}static
void
s1b(c_*O,int
Q8,int
t8a){M*J=O->J;s5(O,Q8);M3(O,J->M0,e5a,"parameters");J->f->d7=g_(S_,J->M0);J->f->J8=g_(S_,t8a);if(t8a)W4a(O,"arg");P1(J,J->M0);}static
void
D9(M*J,f4*bl,int
q_a){bl->k2a=B0;bl->q_a=q_a;bl->M0=J->M0;bl->j2a=0;bl->Y_=J->bl;J->bl=bl;H(J->w0==J->M0);}static
void
f9(M*J){f4*bl=J->bl;J->bl=bl->Y_;F7a(J->O,bl->M0);if(bl->j2a)K_(J,I3a,bl->M0,0,0);H(bl->M0==J->M0);J->w0=J->M0;L0(J,bl->k2a);}static
void
b1b(c_*O,M*Z_,d_*v){M*J=O->J;E_*f=J->f;int
i;B4(O->L,f->p,J->np,f->E0a,E_*,K_a,"constant table overflow");f->p[J->np++]=Z_->f;j4(v,f3,s3(J,K9,0,J->np-1));for(i=0;i<Z_->f->e5;i++){a6
o=(Z_->i0[i].k==z1a)?S8:J5;K_(J,o,0,Z_->i0[i].C_,0);}}static
void
Z8a(c_*O,M*J){E_*f=i0a(O->L);J->f=f;J->N4a=O->J;J->O=O;J->L=O->L;O->J=J;J->pc=0;J->E3a=0;J->jpc=B0;J->w0=0;J->nk=0;J->h=w7(O->L,0,0);J->np=0;J->f_a=0;J->M0=0;J->bl=NULL;f->m0=O->m0;f->Z1=2;}static
void
E7a(c_*O){a*L=O->L;M*J=O->J;E_*f=J->f;F7a(O,0);K_(J,X4,0,1,0);G0(L,f->m1,f->H2,J->pc,j_);f->H2=J->pc;G0(L,f->i4,f->o3,J->pc,int);f->o3=J->pc;G0(L,f->k,f->Z8,J->nk,E);f->Z8=J->nk;G0(L,f->p,f->E0a,J->np,E_*);f->E0a=J->np;G0(L,f->n3,f->m4,J->f_a,O2a);f->m4=J->f_a;G0(L,f->i0,f->G3,f->e5,A_*);f->G3=f->e5;H(D7(f));H(J->bl==NULL);O->J=J->N4a;}E_*e6a(a*L,X8*z,f6*p_){struct
c_
R5;struct
M
Q1a;R5.p_=p_;R5.c2a=0;R3a(L,&R5,z,M5(L,I6b(z)));Z8a(&R5,&Q1a);h_(&R5);m5(&R5);t9(&R5,(R5.t.T_==W7),"<eof> expected");E7a(&R5);H(Q1a.N4a==NULL);H(Q1a.f->e5==0);H(R5.c2a==0);return
Q1a.f;}static
void
D3a(c_*O,d_*v){M*J=O->J;d_
x_;d2(J,v);h_(O);i5a(O,&x_);s1a(J,v,&x_);}static
void
D7a(c_*O,d_*v){h_(O);z9(O,v);k7(O->J,v);J_(O,']');}struct
d8{d_
v;d_*t;int
nh;int
na;int
O0a;};static
void
h3a(c_*O,struct
d8*cc){M*J=O->J;int
b4=O->J->w0;d_
x_,r6;if(O->t.T_==e_a){M3(O,cc->nh,B7,"items in a constructor");cc->nh++;i5a(O,&x_);}else
D7a(O,&x_);J_(O,'=');D3(J,&x_);z9(O,&r6);K_(J,D_a,cc->t->C_,D3(J,&x_),D3(J,&r6));J->w0=b4;}static
void
z8a(M*J,struct
d8*cc){if(cc->v.k==t_a)return;K0(J,&cc->v);cc->v.k=t_a;if(cc->O0a==P4){s3(J,B6,cc->t->C_,cc->na-1);cc->O0a=0;J->w0=cc->t->C_+1;}}static
void
F9a(M*J,struct
d8*cc){if(cc->O0a==0)return;if(cc->v.k==V1a){S1(J,&cc->v,y2);s3(J,a8,cc->t->C_,cc->na-1);}else{if(cc->v.k!=t_a)K0(J,&cc->v);s3(J,B6,cc->t->C_,cc->na-1);}J->w0=cc->t->C_+1;}static
void
Y4a(c_*O,struct
d8*cc){z9(O,&cc->v);M3(O,cc->na,K_a,"items in a constructor");cc->na++;cc->O0a++;}static
void
S6(c_*O,d_*t){M*J=O->J;int
W_=O->n2;int
pc=K_(J,t2a,0,0,0);struct
d8
cc;cc.na=cc.nh=cc.O0a=0;cc.t=t;j4(t,f3,pc);j4(&cc.v,t_a,0);K0(O->J,t);J_(O,'{');do{H(cc.v.k==t_a||cc.O0a>0);L3(O,';');if(O->t.T_=='}')break;z8a(J,&cc);switch(O->t.T_){case
e_a:{V4(O);if(O->V4.T_!='=')Y4a(O,&cc);else
h3a(O,&cc);break;}case'[':{h3a(O,&cc);break;}default:{Y4a(O,&cc);break;}}}while(L3(O,',')||L3(O,';'));p4(O,'}','{',W_);F9a(J,&cc);G6a(J->f->m1[pc],u2a(cc.na));i_b(J->f->m1[pc],Z_a(cc.nh)+1);}static
void
J5a(c_*O){int
Q8=0;int
t8a=0;if(O->t.T_!=')'){do{switch(O->t.T_){case
P1b:t8a=1;h_(O);break;case
e_a:i5(O,G4(O),Q8++);break;default:t0(O,"<name> or `...' expected");}}while(!t8a&&L3(O,','));}s1b(O,Q8,t8a);}static
void
t3a(c_*O,d_*e,int
x8,int
W_){M
O_b;Z8a(O,&O_b);O_b.f->Z7=W_;J_(O,'(');if(x8)W4a(O,"self");J5a(O);J_(O,')');m5(O);p4(O,U2a,o_a,W_);E7a(O);b1b(O,&O_b,e);}static
int
O5(c_*O,d_*v){int
n=1;z9(O,v);while(L3(O,',')){K0(O->J,v);z9(O,v);n++;}return
n;}static
void
y6(c_*O,d_*f){M*J=O->J;d_
B8;int
k_,Q8;int
W_=O->n2;switch(O->t.T_){case'(':{if(W_!=O->J1a)t0(O,"ambiguous syntax (function call x new statement)");h_(O);if(O->t.T_==')')B8.k=t_a;else{O5(O,&B8);S1(J,&B8,y2);}p4(O,')','(',W_);break;}case'{':{S6(O,&B8);break;}case
u6:{i3a(O,&B8,O->t.F1.ts);h_(O);break;}default:{t0(O,"function arguments expected");return;}}H(f->k==X3);k_=f->C_;if(B8.k==V1a)Q8=y2;else{if(B8.k!=t_a)K0(J,&B8);Q8=J->w0-(k_+1);}j4(f,V1a,K_(J,D4,k_,Q8+1,2));O9(J,W_);J->w0=k_+1;}static
void
z4a(c_*O,d_*v){switch(O->t.T_){case'(':{int
W_=O->n2;h_(O);z9(O,v);p4(O,')','(',W_);R0(O->J,v);return;}case
e_a:{m5a(O,v,1);return;}
#ifdef I3b
case'%':{A_*L2;int
W_=O->n2;h_(O);L2=m5a(O,v,1);if(v->k!=w7a)d_a(O,"global upvalues are obsolete",C5(L2),W_);return;}
#endif
default:{t0(O,"unexpected symbol");return;}}}static
void
F7(c_*O,d_*v){M*J=O->J;z4a(O,v);for(;;){switch(O->t.T_){case'.':{D3a(O,v);break;}case'[':{d_
x_;d2(J,v);D7a(O,&x_);s1a(J,v,&x_);break;}case':':{d_
x_;h_(O);i5a(O,&x_);Q8a(J,v,&x_);y6(O,v);break;}case'(':case
u6:case'{':{K0(J,v);y6(O,v);break;}default:return;}}}static
void
c9a(c_*O,d_*v){switch(O->t.T_){case
K8:{j4(v,VK,M9(O->J,O->t.F1.r));h_(O);break;}case
u6:{i3a(O,v,O->t.F1.ts);h_(O);break;}case
b9b:{j4(v,f8a,0);h_(O);break;}case
D7b:{j4(v,f2a,0);h_(O);break;}case
p5b:{j4(v,r1a,0);h_(O);break;}case'{':{S6(O,v);break;}case
o_a:{h_(O);t3a(O,v,0,O->n2);break;}default:{F7(O,v);break;}}}static
G7a
z6b(int
op){switch(op){case
J8b:return
g7b;case'-':return
W8a;default:return
l6a;}}static
c8
c5b(int
op){switch(op){case'+':return
F1b;case'-':return
k7b;case'*':return
o6b;case'/':return
I7b;case'^':return
H1b;case
d9a:return
q3a;case
V6b:return
X6a;case
E6b:return
M8b;case'<':return
Z8b;case
M6b:return
l9b;case'>':return
A4b;case
F6b:return
j9b;case
k9b:return
D8a;case
S9b:return
p_b;default:return
I4a;}}static
const
struct{S_
g8a;S_
X7a;}t8[]={{6,6},{6,6},{7,7},{7,7},{10,9},{5,4},{3,3},{3,3},{3,3},{3,3},{3,3},{3,3},{2,2},{1,1}};
#define d8a 8
static
c8
Q0a(c_*O,d_*v,int
N2){c8
op;G7a
uop;k7a(O);uop=z6b(O->t.T_);if(uop!=l6a){h_(O);Q0a(O,v,d8a);f6a(O->J,uop,v);}else
c9a(O,v);op=c5b(O->t.T_);while(op!=I4a&&g_(int,t8[op].g8a)>N2){d_
v2;c8
M4b;h_(O);N7a(O->J,op,v);M4b=Q0a(O,&v2,g_(int,t8[op].X7a));T5a(O->J,op,v,&v2);op=M4b;}r7a(O);return
op;}static
void
z9(c_*O,d_*v){Q0a(O,v,-1);}static
int
t4a(int
T_){switch(T_){case
M1b:case
V8a:case
U2a:case
z_b:case
W7:return
1;default:return
0;}}static
void
N_(c_*O){M*J=O->J;f4
bl;D9(J,&bl,0);m5(O);H(bl.k2a==B0);f9(J);}struct
l9{struct
l9*N4a;d_
v;};static
void
e8a(c_*O,struct
l9*lh,d_*v){M*J=O->J;int
t3=J->w0;int
c1a=0;for(;lh;lh=lh->N4a){if(lh->v.k==m1a){if(lh->v.C_==v->C_){c1a=1;lh->v.C_=t3;}if(lh->v.r9==v->C_){c1a=1;lh->v.r9=t3;}}}if(c1a){K_(J,S8,J->w0,v->C_,0);P1(J,1);}}static
void
m2(c_*O,struct
l9*lh,int
m3){d_
e;t9(O,z1a<=lh->v.k&&lh->v.k<=m1a,"syntax error");if(L3(O,',')){struct
l9
nv;nv.N4a=lh;F7(O,&nv.v);if(nv.v.k==z1a)e8a(O,lh,&nv.v);m2(O,&nv,m3+1);}else{int
I9;J_(O,'=');I9=O5(O,&e);if(I9!=m3){q0a(O,m3,I9,&e);if(I9>m3)O->J->w0-=I9-m3;}else{S1(O->J,&e,1);J6(O->J,&lh->v,&e);return;}}j4(&e,X3,O->J->w0-1);J6(O->J,&lh->v,&e);}static
void
c6(c_*O,d_*v){z9(O,v);if(v->k==f8a)v->k=r1a;n0a(O->J,v);L0(O->J,v->t);}
#ifndef p2a
#define p2a 100
#endif
#define B6b 5
static
void
q4a(c_*O,int
W_){j_
e2b[p2a+B6b];int
x1b;int
i;int
D5a;M*J=O->J;int
i9a,O8a,R0a;d_
v;f4
bl;h_(O);i9a=t4(J);R0a=W3(J);z9(O,&v);if(v.k==VK)v.k=f2a;x1b=O->n2;R7(J,&v);w2(J,&v.f,J->jpc);J->jpc=B0;D5a=J->pc-R0a;if(D5a>p2a)t0(O,"`while' condition too complex");for(i=0;i<D5a;i++)e2b[i]=J->f->m1[R0a+i];J->pc=R0a;D9(J,&bl,1);J_(O,R9a);O8a=W3(J);N_(O);L0(J,i9a);if(v.t!=B0)v.t+=J->pc-R0a;if(v.f!=B0)v.f+=J->pc-R0a;for(i=0;i<D5a;i++)n2a(J,e2b[i],x1b);p4(O,U2a,N6a,W_);f9(J);I7(J,v.t,O8a);L0(J,v.f);}static
void
r3a(c_*O,int
W_){M*J=O->J;int
i1b=W3(J);d_
v;f4
bl;D9(J,&bl,1);h_(O);N_(O);p4(O,z_b,F8a,W_);c6(O,&v);I7(J,v.f,i1b);f9(J);}static
int
u3a(c_*O){d_
e;int
k;z9(O,&e);k=e.k;K0(O->J,&e);return
k;}static
void
y1b(c_*O,int
k_,int
W_,int
m3,int
isnum){f4
bl;M*J=O->J;int
x5b,e4b;s5(O,m3);J_(O,R9a);D9(J,&bl,1);x5b=W3(J);N_(O);L0(J,x5b-1);e4b=(isnum)?e0a(J,K0a,k_,B0):K_(J,y_a,k_,0,m3-3);O9(J,W_);I7(J,(isnum)?e4b:t4(J),x5b);f9(J);}static
void
z0b(c_*O,A_*L2,int
W_){M*J=O->J;int
k_=J->w0;i5(O,L2,0);G5(O,"(for limit)",1);G5(O,"(for step)",2);J_(O,'=');u3a(O);J_(O,',');u3a(O);if(L3(O,','))u3a(O);else{s3(J,M3a,J->w0,M9(J,1));P1(J,1);}K_(J,W_b,J->w0-3,J->w0-3,J->w0-1);t4(J);y1b(O,k_,W_,3,1);}static
void
n8a(c_*O,A_*W4b){M*J=O->J;d_
e;int
m3=0;int
W_;int
k_=J->w0;G5(O,"(for generator)",m3++);G5(O,"(for state)",m3++);i5(O,W4b,m3++);while(L3(O,','))i5(O,G4(O),m3++);J_(O,Z6b);W_=O->n2;q0a(O,m3,O5(O,&e),&e);n9(J,3);e0a(J,y2a,k_,B0);y1b(O,k_,W_,m3,0);}static
void
v8a(c_*O,int
W_){M*J=O->J;A_*L2;f4
bl;D9(J,&bl,0);h_(O);L2=G4(O);switch(O->t.T_){case'=':z0b(O,L2,W_);break;case',':case
Z6b:n8a(O,L2);break;default:t0(O,"`=' or `in' expected");}p4(O,U2a,H3b,W_);f9(J);}static
void
y9(c_*O,d_*v){h_(O);c6(O,v);J_(O,p7b);N_(O);}static
void
H_b(c_*O,int
W_){M*J=O->J;d_
v;int
L0a=B0;y9(O,&v);while(O->t.T_==V8a){w2(J,&L0a,t4(J));L0(J,v.f);y9(O,&v);}if(O->t.T_==M1b){w2(J,&L0a,t4(J));L0(J,v.f);h_(O);N_(O);}else
w2(J,&L0a,v.f);L0(J,L0a);p4(O,U2a,Y6b,W_);}static
void
j4b(c_*O){d_
v,b;M*J=O->J;i5(O,G4(O),0);j4(&v,z1a,J->w0);P1(J,1);s5(O,1);t3a(O,&b,0,O->n2);J6(J,&v,&b);h2a(J,J->M0-1).G2a=J->pc;}static
void
T8a(c_*O){int
m3=0;int
I9;d_
e;do{i5(O,G4(O),m3++);}while(L3(O,','));if(L3(O,'='))I9=O5(O,&e);else{e.k=t_a;I9=0;}q0a(O,m3,I9,&e);s5(O,m3);}static
int
H6a(c_*O,d_*v){int
x8=0;m5a(O,v,1);while(O->t.T_=='.')D3a(O,v);if(O->t.T_==':'){x8=1;D3a(O,v);}return
x8;}static
void
z6a(c_*O,int
W_){int
x8;d_
v,b;h_(O);x8=H6a(O,&v);t3a(O,&b,x8,W_);J6(O->J,&v,&b);O9(O->J,W_);}static
void
D6b(c_*O){M*J=O->J;struct
l9
v;F7(O,&v.v);if(v.v.k==V1a){S1(J,&v.v,0);}else{v.N4a=NULL;m2(O,&v,1);}}static
void
Z1b(c_*O){M*J=O->J;d_
e;int
V0,Q6a;h_(O);if(t4a(O->t.T_)||O->t.T_==';')V0=Q6a=0;else{Q6a=O5(O,&e);if(e.k==V1a){S1(J,&e,y2);if(Q6a==1){b3b(E7(J,&e),W4);H(w3(E7(J,&e))==J->M0);}V0=J->M0;Q6a=y2;}else{if(Q6a==1)V0=d2(J,&e);else{K0(J,&e);V0=J->M0;H(Q6a==J->w0-V0);}}}K_(J,X4,V0,Q6a+1,0);}static
void
g9a(c_*O){M*J=O->J;f4*bl=J->bl;int
j2a=0;h_(O);while(bl&&!bl->q_a){j2a|=bl->j2a;bl=bl->Y_;}if(!bl)t0(O,"no loop to break");if(j2a)K_(J,I3a,bl->M0,0,0);w2(J,&bl->k2a,t4(J));}static
int
c0a(c_*O){int
W_=O->n2;switch(O->t.T_){case
Y6b:{H_b(O,W_);return
0;}case
N6a:{q4a(O,W_);return
0;}case
R9a:{h_(O);N_(O);p4(O,U2a,R9a,W_);return
0;}case
H3b:{v8a(O,W_);return
0;}case
F8a:{r3a(O,W_);return
0;}case
o_a:{z6a(O,W_);return
0;}case
v5b:{h_(O);if(L3(O,o_a))j4b(O);else
T8a(O);return
0;}case
X3b:{Z1b(O);return
1;}case
n6b:{g9a(O);return
1;}default:{D6b(O);return
0;}}}static
void
m5(c_*O){int
z4b=0;k7a(O);while(!z4b&&!t4a(O->t.T_)){z4b=c0a(O);L3(O,';');H(O->J->w0>=O->J->M0);O->J->w0=O->J->M0;}r7a(O);}
#define w4b "posix"
#define Z4b w4b" library for "X7" / Nov 2003"
#ifndef J6a
#define J6a 512
#endif
struct
n3a{char
rwx;mode_t
e6;};typedef
struct
n3a
n3a;static
n3a
N2a[]={{'r',S_IRUSR},{'w',S_IWUSR},{'x',S_IXUSR},{'r',S_IRGRP},{'w',S_IWGRP},{'x',S_IXGRP},{'r',S_IROTH},{'w',S_IWOTH},{'x',S_IXOTH},{0,(mode_t)-1}};static
int
x5a(mode_t*u0,const
char*p){int
w1;mode_t
Z9=*u0;Z9&=~(S_ISUID|S_ISGID);for(w1=0;w1<9;w1++){if(*p==N2a[w1].rwx)Z9|=N2a[w1].e6;else
if(*p=='-')Z9&=~N2a[w1].e6;else
if(*p=='s')switch(w1){case
2:Z9|=S_ISUID|S_IXUSR;break;case
5:Z9|=S_ISGID|S_IXGRP;break;default:return-4;break;}p++;}*u0=Z9;return
0;}static
void
s_a(mode_t
u0,char*p){int
w1;char*pp;pp=p;for(w1=0;w1<9;w1++){if(u0&N2a[w1].e6)*p=N2a[w1].rwx;else*p='-';p++;}*p=0;if(u0&S_ISUID)pp[2]=(u0&S_IXUSR)?'s':'S';if(u0&S_ISGID)pp[5]=(u0&S_IXGRP)?'s':'S';}static
int
j7a(mode_t*u0,const
char*p){char
op=0;mode_t
Z2,R6;int
x6a=0;
#ifdef DEBUG
char
tmp[10];
#endif
#ifdef DEBUG
s_a(*u0,tmp);printf("modemuncher: got base mode = %s\n",tmp);
#endif
while(!x6a){Z2=0;R6=0;
#ifdef DEBUG
printf("modemuncher step 1\n");
#endif
if(*p=='r'||*p=='-')return
x5a(u0,p);for(;;p++)switch(*p){case'u':Z2|=04700;break;case'g':Z2|=02070;break;case'o':Z2|=01007;break;case'a':Z2|=07777;break;case' ':break;default:goto
u6a;}u6a:if(Z2==0)Z2=07777;
#ifdef DEBUG
printf("modemuncher step 2 (*p='%c')\n",*p);
#endif
switch(*p){case'+':case'-':case'=':op=*p;break;case' ':break;default:return-1;}
#ifdef DEBUG
printf("modemuncher step 3\n");
#endif
for(p++;*p!=0;p++)switch(*p){case'r':R6|=00444;break;case'w':R6|=00222;break;case'x':R6|=00111;break;case's':R6|=06000;break;case' ':break;default:goto
l2b;}l2b:
#ifdef DEBUG
printf("modemuncher step 4\n");
#endif
if(*p!=',')x6a=1;if(*p!=0&&*p!=' '&&*p!=','){
#ifdef DEBUG
printf("modemuncher: comma error!\n");printf("modemuncher: doneflag = %u\n",x6a);
#endif
return-2;}p++;if(R6)switch(op){case'+':*u0=*u0|=R6&Z2;break;case'-':*u0=*u0&=~(R6&Z2);break;case'=':*u0=R6&Z2;break;default:return-3;}}
#ifdef DEBUG
s_a(*u0,tmp);printf("modemuncher: returning mode = %s\n",tmp);
#endif
return
0;}
#ifdef __CYGWIN__
#define _SC_STREAM_MAX 0
#endif
static
const
char*A_b(mode_t
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
int(*M5b)(a*L,int
i,const
void*a3);static
int
W6(a*L,int
i,const
char*const
S[],M5b
F,const
void*a3){if(e3(L,i)){S0(L);for(i=0;S[i]!=NULL;i++){I(L,S[i]);F(L,i,a3);P0(L,-3);}return
1;}else{int
j=a7(Q(L,i),S);if(j==-1)d1(L,i,"unknown selector");return
F(L,j,a3);}}static
void
a7a(a*L,int
i,const
char*m_){I(L,m_);D2(L,-2,i);}static
void
d1b(a*L,const
char*b_,const
char*m_){I(L,b_);I(L,m_);P0(L,-3);}static
void
j6a(a*L,const
char*b_,U
m_){I(L,b_);N(L,m_);P0(L,-3);}static
int
x4(a*L,const
char*C_){w_(L);if(C_==NULL)I(L,strerror(errno));else
P_(L,"%s: %s",C_,strerror(errno));N(L,errno);return
3;}static
int
M_(a*L,int
i,const
char*C_){if(i!=-1){N(L,i);return
1;}else
return
x4(L,C_);}static
void
R8a(a*L,int
i,const
char*r3,int
v5a){d1(L,2,P_(L,"unknown %s option `%c'",r3,v5a));}static
uid_t
w0b(a*L,int
i){if(e3(L,i))return-1;else
if(r2(L,i))return(uid_t)E0(L,i);else
if(W1(L,i)){struct
passwd*p=getpwnam(o_(L,i));return(p==NULL)?-1:p->pw_uid;}else
return
p5(L,i,"string or number");}static
gid_t
y0b(a*L,int
i){if(e3(L,i))return-1;else
if(r2(L,i))return(gid_t)E0(L,i);else
if(W1(L,i)){struct
group*g=getgrnam(o_(L,i));return(g==NULL)?-1:g->gr_gid;}else
return
p5(L,i,"string or number");}static
int
K8b(a*L){I(L,strerror(errno));N(L,errno);return
2;}static
int
Q_c(a*L){const
char*B_=J0(L,1,".");DIR*d=opendir(B_);if(d==NULL)return
x4(L,B_);else{int
i;struct
dirent*D6;S0(L);for(i=1;(D6=readdir(d))!=NULL;i++)a7a(L,i,D6->d_name);closedir(d);return
1;}}static
int
t3b(a*L){DIR*d=Y1(L,O_(1));struct
dirent*D6;if(d==NULL)s_(L,"attempt to use closed dir");D6=readdir(d);if(D6==NULL){closedir(d);w_(L);Q5(L,O_(1));w_(L);}else{I(L,D6->d_name);
#if 0
#ifdef p3b
I(L,A_b(DTTOIF(D6->d_type)));return
2;
#endif
#endif
}return
1;}static
int
w8b(a*L){const
char*B_=J0(L,1,".");DIR*d=opendir(B_);if(d==NULL)return
x4(L,B_);else{C1(L,d);x1(L,t3b,1);return
1;}}static
int
Z7b(a*L){char
buf[J6a];if(getcwd(buf,sizeof(buf))==NULL)return
x4(L,".");else{I(L,buf);return
1;}}static
int
s8b(a*L){const
char*B_=Q(L,1);return
M_(L,mkdir(B_,0777),B_);}static
int
C8b(a*L){const
char*B_=Q(L,1);return
M_(L,chdir(B_),B_);}static
int
F8b(a*L){const
char*B_=Q(L,1);return
M_(L,rmdir(B_),B_);}static
int
P7b(a*L){const
char*B_=Q(L,1);return
M_(L,unlink(B_),B_);}static
int
h_c(a*L){const
char*b3a=Q(L,1);const
char*A2a=Q(L,2);return
M_(L,link(b3a,A2a),NULL);}static
int
F5b(a*L){const
char*b3a=Q(L,1);const
char*A2a=Q(L,2);return
M_(L,symlink(b3a,A2a),NULL);}static
int
V3b(a*L){char
buf[J6a];const
char*B_=Q(L,1);int
n=readlink(B_,buf,sizeof(buf));if(n==-1)return
x4(L,B_);Z0(L,buf,n);return
1;}static
int
H7b(a*L){int
u0=F_OK;const
char*B_=Q(L,1);const
char*s;for(s=J0(L,2,"f");*s!=0;s++)switch(*s){case' ':break;case'r':u0|=R_OK;break;case'w':u0|=W_OK;break;case'x':u0|=X_OK;break;case'f':u0|=F_OK;break;default:R8a(L,2,"mode",*s);break;}return
M_(L,access(B_,u0),B_);}static
int
e8b(a*L){const
char*B_=Q(L,1);return
M_(L,mkfifo(B_,0777),B_);}static
int
Q9b(a*L){const
char*B_=Q(L,1);int
i,n=D_(L);char**q3=malloc((n+1)*sizeof(char*));if(q3==NULL)s_(L,"not enough memory");q3[0]=(char*)B_;for(i=1;i<n;i++)q3[i]=(char*)Q(L,i+1);q3[i]=NULL;execvp(B_,q3);return
x4(L,B_);}static
int
i_c(a*L){return
M_(L,fork(),NULL);}static
int
d_c(a*L){pid_t
pid=a1(L,1,-1);return
M_(L,waitpid(pid,NULL,0),NULL);}static
int
V9b(a*L){pid_t
pid=X_(L,1);int
sig=a1(L,2,SIGTERM);return
M_(L,kill(pid,sig),NULL);}static
int
E8b(a*L){unsigned
int
c2b=X_(L,1);N(L,sleep(c2b));return
1;}static
int
i7b(a*L){size_t
l;const
char*s=y_(L,1,&l);char*e=malloc(++l);return
M_(L,(e==NULL)?-1:putenv(memcpy(e,s,l)),s);}
#ifdef linux
static
int
X7b(a*L){const
char*b_=Q(L,1);const
char*m_=Q(L,2);int
x4b=J1(L,3)||V1(L,3);return
M_(L,setenv(b_,m_,x4b),b_);}static
int
L3b(a*L){const
char*b_=Q(L,1);unsetenv(b_);return
0;}
#endif
static
int
Q7b(a*L){if(e3(L,1)){extern
char**environ;char**e;if(*environ==NULL)w_(L);else
S0(L);for(e=environ;*e!=NULL;e++){char*s=*e;char*eq=strchr(s,'=');if(eq==NULL){I(L,s);n0(L,0);}else{Z0(L,s,eq-s);I(L,eq+1);}P0(L,-3);}}else
I(L,getenv(Q(L,1)));return
1;}static
int
i9b(a*L){char
m[10];mode_t
u0;umask(u0=umask(0));u0=(~u0)&0777;if(!e3(L,1)){if(j7a(&u0,Q(L,1))){w_(L);return
1;}u0&=0777;umask(~u0);}s_a(u0,m);I(L,m);return
1;}static
int
g9b(a*L){mode_t
u0;struct
stat
s;const
char*B_=Q(L,1);const
char*f7b=Q(L,2);if(stat(B_,&s))return
x4(L,B_);u0=s.st_mode;if(j7a(&u0,f7b))d1(L,2,"bad mode");return
M_(L,chmod(B_,u0),B_);}static
int
T8b(a*L){const
char*B_=Q(L,1);uid_t
uid=w0b(L,2);gid_t
gid=y0b(L,3);return
M_(L,chown(B_,uid,gid),B_);}static
int
o9b(a*L){struct
utimbuf
times;time_t
o_b=time(NULL);const
char*B_=Q(L,1);times.modtime=y3(L,2,o_b);times.actime=y3(L,3,o_b);return
M_(L,utime(B_,&times),B_);}static
int
N8b(a*L,int
i,const
void*a3){switch(i){case
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
X8b[]={"egid","euid","gid","uid","pgrp","pid","ppid",NULL};static
int
v9a(a*L){return
W6(L,1,X8b,N8b,NULL);}static
int
o5b(a*L){int
fd=a1(L,1,0);I(L,ttyname(fd));return
1;}static
int
p6b(a*L){char
b[L_ctermid];I(L,ctermid(b));return
1;}static
int
M3b(a*L){I(L,getlogin());return
1;}static
int
w2b(a*L,int
i,const
void*a3){const
struct
passwd*p=a3;switch(i){case
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
f3b[]={"name","uid","gid","dir","shell","gecos","passwd",NULL};static
int
i3b(a*L){struct
passwd*p=NULL;if(J1(L,1))p=getpwuid(geteuid());else
if(r2(L,1))p=getpwuid((uid_t)E0(L,1));else
if(W1(L,1))p=getpwnam(o_(L,1));else
p5(L,1,"string or number");if(p==NULL)w_(L);else
W6(L,2,f3b,w2b,p);return
1;}static
int
N3b(a*L){struct
group*g=NULL;if(r2(L,1))g=getgrgid((gid_t)E0(L,1));else
if(W1(L,1))g=getgrnam(o_(L,1));else
p5(L,1,"string or number");if(g==NULL)w_(L);else{int
i;S0(L);d1b(L,"name",g->gr_name);j6a(L,"gid",g->gr_gid);for(i=0;g->gr_mem[i]!=NULL;i++)a7a(L,i+1,g->gr_mem[i]);}return
1;}static
int
K7b(a*L){return
M_(L,setuid(w0b(L,1)),NULL);}static
int
h7b(a*L){return
M_(L,setgid(y0b(L,1)),NULL);}struct
S1b{struct
tms
t;clock_t
T1b;};
#define u1a(L,x) N(L,((U)x)/CLOCKS_PER_SEC)
static
int
c9b(a*L,int
i,const
void*a3){const
struct
S1b*t=a3;switch(i){case
0:u1a(L,t->t.tms_utime);break;case
1:u1a(L,t->t.tms_stime);break;case
2:u1a(L,t->t.tms_cutime);break;case
3:u1a(L,t->t.tms_cstime);break;case
4:u1a(L,t->T1b);break;}return
1;}static
const
char*const
V8b[]={"utime","stime","cutime","cstime","elapsed",NULL};
#define n_c(L,b_,x) j6a(L,b_,(U)x/CLK_TCK)
static
int
d9b(a*L){struct
S1b
t;t.T1b=times(&t.t);return
W6(L,1,V8b,c9b,&t);}struct
R3b{struct
stat
s;char
u0[10];const
char*x4a;};static
int
g_c(a*L,int
i,const
void*a3){const
struct
R3b*s=a3;switch(i){case
0:I(L,s->u0);break;case
1:N(L,s->s.st_ino);break;case
2:N(L,s->s.st_dev);break;case
3:N(L,s->s.st_nlink);break;case
4:N(L,s->s.st_uid);break;case
5:N(L,s->s.st_gid);break;case
6:N(L,s->s.st_size);break;case
7:N(L,s->s.st_atime);break;case
8:N(L,s->s.st_mtime);break;case
9:N(L,s->s.st_ctime);break;case
10:I(L,s->x4a);break;case
11:N(L,s->s.st_mode);break;}return
1;}static
const
char*const
D9b[]={"mode","ino","dev","nlink","uid","gid","size","atime","mtime","ctime","type","_mode",NULL};static
int
N9b(a*L){struct
R3b
s;const
char*B_=Q(L,1);if(stat(B_,&s.s)==-1)return
x4(L,B_);s.x4a=A_b(s.s.st_mode);s_a(s.s.st_mode,s.u0);return
W6(L,2,D9b,g_c,&s);}static
int
y8b(a*L){struct
utsname
u;I_
b;const
char*s;if(uname(&u)==-1)return
x4(L,NULL);U1(L,&b);for(s=J0(L,1,"%s %n %r %v %m");*s;s++)if(*s!='%')k1(&b,*s);else
switch(*++s){case'%':k1(&b,*s);break;case'm':c5(&b,u.machine);break;case'n':c5(&b,u.nodename);break;case'r':c5(&b,u.release);break;case's':c5(&b,u.sysname);break;case'v':c5(&b,u.version);break;default:R8a(L,2,"format",*s);break;}X0(&b);return
1;}static
const
int
p4b[]={_PC_LINK_MAX,_PC_MAX_CANON,_PC_MAX_INPUT,_PC_NAME_MAX,_PC_PATH_MAX,_PC_PIPE_BUF,_PC_CHOWN_RESTRICTED,_PC_NO_TRUNC,_PC_VDISABLE,-1};static
int
N4b(a*L,int
i,const
void*a3){const
char*B_=a3;N(L,pathconf(B_,p4b[i]));return
1;}static
const
char*const
T3b[]={"link_max","max_canon","max_input","name_max","path_max","pipe_buf","chown_restricted","no_trunc","vdisable",NULL};static
int
s4b(a*L){const
char*B_=Q(L,1);return
W6(L,2,T3b,N4b,B_);}static
const
int
W5b[]={_SC_ARG_MAX,_SC_CHILD_MAX,_SC_CLK_TCK,_SC_NGROUPS_MAX,_SC_STREAM_MAX,_SC_TZNAME_MAX,_SC_OPEN_MAX,_SC_JOB_CONTROL,_SC_SAVED_IDS,_SC_VERSION,-1};static
int
N5b(a*L,int
i,const
void*a3){N(L,sysconf(W5b[i]));return
1;}static
const
char*const
A6b[]={"arg_max","child_max","clk_tck","ngroups_max","stream_max","tzname_max","open_max","job_control","saved_ids","version",NULL};static
int
e6b(a*L){return
W6(L,1,A6b,N5b,NULL);}static
const
g3
R[]={{"access",H7b},{"chdir",C8b},{"chmod",g9b},{"chown",T8b},{"ctermid",p6b},{"dir",Q_c},{"errno",K8b},{"exec",Q9b},{"files",w8b},{"fork",i_c},{"getcwd",Z7b},{"getenv",Q7b},{"getgroup",N3b},{"getlogin",M3b},{"getpasswd",i3b},{"getprocessid",v9a},{"kill",V9b},{"link",h_c},{"mkdir",s8b},{"mkfifo",e8b},{"pathconf",s4b},{"putenv",i7b},{"readlink",V3b},{"rmdir",F8b},{"setgid",h7b},{"setuid",K7b},{"sleep",E8b},{"stat",N9b},{"symlink",F5b},{"sysconf",e6b},{"times",d9b},{"ttyname",o5b},{"umask",i9b},{"uname",y8b},{"unlink",P7b},{"utime",o9b},{"wait",d_c},
#ifdef linux
{"setenv",X7b},{"unsetenv",L3b},
#endif
{NULL,NULL}};P
int
k4a(a*L){u2(L,w4b,R,0);e_(L,"version");e_(L,Z4b);P0(L,-3);return
1;}
#define v_c
#ifndef M9a
#define g9 0
#else
union
Z0b{g8
a;M9a
b;};
#define g9 (sizeof(union Z0b))
#endif
static
int
B9a(a*L){B2a(L);return
0;}static
a*k6a(a*L){S_*N_=(S_*)S5(L,sizeof(a)+g9);if(N_==NULL)return
NULL;else{N_+=g9;return
g_(a*,N_);}}static
void
b9a(a*L,a*L1){R1a(L,g_(S_*,L1)-g9,sizeof(a)+g9);}static
void
m7a(a*L1,a*L){L1->l_=C2(L,v8+V6,E);L1->E2=v8+V6;L1->X=L1->l_;L1->r5=L1->l_+(L1->E2-V6)-1;L1->N0=C2(L,k0a,l0);L1->ci=L1->N0;L1->ci->g0=K1a;R_(L1->X++);L1->k_=L1->ci->k_=L1->X;L1->ci->X=L1->X+J3;L1->S3=k0a;L1->y7a=L1->N0+L1->S3;}static
void
l9a(a*L,a*L1){u1(L,L1->N0,L1->S3,l0);u1(L,L1->l_,L1->E2,E);}static
void
C3b(a*L,void*ud){q4*g=v3a(NULL,q4);B2a(ud);if(g==NULL)E5(L,s3a);L->l_G=g;g->m9=L;g->I5=0;g->X6.W=0;g->X6.v6a=0;g->X6.f2=NULL;R_(B3(L));R_(T5(L));i2a(L,&g->p_);g->P9a=B9a;g->P4a=NULL;g->t6=NULL;g->k6=NULL;R_(g4(g->Y3));R_(y4(g->Y3));g->Y3->h_=NULL;g->T6=sizeof(a)+sizeof(q4);m7a(L,L);B3(L)->tt=H_;s6(B3(L),w7(L,0,0));i1(B3(L))->r_=i1(B3(L));s6(gt(L),w7(L,0,4));s6(T5(L),w7(L,4,4));w_a(L,h0a);a9a(L);M8a(L);B6a(W1a(L,k9a));g->I5=4*G(L)->T6;}static
void
N3a(a*L){L->l_=NULL;L->E2=0;L->E8=NULL;L->w6=NULL;L->C6=L->d3a=0;L->n8=0;L->a4=1;X9(L);L->p6=NULL;L->S3=0;L->d6=0;L->N0=L->ci=NULL;L->k4=0;R_(gt(L));}static
void
W5a(a*L){S4(L,L->l_);if(G(L)){C3a(L,1);H(G(L)->P4a==NULL);H(G(L)->t6==NULL);f5a(L);b2a(L,&G(L)->p_);}l9a(L,L);if(G(L)){H(G(L)->T6==sizeof(a)+sizeof(q4));i9(NULL,G(L));}b9a(NULL,L);}a*T2a(a*L){a*L1=k6a(L);f7(L,L4(L1),Y2);N3a(L1);L1->l_G=L->l_G;m7a(L1,L);m3a(gt(L1),gt(L));return
L1;}void
m2a(a*L,a*L1){S4(L1,L1->l_);H(L1->p6==NULL);l9a(L,L1);b9a(L,L1);}K
a*P6a(void){a*L=k6a(NULL);if(L){L->tt=Y2;L->U2=0;L->h_=L->h5=NULL;N3a(L);L->l_G=NULL;if(c3(L,C3b,NULL)!=0){W5a(L);L=NULL;}}M4(L);return
L;}static
void
o1b(a*L,void*ud){B2a(ud);g0a(L);}K
void
T1a(a*L){n_(L);L=G(L)->m9;S4(L,L->l_);n7(L);L->k4=0;do{L->ci=L->N0;L->k_=L->X=L->ci->k_;L->d6=0;}while(c3(L,o1b,NULL)!=0);H(G(L)->k6==NULL);W5a(L);}
#define l_c
void
f5a(a*L){H(G(L)->X6.v6a==0);u1(L,G(L)->X6.f2,G(L)->X6.W,A_*);}void
w_a(a*L,int
Q1){u_**N5a=C2(L,Q1,u_*);b8*tb=&G(L)->X6;int
i;for(i=0;i<Q1;i++)N5a[i]=NULL;for(i=0;i<tb->W;i++){u_*p=tb->f2[i];while(p){u_*h_=p->A3.h_;U9
h=L5a(p)->q6.f2;int
h1=d_b(h,Q1);H(g_(int,h%Q1)==d_b(h,Q1));p->A3.h_=N5a[h1];N5a[h1]=p;p=h_;}}u1(L,tb->f2,tb->W,A_*);tb->W=Q1;tb->f2=N5a;}static
A_*i8b(a*L,const
char*str,size_t
l,U9
h){A_*ts=g_(A_*,S5(L,c7a(l)));b8*tb;ts->q6.E1=l;ts->q6.f2=h;ts->q6.U2=0;ts->q6.tt=q1;ts->q6.x3=0;memcpy(ts+1,str,l*sizeof(char));((char*)(ts+1))[l]='\0';tb=&G(L)->X6;h=d_b(h,tb->W);ts->q6.h_=tb->f2[h];tb->f2[h]=L4(ts);tb->v6a++;if(tb->v6a>g_(o8a,tb->W)&&tb->W<=B7/2)w_a(L,tb->W*2);return
ts;}A_*S2(a*L,const
char*str,size_t
l){u_*o;U9
h=(U9)l;size_t
e9=(l>>5)+1;size_t
l1;for(l1=l;l1>=e9;l1-=e9)h=h^((h<<5)+(h>>2)+(unsigned
char)(str[l1-1]));for(o=G(L)->X6.f2[d_b(h,G(L)->X6.W)];o!=NULL;o=o->A3.h_){A_*ts=L5a(o);if(ts->q6.E1==l&&(memcmp(str,C5(ts),l)==0))return
ts;}return
i8b(L,str,l,h);}r_a*g4a(a*L,size_t
s){r_a*u;u=g_(r_a*,S5(L,n5a(s)));u->uv.U2=(1<<1);u->uv.tt=c1;u->uv.E1=s;u->uv.r_=i1(B3(L));u->uv.h_=G(L)->t6;G(L)->t6=L4(u);return
u;}
#define m_c
#ifndef H3
#define H3(c) ((unsigned char)(c))
#endif
typedef
long
M6;static
int
a8b(a*L){size_t
l;y_(L,1,&l);N(L,(U)l);return
1;}static
M6
w3a(M6
G6,size_t
E1){return(G6>=0)?G6:(M6)E1+G6+1;}static
int
U7b(a*L){size_t
l;const
char*s=y_(L,1,&l);M6
v_a=w3a(M2a(L,2),l);M6
l7=w3a(x7(L,3,-1),l);if(v_a<1)v_a=1;if(l7>(M6)l)l7=(M6)l;if(v_a<=l7)Z0(L,s+v_a-1,l7-v_a+1);else
e_(L,"");return
1;}static
int
v3b(a*L){size_t
l;size_t
i;I_
b;const
char*s=y_(L,1,&l);U1(L,&b);for(i=0;i<l;i++)k1(&b,tolower(H3(s[i])));X0(&b);return
1;}static
int
y3b(a*L){size_t
l;size_t
i;I_
b;const
char*s=y_(L,1,&l);U1(L,&b);for(i=0;i<l;i++)k1(&b,toupper(H3(s[i])));X0(&b);return
1;}static
int
F7b(a*L){size_t
l;I_
b;const
char*s=y_(L,1,&l);int
n=X_(L,2);U1(L,&b);while(n-->0)k3(&b,s,l);X0(&b);return
1;}static
int
j6b(a*L){size_t
l;const
char*s=y_(L,1,&l);M6
G6=w3a(x7(L,2,1),l);if(G6<=0||(size_t)(G6)>l)return
0;N(L,H3(s[G6-1]));return
1;}static
int
q5b(a*L){int
n=D_(L);int
i;I_
b;U1(L,&b);for(i=1;i<=n;i++){int
c=X_(L,i);e0(L,H3(c)==c,i,"invalid value");k1(&b,H3(c));}X0(&b);return
1;}static
int
x7a(a*L,const
void*b,size_t
W,void*B){(void)L;k3((I_*)B,(const
char*)b,W);return
1;}static
int
d6b(a*L){I_
b;G_(L,1,d0);U1(L,&b);if(!C0b(L,x7a,&b))s_(L,"unable to dump given function");X0(&b);return
1;}
#ifndef D1a
#define D1a 32
#endif
#define i6 (-1)
#define B4a (-2)
typedef
struct
B1{const
char*H1a;const
char*Z4;a*L;int
z_;struct{const
char*G1;M6
E1;}M2[D1a];}B1;
#define ESC '%'
#define T5b "^$*+?.([%-"
static
int
Z3a(B1*ms,int
l){l-='1';if(l<0||l>=ms->z_||ms->M2[l].E1==i6)return
s_(ms->L,"invalid capture index");return
l;}static
int
T6a(B1*ms){int
z_=ms->z_;for(z_--;z_>=0;z_--)if(ms->M2[z_].E1==i6)return
z_;return
s_(ms->L,"invalid pattern capture");}static
const
char*l4a(B1*ms,const
char*p){switch(*p++){case
ESC:{if(*p=='\0')s_(ms->L,"malformed pattern (ends with `%')");return
p+1;}case'[':{if(*p=='^')p++;do{if(*p=='\0')s_(ms->L,"malformed pattern (missing `]')");if(*(p++)==ESC&&*p!='\0')p++;}while(*p!=']');return
p+1;}default:{return
p;}}}static
int
c6a(int
c,int
cl){int
h0;switch(tolower(cl)){case'a':h0=isalpha(c);break;case'c':h0=iscntrl(c);break;case'd':h0=isdigit(c);break;case'l':h0=islower(c);break;case'p':h0=ispunct(c);break;case's':h0=isspace(c);break;case'u':h0=isupper(c);break;case'w':h0=isalnum(c);break;case'x':h0=isxdigit(c);break;case'z':h0=(c==0);break;default:return(cl==c);}return(islower(cl)?h0:!h0);}static
int
T7(int
c,const
char*p,const
char*ec){int
sig=1;if(*(p+1)=='^'){sig=0;p++;}while(++p<ec){if(*p==ESC){p++;if(c6a(c,*p))return
sig;}else
if((*(p+1)=='-')&&(p+2<ec)){p+=2;if(H3(*(p-2))<=c&&c<=H3(*p))return
sig;}else
if(H3(*p)==c)return
sig;}return!sig;}static
int
C8(int
c,const
char*p,const
char*ep){switch(*p){case'.':return
1;case
ESC:return
c6a(c,*(p+1));case'[':return
T7(c,p,ep-1);default:return(H3(*p)==c);}}static
const
char*F3(B1*ms,const
char*s,const
char*p);static
const
char*s_b(B1*ms,const
char*s,const
char*p){if(*p==0||*(p+1)==0)s_(ms->L,"unbalanced pattern");if(*s!=*p)return
NULL;else{int
b=*p;int
e=*(p+1);int
C8a=1;while(++s<ms->Z4){if(*s==e){if(--C8a==0)return
s+1;}else
if(*s==b)C8a++;}}return
NULL;}static
const
char*Q7a(B1*ms,const
char*s,const
char*p,const
char*ep){M6
i=0;while((s+i)<ms->Z4&&C8(H3(*(s+i)),p,ep))i++;while(i>=0){const
char*h0=F3(ms,(s+i),ep+1);if(h0)return
h0;i--;}return
NULL;}static
const
char*e3b(B1*ms,const
char*s,const
char*p,const
char*ep){for(;;){const
char*h0=F3(ms,s,ep+1);if(h0!=NULL)return
h0;else
if(s<ms->Z4&&C8(H3(*s),p,ep))s++;else
return
NULL;}}static
const
char*O3a(B1*ms,const
char*s,const
char*p,int
r3){const
char*h0;int
z_=ms->z_;if(z_>=D1a)s_(ms->L,"too many captures");ms->M2[z_].G1=s;ms->M2[z_].E1=r3;ms->z_=z_+1;if((h0=F3(ms,s,p))==NULL)ms->z_--;return
h0;}static
const
char*R0b(B1*ms,const
char*s,const
char*p){int
l=T6a(ms);const
char*h0;ms->M2[l].E1=s-ms->M2[l].G1;if((h0=F3(ms,s,p))==NULL)ms->M2[l].E1=i6;return
h0;}static
const
char*O9a(B1*ms,const
char*s,int
l){size_t
E1;l=Z3a(ms,l);E1=ms->M2[l].E1;if((size_t)(ms->Z4-s)>=E1&&memcmp(ms->M2[l].G1,s,E1)==0)return
s+E1;else
return
NULL;}static
const
char*F3(B1*ms,const
char*s,const
char*p){G1:switch(*p){case'(':{if(*(p+1)==')')return
O3a(ms,s,p+2,B4a);else
return
O3a(ms,s,p+1,i6);}case')':{return
R0b(ms,s,p+1);}case
ESC:{switch(*(p+1)){case'b':{s=s_b(ms,s,p+2);if(s==NULL)return
NULL;p+=4;goto
G1;}case'f':{const
char*ep;char
Y_;p+=2;if(*p!='[')s_(ms->L,"missing `[' after `%%f' in pattern");ep=l4a(ms,p);Y_=(s==ms->H1a)?'\0':*(s-1);if(T7(H3(Y_),p,ep-1)||!T7(H3(*s),p,ep-1))return
NULL;p=ep;goto
G1;}default:{if(isdigit(H3(*(p+1)))){s=O9a(ms,s,*(p+1));if(s==NULL)return
NULL;p+=2;goto
G1;}goto
n9b;}}}case'\0':{return
s;}case'$':{if(*(p+1)=='\0')return(s==ms->Z4)?s:NULL;else
goto
n9b;}default:n9b:{const
char*ep=l4a(ms,p);int
m=s<ms->Z4&&C8(H3(*s),p,ep);switch(*ep){case'?':{const
char*h0;if(m&&((h0=F3(ms,s+1,ep+1))!=NULL))return
h0;p=ep+1;goto
G1;}case'*':{return
Q7a(ms,s,p,ep);}case'+':{return(m?Q7a(ms,s+1,p,ep):NULL);}case'-':{return
e3b(ms,s,p,ep);}default:{if(!m)return
NULL;s++;p=ep;goto
G1;}}}}}static
const
char*k6b(const
char*s1,size_t
l1,const
char*s2,size_t
l2){if(l2==0)return
s1;else
if(l2>l1)return
NULL;else{const
char*G1;l2--;l1=l1-l2;while(l1>0&&(G1=(const
char*)memchr(s1,*s2,l1))!=NULL){G1++;if(memcmp(G1,s2+1,l2)==0)return
G1-1;else{l1-=G1-s1;s1=G1;}}return
NULL;}}static
void
Y1a(B1*ms,int
i){int
l=ms->M2[i].E1;if(l==i6)s_(ms->L,"unfinished capture");if(l==B4a)N(ms->L,(U)(ms->M2[i].G1-ms->H1a+1));else
Z0(ms->L,ms->M2[i].G1,l);}static
int
l0a(B1*ms,const
char*s,const
char*e){int
i;A4(ms->L,ms->z_,"too many captures");if(ms->z_==0&&s){Z0(ms->L,s,e-s);return
1;}else{for(i=0;i<ms->z_;i++)Y1a(ms,i);return
ms->z_;}}static
int
C6b(a*L){size_t
l1,l2;const
char*s=y_(L,1,&l1);const
char*p=y_(L,2,&l2);M6
G1=w3a(x7(L,3,1),l1)-1;if(G1<0)G1=0;else
if((size_t)(G1)>l1)G1=(M6)l1;if(V1(L,4)||strpbrk(p,T5b)==NULL){const
char*s2=k6b(s+G1,l1-G1,p,l2);if(s2){N(L,(U)(s2-s+1));N(L,(U)(s2-s+l2));return
2;}}else{B1
ms;int
G0b=(*p=='^')?(p++,1):0;const
char*s1=s+G1;ms.L=L;ms.H1a=s;ms.Z4=s+l1;do{const
char*h0;ms.z_=0;if((h0=F3(&ms,s1,p))!=NULL){N(L,(U)(s1-s+1));N(L,(U)(h0-s));return
l0a(&ms,NULL,0)+2;}}while(s1++<ms.Z4&&!G0b);}w_(L);return
1;}static
int
d4b(a*L){B1
ms;const
char*s=o_(L,O_(1));size_t
O=N3(L,O_(1));const
char*p=o_(L,O_(2));const
char*src;ms.L=L;ms.H1a=s;ms.Z4=s+O;for(src=s+(size_t)E0(L,O_(3));src<=ms.Z4;src++){const
char*e;ms.z_=0;if((e=F3(&ms,src,p))!=NULL){int
F0b=e-s;if(e==src)F0b++;N(L,(U)F0b);Q5(L,O_(3));return
l0a(&ms,src,e);}}return
0;}static
int
z9b(a*L){Q(L,1);Q(L,2);I0(L,2);N(L,0);x1(L,d4b,3);return
1;}static
void
R9b(B1*ms,I_*b,const
char*s,const
char*e){a*L=ms->L;if(W1(L,3)){const
char*E0b=o_(L,3);size_t
l=N3(L,3);size_t
i;for(i=0;i<l;i++){if(E0b[i]!=ESC)k1(b,E0b[i]);else{i++;if(!isdigit(H3(E0b[i])))k1(b,E0b[i]);else{int
z_=Z3a(ms,E0b[i]);Y1a(ms,z_);N6(b);}}}}else{int
n;Y(L,3);n=l0a(ms,s,e);e4(L,n,1);if(W1(L,-1))N6(b);else
U_(L,1);}}static
int
Z5b(a*L){size_t
y6b;const
char*src=y_(L,1,&y6b);const
char*p=Q(L,2);int
I9b=a1(L,4,y6b+1);int
G0b=(*p=='^')?(p++,1):0;int
n=0;B1
ms;I_
b;e0(L,D_(L)>=3&&(W1(L,3)||c2(L,3)),3,"string or function expected");U1(L,&b);ms.L=L;ms.H1a=src;ms.Z4=src+y6b;while(n<I9b){const
char*e;ms.z_=0;e=F3(&ms,src,p);if(e){n++;R9b(&ms,&b,src,e);}if(e&&e>src)src=e;else
if(src<ms.Z4)k1(&b,*src++);else
break;if(G0b)break;}k3(&b,src,ms.Z4-src);X0(&b);N(L,(U)n);return
2;}
#define x6b 512
#define C7a 20
static
void
s8a(a*L,I_*b,int
S7){size_t
l;const
char*s=y_(L,S7,&l);k1(b,'"');while(l--){switch(*s){case'"':case'\\':case'\n':{k1(b,'\\');k1(b,*s);break;}case'\0':{k3(b,"\\000",4);break;}default:{k1(b,*s);break;}}s++;}k1(b,'"');}static
const
char*x2b(a*L,const
char*z3,char*A1a,int*x9){const
char*p=z3;while(strchr("-+ #0",*p))p++;if(isdigit(H3(*p)))p++;if(isdigit(H3(*p)))p++;if(*p=='.'){p++;*x9=1;if(isdigit(H3(*p)))p++;if(isdigit(H3(*p)))p++;}if(isdigit(H3(*p)))s_(L,"invalid format (width or precision too long)");if(p-z3+2>C7a)s_(L,"invalid format (too long)");A1a[0]='%';strncpy(A1a+1,z3,p-z3+1);A1a[p-z3+2]=0;return
p;}static
int
Q2b(a*L){int
S7=1;size_t
sfl;const
char*z3=y_(L,S7,&sfl);const
char*f1b=z3+sfl;I_
b;U1(L,&b);while(z3<f1b){if(*z3!='%')k1(&b,*z3++);else
if(*++z3=='%')k1(&b,*z3++);else{char
A1a[C7a];char
p_[x6b];int
x9=0;if(isdigit(H3(*z3))&&*(z3+1)=='$')return
s_(L,"obsolete option (d$) to `format'");S7++;z3=x2b(L,z3,A1a,&x9);switch(*z3++){case'c':case'd':case'i':{sprintf(p_,A1a,X_(L,S7));break;}case'o':case'u':case'x':case'X':{sprintf(p_,A1a,(unsigned
int)(b1(L,S7)));break;}case'e':case'E':case'f':case'g':case'G':{sprintf(p_,A1a,b1(L,S7));break;}case'q':{s8a(L,&b,S7);continue;}case's':{size_t
l;const
char*s=y_(L,S7,&l);if(!x9&&l>=100){Y(L,S7);N6(&b);continue;}else{sprintf(p_,A1a,s);break;}}default:{return
s_(L,"invalid option to `format'");}}k3(&b,p_,strlen(p_));}}X0(&b);return
1;}static
const
g3
z8b[]={{"len",a8b},{"sub",U7b},{"lower",v3b},{"upper",y3b},{"char",q5b},{"rep",F7b},{"byte",j6b},{"format",Q2b},{"dump",d6b},{"find",C6b},{"gfind",z9b},{"gsub",Z5b},{NULL,NULL}};P
int
J7(a*L){u2(L,p8a,z8b,0);return
1;}
#define I_c
#if BITS_INT>26
#define R8 24
#else
#define R8 (BITS_INT-2)
#endif
#define I8b(x) ((((x)-1)>>R8)!=0)
#ifndef Y9
#define Y9(i,n) ((i)=(int)(n))
#endif
#define M_b(t,n) (l5(t,d_b((n),k5(t))))
#define D1b(t,str) M_b(t,(str)->q6.f2)
#define k1b(t,p) M_b(t,p)
#define A1b(t,n) (l5(t,((n)%((k5(t)-1)|1))))
#define a6a(t,p) A1b(t,A5b(p))
#define O1b g_(int,sizeof(U)/sizeof(int))
static
I3*J1b(const
o0*t,U
n){unsigned
int
a[O1b];int
i;n+=1;H(sizeof(a)<=sizeof(n));memcpy(a,&n,sizeof(a));for(i=1;i<O1b;i++)a[0]+=a[i];return
A1b(t,g_(U9,a[0]));}I3*U3(const
o0*t,const
E*x_){switch(T0(x_)){case
N1:return
J1b(t,r0(x_));case
q1:return
D1b(t,k2(x_));case
f5:return
k1b(t,R2a(x_));case
I1:return
a6a(t,D2a(x_));default:return
a6a(t,H7(x_));}}static
int
P7a(const
E*x_){if(W0(x_)){int
k;Y9(k,(r0(x_)));if(g_(U,k)==r0(x_)&&k>=1&&!I8b(k))return
k;}return-1;}static
int
B2b(a*L,o0*t,t_
x_){int
i;if(H0(x_))return-1;i=P7a(x_);if(0<=i&&i<=t->M1){return
i-1;}else{const
E*v=p7(t,x_);if(v==&B2)q_(L,"invalid key for `next'");i=g_(int,(g_(const
S_*,v)-g_(const
S_*,y4(l5(t,0))))/sizeof(I3));return
i+t->M1;}}int
S8a(a*L,o0*t,t_
x_){int
i=B2b(L,t,x_);for(i++;i<t->M1;i++){if(!H0(&t->v0[i])){K1(x_,g_(U,i+1));k0(x_+1,&t->v0[i]);return
1;}}for(i-=t->M1;i<k5(t);i++){if(!H0(y4(l5(t,i)))){k0(x_,g4(l5(t,i)));k0(x_+1,y4(l5(t,i)));return
1;}}return
0;}static
void
J_b(int
J3a[],int
i5b,int*B5,int*G2b){int
i;int
a=J3a[0];int
na=a;int
n=(na==0)?-1:0;for(i=1;a<*B5&&*B5>=a2a(i-1);i++){if(J3a[i]>0){a+=J3a[i];if(a>=a2a(i-1)){n=i;na=a;}}}H(na<=*B5&&*B5<=i5b);*G2b=i5b-na;*B5=(n==-1)?0:a2a(n);H(na<=*B5&&na>=*B5/2);}static
void
S8b(const
o0*t,int*B5,int*G2b){int
J3a[R8+1];int
i,lg;int
x3a=0;for(i=0,lg=0;lg<=R8;lg++){int
X2b=a2a(lg);if(X2b>t->M1){X2b=t->M1;if(i>=X2b)break;}J3a[lg]=0;for(;i<X2b;i++){if(!H0(&t->v0[i])){J3a[lg]++;x3a++;}}}for(;lg<=R8;lg++)J3a[lg]=0;*B5=x3a;i=k5(t);while(i--){I3*n=&t->d3[i];if(!H0(y4(n))){int
k=P7a(g4(n));if(k>=0){J3a[Z_a(k-1)+1]++;(*B5)++;}x3a++;}}J_b(J3a,x3a,B5,G2b);}static
void
W2a(a*L,o0*t,int
W){int
i;G0(L,t->v0,t->M1,W,E);for(i=t->M1;i<W;i++)R_(&t->v0[i]);t->M1=W;}static
void
Y3a(a*L,o0*t,int
Y9a){int
i;int
W=a2a(Y9a);if(Y9a>R8)q_(L,"table overflow");if(Y9a==0){t->d3=G(L)->Y3;H(H0(g4(t->d3)));H(H0(y4(t->d3)));H(t->d3->h_==NULL);}else{t->d3=C2(L,W,I3);for(i=0;i<W;i++){t->d3[i].h_=NULL;R_(g4(l5(t,i)));R_(y4(l5(t,i)));}}t->P8=g_(S_,Y9a);t->o7=l5(t,W-1);}static
void
Y8b(a*L,o0*t,int
H9,int
Y6a){int
i;int
f3a=t->M1;int
H3a=t->P8;I3*H2b;I3
Y6[1];if(H3a)H2b=t->d3;else{H(t->d3==G(L)->Y3);Y6[0]=t->d3[0];H2b=Y6;R_(g4(G(L)->Y3));R_(y4(G(L)->Y3));H(G(L)->Y3->h_==NULL);}if(H9>f3a)W2a(L,t,H9);Y3a(L,t,Y6a);if(H9<f3a){t->M1=H9;for(i=H9;i<f3a;i++){if(!H0(&t->v0[i]))h9a(i8(L,t,i+1),&t->v0[i]);}G0(L,t->v0,f3a,H9,E);}for(i=a2a(H3a)-1;i>=0;i--){I3*old=H2b+i;if(!H0(y4(old)))h9a(h_a(L,t,g4(old)),y4(old));}if(H3a)u1(L,H2b,a2a(H3a),I3);}static
void
w3b(a*L,o0*t){int
H9,Y6a;S8b(t,&H9,&Y6a);Y8b(L,t,H9,Z_a(Y6a)+1);}o0*w7(a*L,int
B5,int
G3b){o0*t=v3a(L,o0);f7(L,L4(t),H_);t->r_=i1(B3(L));t->p3a=g_(S_,~0);t->v0=NULL;t->M1=0;t->P8=0;t->d3=NULL;W2a(L,t,B5);Y3a(L,t,G3b);return
t;}void
o9a(a*L,o0*t){if(t->P8)u1(L,t->d3,k5(t),I3);u1(L,t->v0,t->M1,E);i9(L,t);}
#if 0
void
t9b(o0*t,I3*e){I3*mp=U3(t,g4(e));if(e!=mp){while(mp->h_!=e)mp=mp->h_;mp->h_=e->h_;}else{if(e->h_!=NULL)??}H(H0(y4(d3)));R_(g4(e));e->h_=NULL;}
#endif
static
E*g5b(a*L,o0*t,const
E*x_){E*r6;I3*mp=U3(t,x_);if(!H0(y4(mp))){I3*S4a=U3(t,g4(mp));I3*n=t->o7;if(S4a!=mp){while(S4a->h_!=mp)S4a=S4a->h_;S4a->h_=n;*n=*mp;mp->h_=NULL;R_(y4(mp));}else{n->h_=mp->h_;mp->h_=n;mp=n;}}p1a(g4(mp),x_);H(H0(y4(mp)));for(;;){if(H0(g4(t->o7)))return
y4(mp);else
if(t->o7==t->d3)break;else(t->o7)--;}X1a(y4(mp),0);w3b(L,t);r6=g_(E*,p7(t,x_));H(z2a(r6));R_(r6);return
r6;}static
const
E*h1b(o0*t,const
E*x_){if(H0(x_))return&B2;else{I3*n=U3(t,x_);do{if(u3(g4(n),x_))return
y4(n);else
n=n->h_;}while(n);return&B2;}}const
E*m_a(o0*t,int
x_){if(1<=x_&&x_<=t->M1)return&t->v0[x_-1];else{U
nk=g_(U,x_);I3*n=J1b(t,nk);do{if(W0(g4(n))&&r0(g4(n))==nk)return
y4(n);else
n=n->h_;}while(n);return&B2;}}const
E*o4(o0*t,A_*x_){I3*n=D1b(t,x_);do{if(n1(g4(n))&&k2(g4(n))==x_)return
y4(n);else
n=n->h_;}while(n);return&B2;}const
E*p7(o0*t,const
E*x_){switch(T0(x_)){case
q1:return
o4(t,k2(x_));case
N1:{int
k;Y9(k,(r0(x_)));if(g_(U,k)==r0(x_))return
m_a(t,k);}default:return
h1b(t,x_);}}E*h_a(a*L,o0*t,const
E*x_){const
E*p=p7(t,x_);t->p3a=0;if(p!=&B2)return
g_(E*,p);else{if(H0(x_))q_(L,"table index is nil");else
if(W0(x_)&&r0(x_)!=r0(x_))q_(L,"table index is NaN");return
g5b(L,t,x_);}}E*i8(a*L,o0*t,int
x_){const
E*p=m_a(t,x_);if(p!=&B2)return
g_(E*,p);else{E
k;K1(&k,g_(U,x_));return
g5b(L,t,&k);}}
#define s_c
#define L1a(L,n) (G_(L,n,H_),I8(L,n))
static
int
G9a(a*L){int
i;int
n=L1a(L,1);G_(L,2,d0);for(i=1;i<=n;i++){Y(L,2);N(L,(U)i);c0(L,1,i);e4(L,2,1);if(!l3(L,-1))return
1;U_(L,1);}return
0;}static
int
f0b(a*L){G_(L,1,H_);G_(L,2,d0);w_(L);for(;;){if(G3a(L,1)==0)return
0;Y(L,2);Y(L,-3);Y(L,-3);e4(L,2,1);if(!l3(L,-1))return
1;U_(L,2);}}static
int
G4b(a*L){N(L,(U)L1a(L,1));return
1;}static
int
f5b(a*L){G_(L,1,H_);O8(L,1,X_(L,2));return
0;}static
int
g0b(a*L){int
v=D_(L);int
n=L1a(L,1)+1;int
G6;if(v==2)G6=n;else{G6=X_(L,2);if(G6>n)n=G6;v=3;}O8(L,1,n);while(--n>=G6){c0(L,1,n);D2(L,1,n+1);}Y(L,v);D2(L,1,G6);return
0;}static
int
j0b(a*L){int
n=L1a(L,1);int
G6=a1(L,2,n);if(n<=0)return
0;O8(L,1,n-1);c0(L,1,G6);for(;G6<n;G6++){c0(L,1,G6+1);D2(L,1,G6);}w_(L);D2(L,1,n);return
1;}static
int
s2b(a*L){I_
b;size_t
t8b;const
char*sep=Z6(L,2,"",&t8b);int
i=a1(L,3,1);int
n=a1(L,4,0);G_(L,1,H_);if(n==0)n=I8(L,1);U1(L,&b);for(;i<=n;i++){c0(L,1,i);e0(L,W1(L,-1),1,"table contains non-strings");N6(&b);if(i!=n)k3(&b,sep,t8b);}X0(&b);return
1;}static
void
A8a(a*L,int
i,int
j){D2(L,1,i);D2(L,1,j);}static
int
W_a(a*L,int
a,int
b){if(!l3(L,2)){int
h0;Y(L,2);Y(L,a-1);Y(L,b-2);e4(L,2,1);h0=V1(L,-1);U_(L,1);return
h0;}else
return
B1a(L,a,b);}static
void
d2b(a*L,int
l,int
u){while(l<u){int
i,j;c0(L,1,l);c0(L,1,u);if(W_a(L,-1,-2))A8a(L,l,u);else
U_(L,2);if(u-l==1)break;i=(l+u)/2;c0(L,1,i);c0(L,1,l);if(W_a(L,-2,-1))A8a(L,i,l);else{U_(L,1);c0(L,1,u);if(W_a(L,-1,-2))A8a(L,i,u);else
U_(L,2);}if(u-l==2)break;c0(L,1,i);Y(L,-1);c0(L,1,u-1);A8a(L,i,u-1);i=l;j=u-1;for(;;){while(c0(L,1,++i),W_a(L,-1,-2)){if(i>u)s_(L,"invalid order function for sorting");U_(L,1);}while(c0(L,1,--j),W_a(L,-3,-1)){if(j<l)s_(L,"invalid order function for sorting");U_(L,1);}if(j<i){U_(L,3);break;}A8a(L,i,j);}c0(L,1,u-1);c0(L,1,i);A8a(L,u-1,i);if(i-l<u-i){j=l;i=i-1;l=i+2;}else{j=i+1;i=u;u=j-2;}d2b(L,j,i);}}static
int
m4b(a*L){int
n=L1a(L,1);A4(L,40,"");if(!J1(L,2))G_(L,2,d0);I0(L,2);d2b(L,1,n);return
0;}static
const
g3
l4b[]={{"concat",s2b},{"foreach",f0b},{"foreachi",G9a},{"getn",G4b},{"setn",f5b},{"sort",m4b},{"insert",g0b},{"remove",j0b},{NULL,NULL}};P
int
m8(a*L){u2(L,B8a,l4b,0);return
1;}
#define z_c
#ifdef v4b
#define a_(L,i) N(L,g_(U,(i)))
static
a*H8a=NULL;int
a6b=0;
#define c_a(L,k) (L->ci->k_+(k)-1)
static
void
t5(a*L,const
char*b_,int
r6){I(L,b_);a_(L,r6);P0(L,-3);}
#define h0b 0x55
#ifndef EXTERNMEMCHECK
#define j8 (sizeof(g8))
#define t1a 16
#define s5a(b) (g_(char*,b)-j8)
#define z1b(d4,W) (*g_(size_t*,d4)=W)
#define a_a(b,W) (W==(*g_(size_t*,s5a(b))))
#define i8a(mem,W) memset(mem,-h0b,W)
#else
#define j8 0
#define t1a 0
#define s5a(b) (b)
#define z1b(d4,W)
#define a_a(b,W) (1)
#define i8a(mem,W)
#endif
unsigned
long
H5=0;unsigned
long
h4=0;unsigned
long
C9=0;unsigned
long
U7=ULONG_MAX;static
void*o3b(void*N_,size_t
W){void*b=s5a(N_);int
i;for(i=0;i<t1a;i++)H(*(g_(char*,b)+j8+W+i)==h0b+i);return
b;}static
void
J8a(void*N_,size_t
W){if(N_){H(a_a(N_,W));N_=o3b(N_,W);i8a(N_,W+j8+t1a);free(N_);H5--;h4-=W;}}void*q8b(void*N_,size_t
l4,size_t
W){H(l4==0||a_a(N_,l4));H(N_!=NULL||W>0);if(W==0){J8a(N_,l4);return
NULL;}else
if(W>l4&&h4+W-l4>U7)return
NULL;else{void*d4;int
i;size_t
e_b=j8+W+t1a;size_t
o3a=(l4<W)?l4:W;if(e_b<W)return
NULL;d4=malloc(e_b);if(d4==NULL)return
NULL;if(N_){memcpy(g_(char*,d4)+j8,N_,o3a);J8a(N_,l4);}i8a(g_(char*,d4)+j8+o3a,W-o3a);h4+=W;if(h4>C9)C9=h4;H5++;z1b(d4,W);for(i=0;i<t1a;i++)*(g_(char*,d4)+j8+W+i)=g_(char,h0b+i);return
g_(char*,d4)+j8;}}static
char*Y1b(E_*p,int
pc,char*p_){j_
i=p->m1[pc];a6
o=V_(i);const
char*b_=X4a[o];int
W_=A5a(p,pc);sprintf(p_,"(%4d) %4d - ",W_,pc);switch(J_a(o)){case
P3:sprintf(p_+strlen(p_),"%-12s%4d %4d %4d",b_,w3(i),a2(i),X2(i));break;case
y3a:sprintf(p_+strlen(p_),"%-12s%4d %4d",b_,w3(i),v7(i));break;case
K5a:sprintf(p_+strlen(p_),"%-12s%4d %4d",b_,w3(i),Q3(i));break;}return
p_;}
#if 0
void
f8b(E_*pt,int
W){int
pc;for(pc=0;pc<W;pc++){char
p_[100];printf("%s\n",Y1b(pt,pc,p_));}printf("-------\n");}
#endif
static
int
f6b(a*L){int
pc;E_*p;e0(L,c2(L,1)&&!K3(L,1),1,"Lua function expected");p=A2(c_a(L,1))->l.p;S0(L);t5(L,"maxstack",p->Z1);t5(L,"numparams",p->d7);for(pc=0;pc<p->H2;pc++){char
p_[100];a_(L,pc+1);I(L,Y1b(p,pc,p_));P0(L,-3);}return
1;}static
int
J9b(a*L){E_*p;int
i;e0(L,c2(L,1)&&!K3(L,1),1,"Lua function expected");p=A2(c_a(L,1))->l.p;S0(L);for(i=0;i<p->Z8;i++){a_(L,i+1);C4(L,p->k+i);P0(L,-3);}return
1;}static
int
m3b(a*L){E_*p;int
pc=X_(L,2)-1;int
i=0;const
char*b_;e0(L,c2(L,1)&&!K3(L,1),1,"Lua function expected");p=A2(c_a(L,1))->l.p;while((b_=O4(p,++i,pc))!=NULL)I(L,b_);return
i-1;}static
int
k2b(a*L){S0(L);t5(L,"BITS_INT",BITS_INT);t5(L,"LFPF",P4);t5(L,"MAXVARS",O5a);t5(L,"MAXPARAMS",e5a);t5(L,"MAXSTACK",q2);t5(L,"MAXUPVALUES",G_a);return
1;}static
int
a5b(a*L){if(e3(L,1)){a_(L,h4);a_(L,H5);a_(L,C9);return
3;}else{U7=X_(L,1);return
0;}}static
int
E2b(a*L){if(e3(L,2)){e0(L,b2(L,1)==q1,1,"string expected");a_(L,k2(c_a(L,1))->q6.f2);}else{E*o=c_a(L,1);o0*t;G_(L,2,H_);t=i1(c_a(L,2));a_(L,U3(t,o)-t->d3);}return
1;}static
int
j3b(a*L){unsigned
long
a=0;a_(L,(int)(L->X-L->l_));a_(L,(int)(L->r5-L->l_));a_(L,(int)(L->ci-L->N0));a_(L,(int)(L->y7a-L->N0));a_(L,(unsigned
long)&a);return
5;}static
int
v1b(a*L){const
o0*t;int
i=a1(L,2,-1);G_(L,1,H_);t=i1(c_a(L,1));if(i==-1){a_(L,t->M1);a_(L,k5(t));a_(L,t->o7-t->d3);}else
if(i<t->M1){a_(L,i);C4(L,&t->v0[i]);w_(L);}else
if((i-=t->M1)<k5(t)){if(!H0(y4(l5(t,i)))||H0(g4(l5(t,i)))||W0(g4(l5(t,i)))){C4(L,g4(l5(t,i)));}else
I(L,"<undef>");C4(L,y4(l5(t,i)));if(t->d3[i].h_)a_(L,t->d3[i].h_-t->d3);else
w_(L);}return
3;}static
int
m_b(a*L){b8*tb=&G(L)->X6;int
s=a1(L,2,0)-1;if(s==-1){a_(L,tb->v6a);a_(L,tb->W);return
2;}else
if(s<tb->W){u_*ts;int
n=0;for(ts=tb->f2[s];ts;ts=ts->A3.h_){C3(L->X,L5a(ts));R3(L);n++;}return
n;}return
0;}static
int
N_c(a*L){int
z_=D_(L);int
T_b=a1(L,2,1);A0(L,1);Y(L,1);a_(L,y7b(L,T_b));assert(D_(L)==z_+1);return
1;}static
int
a9b(a*L){int
z_=D_(L);m2b(L,X_(L,1));assert(D_(L)==z_+1);return
1;}static
int
a_c(a*L){int
z_=D_(L);O4b(L,X_(L,1));assert(D_(L)==z_);return
0;}static
int
r_(a*L){A0(L,1);if(e3(L,2)){if(T2(L,1)==0)w_(L);}else{I0(L,2);G_(L,2,H_);V2(L,1);}return
1;}static
int
E4(a*L){int
n=X_(L,2);G_(L,1,d0);if(e3(L,3)){const
char*b_=i_a(L,1,n);if(b_==NULL)return
0;I(L,b_);return
2;}else{const
char*b_=W9(L,1,n);I(L,b_);return
1;}}static
int
I0b(a*L){size_t
W=X_(L,1);char*p=g_(char*,y5(L,W));while(W--)*p++='\0';return
1;}static
int
B0b(a*L){C1(L,g_(void*,X_(L,1)));return
1;}static
int
D5b(a*L){a_(L,g_(int,Y1(L,1)));return
1;}static
int
l0b(a*L){a*L1=r0a(L);size_t
l;const
char*s=y_(L,1,&l);int
T=h3(L1,s,l,s);if(T==0)T=w4(L1,0,0,0);a_(L,T);return
1;}static
int
s2d(a*L){N(L,*g_(const
double*,Q(L,1)));return
1;}static
int
d2s(a*L){double
d=b1(L,1);Z0(L,g_(char*,&d),sizeof(d));return
1;}static
int
i6b(a*L){a*L1=P6a();if(L1){M4(L1);a_(L,(unsigned
long)L1);}else
w_(L);return
1;}static
int
V3(a*L){static
const
g3
C_c[]={{"mathlibopen",O1a},{"strlibopen",J7},{"iolibopen",C0a},{"tablibopen",m8},{"dblibopen",k8},{"baselibopen",q9},{NULL,NULL}};a*L1=g_(a*,g_(unsigned
long,b1(L,1)));Y(L1,a0);u2(L1,NULL,C_c,0);return
0;}static
int
K2b(a*L){a*L1=g_(a*,g_(unsigned
long,b1(L,1)));T1a(L1);f_(L);return
0;}static
int
t6b(a*L){a*L1=g_(a*,g_(unsigned
long,b1(L,1)));size_t
Q9a;const
char*m1=y_(L,2,&Q9a);int
T;I0(L1,0);T=h3(L1,m1,Q9a,m1);if(T==0)T=w4(L1,0,y2,0);if(T!=0){w_(L);a_(L,T);I(L,o_(L1,-1));return
3;}else{int
i=0;while(!e3(L1,++i))I(L,o_(L1,i));U_(L1,i-1);return
i-1;}}static
int
g6b(a*L){a_(L,Z_a(X_(L,1)));return
1;}static
int
t2b(a*L){int
b=u2a(X_(L,1));a_(L,b);a_(L,q4b(b));return
2;}static
int
h8b(a*L){const
char*p=Q(L,1);if(*p=='@')V6a(L,p+1);else
o1a(L,p);return
D_(L);}static
const
char*const
Z_b=" \t\n,;";static
void
g2(const
char**pc){while(**pc!='\0'&&strchr(Z_b,**pc))(*pc)++;}static
int
p2b(a*L,const
char**pc){int
h0=0;int
sig=1;g2(pc);if(**pc=='.'){h0=g_(int,E0(L,-1));U_(L,1);(*pc)++;return
h0;}else
if(**pc=='-'){sig=-1;(*pc)++;}while(isdigit(g_(int,**pc)))h0=h0*10+(*(*pc)++)-'0';return
sig*h0;}static
const
char*Q0b(char*p_,const
char**pc){int
i=0;g2(pc);while(**pc!='\0'&&!strchr(Z_b,**pc))p_[i++]=*(*pc)++;p_[i]='\0';return
p_;}
#define EQ(s1) (strcmp(s1,F_c)==0)
#define s0 (p2b(L,&pc))
#define z7b (Q0b(p_,&pc))
static
int
K6b(a*L){char
p_[30];const
char*pc=Q(L,1);for(;;){const
char*F_c=z7b;if
EQ("")return
0;else
if
EQ("isnumber"){a_(L,r2(L,s0));}else
if
EQ("isstring"){a_(L,W1(L,s0));}else
if
EQ("istable"){a_(L,h6a(L,s0));}else
if
EQ("iscfunction"){a_(L,K3(L,s0));}else
if
EQ("isfunction"){a_(L,c2(L,s0));}else
if
EQ("isuserdata"){a_(L,J2a(L,s0));}else
if
EQ("isudataval"){a_(L,o4a(L,s0));}else
if
EQ("isnil"){a_(L,l3(L,s0));}else
if
EQ("isnull"){a_(L,e3(L,s0));}else
if
EQ("tonumber"){N(L,E0(L,s0));}else
if
EQ("tostring"){const
char*s=o_(L,s0);I(L,s);}else
if
EQ("strlen"){a_(L,N3(L,s0));}else
if
EQ("tocfunction"){V7(L,Z1a(L,s0));}else
if
EQ("return"){return
s0;}else
if
EQ("gettop"){a_(L,D_(L));}else
if
EQ("settop"){I0(L,s0);}else
if
EQ("pop"){U_(L,s0);}else
if
EQ("pushnum"){a_(L,s0);}else
if
EQ("pushnil"){w_(L);}else
if
EQ("pushbool"){n0(L,s0);}else
if
EQ("tobool"){a_(L,V1(L,s0));}else
if
EQ("pushvalue"){Y(L,s0);}else
if
EQ("pushcclosure"){x1(L,K6b,s0);}else
if
EQ("pushupvalues"){y8(L);}else
if
EQ("remove"){z5(L,s0);}else
if
EQ("insert"){A1(L,s0);}else
if
EQ("replace"){Q5(L,s0);}else
if
EQ("gettable"){l6(L,s0);}else
if
EQ("settable"){P0(L,s0);}else
if
EQ("next"){G3a(L,-2);}else
if
EQ("concat"){O3(L,s0);}else
if
EQ("lessthan"){int
a=s0;n0(L,B1a(L,a,s0));}else
if
EQ("equal"){int
a=s0;n0(L,P8a(L,a,s0));}else
if
EQ("rawcall"){int
O1=s0;int
U6a=s0;e4(L,O1,U6a);}else
if
EQ("call"){int
O1=s0;int
U6a=s0;w4(L,O1,U6a,0);}else
if
EQ("loadstring"){size_t
sl;const
char*s=y_(L,s0,&sl);h3(L,s,sl,s);}else
if
EQ("loadfile"){J4(L,Q(L,s0));}else
if
EQ("setmetatable"){V2(L,s0);}else
if
EQ("getmetatable"){if(T2(L,s0)==0)w_(L);}else
if
EQ("type"){I(L,g7(L,b2(L,s0)));}else
if
EQ("getn"){int
i=s0;a_(L,I8(L,i));}else
if
EQ("setn"){int
i=s0;int
n=g_(int,E0(L,-1));O8(L,i,n);U_(L,1);}else
s_(L,"unknown instruction %s",p_);}return
0;}static
void
h9b(a*L,C0*ar){y4a(L,0);}static
int
Y5b(a*L){if(J1(L,1))K5(L,NULL,0,0);else{const
char*P7=Q(L,1);int
w1=a1(L,2,0);int
F4=0;if(strchr(P7,'l'))F4|=n6;if(w1>0)F4|=L6;K5(L,h9b,F4,w1);}return
0;}static
int
X5b(a*L){int
T;a*co=j6(L,1);e0(L,co,1,"coroutine expected");T=k3a(co,0);if(T!=0){n0(L,0);A1(L,-2);return
2;}else{n0(L,1);return
1;}}static
const
struct
g3
U0b[]={{"hash",E2b},{"limits",k2b},{"listcode",f6b},{"listk",J9b},{"listlocals",m3b},{"loadlib",V3},{"stacklevel",j3b},{"querystr",m_b},{"querytab",v1b},{"doit",h8b},{"testC",K6b},{"ref",N_c},{"getref",a9b},{"unref",a_c},{"d2s",d2s},{"s2d",s2d},{"metatable",r_},{"upvalue",E4},{"newuserdata",I0b},{"pushuserdata",B0b},{"udataval",D5b},{"doonnewstack",l0b},{"newstate",i6b},{"closestate",K2b},{"doremote",t6b},{"log2",g6b},{"int2fb",t2b},{"totalmem",a5b},{"resume",X5b},{"setyhook",Y5b},{NULL,NULL}};static
void
fim(void){if(!a6b)T1a(H8a);H(H5==0);H(h4==0);}static
int
C7b(a*L){B2a(L);fprintf(stderr,"unable to recover; exiting\n");return
0;}int
T7b(a*L){U5a(L,C7b);M4(L);H8a=L;u2(L,"T",U0b,0);atexit(fim);return
0;}
#undef main
int
main(int
n_b,char*q3[]){char*N2=getenv("MEMLIMIT");if(N2)U7=strtoul(N2,NULL,10);W_c(n_b,q3);return
0;}
#endif
#define e0c
const
char*const
Z5[]={"nil","boolean","userdata","number","string","table","function","userdata","thread"};void
a9a(a*L){static
const
char*const
q8a[]={"__index","__newindex","__gc","__mode","__eq","__add","__sub","__mul","__div","__pow","__unm","__lt","__le","__concat","__call"};int
i;for(i=0;i<R8b;i++){G(L)->d5a[i]=M5(L,q8a[i]);B6a(G(L)->d5a[i]);}}const
E*R7a(o0*q_b,TMS
O2,A_*f7a){const
E*tm=o4(q_b,f7a);H(O2<=A2b);if(H0(tm)){q_b->p3a|=g_(S_,1u<<O2);return
NULL;}else
return
tm;}const
E*j3(a*L,const
E*o,TMS
O2){A_*f7a=G(L)->d5a[O2];switch(T0(o)){case
H_:return
o4(i1(o)->r_,f7a);case
c1:return
o4(T_a(o)->uv.r_,f7a);default:return&B2;}}
#define d0c
#ifdef l7b
#include l7b
#endif
#ifdef _POSIX_C_SOURCE
#define v4a() isatty(0)
#else
#define v4a() 1
#endif
#ifndef Q4b
#define Q4b "> "
#endif
#ifndef g2b
#define g2b ">> "
#endif
#ifndef H0b
#define H0b "lua"
#endif
#ifndef F4a
#define F4a(L) O0b(L)
#endif
#ifndef b4a
#define b4a
#endif
static
a*L=NULL;static
const
char*v6=H0b;P
int
k4a(a*L);static
const
g3
x7b[]={{"base",q9},{"table",m8},{"io",C0a},{"string",J7},{"debug",k8},{"loadlib",d2a},{"posix",k4a},b4a{NULL,NULL}};static
void
U6b(a*l,C0*ar){(void)ar;K5(l,NULL,0,0);s_(l,"interrupted!");}static
void
d8b(int
i){signal(i,SIG_DFL);K5(L,U6b,q7|E_a|L6,1);}static
void
n_a(void){fprintf(stderr,"usage: %s [options] [script [args]].\n""Available options are:\n""  -        execute stdin as a file\n""  -e stat  execute string `stat'\n""  -i       enter interactive mode after executing `script'\n""  -l name  load and run library `name'\n""  -v       show version information\n""  --       stop handling options\n",v6);}static
void
G8(const
char*O6b,const
char*O6){if(O6b)fprintf(stderr,"%s: ",O6b);fprintf(stderr,"%s\n",O6);}static
int
u4a(int
T){const
char*O6;if(T){O6=o_(L,-1);if(O6==NULL)O6="(error with no message)";G8(v6,O6);U_(L,1);}return
T;}static
int
n2b(int
O1,int
F0a){int
T;int
k_=D_(L)-O1;e_(L,"_TRACEBACK");x0(L,a0);A1(L,k_);signal(SIGINT,d8b);T=w4(L,O1,(F0a?0:y2),k_);signal(SIGINT,SIG_DFL);z5(L,k_);return
T;}static
void
a4a(void){G8(NULL,X7"  "f4a);}static
void
n7b(char*q3[],int
n){int
i;S0(L);for(i=0;q3[i];i++){N(L,i-n);I(L,q3[i]);F0(L,-3);}e_(L,"n");N(L,i-n-1);F0(L,-3);}static
int
O3b(int
T){if(T==0)T=n2b(0,1);return
u4a(T);}static
int
G9(const
char*b_){return
O3b(J4(L,b_));}static
int
x_b(const
char*s,const
char*b_){return
O3b(h3(L,s,strlen(s),b_));}static
int
t4b(const
char*b_){e_(L,"require");x0(L,a0);if(!c2(L,-1)){U_(L,1);return
G9(b_);}else{I(L,b_);return
u4a(n2b(1,1));}}
#ifndef R4a
#define R4a(L,W_)
#endif
#ifndef N1a
#define N1a(L,w5a) q6b(L,w5a)
#ifndef h_b
#define h_b 512
#endif
static
int
q6b(a*l,const
char*w5a){static
char
b0[h_b];if(w5a){fputs(w5a,stdout);fflush(stdout);}if(fgets(b0,sizeof(b0),stdin)==NULL)return
0;else{I(l,b0);return
1;}}
#endif
static
const
char*e7a(int
Y8a){const
char*p=NULL;I(L,Y8a?"_PROMPT":"_PROMPT2");x0(L,a0);p=o_(L,-1);if(p==NULL)p=(Y8a?Q4b:g2b);U_(L,1);return
p;}static
int
J2b(int
T){if(T==s0a&&strstr(o_(L,-1),"near `<eof>'")!=NULL){U_(L,1);return
1;}else
return
0;}static
int
P0b(void){int
T;I0(L,0);if(N1a(L,e7a(1))==0)return-1;if(o_(L,-1)[0]=='='){P_(L,"return %s",o_(L,-1)+1);z5(L,-2);}for(;;){T=h3(L,o_(L,1),N3(L,1),"=stdin");if(!J2b(T))break;if(N1a(L,e7a(0))==0)return-1;O3(L,D_(L));}R4a(L,o_(L,1));z5(L,1);return
T;}static
void
T4a(void){int
T;const
char*q1b=v6;v6=NULL;while((T=P0b())!=-1){if(T==0)T=n2b(0,0);u4a(T);if(T==0&&D_(L)>0){n5(L,"print");A1(L,1);if(w4(L,D_(L)-1,0,0)!=0)G8(v6,P_(L,"error calling `print' (%s)",o_(L,-1)));}}I0(L,0);fputs("\n",stdout);v6=q1b;}static
int
X0b(char*q3[],int*z_a){if(q3[1]==NULL){if(v4a()){a4a();T4a();}else
G9(NULL);}else{int
i;for(i=1;q3[i]!=NULL;i++){if(q3[i][0]!='-')break;switch(q3[i][1]){case'-':{if(q3[i][2]!='\0'){n_a();return
1;}i++;goto
k8a;}case'\0':{G9(NULL);break;}case'i':{*z_a=1;break;}case'v':{a4a();break;}case'e':{const
char*m5=q3[i]+2;if(*m5=='\0')m5=q3[++i];if(m5==NULL){n_a();return
1;}if(x_b(m5,"=<command line>")!=0)return
1;break;}case'l':{const
char*Q_=q3[i]+2;if(*Q_=='\0')Q_=q3[++i];if(Q_==NULL){n_a();return
1;}if(t4b(Q_))return
1;break;}case'c':{G8(v6,"option `-c' is deprecated");break;}case's':{G8(v6,"option `-s' is deprecated");break;}default:{n_a();return
1;}}}k8a:if(q3[i]!=NULL){const
char*Q_=q3[i];n7b(q3,i);s8(L,"arg");if(strcmp(Q_,"/dev/stdin")==0)Q_=NULL;return
G9(Q_);}}return
0;}static
void
O0b(a*l){const
g3*Y7=x7b;for(;Y7->Z_;Y7++){Y7->Z_(l);I0(l,0);}}static
int
w8a(void){const
char*G1=getenv("LUA_INIT");if(G1==NULL)return
0;else
if(G1[0]=='@')return
G9(G1+1);else
return
x_b(G1,"=LUA_INIT");}struct
Z2b{int
n_b;char**q3;int
T;};static
int
L9b(a*l){struct
Z2b*s=(struct
Z2b*)Y1(l,1);int
T;int
z_a=0;if(s->q3[0]&&s->q3[0][0])v6=s->q3[0];L=l;F4a(l);T=w8a();if(T==0){T=X0b(s->q3,&z_a);if(T==0&&z_a)T4a();}s->T=T;return
0;}int
main(int
n_b,char*q3[]){int
T;struct
Z2b
s;a*l=P6a();if(l==NULL){G8(q3[0],"cannot create state: not enough memory");return
EXIT_FAILURE;}s.n_b=n_b;s.q3=q3;T=u7a(l,&L9b,&s);u4a(T);T1a(l);return(T||s.T)?EXIT_FAILURE:EXIT_SUCCESS;}
#define o_c
#define m7 (S_)O7a
typedef
struct{a*L;X8*Z;f6*b;int
j8a;const
char*b_;}r1;static
void
S3a(r1*S){q_(S->L,"unexpected end of file in %s",S->b_);}static
int
O7a(r1*S){int
c=c7b(S->Z);if(c==EOZ)S3a(S);return
c;}static
void
r0b(r1*S,void*b,int
n){int
r=G8a(S->Z,b,n);if(r!=0)S3a(S);}static
void
t5a(r1*S,void*b,size_t
W){if(S->j8a){char*p=(char*)b+W-1;int
n=W;while(n--)*p--=(char)O7a(S);}else
r0b(S,b,W);}static
void
z7a(r1*S,void*b,int
m,size_t
W){if(S->j8a){char*q=(char*)b;while(m--){char*p=q+W-1;int
n=W;while(n--)*p--=(char)O7a(S);q+=W;}}else
r0b(S,b,m*W);}static
int
O7(r1*S){int
x;t5a(S,&x,sizeof(x));if(x<0)q_(S->L,"bad integer in %s",S->b_);return
x;}static
size_t
u5b(r1*S){size_t
x;t5a(S,&x,sizeof(x));return
x;}static
U
Z6a(r1*S){U
x;t5a(S,&x,sizeof(x));return
x;}static
A_*H0a(r1*S){size_t
W=u5b(S);if(W==0)return
NULL;else{char*s=N7(S->L,S->b,W);r0b(S,s,W);return
S2(S->L,s,W-1);}}static
void
C5b(r1*S,E_*f){int
W=O7(S);f->m1=C2(S->L,W,j_);f->H2=W;z7a(S,f->m1,W,sizeof(*f->m1));}static
void
C2b(r1*S,E_*f){int
i,n;n=O7(S);f->n3=C2(S->L,n,O2a);f->m4=n;for(i=0;i<n;i++){f->n3[i].L2=H0a(S);f->n3[i].G2a=O7(S);f->n3[i].S9a=O7(S);}}static
void
b5b(r1*S,E_*f){int
W=O7(S);f->i4=C2(S->L,W,int);f->o3=W;z7a(S,f->i4,W,sizeof(*f->i4));}static
void
b0b(r1*S,E_*f){int
i,n;n=O7(S);if(n!=0&&n!=f->e5)q_(S->L,"bad nupvalues in %s: read %d; expected %d",S->b_,n,f->e5);f->i0=C2(S->L,n,A_*);f->G3=n;for(i=0;i<n;i++)f->i0[i]=H0a(S);}static
E_*I1a(r1*S,A_*p);static
void
N9a(r1*S,E_*f){int
i,n;n=O7(S);f->k=C2(S->L,n,E);f->Z8=n;for(i=0;i<n;i++){E*o=&f->k[i];int
t=m7(S);switch(t){case
N1:K1(o,Z6a(S));break;case
q1:a1b(o,H0a(S));break;case
P5:R_(o);break;default:q_(S->L,"bad constant type (%d) in %s",t,S->b_);break;}}n=O7(S);f->p=C2(S->L,n,E_*);f->E0a=n;for(i=0;i<n;i++)f->p[i]=I1a(S,f->m0);}static
E_*I1a(r1*S,A_*p){E_*f=i0a(S->L);f->m0=H0a(S);if(f->m0==NULL)f->m0=p;f->Z7=O7(S);f->e5=m7(S);f->d7=m7(S);f->J8=m7(S);f->Z1=m7(S);b5b(S,f);C2b(S,f);b0b(S,f);N9a(S,f);C5b(S,f);
#ifndef J7b
if(!D7(f))q_(S->L,"bad code in %s",S->b_);
#endif
return
f;}static
void
y9a(r1*S){const
char*s=l8;while(*s!=0&&O7a(S)==*s)++s;if(*s!=0)q_(S->L,"bad signature in %s",S->b_);}static
void
y5b(r1*S,int
s,const
char*r3){int
r=m7(S);if(r!=s)q_(S->L,"virtual machine mismatch in %s: ""size of %s is %d but read %d",S->b_,r3,s,r);}
#define j7(s,w) y5b(S,s,w)
#define V(v) v/16,v%16
static
void
d3b(r1*S){int
version;U
x,tx=Y5a;y9a(S);version=m7(S);if(version>x8a)q_(S->L,"%s too new: ""read version %d.%d; expected at most %d.%d",S->b_,V(version),V(x8a));if(version<C_b)q_(S->L,"%s too old: ""read version %d.%d; expected at least %d.%d",S->b_,V(version),V(C_b));S->j8a=(Q9()!=m7(S));j7(sizeof(int),"int");j7(sizeof(size_t),"size_t");j7(sizeof(j_),"Instruction");j7(P2a,"OP");j7(l5a,"A");j7(S_a,"B");j7(L_a,"C");j7(sizeof(U),"number");x=Z6a(S);if((long)x!=(long)tx)q_(S->L,"unknown number format in %s",S->b_);}static
E_*u4b(r1*S){d3b(S);return
I1a(S,NULL);}E_*Z5a(a*L,X8*Z,f6*p_){r1
S;const
char*s=I6b(Z);if(*s=='@'||*s=='=')S.b_=s+1;else
if(*s==l8[0])S.b_="binary string";else
S.b_=s;S.L=L;S.Z=Z;S.b=p_;return
u4b(&S);}int
Q9(void){int
x=1;return*(char*)&x;}
#define c0c
#ifndef g_a
#define g_a(s,n) sprintf((s),L7,(n))
#endif
#define h7a 100
const
E*I6(const
E*R1,E*n){U
num;if(W0(R1))return
R1;if(n1(R1)&&A3a(h9(R1),&num)){K1(n,num);return
n;}else
return
NULL;}int
q5(a*L,t_
R1){if(!W0(R1))return
0;else{char
s[32];g_a(s,r0(R1));C3(R1,M5(L,s));return
1;}}static
void
K4b(a*L){S_
F4=L->C6;if(F4&L6){if(L->c5a==0){X9(L);I4(L,T3a,-1);return;}}if(F4&n6){l0*ci=L->ci;E_*p=M0a(ci)->l.p;int
C5a=A5a(p,W9a(*ci->u.l.pc,p));if(!L->d3a){Z2a(L);return;}H(ci->g0&U6);if(W9a(*ci->u.l.pc,p)==0)ci->u.l.j2=*ci->u.l.pc;if(*ci->u.l.pc<=ci->u.l.j2||C5a!=A5a(p,W9a(ci->u.l.j2,p))){I4(L,E4a,C5a);ci=L->ci;}ci->u.l.j2=*ci->u.l.pc;}}static
void
V8(a*L,const
E*f,const
E*p1,const
E*p2){k0(L->X,f);k0(L->X+1,p1);k0(L->X+2,p2);K2(L,3);L->X+=3;u5(L,L->X-3,1);L->X--;}static
void
f9b(a*L,const
E*f,const
E*p1,const
E*p2,const
E*p3){k0(L->X,f);k0(L->X+1,p1);k0(L->X+2,p2);k0(L->X+3,p3);K2(L,4);L->X+=4;u5(L,L->X-4,0);}static
const
E*A0a(a*L,const
E*t,E*x_,int
R4){const
E*tm=X2a(L,i1(t)->r_,p0b);if(tm==NULL)return&B2;if(X1(tm)){V8(L,tm,t,x_);return
L->X;}else
return
o8(L,tm,x_,R4);}static
const
E*j9(a*L,const
E*t,E*x_,int
R4){const
E*tm=j3(L,t,p0b);if(H0(tm))d5(L,t,"index");if(X1(tm)){V8(L,tm,t,x_);return
L->X;}else
return
o8(L,tm,x_,R4);}const
E*o8(a*L,const
E*t,E*x_,int
R4){if(R4>h7a)q_(L,"loop in gettable");if(F2(t)){o0*h=i1(t);const
E*v=p7(h,x_);if(!H0(v))return
v;else
return
A0a(L,t,x_,R4+1);}else
return
j9(L,t,x_,R4+1);}void
q8(a*L,const
E*t,E*x_,t_
r6){const
E*tm;int
R4=0;do{if(F2(t)){o0*h=i1(t);E*B4b=h_a(L,h,x_);if(!H0(B4b)||(tm=X2a(L,h->r_,i6a))==NULL){p1a(B4b,r6);return;}}else
if(H0(tm=j3(L,t,i6a)))d5(L,t,"index");if(X1(tm)){f9b(L,tm,t,x_,r6);return;}t=tm;}while(++R4<=h7a);q_(L,"loop in settable");}static
int
e3a(a*L,const
E*p1,const
E*p2,t_
h0,TMS
O2){ptrdiff_t
H1=v4(L,h0);const
E*tm=j3(L,p1,O2);if(H0(tm))tm=j3(L,p2,O2);if(!X1(tm))return
0;V8(L,tm,p1,p2);h0=W2(L,H1);f1(h0,L->X);return
1;}static
const
E*L7a(a*L,o0*mt1,o0*mt2,TMS
O2){const
E*tm1=X2a(L,mt1,O2);const
E*tm2;if(tm1==NULL)return
NULL;if(mt1==mt2)return
tm1;tm2=X2a(L,mt2,O2);if(tm2==NULL)return
NULL;if(u3(tm1,tm2))return
tm1;return
NULL;}static
int
E1a(a*L,const
E*p1,const
E*p2,TMS
O2){const
E*tm1=j3(L,p1,O2);const
E*tm2;if(H0(tm1))return-1;tm2=j3(L,p2,O2);if(!u3(tm1,tm2))return-1;V8(L,tm1,p1,p2);return!d0a(L->X);}static
int
s6a(const
A_*O,const
A_*rs){const
char*l=C5(O);size_t
ll=O->q6.E1;const
char*r=C5(rs);size_t
lr=rs->q6.E1;for(;;){int
Y6=strcoll(l,r);if(Y6!=0)return
Y6;else{size_t
E1=strlen(l);if(E1==lr)return(E1==ll)?0:1;else
if(E1==ll)return-1;E1++;l+=E1;ll-=E1;r+=E1;lr-=E1;}}}int
o0a(a*L,const
E*l,const
E*r){int
h0;if(T0(l)!=T0(r))return
A5(L,l,r);else
if(W0(l))return
r0(l)<r0(r);else
if(n1(l))return
s6a(k2(l),k2(r))<0;else
if((h0=E1a(L,l,r,X6b))!=-1)return
h0;return
A5(L,l,r);}static
int
l8a(a*L,const
E*l,const
E*r){int
h0;if(T0(l)!=T0(r))return
A5(L,l,r);else
if(W0(l))return
r0(l)<=r0(r);else
if(n1(l))return
s6a(k2(l),k2(r))<=0;else
if((h0=E1a(L,l,r,K9b))!=-1)return
h0;else
if((h0=E1a(L,r,l,X6b))!=-1)return!h0;return
A5(L,l,r);}int
W3a(a*L,const
E*t1,const
E*t2){const
E*tm;H(T0(t1)==T0(t2));switch(T0(t1)){case
P5:return
1;case
N1:return
r0(t1)==r0(t2);case
f5:return
R2a(t1)==R2a(t2);case
I1:return
D2a(t1)==D2a(t2);case
c1:{if(T_a(t1)==T_a(t2))return
1;tm=L7a(L,T_a(t1)->uv.r_,T_a(t2)->uv.r_,A2b);break;}case
H_:{if(i1(t1)==i1(t2))return
1;tm=L7a(L,i1(t1)->r_,i1(t2)->r_,A2b);break;}default:return
H7(t1)==H7(t2);}if(tm==NULL)return
0;V8(L,tm,t1,t2);return!d0a(L->X);}void
u_a(a*L,int
y0a,int
I2){do{t_
X=L->k_+I2+1;int
n=2;if(!C6a(L,X-2)||!C6a(L,X-1)){if(!e3a(L,X-2,X-1,X-2,i4b))g1a(L,X-2,X-1);}else
if(k2(X-1)->q6.E1>0){h2
tl=g_(h2,k2(X-1)->q6.E1)+g_(h2,k2(X-2)->q6.E1);char*b0;int
i;while(n<y0a&&C6a(L,X-n-1)){tl+=k2(X-n-1)->q6.E1;n++;}if(tl>N8a)q_(L,"string size overflow");b0=N7(L,&G(L)->p_,tl);tl=0;for(i=n;i>0;i--){size_t
l=k2(X-i)->q6.E1;memcpy(b0+tl,h9(X-i),l);tl+=l;}C3(X-n,S2(L,b0,tl));}y0a-=n-1;I2-=n-1;}while(y0a>1);}static
void
g7a(a*L,t_
ra,const
E*rb,const
E*rc,TMS
op){E
c_c,b_c;const
E*b,*c;if((b=I6(rb,&c_c))!=NULL&&(c=I6(rc,&b_c))!=NULL){switch(op){case
o4b:K1(ra,r0(b)+r0(c));break;case
I4b:K1(ra,r0(b)-r0(c));break;case
F4b:K1(ra,r0(b)*r0(c));break;case
Z3b:K1(ra,r0(b)/r0(c));break;case
G_b:{const
E*f=o4(i1(gt(L)),G(L)->d5a[G_b]);ptrdiff_t
h0=v4(L,ra);if(!X1(f))q_(L,"`__pow' (`^' operator) is not a function");V8(L,f,b,c);ra=W2(L,h0);f1(ra,L->X);break;}default:H(0);break;}}else
if(!e3a(L,rb,rc,ra,op))d9(L,rb,rc);}
#define i4a(L,c) {if(!(c))return 0;}
#define RA(i) (k_+w3(i))
#define XRA(i) (L->k_+w3(i))
#define RB(i) (k_+a2(i))
#define RKB(i) ((a2(i)<q2)?RB(i):k+a2(i)-q2)
#define RC(i) (k_+X2(i))
#define RKC(i) ((X2(i)<q2)?RC(i):k+X2(i)-q2)
#define KBx(i) (k+v7(i))
#define O_a(pc,i) ((pc)+=(i))
t_
o6(a*L){C1a*cl;E*k;const
j_*pc;z3b:if(L->C6&q7){L->ci->u.l.pc=&pc;I4(L,y1a,-1);}r6b:L->ci->u.l.pc=&pc;H(L->ci->g0==b3||L->ci->g0==(b3|F9));L->ci->g0=U6;pc=L->ci->u.l.j2;cl=&A2(L->k_-1)->l;k=cl->p->k;for(;;){const
j_
i=*pc++;t_
k_,ra;if((L->C6&(n6|L6))&&(--L->c5a==0||L->C6&n6)){K4b(L);if(L->ci->g0&u8){L->ci->u.l.j2=pc-1;L->ci->g0=u8|b3;return
NULL;}}k_=L->k_;ra=RA(i);H(L->ci->g0&U6);H(k_==L->ci->k_);H(L->X<=L->l_+L->E2&&L->X>=k_);H(L->X==L->ci->X||V_(i)==D4||V_(i)==W4||V_(i)==X4||V_(i)==a8);switch(V_(i)){case
S8:{f1(ra,RB(i));break;}case
M3a:{k0(ra,KBx(i));break;}case
f8:{X1a(ra,a2(i));if(X2(i))pc++;break;}case
v9:{E*rb=RB(i);do{R_(rb--);}while(rb>=ra);break;}case
J5:{int
b=a2(i);k0(ra,cl->P1a[b]->v);break;}case
z7:{E*rb=KBx(i);const
E*v;H(n1(rb)&&F2(&cl->g));v=o4(i1(&cl->g),k2(rb));if(!H0(v)){k0(ra,v);}else
k0(XRA(i),A0a(L,&cl->g,rb,0));break;}case
x_a:{t_
rb=RB(i);E*rc=RKC(i);if(F2(rb)){const
E*v=p7(i1(rb),rc);if(!H0(v)){k0(ra,v);}else
k0(XRA(i),A0a(L,rb,rc,0));}else
k0(XRA(i),j9(L,rb,rc,0));break;}case
J9:{H(n1(KBx(i))&&F2(&cl->g));q8(L,&cl->g,KBx(i),ra);break;}case
p_a:{int
b=a2(i);E9(cl->P1a[b]->v,ra);break;}case
D_a:{q8(L,ra,RKB(i),RKC(i));break;}case
t2a:{int
b=a2(i);b=q4b(b);s6(ra,w7(L,b,X2(i)));z1(L);break;}case
C2a:{t_
rb=RB(i);E*rc=RKC(i);i4a(L,n1(rc));f1(ra+1,rb);if(F2(rb)){const
E*v=o4(i1(rb),k2(rc));if(!H0(v)){k0(ra,v);}else
k0(XRA(i),A0a(L,rb,rc,0));}else
k0(XRA(i),j9(L,rb,rc,0));break;}case
k0b:{E*rb=RKB(i);E*rc=RKC(i);if(W0(rb)&&W0(rc)){K1(ra,r0(rb)+r0(rc));}else
g7a(L,ra,rb,rc,o4b);break;}case
W_b:{E*rb=RKB(i);E*rc=RKC(i);if(W0(rb)&&W0(rc)){K1(ra,r0(rb)-r0(rc));}else
g7a(L,ra,rb,rc,I4b);break;}case
r4b:{E*rb=RKB(i);E*rc=RKC(i);if(W0(rb)&&W0(rc)){K1(ra,r0(rb)*r0(rc));}else
g7a(L,ra,rb,rc,F4b);break;}case
B3b:{E*rb=RKB(i);E*rc=RKC(i);if(W0(rb)&&W0(rc)){K1(ra,r0(rb)/r0(rc));}else
g7a(L,ra,rb,rc,Z3b);break;}case
P3b:{g7a(L,ra,RKB(i),RKC(i),G_b);break;}case
A0b:{const
E*rb=RB(i);E
Y6;if(i1a(rb,&Y6)){K1(ra,-r0(rb));}else{R_(&Y6);if(!e3a(L,RB(i),&Y6,ra,m9b))d9(L,RB(i),&Y6);}break;}case
M4a:{int
h0=d0a(RB(i));X1a(ra,h0);break;}case
R_a:{int
b=a2(i);int
c=X2(i);u_a(L,c-b+1,c);k_=L->k_;f1(RA(i),k_+b);z1(L);break;}case
r5a:{O_a(pc,Q3(i));break;}case
b_b:{if(o0b(L,RKB(i),RKC(i))!=w3(i))pc++;else
O_a(pc,Q3(*pc)+1);break;}case
T9a:{if(o0a(L,RKB(i),RKC(i))!=w3(i))pc++;else
O_a(pc,Q3(*pc)+1);break;}case
V9a:{if(l8a(L,RKB(i),RKC(i))!=w3(i))pc++;else
O_a(pc,Q3(*pc)+1);break;}case
l_a:{E*rb=RB(i);if(d0a(rb)==X2(i))pc++;else{f1(ra,rb);O_a(pc,Q3(*pc)+1);}break;}case
D4:case
W4:{t_
D0;int
b=a2(i);int
z0;if(b!=0)L->X=ra+b;z0=X2(i)-1;D0=i7(L,ra);if(D0){if(D0>L->X){H(L->ci->g0==(K1a|u8));(L->ci-1)->u.l.j2=pc;(L->ci-1)->g0=b3;return
NULL;}b6(L,z0,D0);if(z0>=0)L->X=L->ci->X;}else{if(V_(i)==D4){(L->ci-1)->u.l.j2=pc;(L->ci-1)->g0=(b3|F9);}else{int
r9;k_=(L->ci-1)->k_;ra=RA(i);if(L->p6)S4(L,k_);for(r9=0;ra+r9<L->X;r9++)f1(k_+r9-1,ra+r9);(L->ci-1)->X=L->X=k_+r9;H(L->ci->g0&b3);(L->ci-1)->u.l.j2=L->ci->u.l.j2;(L->ci-1)->u.l.V_a++;(L->ci-1)->g0=b3;L->ci--;L->k_=L->ci->k_;}goto
z3b;}break;}case
X4:{l0*ci=L->ci-1;int
b=a2(i);if(b!=0)L->X=ra+b-1;H(L->ci->g0&U6);if(L->p6)S4(L,k_);L->ci->g0=b3;L->ci->u.l.j2=pc;if(!(ci->g0&F9)){H((ci->g0&K1a)||ci->u.l.pc!=&pc);return
ra;}else{int
z0;H(X1(ci->k_-1)&&(ci->g0&b3));H(V_(*(ci->u.l.j2-1))==D4);z0=X2(*(ci->u.l.j2-1))-1;b6(L,z0,ra);if(z0>=0)L->X=L->ci->X;goto
r6b;}}case
K0a:{U
e9,F_,N2;const
E*n4b=ra+1;const
E*T6b=ra+2;if(!W0(ra))q_(L,"`for' initial value must be a number");if(!i1a(n4b,ra+1))q_(L,"`for' limit must be a number");if(!i1a(T6b,ra+2))q_(L,"`for' step must be a number");e9=r0(T6b);F_=r0(ra)+e9;N2=r0(n4b);if(e9>0?F_<=N2:F_>=N2){O_a(pc,Q3(i));Y3b(ra,F_);}break;}case
y_a:{int
E6a=X2(i)+1;t_
cb=ra+E6a+2;f1(cb,ra);f1(cb+1,ra+1);f1(cb+2,ra+2);L->X=cb+3;u5(L,cb,E6a);L->X=L->ci->X;ra=XRA(i)+2;cb=ra+E6a;do{E6a--;f1(ra+E6a,cb+E6a);}while(E6a>0);if(H0(ra))pc++;else
O_a(pc,Q3(*pc)+1);break;}case
y2a:{if(F2(ra)){f1(ra+1,ra);k0(ra,o4(i1(gt(L)),M5(L,"next")));}O_a(pc,Q3(i));break;}case
B6:case
a8:{int
bc;int
n;o0*h;i4a(L,F2(ra));h=i1(ra);bc=v7(i);if(V_(i)==B6)n=(bc&(P4-1))+1;else{n=L->X-ra-1;L->X=L->ci->X;}bc&=~(P4-1);for(;n>0;n--)p1a(i8(L,h,bc+n),ra+n);break;}case
I3a:{S4(L,ra);break;}case
K9:{E_*p;z2*ncl;int
nup,j;p=cl->p->p[v7(i)];nup=p->e5;ncl=D8(L,nup,&cl->g);ncl->l.p=p;for(j=0;j<nup;j++,pc++){if(V_(*pc)==J5)ncl->l.P1a[j]=cl->P1a[a2(*pc)];else{H(V_(*pc)==S8);ncl->l.P1a[j]=H2a(L,k_+a2(*pc));}}x0a(ra,ncl);z1(L);break;}}}}
#define X_c
int
o2a(X8*z){size_t
W;const
char*p_=z->a0a(NULL,z->a3,&W);if(p_==NULL||W==0)return
EOZ;z->n=W-1;z->p=p_;return
S6a(*(z->p++));}int
L2a(X8*z){if(z->n==0){int
c=o2a(z);if(c==EOZ)return
c;z->n++;z->p--;}return
S6a(*z->p);}void
U8a(X8*z,D5
a0a,void*a3,const
char*b_){z->a0a=a0a;z->a3=a3;z->b_=b_;z->n=0;z->p=NULL;}size_t
G8a(X8*z,void*b,size_t
n){while(n){size_t
m;if(z->n==0){if(o2a(z)==EOZ)return
n;else{++z->n;--z->p;}}m=(n<=z->n)?n:z->n;memcpy(b,z->p,m);z->n-=m;z->p+=m;b=(char*)b+m;n-=m;}return
0;}char*N7(a*L,f6*p_,size_t
n){if(n>p_->F8){if(n<p8)n=p8;G0(L,p_->b0,p_->F8,n,char);p_->F8=n;}return
p_->b0;}
