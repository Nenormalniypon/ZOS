-- Run on OpenOS with an extracted ZOS distribution on a separate source disk.
local component=require("component")
local computer=require("computer")
local fs=require("filesystem")
local shell=require("shell")
local term=require("term")
local event=require("event")
local serialization=require("serialization")
local gpu=component.gpu
local args={...}
local script=shell.getRunningProgram()
local root=args[1] or (fs.path(fs.path(script):gsub("/$","")))
root=fs.canonical(root).."/"
local mf=assert(io.open(root.."Installer/Manifest.lua","r"),"Distribution missing; pass its folder as argument")
local manifestText=mf:read("*a");mf:close()
local manifest=assert(load(manifestText,"=ZOS manifest","t",{}))()
local oldBG,oldFG=gpu.getBackground(),gpu.getForeground()
local oldX,oldY=gpu.getResolution()
local ru=false
local function tr(a,b) return ru and a or b end
local function screen(title)
 gpu.setBackground(0x0000AA);gpu.setForeground(0xFFFFFF);term.clear();term.setCursor(2,2)
 print("ZOS 0.1.0 Setup | "..title)
 print(string.rep("=",math.min(oldX-4,76)))
end
local function menu(title,items,selected)
 selected=selected or 1
 local page=1
 while true do
  screen(title)
  page=math.floor((selected-1)/math.max(1,oldY-9))
  local span=math.max(1,oldY-9)
  for i=page*span+1,math.min(#items,(page+1)*span) do
   gpu.setForeground(i==selected and 0xFFFF55 or 0xFFFFFF)
   print((i==selected and " > " or "   ")..items[i])
  end
  gpu.setForeground(0xAAAAAA)
  print("\n"..tr("Стрелки: выбор | Enter: далее | Esc: выход","Arrows: select | Enter: continue | Esc: cancel"))
  local _,_,_,key=event.pull("key_down")
  if key==200 then selected=math.max(1,selected-1)
  elseif key==208 then selected=math.min(#items,selected+1)
  elseif key==28 then return selected
  elseif key==1 then error("Setup cancelled",0) end
 end
end
local function readFile(path)
 local h=assert(io.open(path,"rb"));local s=h:read("*a");h:close();return s
end
-- OpenOS/OC can return false for mkdir on an existing directory.
local function ensureDirectory(proxy,path)
 if proxy.exists(path) then
  assert(proxy.isDirectory(path),"Not a directory: "..path)
 else
  local ok,reason=proxy.makeDirectory(path)
  assert(ok,reason or ("Cannot create directory: "..path))
 end
end
local function writeProxy(proxy,path,data)
 ensureDirectory(proxy,fs.path(path))
 local h=assert(proxy.open(path,"wb"))
 local ok,why=proxy.write(h,data);proxy.close(h);assert(ok,why)
end
local function digest(a,b,s)
 for i=1,#s do a=(a+s:byte(i))%65521;b=(b+a)%65521 end
 return a,b
end
local function chosenPath(path,lang,allLanguages,full,wall)
 local language=path:match("/([^/]+)%.lang$") or path:match("^Localizations/([^/]+)%.lang$")
 if language and not allLanguages and language~=lang and language~="English" then return false end
 local app=path:match("^Applications/([^/]+)/")
 local core={['Finder.app']=true,['Settings.app']=true,['Console.app']=true,['App Market.app']=true,
  ['MineCode IDE.app']=true,['Picture View.app']=true,['Picture Edit.app']=true,['ZOS Packages.app']=true}
 if app and not full and not core[app] then return false end
 local wallpaper=path:match("^Wallpapers/([^/]+)/")
 if wallpaper and not full and wallpaper~="ZOS Hills.wlp" and wallpaper~="ZOS Teal.wlp" and wallpaper~="Solid color.wlp" and wallpaper~="Static picture.wlp" then return false end
 return true
end
local function run()
 assert(oldX>=80 and oldY>=25,"Screen resolution must be at least 80x25")
 assert(gpu.maxDepth()>=8,"MineOS compatibility requires Tier 3 graphics/screen")
 assert(computer.totalMemory()>=2*1024*1024,"At least 2 MiB RAM required")
 ru=menu("Language / Язык",{"English","Русский"})==2
 local languages=manifest.languages
 local default=1
 for i,v in ipairs(languages) do if v==(ru and "Russian" or "English") then default=i end end
 local lang=languages[menu(tr("Язык системы","System language"),languages,default)]
 local allLanguages=menu(tr("Языковые пакеты","Language packs"),{
  tr("Только выбранный + английский (экономия диска)","Selected + English only (save disk space)"),
  tr("Все языковые пакеты","All language packs")})==2
 local wall=menu(tr("Обои рабочего стола","Desktop wallpaper"),{
  tr("ZOS Hills — статичные холмы в духе XP","ZOS Hills — static XP-inspired hills"),
  tr("ZOS Teal — классический бирюзовый","ZOS Teal — classic teal"),
  tr("Без обоев","No wallpaper")})
 local full=menu(tr("Набор приложений","Applications"),{
  tr("Lite: основные приложения; все библиотеки MineOS","Lite: core apps; every MineOS library"),
  tr("Full: все приложения из исходного архива","Full: every app from the original archive")})==2
 screen(tr("Имя пользователя","User name"))
 print(tr("Латинские буквы/цифры/_/-; Enter = Guest","ASCII letters/digits/_/-; Enter = Guest"))
 local username=(term.read() or ""):gsub("%s+$","")
 if username=="" then username="Guest" end
 assert(username:match("^[%w_%-]+$") and #username<=32,"Invalid user name")
 screen(tr("Лицензия исходного архива","Source archive license"))
 print(tr("В исходном LICENSE есть нестандартный пункт.","The source LICENSE contains a nonstandard clause."))
 print(tr("Прочитайте system/LICENSE и NOTICE.md до продолжения.","Read system/LICENSE and NOTICE.md before continuing."))
 print(tr("Это не стандартная MIT-лицензия. ZOS не меняет её текст.","This is not standard MIT. ZOS preserves its text unchanged."))
 if menu(tr("Продолжить после ознакомления?","Continue after reviewing?"),{
  tr("Нет — выйти","No — exit"),tr("Да — продолжить","Yes — continue")})~=2 then return end
 local files,total={},0
 for _,v in ipairs(manifest.files) do
  if chosenPath(v.path,lang,allLanguages,full,wall) then files[#files+1]=v;total=total+v.size end
 end
 local candidates,labels={},{}
 local source=fs.get(root)
 for address in component.list("filesystem") do
  local proxy=component.proxy(address)
  -- Only truly empty disks; the source, temporary and existing OS disks are never candidates.
  local entries=proxy.list("/")
  local empty=type(entries)=="table" and next(entries)==nil
  if address~=source.address and address~=computer.tmpAddress() and not proxy.isReadOnly() and empty
   and proxy.spaceTotal()-proxy.spaceUsed()>=total+128*1024 then
   candidates[#candidates+1]=proxy
   labels[#labels+1]=(proxy.getLabel() or "HDD").."  "..address:sub(1,8).."  "..math.floor(proxy.spaceTotal()/1024).." KiB"
  end
 end
 assert(#candidates>0,tr("Нет пустого HDD нужного размера. Добавьте отдельный пустой диск.","No suitable empty HDD. Add a separate blank disk."))
 local target=candidates[menu(tr("Выберите ПУСТОЙ целевой диск","Select EMPTY destination disk"),labels)]
 if menu(tr("Записать ZOS на ","Write ZOS to ")..target.address:sub(1,8).."?",{
  tr("Отмена","Cancel"),tr("Установить","Install")})~=2 then return end
 local stage="/.zos-staging/"
 ensureDirectory(target,stage)
 for _,directory in ipairs({"Libraries","Applications","Icons","Localizations","Extensions","Mounts","Temporary","Wallpapers","Themes","Users","ZOS"}) do
  ensureDirectory(target,stage..directory)
 end
 for i,file in ipairs(files) do
  screen(tr("Копирование и проверка","Copy and verify"))
  print(math.floor((i-1)/#files*100).."%  "..file.path)
  assert(not file.path:find("..",1,true) and file.path:sub(1,1)~="/","Unsafe manifest path")
  local input=assert(io.open(root.."system/"..file.path,"rb"))
  ensureDirectory(target,fs.path(stage..file.path))
  local output=assert(target.open(stage..file.path,"wb"))
  local a,b,size=1,0,0
  while true do
   local chunk=input:read(8192);if not chunk then break end
   local success,why=target.write(output,chunk)
   if not success then input:close();target.close(output);error(why) end
   a,b=digest(a,b,chunk);size=size+#chunk
   os.sleep(0)
  end
  input:close();target.close(output)
  assert(size==file.size and b*65536+a==file.adler,"Checksum mismatch: "..file.path)
  -- Read back the destination as well; a successful write alone is not proof of integrity.
  local verify=assert(target.open(stage..file.path,"rb"))
  local va,vb,vs=1,0,0
  while true do
   local chunk,reason=target.read(verify,8192)
   if not chunk then target.close(verify);assert(not reason,reason);break end
   va,vb=digest(va,vb,chunk);vs=vs+#chunk
  end
  assert(vs==file.size and vb*65536+va==file.adler,"Read-back mismatch: "..file.path)
 end
 -- Initialize settings by executing the unchanged defaults function, not the live OS.
 local systemSource=readFile(root.."system/Libraries/System.lua")
 local body=assert(systemSource:match("function system.getDefaultUserSettings%(%)%s*(.-)\nend"))
 local defaults=assert(load(body,"=ZOS defaults","t",{
  paths={system={wallpapers="/Wallpapers/",applicationAppMarket="/Applications/App Market.app/Main.lua",
   applicationMineCodeIDE="/Applications/MineCode IDE.app/Main.lua",applicationFinder="/Applications/Finder.app/Main.lua",
   applicationPictureEdit="/Applications/Picture Edit.app/Main.lua",applicationSettings="/Applications/Settings.app/Main.lua",
   applicationPictureView="/Applications/Picture View.app/Main.lua",applicationPrint3D="/Applications/3D Print.app/Main.lua"}},
  filesystem={path=fs.path},string=string,math=math
 }))()
 defaults.localizationLanguage=lang;defaults.theme="ZOS Luna"
 defaults.networkName="ZOS-"..username
 defaults.interfaceWallpaperEnabled=wall~=3
 defaults.interfaceWallpaperPath=wall==1 and "/Wallpapers/ZOS Hills.wlp/" or wall==2 and "/Wallpapers/ZOS Teal.wlp/" or nil
 local versions={}
 for _,item in ipairs(files) do
  if item.id then versions[item.id]={path="/"..item.path,version=item.version or 1} end
 end
 writeProxy(target,stage.."Versions.cfg",serialization.serialize(versions))
 local home="/Users/"..username.."/"
 for _,folder in ipairs({"Desktop","Applications","Application data","Trash","Downloads"}) do ensureDirectory(target,stage..home:sub(2)..folder) end
 writeProxy(target,stage..home:sub(2).."Settings.cfg",serialization.serialize(defaults))
 writeProxy(target,stage..home:sub(2).."Icon.pic",readFile(root.."system/Icons/User.pic"))
 for _,app in ipairs({"Finder","ZOS Packages","App Market","Settings"}) do
  writeProxy(target,stage..home:sub(2).."Desktop/"..app..".lnk","/Applications/"..app..".app/")
 end
 local eeprom=component.isAvailable("eeprom") and component.eeprom
 if eeprom then
  writeProxy(target,stage.."ZOS/Backup/EEPROM.lua",eeprom.get())
  writeProxy(target,stage.."ZOS/Backup/EEPROM-data.txt",eeprom.getData())
  writeProxy(target,stage.."ZOS/Backup/EEPROM-label.txt",eeprom.getLabel() or "EEPROM")
  -- A second backup remains accessible from the OpenOS installation medium.
  local backup=root.."EEPROM-backup-"..target.address:sub(1,8)
  ensureDirectory(fs,backup)
  for _,name in ipairs({"EEPROM.lua","EEPROM-data.txt","EEPROM-label.txt"}) do
   local h=assert(io.open(backup.."/"..name,"wb"))
   h:write(name=="EEPROM.lua" and eeprom.get() or name=="EEPROM-data.txt" and eeprom.getData() or eeprom.getLabel() or "EEPROM")
   h:close()
  end
 end
 -- Commit directories first. OS.lua is the last move: partial copies are not bootable.
 for _,name in ipairs(assert(target.list(stage))) do
  if name~="OS.lua" then assert(target.rename(stage..name,"/"..name)) end
 end
 assert(target.rename(stage.."OS.lua","/OS.lua"));assert(target.remove(stage))
 target.setLabel("ZOS HDD")
 screen(tr("Система установлена","System installed"))
 if eeprom and menu(tr("Установить ZOS EFI в EEPROM?","Flash ZOS EFI to EEPROM?"),{
  tr("Нет — оставить текущую прошивку","No — keep current firmware"),
  tr("Да — резервная копия уже сохранена","Yes — backup has been saved")})==2 then
  local code=readFile(root.."system/EFI/ZOS.lua")
  assert(#code<=eeprom.getSize(),"EEPROM capacity too small")
  local ok,why=pcall(function()
   eeprom.set(code);eeprom.setData(target.address);eeprom.setLabel("ZOS EFI")
  end)
  if not ok then
   print("EFI failed: "..tostring(why).."; attempting rollback")
   local backup=root.."EEPROM-backup-"..target.address:sub(1,8).."/"
   local restored,err=pcall(function()
    eeprom.set(readFile(backup.."EEPROM.lua"));eeprom.setData(readFile(backup.."EEPROM-data.txt"));eeprom.setLabel(readFile(backup.."EEPROM-label.txt"))
   end)
   assert(restored,"Restore EEPROM manually: "..tostring(err))
   error(why)
  end
 end
 screen(tr("Готово","Done"))
 print(tr("ZOS установлена. Перезагрузитесь и выберите ZOS HDD в EFI.","ZOS installed. Reboot and select ZOS HDD in EFI."))
 print(tr("OpenOS не удалена. Резервная копия EEPROM: ZOS/Backup/.","OpenOS was not erased. EEPROM backup: ZOS/Backup/."))
 print(tr("Файлы проверены Adler-32 (не криптографическая подпись).","Files checked with Adler-32 (not a cryptographic signature)."))
end
local ok,why=xpcall(run,debug.traceback)
gpu.setBackground(oldBG);gpu.setForeground(oldFG)
if not ok then io.stderr:write(tostring(why).."\n");io.stderr:write("No disks were formatted. Inspect .zos-staging after a failed copy.\n") end
return ok,why
