-- ZOS 0.1.0 mkdir hotfix: https://github.com/Nenormalniypon/ZOS
-- Paste this entire file into Pastebin. Run: pastebin run YOUR_ID
local args={...}
local BASE=args[1] or "https://raw.githubusercontent.com/Nenormalniypon/ZOS/main/"
assert(BASE:match("^https://") and not BASE:find("[%s?#]"),
 "Usage: pastebin run YOUR_ID https://HOST/ZOS-0.1.0/")
if BASE:sub(-1)~="/" then BASE=BASE.."/" end
local component=require("component")
local fs=require("filesystem")
local shell=require("shell")
local computer=require("computer")
assert(component.isAvailable("internet"),"Internet card required")
local ROOT="/home/ZOS-download/"
-- Preserve all previous attempts; choose an unused download directory.
local attempt=1
while fs.exists(ROOT) do
 attempt=attempt+1
 ROOT="/home/ZOS-download-"..attempt.."/"
end
local function ensureDirectory(path)
 if fs.exists(path) then
  assert(fs.isDirectory(path),"Not a directory: "..path)
 else
  local ok,reason=fs.makeDirectory(path)
  assert(ok,reason or ("Cannot create directory: "..path))
 end
end
local function safe(path)
 assert(type(path)=="string" and path:sub(1,1)~="/" and not path:find("..",1,true)
  and not path:find("[\r\n\\]"),"Unsafe download path")
 return path
end
-- Base64 is a repository transport only; installed files retain their original bytes.
local function decodeBase64(data)
 data=data:gsub("%s", "")
 assert(#data%4==0,"Invalid Base64 length")
 local alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
 local out={}
 for i=1,#data,4 do
  local chars={data:sub(i,i),data:sub(i+1,i+1),data:sub(i+2,i+2),data:sub(i+3,i+3)}
  local n={}
  for j=1,4 do
   if chars[j]=="=" then
    assert(i+3==#data and j>=3,"Invalid Base64 padding");n[j]=0
   else
    local index=alphabet:find(chars[j],1,true)
    assert(index,"Invalid Base64 character");n[j]=index-1
   end
  end
  assert(chars[3]~="=" or chars[4]=="=","Invalid Base64 padding")
  local value=n[1]*262144+n[2]*4096+n[3]*64+n[4]
  out[#out+1]=string.char(math.floor(value/65536)%256)
  if chars[3]~="=" then out[#out+1]=string.char(math.floor(value/256)%256) end
  if chars[4]~="=" then out[#out+1]=string.char(value%256) end
 end
 return table.concat(out)
end
local function fetch(path,destination,encoding)
 assert(not encoding or encoding=="base64","Unknown repository encoding")
 path=safe(path)
 local url=BASE..path:gsub("([^%w%-%_%.%~/])",function(c) return string.format("%%%02X",c:byte()) end)
 local conn=assert(component.internet.request(url))
 local out
 local ok,reason=xpcall(function()
  local deadline=computer.uptime()+60
  while true do
   local connected,why=conn.finishConnect()
   if connected then break end
   assert(not why,why)
   assert(computer.uptime()<deadline,"Connection timeout")
   os.sleep(0.05)
  end
  local status=conn.response()
  assert(status==200,"HTTP "..tostring(status)..": "..path)
  ensureDirectory(fs.path(destination))
  out=assert(io.open(destination,"wb"))
  local encoded,encodedSize={},0
  while true do
   assert(computer.uptime()<deadline,"Download timeout")
   local chunk,why=conn.read(8192)
   if not chunk then assert(not why,why);break end
   if encoding then
    encodedSize=encodedSize+#chunk;assert(encodedSize<=1024*1024,"Encoded asset too large")
    encoded[#encoded+1]=chunk
   else assert(out:write(chunk)) end
   os.sleep(0)
  end
  if encoding then assert(out:write(decodeBase64(table.concat(encoded)))) end
 end,debug.traceback)
 if out then out:close() end
 conn.close()
 assert(ok,reason)
end
print("ZOS: downloading from your trusted HTTPS distribution host.")
print("Destination: "..ROOT)
fetch("Installer/Manifest.lua",ROOT.."Installer/Manifest.lua")
local h=assert(io.open(ROOT.."Installer/Manifest.lua","rb"));local data=h:read("*a");h:close()
local manifest=assert(load(data,"=manifest","t",{}))()
local source=fs.get(ROOT)
local required=0
for _,item in ipairs(manifest.files) do required=required+item.size end
assert(source.spaceTotal()-source.spaceUsed()>required+256*1024,"Not enough space on OpenOS source disk")
for _,path in ipairs({"Installer/install.lua","NOTICE.md","README-RU.md"}) do fetch(path,ROOT..path) end
for i,file in ipairs(manifest.files) do
 print(i.."/"..#manifest.files.." "..file.path)
 fetch("system/"..safe(file.remotePath or file.path),ROOT.."system/"..safe(file.path),file.encoding)
end
print("Downloaded. Read NOTICE.md and system/LICENSE before installing.")
assert(shell.execute(ROOT.."Installer/install.lua",nil,ROOT))
