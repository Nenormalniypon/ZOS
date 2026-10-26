-- ZOS EFI 0.1.0. F2: disk menu; F8: safe mode. No formatting or network boot.
local list,proxy=component.list,component.proxy
local e=proxy(list("eeprom")())
local ga,sa=list("gpu")(),list("screen")()
local g=ga and proxy(ga)
local w,h=80,25
if g and sa then g.bind(sa); w,h=g.getResolution() end
local function text(y,s)
 if g and sa then g.setForeground(0xFFFFFF);g.set(2,y,s:sub(1,w-2)) end
end
local function clear()
 if g and sa then g.setBackground(0);g.fill(1,1,w,h," ") end
end
local drives={}
for a in list("filesystem") do
 local f=proxy(a)
 if f.exists("/OS.lua") or f.exists("/init.lua") then drives[#drives+1]=a end
end
table.sort(drives)
local chosen=e.getData()
local function menu()
 clear();text(2,"ZOS EFI | Select boot disk (Up/Down, Enter, Esc)")
 local i=1
 for n,a in ipairs(drives) do if a==chosen then i=n end end
 while #drives>0 do
  for n,a in ipairs(drives) do
   local f=proxy(a)
   text(4+n,((n==i) and "> " or "  ")..(f.getLabel() or "Disk").."  "..a:sub(1,8).."        ")
  end
  local ev,_,_,key=computer.pullSignal()
  if ev=="key_down" then
   if key==200 then i=math.max(1,i-1)
   elseif key==208 then i=math.min(#drives,i+1)
   elseif key==28 then chosen=drives[i];e.setData(chosen);return
   elseif key==1 then return end
  end
 end
end
clear();text(2,"ZOS EFI 0.1.0");text(4,"F2: boot menu   F8: safe mode")
local deadline=computer.uptime()+1.2
while computer.uptime()<deadline do
 local ev,_,_,key=computer.pullSignal(math.max(0,deadline-computer.uptime()))
 if ev=="key_down" and key==60 then menu();break end
 if ev=="key_down" and key==66 then _G.ZOS_SAFE_MODE=true;break end
end
local function boot(a)
 if not a or not component.type(a) then return false,"Disk missing" end
 local f=proxy(a)
 local path=f.exists("/OS.lua") and "/OS.lua" or "/init.lua"
 local handle,reason=f.open(path,"rb")
 if not handle then return false,reason end
 local chunks={}
 while true do
  local chunk,why=f.read(handle,4096)
  if not chunk then f.close(handle);if why then return false,why end;break end
  chunks[#chunks+1]=chunk
 end
 local fn,why=load(table.concat(chunks),"="..path,"t",_G)
 if not fn then return false,why end
 e.setData(a)
 computer.getBootAddress=e.getData
 computer.setBootAddress=e.setData
 return xpcall(fn,debug.traceback)
end
if not chosen or chosen=="" then chosen=drives[1] end
local ok,reason=boot(chosen)
if not ok then
 clear();text(2,"ZOS EFI: boot failed (Enter: choose disk; R: restart)")
 local y=4
 for line in tostring(reason):gmatch("[^\n]+") do if y<h then text(y,line);y=y+1 end end
 while true do
  local ev,char,key
  ev,_,char,key=computer.pullSignal()
  if ev=="key_down" and key==19 then computer.shutdown(true) end
  if ev=="key_down" and key==28 then
   menu();local success,why=boot(chosen)
   if success then break end
   text(h-1,tostring(why))
  end
 end
end
