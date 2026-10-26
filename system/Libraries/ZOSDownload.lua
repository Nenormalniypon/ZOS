-- Shared OpenOS/MineOS downloader. Atomic files, integrity checks and cache reuse.
local module={}
local COMMIT="fb6c529e4d16198ad37dcc538ada99754294a456"
local function safe(path)
 assert(type(path)=="string" and path~="" and path:sub(1,1)~="/" and not path:find("..",1,true) and not path:find("[\r\n\\]"),"Unsafe path")
 return path
end
local function decode64(data)
 data=data:gsub("%s","");assert(#data%4==0,"Invalid Base64")
 local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";local out={}
 for i=1,#data,4 do
  local n={};local c={}
  for j=1,4 do c[j]=data:sub(i+j-1,i+j-1)
   if c[j]=="=" then assert(i+3==#data and j>=3,"Invalid padding");n[j]=0
   else n[j]=assert(alphabet:find(c[j],1,true),"Invalid Base64 character")-1 end
  end
  assert(c[3]~="=" or c[4]=="=","Invalid padding")
  local v=n[1]*262144+n[2]*4096+n[3]*64+n[4]
  out[#out+1]=string.char(math.floor(v/65536)%256)
  if c[3]~="=" then out[#out+1]=string.char(math.floor(v/256)%256) end
  if c[4]~="=" then out[#out+1]=string.char(v%256) end
 end
 return table.concat(out)
end
function module.new(o)
 local fs,open,component,computer=o.fs,o.open,o.component,o.computer
 local sleep=o.sleep or function()end
 local base=o.base or "https://raw.githubusercontent.com/Nenormalniypon/ZOS/main/"
 if base:sub(-1)~="/" then base=base.."/" end
 assert(base:match("^https://"),"HTTPS required")
 local commit=o.commit or COMMIT
 assert(#commit==40 and commit:match("^%x+$"),"Invalid MineOS commit")
 local upstream="https://raw.githubusercontent.com/IgorTimofeev/MineOS/"..commit.."/"
 local client={}
 local function mkdir(path)
  if fs.exists(path) then assert(fs.isDirectory(path),"Not a directory: "..path)
  else local ok,why=fs.makeDirectory(path);assert(ok,why) end
 end
 function client.valid(path,info)
  if not fs.exists(path) or fs.isDirectory(path) then return false end
  local h=open(path,"rb");if not h then return false end
  local a,b,size=1,0,0
  while true do local s=h:read(8192);if not s then break end
   size=size+#s;for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
  end
  h:close();return size==info.size and b*65536+a==info.adler
 end
 local function commitFile(part,path)
  if fs.exists(path) then assert(not fs.isDirectory(path),"Destination is a directory");assert(fs.remove(path)) end
  assert(fs.rename(part,path))
 end
 function client.copy(source,dest,info)
  mkdir(fs.path(dest));local input=assert(open(source,"rb"));local output=assert(open(dest..".part","wb"))
  local ok,why=pcall(function()
   while true do local s=input:read(8192);if not s then break end;assert(output:write(s)) end
  end)
  input:close();output:close();assert(ok,why)
  assert(client.valid(dest..".part",info),"Cache copy failed integrity check")
  commitFile(dest..".part",dest)
 end
 function client.download(info,dest)
  safe(info.path)
  if client.valid(dest,info) then return "cached" end
  local path,host,encoding
  if info.source=="mineos" then path=info.upstreamPath or info.path;host=upstream
  else path=info.remotePath or ("system/"..info.path);host=base;encoding=info.encoding end
  safe(path);assert(not encoding or encoding=="base64","Unknown encoding")
  local url=host..path:gsub("([^%w%-%_%.%~/])",function(c)return string.format("%%%02X",c:byte())end)
  local address=assert(component.list("internet")(),"Internet card required")
  local connection=assert(component.proxy(address).request(url))
  local output
  local ok,why=xpcall(function()
   local deadline=computer.uptime()+90
   while true do
    local connected,reason=connection.finishConnect()
    if connected then break end
    assert(not reason,reason);assert(computer.uptime()<deadline,"Connection timeout");sleep(0.05)
   end
   local status=connection.response();assert(status==200,"HTTP "..tostring(status)..": "..url)
   mkdir(fs.path(dest));output=assert(open(dest..".part","wb"))
   local encoded,bytes={},0
   while true do
    assert(computer.uptime()<deadline,"Download timeout: "..path)
    local s,reason=connection.read(8192)
    if not s then assert(not reason,reason);break end
    if s~="" then
     if encoding then bytes=bytes+#s;assert(bytes<=1024*1024,"Asset too large");encoded[#encoded+1]=s
     else assert(output:write(s)) end
    end
    sleep(0)
   end
   if encoding then assert(output:write(decode64(table.concat(encoded)))) end
  end,debug.traceback)
  if output then output:close() end
  connection.close();assert(ok,why)
  assert(client.valid(dest..".part",info),"Downloaded file failed integrity check: "..info.path)
  commitFile(dest..".part",dest)
  return "downloaded"
 end
 function client.ensure(info,dest,cacheRoots)
  if client.valid(dest,info) then return "cached" end
  for _,root in ipairs(cacheRoots or {}) do
   local candidate=root.."system/"..safe(info.path)
   if candidate~=dest and client.valid(candidate,info) then client.copy(candidate,dest,info);return "reused" end
  end
  return client.download(info,dest)
 end
 return client
end
return module
