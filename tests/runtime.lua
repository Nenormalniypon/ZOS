local hostIO,hostRequire,hostLoadfile,hostDofile=io,require,loadfile,dofile
local function file(path)
 local h=assert(hostIO.open(path,"rb"));local s=h:read("*a");h:close();return s
end
local manifest=hostDofile(ROOT.."/Installer/Manifest.lua")
local function adler(s)
 local a,b=1,0
 for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
 return b*65536+a
end
for _,v in ipairs(manifest.files) do
 local s=file(ROOT.."/system/"..v.path)
 assert(#s==v.size and adler(s)==v.adler,v.path)
end
print("PASS: manifest sizes and Adler-32 for every system file")
assert(#file(ROOT.."/system/EFI/ZOS.lua")<=4096)
print("PASS: ZOS EFI fits a 4096-byte EEPROM")
local function canonical(p)
 p=p:gsub("/+","/")
 if p~="/" then p=p:gsub("/$","") end
 return p
end
local function newDisk(address,readOnly)
 local entries={["/"]=true}
 local handles={};local n=0
 local disk={address=address,_entries=entries}
 function disk.exists(p) return entries[canonical(p)]~=nil end
 function disk.isDirectory(p)return entries[canonical(p)]==true end
 function disk.makeDirectory(p)
  local cur=""
  for part in p:gmatch("[^/]+") do
   cur=cur.."/"..part
   if entries[cur] and entries[cur]~=true then return false,"File exists" end
   entries[cur]=true
  end
  return true
 end
 function disk.list(p)
  p=canonical(p);local prefix=p=="/" and "/" or p.."/";local result={}
  for k,v in pairs(entries) do
   if k~=p and k:sub(1,#prefix)==prefix then
    local tail=k:sub(#prefix+1)
    if not tail:find("/",1,true) then result[#result+1]=tail..(v==true and "/" or "") end
   end
  end
  table.sort(result);return result
 end
 function disk.open(p,mode)
  p=canonical(p)
  if mode=="rb" or mode=="r" then if type(entries[p])~="string" then return nil,"Not found" end
  else entries[p]="" end
  n=n+1;handles[n]={path=p,pos=1};return n
 end
 function disk.read(h,count)
  local f=assert(handles[h]);local data=entries[f.path]
  if f.pos>#data then return nil end
  local chunk=data:sub(f.pos,f.pos+count-1);f.pos=f.pos+#chunk;return chunk
 end
 function disk.write(h,s)
  local f=assert(handles[h]);entries[f.path]=entries[f.path]..s;return true
 end
 function disk.close(h)handles[h]=nil;return true end
 function disk.rename(a,b)
  a,b=canonical(a),canonical(b)
  if not entries[a] then return false,"Missing source: "..a end
  if entries[b] then return false,"Destination exists: "..b end
  local moves={}
  for k,v in pairs(entries) do if k==a or k:sub(1,#a+1)==a.."/" then moves[k]=v end end
  for k,v in pairs(moves) do entries[b..k:sub(#a+1)]=v;entries[k]=nil end
  return true
 end
 function disk.remove(p)
  p=canonical(p)
  for k in pairs(entries) do if k==p or k:sub(1,#p+1)==p.."/" then entries[k]=nil end end
  return true
 end
 function disk.spaceTotal()return 8*1024*1024 end
 function disk.spaceUsed()
  local n=0;for _,v in pairs(entries) do if type(v)=="string" then n=n+#v end end;return n
 end
 function disk.isReadOnly()return readOnly or false end
 function disk.getLabel()return disk.label or "Test disk" end
 function disk.setLabel(s)disk.label=s;return true end
 return disk
end
local modules={}
local source=newDisk("source")
local target=newDisk("target")
local existing=newDisk("existing")
existing._entries["/init.lua"]="DO NOT MODIFY"
local raw={source=source,target=target,existing=existing}
local time,keys=0,{}
local oldFirmware,oldData,oldLabel="original-firmware","existing","Original EFI"
local eeprom={code=oldFirmware,data=oldData,label=oldLabel}
function eeprom.get()return eeprom.code end
function eeprom.set(s)eeprom.code=s;return true end
function eeprom.getData()return eeprom.data end
function eeprom.setData(s)eeprom.data=s;return true end
function eeprom.getLabel()return eeprom.label end
function eeprom.setLabel(s)eeprom.label=s;return true end
function eeprom.getSize()return 4096 end
function eeprom.getChecksum()return "abcd1234" end
local gpu={}
function gpu.getBackground()return 0 end
function gpu.getForeground()return 0xFFFFFF end
function gpu.getResolution()return 160,50 end
function gpu.maxDepth()return 8 end
function gpu.setBackground()end
function gpu.setForeground()end
function gpu.fill()end
function gpu.set()end
function gpu.bind()end
local component={gpu=gpu,eeprom=eeprom}
function component.list(kind)
 local items=kind=="filesystem" and {"existing","source","target"} or kind=="eeprom" and {"eeprom"} or kind=="gpu" and {"gpu"} or kind=="screen" and {"screen"} or {}
 local i=0;return function()i=i+1;return items[i]end
end
function component.proxy(a)if a=="eeprom" then return eeprom elseif a=="gpu" then return gpu end;return assert(raw[a],a) end
function component.type(a)return raw[a] and "filesystem" or nil end
function component.isAvailable(kind)return kind=="eeprom" end
local computer={}
function computer.totalMemory()return 4*1024*1024 end
function computer.tmpAddress()return "tmp" end
function computer.uptime()return time end
function computer.pullSignal(timeout)
 time=time+(timeout or 0.1)
 local key=table.remove(keys,1)
 if key then return "key_down","keyboard",0,key end
 assert(timeout,"Unexpected blocking signal wait")
 return nil
end
function computer.shutdown()error("TEST_SHUTDOWN",0)end
local pathFS={}
function pathFS.path(p)return p:match("^(.*/)[^/]*$") or "/" end
function pathFS.canonical(p)return canonical(p) end
function pathFS.get()return source end
function pathFS.makeDirectory()return true end
local serialization={}
local function serialize(v)
 if type(v)=="table" then
  local out={"{"};for k,x in pairs(v) do out[#out+1]="["..serialize(k).."]="..serialize(x).."," end;out[#out+1]="}";return table.concat(out)
 elseif type(v)=="string" then return string.format("%q",v)
 else return tostring(v) end
end
serialization.serialize=serialize
local term={clear=function()end,setCursor=function()end,read=function()return "Guest\n" end}
local event={pull=function()
 local key=assert(table.remove(keys,1),"Menu consumed more keys than expected")
 return "key_down","keyboard",0,key
end}
modules.component=component;modules.computer=computer;modules.filesystem=pathFS
modules.shell={getRunningProgram=function()return ROOT.."/Installer/install.lua"end}
modules.term=term;modules.event=event;modules.serialization=serialization
local backups={}
local fakeIO=setmetatable({},{__index=hostIO})
function fakeIO.open(path,mode)
 if path:find("EEPROM-backup-",1,true) then
  if mode=="wb" then
   backups[path]=""
   return {write=function(_,s)backups[path]=backups[path]..s;return true end,close=function()return true end}
  else
   return {read=function()return backups[path]end,close=function()return true end}
  end
 end
 return hostIO.open(path,mode)
end
local env=setmetatable({component=component,computer=computer,io=fakeIO,
 print=function()end,os=setmetatable({sleep=function()end},{__index=os}),
 require=function(name)return assert(modules[name],"Missing mock "..name)end},{__index=_G})
env._G=env
local function enter()keys[#keys+1]=28 end
for _=1,5 do enter() end -- English UI, English OS, selected languages, Hills, Lite
keys[#keys+1]=208;enter() -- license acknowledgement
enter() -- blank target disk (source/existing are excluded)
keys[#keys+1]=208;enter() -- install confirmation
keys[#keys+1]=208;enter() -- EFI confirmation
local installer=assert(load(file(ROOT.."/Installer/install.lua"),"=installer","t",env))
local ok,why=installer(ROOT)
assert(ok,why)
assert(#keys==0)
assert(target.exists("/OS.lua") and target.exists("/init.lua"))
assert(target._entries["/ZOS/Backup/EEPROM.lua"]==oldFirmware)
assert(target._entries["/ZOS/Backup/EEPROM-data.txt"]==oldData)
assert(eeprom.data=="target" and eeprom.label=="ZOS EFI")
assert(eeprom.code==file(ROOT.."/system/EFI/ZOS.lua"))
assert(existing._entries["/init.lua"]=="DO NOT MODIFY")
assert(not target.exists("/.zos-staging"))
local settings=assert(load("return "..target._entries["/Users/Guest/Settings.cfg"],"=settings","t",{}))()
assert(settings.theme=="ZOS Luna" and settings.localizationLanguage=="English")
assert(settings.interfaceWallpaperPath=="/Wallpapers/ZOS Hills.wlp/")
assert(not settings.interfaceTransparencyEnabled)
for _,item in ipairs(manifest.files) do
 if item.path:sub(1,10)=="Libraries/" then assert(target._entries["/"..item.path]==file(ROOT.."/system/"..item.path),item.path) end
end
assert(not target.exists("/Applications/3D Print.app"))
assert(not target.exists("/Localizations/Russian.lang"))
print("PASS: complete Lite install, defaults, language filtering, ALL libraries, existing disk preserved")
print("PASS: EEPROM backup in target + source, verified flash, boot-address assignment")
-- Test EFI boot and hotkeys without loading the real graphical OS.
local savedOS=target._entries["/OS.lua"]
local function efi(key,expectedSafe)
 time=0;keys=key and {key} or {};env.ZOS_SAFE_MODE=nil;env.BOOTED=nil
 target._entries["/OS.lua"]="BOOTED=true; assert((ZOS_SAFE_MODE or false)=="..tostring(expectedSafe)..")"
 assert(load(file(ROOT.."/system/EFI/ZOS.lua"),"=EFI","t",env))()
 assert(env.BOOTED)
end
efi(nil,false)
efi(66,true)
-- F2 opens selector, Down chooses target after existing disk, Enter boots.
time=0;keys={60,208,28};env.BOOTED=nil;env.ZOS_SAFE_MODE=nil;eeprom.data="existing"
target._entries["/OS.lua"]="BOOTED=true; assert(not ZOS_SAFE_MODE)"
assert(load(file(ROOT.."/system/EFI/ZOS.lua"),"=EFI","t",env))()
assert(env.BOOTED and eeprom.data=="target")
target._entries["/OS.lua"]=savedOS
print("PASS: EFI normal boot, F8 safe mode and F2 disk selection")
-- Package manager with an in-memory MineOS Filesystem adapter.
local disk=newDisk("packages")
local appFS={}
for _,name in ipairs({"exists","makeDirectory","rename","remove"}) do appFS[name]=disk[name] end
function appFS.path(p)return pathFS.path(p)end
function appFS.size(p)return #assert(disk._entries[canonical(p)])end
function appFS.open(p,mode)
 local id,why=disk.open(p,mode);if not id then return nil,why end
 local h={}
 function h:readString(n)return disk.read(id,n) end
 function h:readLine()
  local chars={}
  while true do local c=disk.read(id,1);if not c then return #chars>0 and table.concat(chars) or nil end
   if c=="\n" then return table.concat(chars) end;chars[#chars+1]=c end
 end
 function h:write(s)return disk.write(id,s)end
 function h:close()return disk.close(id)end
 return h
end
local pkgEnv=setmetatable({require=function(name)assert(name=="Filesystem");return appFS end},{__index=_G})
local packages=assert(load(file(ROOT.."/system/Libraries/ZOSPackages.lua"),"=packages","t",pkgEnv))()
for _,bad in ipairs({"../bad","/absolute","a/../b","a//b","a\\b","a/./b","a\nb","a/","a:b"}) do assert(not packages.validPath(bad),bad) end
for _,good in ipairs({"Main.lua","Images/Icon.pic","nested/a-b.txt"}) do assert(packages.validPath(good),good) end
disk._entries["/Hello.zpk"]=file(ROOT.."/examples/Hello.zpk")
local success,result=packages.install("/Hello.zpk");assert(success,result)
assert(disk._entries["/Applications/Hello.app/Main.lua"]==file(ROOT.."/examples/Hello.app/Main.lua"))
assert(not packages.install("/Hello.zpk"))
disk._entries["/evil.zpk"]="ZPK1\nEvil\n1\n../OS.lua\n4\nevil"
assert(not packages.install("/evil.zpk"));assert(not disk.exists("/OS.lua"))
disk._entries["/short.zpk"]="ZPK1\nShort\n1\nMain.lua\n100\nabc"
assert(not packages.install("/short.zpk"));assert(not disk.exists("/Applications/Short.app"))
print("PASS: ZPK install, overwrite refusal, path traversal rejection and truncated package rejection")
-- Second installation: Russian UI, all language packs, no wallpaper, Full apps.
target=newDisk("target");raw.target=target;eeprom.code=oldFirmware;eeprom.data=oldData;eeprom.label=oldLabel
keys={208,28, 28, 208,28, 208,208,28, 208,28, 208,28, 28, 208,28, 28}
ok,why=installer(ROOT);assert(ok,why);assert(#keys==0)
settings=assert(load("return "..target._entries["/Users/Guest/Settings.cfg"],"=settings","t",{}))()
assert(settings.localizationLanguage=="Russian" and not settings.interfaceWallpaperEnabled and not settings.interfaceWallpaperPath)
assert(target.exists("/Applications/3D Print.app/Main.lua") and target.exists("/Localizations/Japanese.lang"))
assert(eeprom.code==oldFirmware and eeprom.data==oldData)
print("PASS: Russian Full installation, all language packs, no wallpaper, no EEPROM flash")
-- No candidate disk: an occupied destination must never be touched.
target=newDisk("target");target._entries["/private.txt"]="keep";raw.target=target
keys={28,28,28,28,28,208,28}
local errors={};fakeIO.stderr={write=function(_,s)errors[#errors+1]=s end}
ok,why=installer(ROOT)
assert(not ok and tostring(why):find("No suitable empty HDD",1,true))
assert(target._entries["/private.txt"]=="keep" and not target.exists("/OS.lua"))
print("PASS: occupied destination disk is refused without modification")
-- EEPROM flash failure: system remains installed, original EEPROM is restored.
target=newDisk("target");raw.target=target;eeprom.code=oldFirmware;eeprom.data=oldData;eeprom.label=oldLabel
local realSet=eeprom.set;local failOnce=true
function eeprom.set(s)
 if failOnce then failOnce=false;error("Injected flash failure") end
 return realSet(s)
end
keys={28,28,28,28,28,208,28,28,208,28,208,28}
ok,why=installer(ROOT)
assert(not ok and tostring(why):find("Injected flash failure",1,true))
assert(eeprom.code==oldFirmware and eeprom.data==oldData and eeprom.label==oldLabel)
assert(target.exists("/OS.lua"))
eeprom.set=realSet
print("PASS: injected EEPROM flash failure rolls back firmware, label and boot data")
-- Shell behavior with deterministic GUI mocks.
local ws={width=160,height=50,children={}}
function ws:addChild(o)o.parent=self;self.children[#self.children+1]=o;return o end
function ws:draw()end
local windows={children={}}
local dock={}
local options={localizationLanguage="English"}
local launched={}
local sys={}
function sys.getUserSettings()return options end
function sys.getWorkspace()return ws end
function sys.getWindowsContainer()return windows end
function sys.getDockContainer()return dock end
function sys.updateResolution()end
function sys.updateDesktop()windows.height=49 end
function sys.execute(path)launched[#launched+1]=path end
function sys.getTime()return 0 end
function sys.applyThemeToContextMenu(m)return m end
local lastMenu
local function makeMenu()
 local m={items={}}
 function m:addItem(name)local item={name=name};self.items[#self.items+1]=item;return item end
 function m:addSubMenuItem(name)local item=makeMenu();item.name=name;self.items[#self.items+1]=item;return item end
 return m
end
local gui={}
function gui.object(x,y,w,h)return {x=x,y=y,localX=x,localY=y,width=w,height=h}end
function gui.addContextMenu()lastMenu=makeMenu();return lastMenu end
local drawCalls=0
local scr={drawRectangle=function()drawCalls=drawCalls+1 end,drawText=function()end}
local sf={}
function sf.name(p)return p:gsub("/$",""):match("([^/]+)$")end
function sf.hideExtension(p)return p:gsub("%.[^%.]+$","")end
function sf.list(p)if p=="/Applications/" then return {"One.app/","Two.app/"} else return {} end end
function sf.exists()return true end
local paths={user={applications="/Users/Guest/Applications/",home="/Users/Guest/"},system={applications="/Applications/",applicationFinder="Finder",applicationSettings="Settings",applicationAppMarket="Market"}}
local shellEnv=setmetatable({unicode={sub=string.sub},computer=computer},{__index=_G})
local zosShell=assert(load(file(ROOT.."/system/Libraries/ZOSShell.lua"),"=shell","t",shellEnv))()
zosShell.install(sys,gui,scr,sf,paths);sys.updateDesktop()
assert(dock.hidden and windows.height==46)
local bar=ws.children[#ws.children]
local function win(name)
 local w={titleLabel={text=name},hidden=false}
 function w:minimize()self.hidden=true end
 function w:focus()self.hidden=false;self.focused=true end
 return w
end
local a,b=win("First"),win("Second");windows.children={a,b}
bar.draw(bar);assert(#bar.hits==2 and drawCalls>0)
local hit=bar.hits[2];bar.eventHandler(ws,bar,"touch",nil,hit.x,bar.y+1,0);assert(b.hidden)
bar.eventHandler(ws,bar,"touch",nil,hit.x,bar.y+1,0);assert(not b.hidden and b.focused)
bar.eventHandler(ws,bar,"touch",nil,2,bar.y+1,0)
local apps=lastMenu.items[4];assert(apps.name=="All programs")
apps.items[1].onTouch();apps.items[2].onTouch()
assert(launched[1]=="/Applications/One.app/Main.lua" and launched[2]=="/Applications/Two.app/Main.lua")
options.localizationLanguage="Russian";bar.eventHandler(ws,bar,"touch",nil,2,bar.y+1,0)
assert(lastMenu.items[1].name=="Мои файлы")
ws.width=80;ws.height=25;sys.updateResolution();assert(bar.width==80 and bar.localY==23 and windows.height==21)
print("PASS: taskbar minimize/restore, Start menu callbacks, RU localization and resize")
-- Both procedural wallpapers must stay inside their rectangle.
for _,name in ipairs({"ZOS Hills","ZOS Teal"}) do
 local w={x=1,y=2,width=80,height=23}
 local s={drawRectangle=function(x,y,width,height)
  assert(x>=w.x and y>=w.y and x+width<=w.x+w.width and y+height<=w.y+w.height)
 end}
 local e=setmetatable({require=function()return s end},{__index=_G})
 assert(load(file(ROOT.."/system/Wallpapers/"..name..".wlp/Main.lua"),"=wallpaper","t",e))(ws,w)
 assert(w.zosStatic);w.draw(w)
end
print("PASS: static wallpaper drawing bounds at 80x25")
