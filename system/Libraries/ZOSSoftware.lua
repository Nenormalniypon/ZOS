-- Install optional bundled MineOS apps after first boot. No system files are replaced.
local fs=require("Filesystem")
local system=require("System")
local event=require("Event")
local api={}
local function readManifest()
 local h=assert(fs.open("/ZOS/Manifest.lua","rb"),"Application catalog is not installed")
 local s=h:read("a");h:close()
 return assert(load(s,"=ZOS application catalog","t",{}))()
end
function api.catalog()
 local manifest=readManifest();local names,seen={},{}
 for _,info in ipairs(manifest.files) do
  local name=info.path:match("^Applications/([^/]+)%.app/Main%.lua$")
  if name and not seen[name] then seen[name]=true;names[#names+1]=name end
 end
 table.sort(names);return names
end
function api.install(name,progress)
 local ok,result=xpcall(function()
  assert(type(name)=="string" and not name:find("[/\\%c]") and not name:find("..",1,true),"Invalid application name")
  local manifest=readManifest();local prefix="Applications/"..name..".app/"
  local target="/"..prefix:sub(1,-2)
  assert(not fs.exists(target),"Application already exists; it was not replaced")
  local settings=system.getUserSettings();local files={};local main=false
  for _,info in ipairs(manifest.files) do
   if info.path:sub(1,#prefix)==prefix then
    local lang=info.path:match("/([^/]+)%.lang$")
    if not lang or lang=="English" or lang==settings.localizationLanguage then files[#files+1]=info end
    if info.path==prefix.."Main.lua" then main=true end
   end
  end
  assert(main and #files>0,"App not found in pinned catalog")
  local sources=assert(fs.readTable("/ZOS/Sources.cfg"))
  local client=require("ZOSDownload").new({fs=fs,open=fs.open,component=component,computer=computer,sleep=event.sleep,base=sources.zosBase,commit=sources.mineosCommit})
  local stage="/Applications/.zos-download-"..name..".stage/"
  for i,info in ipairs(files) do
   if progress then progress(i,#files,info.path) end
   client.download(info,stage..info.path:sub(#prefix+1))
  end
  assert(fs.rename(stage:sub(1,-2),target))
  local versions=fs.exists("/Versions.cfg") and fs.readTable("/Versions.cfg") or {}
  for _,info in ipairs(files) do if info.id then versions[info.id]={path="/"..info.path,version=info.version or 1} end end
  assert(fs.writeTable("/Versions.cfg",versions,true))
  computer.pushSignal("system","updateFileList")
  return target.."/Main.lua"
 end,debug.traceback)
 return ok,result
end
return api
