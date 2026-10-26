-- ZOS shell extensions; retain MineOS System/GUI APIs and window lifecycle.
local shell = {}
function shell.install(system, GUI, screen, fs, paths)
 GUI.WINDOW_BACKGROUND_PANEL_COLOR = 0xECE9D8
 GUI.WINDOW_TITLE_BACKGROUND_COLOR = 0x245EDB
 GUI.WINDOW_TITLE_TEXT_COLOR = 0xFFFFFF
 local function ru() return system.getUserSettings().localizationLanguage == "Russian" end
 local function tr(a,b) return ru() and a or b end
 local function launch(path, ...) system.execute(path, ...) end
 local function label(window)
  if window.dockIcon then return fs.hideExtension(fs.name(window.dockIcon.path)) end
  return window.titleLabel and window.titleLabel.text or "Window"
 end
 local function startMenu(ws, x, y)
  local menu = system.applyThemeToContextMenu(GUI.addContextMenu(ws, x, math.max(2, y - 13)))
  menu:addItem(tr("Мои файлы", "My files")).onTouch = function() launch(paths.system.applicationFinder, "-o", paths.user.home) end
  menu:addItem(tr("Установка приложений", "Install applications")).onTouch = function() launch("/Applications/ZOS Software.app/Main.lua") end
  menu:addItem("MineOS App Market").onTouch = function()
   if fs.exists(paths.system.applicationAppMarket) then launch(paths.system.applicationAppMarket)
   else launch("/Applications/ZOS Software.app/Main.lua", "App Market") end
  end
  local apps = menu:addSubMenuItem(tr("Все программы", "All programs"))
  for _, folder in ipairs({paths.system.applications, paths.user.applications}) do
   for _, entry in ipairs(fs.list(folder)) do
    local main = folder .. entry .. "Main.lua"
    if entry:match("%.app/$") and fs.exists(main) then
     local target = main
     apps:addItem(entry:gsub("%.app/$", "")).onTouch = function() launch(target) end
    end
   end
  end
  local tasks = menu:addSubMenuItem(tr("Все окна", "All windows"))
  for _, window in ipairs(system.getWindowsContainer().children) do
   local selected = window
   tasks:addItem(label(window)).onTouch = function() selected:focus();ws:draw() end
  end
  menu:addItem(tr("Настройки", "Settings")).onTouch = function() launch(paths.system.applicationSettings) end
  menu:addItem(tr("О системе ZOS", "About ZOS")).onTouch = function()
   GUI.alert(tr("ZOS 0.1.0 — форк MineOS для OpenComputers. F2: ZOS EFI; F8: безопасная загрузка.",
     "ZOS 0.1.0 — MineOS fork for OpenComputers. F2: ZOS EFI; F8: safe boot."))
  end
  menu:addItem(tr("Перезагрузить", "Restart")).onTouch = function() computer.shutdown(true) end
  menu:addItem(tr("Выключить", "Shut down")).onTouch = function() computer.shutdown() end
 end
 local originalDesktop = system.updateDesktop
 local originalResolution = system.updateResolution
 local bar
 system.updateResolution = function(...)
  originalResolution(...)
  local ws, windows = system.getWorkspace(), system.getWindowsContainer()
  if windows then windows.height = math.max(1, ws.height - 4) end
  if bar then bar.width, bar.localY = ws.width, ws.height - 2 end
 end
 system.updateDesktop = function(...)
  bar = nil
  originalDesktop(...)
  local ws = system.getWorkspace()
  -- Keep invisible dock for all app/window bookkeeping. Keep top app menus.
  system.getDockContainer().hidden = true
  local windows = system.getWindowsContainer()
  windows.height = math.max(1, ws.height - 4)
  bar = ws:addChild(GUI.object(1, ws.height - 2, ws.width, 3))
  bar.draw = function(o)
   screen.drawRectangle(o.x,o.y,o.width,3,0x245EDB,0," ")
   screen.drawRectangle(o.x,o.y,o.width,1,0x4A8AFF,0," ")
   screen.drawRectangle(o.x,o.y,11,3,0x388C35,0," ")
   screen.drawText(o.x+2,o.y+1,0xFFFFFF,tr("Пуск", "Start"))
   o.hits = {}
   local x, available = o.x+12, math.max(0,o.width-26)
   local n = #windows.children
   local width = math.max(8, math.min(22, math.floor(available / math.max(1,n))))
   for _, win in ipairs(windows.children) do
    if x + width > o.x + o.width - 13 then break end
    screen.drawRectangle(x,o.y+1,width-1,1,win.hidden and 0x3A7BE0 or 0x1645A5,0," ")
    screen.drawText(x+1,o.y+1,0xFFFFFF,unicode.sub(label(win),1,width-3))
    o.hits[#o.hits+1] = {x=x, last=x+width-2, window=win}
    x = x+width
   end
   screen.drawRectangle(o.x+o.width-12,o.y,12,3,0x1386DC,0," ")
   screen.drawText(o.x+o.width-10,o.y+1,0xFFFFFF,os.date("%H:%M",system.getTime()))
  end
  bar.eventHandler = function(workspace,o,e,_,x,y,button)
   if e~="touch" or button~=0 then return end
   if x < o.x+11 then startMenu(workspace,o.x,o.y)
   else
    for _, hit in ipairs(o.hits or {}) do
     if x>=hit.x and x<=hit.last then
      local win=hit.window
      if not win.hidden and windows.children[#windows.children]==win then win:minimize()
      else win:focus() end
      break
     end
    end
   end
   workspace:draw()
  end
 end
end
return shell
