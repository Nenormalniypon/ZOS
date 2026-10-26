-- ZOS setup: download metadata first, show setup, then fetch only selected core files.
local args={...}
local BASE=args[1] or "https://raw.githubusercontent.com/Nenormalniypon/ZOS/main/"
assert(BASE:match("^https://") and not BASE:find("[%s?#]"),"HTTPS repository URL required")
if BASE:sub(-1)~="/" then BASE=BASE.."/" end
local component=require("component")
local computer=require("computer")
local fs=require("filesystem")
assert(component.isAvailable("internet"),"Internet card required")
local roots={};local ROOT=args[2]
for i=1,100 do
 local path=i==1 and "/home/ZOS-download/" or "/home/ZOS-download-"..i.."/"
 if fs.exists(path) and fs.isDirectory(path) then roots[#roots+1]=path;if not args[2] then ROOT=path end end
end
ROOT=ROOT or "/home/ZOS-download/"
if ROOT:sub(-1)~="/" then ROOT=ROOT.."/" end
local function mkdir(path)
 if fs.exists(path) then assert(fs.isDirectory(path),"Not a directory: "..path)
 else local ok,why=fs.makeDirectory(path);assert(ok,why) end
end
local function metadata(path)
 local url=BASE..path
 local conn=assert(component.internet.request(url));local out
 local ok,why=xpcall(function()
  local deadline=computer.uptime()+60
  while true do
   local ready,reason=conn.finishConnect();if ready then break end
   assert(not reason,reason);assert(computer.uptime()<deadline,"Connection timeout");os.sleep(0.05)
  end
  assert(conn.response()==200,"Cannot download setup metadata: "..path)
  local dest=ROOT..path;mkdir(fs.path(dest));out=assert(io.open(dest..".part","wb"))
  while true do
   assert(computer.uptime()<deadline,"Metadata timeout")
   local chunk,reason=conn.read(8192);if not chunk then assert(not reason,reason);break end
   assert(out:write(chunk));os.sleep(0)
  end
  assert(out:close());out=nil
  if fs.exists(dest) then assert(not fs.isDirectory(dest));assert(fs.remove(dest)) end
  assert(fs.rename(dest..".part",dest))
 end,debug.traceback)
 if out then out:close() end;conn.close();assert(ok,why)
end
print("ZOS: loading setup only. Applications will NOT be downloaded yet.")
print("Reusing download folder: "..ROOT)
for _,path in ipairs({"Installer/Manifest.lua","Installer/install.lua","system/Libraries/ZOSDownload.lua","NOTICE.md"}) do metadata(path) end
local h=assert(io.open(ROOT.."Installer/Manifest.lua","rb"));local text=h:read("*a");h:close()
local manifest=assert(load(text,"=manifest","t",{}))()
local downloader=assert(loadfile(ROOT.."system/Libraries/ZOSDownload.lua"))()
local client=downloader.new({fs=fs,open=io.open,component=component,computer=computer,sleep=os.sleep,base=BASE,commit=manifest.mineosCommit})
local context={zosBase=BASE,ensure=function(info)
 return client.ensure(info,ROOT.."system/"..info.path,roots)
end}
-- Read source license before setup; never download application files here.
for _,info in ipairs(manifest.files) do if info.path=="LICENSE" then context.ensure(info);break end end
local installer=assert(loadfile(ROOT.."Installer/install.lua"))
local ok,why=installer(ROOT,context)
assert(ok,why or "Setup did not complete")
