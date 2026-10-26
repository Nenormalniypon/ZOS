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
local function fetch(path,destination)
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
  while true do
   assert(computer.uptime()<deadline,"Download timeout")
   local chunk,why=conn.read(8192)
   if not chunk then assert(not why,why);break end
   assert(out:write(chunk));os.sleep(0)
  end
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
 fetch("system/"..safe(file.path),ROOT.."system/"..file.path)
end
print("Downloaded. Read NOTICE.md and system/LICENSE before installing.")
assert(shell.execute(ROOT.."Installer/install.lua",nil,ROOT))
