-- Local ZPK1 app archives. Data only: no manifest code is evaluated.
local fs=require("Filesystem")
local packages={}
local function ensureDirectory(path)
 if fs.exists(path) then
  assert(fs.isDirectory(path),"Not a directory: "..path)
 else
  local ok,reason=fs.makeDirectory(path)
  assert(ok,reason or ("Cannot create directory: "..path))
 end
end
function packages.validPath(path)
 if type(path)~="string" or #path==0 or #path>180 or path:sub(1,1)=="/" or path:find("\\",1,true) or path:find("[%c:]") then return false end
 for part in path:gmatch("[^/]+") do if part=="." or part==".." then return false end end
 return not path:find("//",1,true) and path:sub(-1)~="/"
end
function packages.install(archive)
 local input,why=fs.open(archive,"rb")
 if not input then return false,why end
 local staging,output
 local ok,result=xpcall(function()
  assert(input:readLine()=="ZPK1","Not a ZPK1 archive")
  local name=input:readLine()
  assert(name and name:match("^[%w _%-]+$") and #name<=48,"Invalid app name (ASCII only)")
  local count=tonumber(input:readLine())
  assert(count and count%1==0 and count>=1 and count<=256,"Invalid file count")
  local target="/Applications/"..name..".app"
  staging="/Applications/.zos-"..name..".stage"
  assert(not fs.exists(target),"Application exists; no files were replaced")
  assert(not fs.exists(staging),"Old staging directory exists; inspect it first")
  ensureDirectory(staging)
  local total,seen,main=0,{},false
  for _=1,count do
   local path=input:readLine()
   assert(packages.validPath(path) and not seen[path],"Invalid or duplicate path")
   seen[path]=true; if path=="Main.lua" then main=true end
   local size=tonumber(input:readLine())
   assert(size and size%1==0 and size>=0 and size<=1024*1024,"Invalid file size")
   total=total+size; assert(total<=4*1024*1024,"Package is too large")
   local full=staging.."/"..path
   ensureDirectory(fs.path(full))
   output=assert(fs.open(full,"wb"))
   local left=size
   while left>0 do
    local chunk=input:readString(math.min(left,4096))
    assert(chunk and #chunk>0,"Truncated package")
    assert(output:write(chunk));left=left-#chunk
   end
   assert(output:close());output=nil
   assert(fs.size(full)==size,"Disk write incomplete")
  end
  assert(main,"Main.lua missing")
  assert(not input:readString(1),"Trailing archive data")
  assert(fs.rename(staging,target));staging=nil
  return target
 end,debug.traceback)
 input:close()
 if output then pcall(output.close,output) end
 -- Failed staging directories are retained for inspection; never delete user data.
 return ok,result
end
return packages
