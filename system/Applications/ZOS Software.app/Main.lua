local GUI=require("GUI")
local system=require("System")
local fs=require("Filesystem")
local software=require("ZOSSoftware")
local desired=...
local ru=system.getUserSettings().localizationLanguage=="Russian"
local function tr(a,b)return ru and a or b end
local ws,win=system.addWindow(GUI.titledWindow(1,1,68,19,tr("Программы MineOS","MineOS programs"),true))
win:addChild(GUI.label(3,3,62,2,0x333333,tr("Программы скачиваются только после нажатия «Установить».","Applications download only when Install is pressed.")))
local combo=win:addChild(system.applyThemeToComboBox(GUI.comboBox(3,6,62,3,0xFFFFFF,0x333333,0x245EDB,0xFFFFFF)))
local names=software.catalog()
for i,name in ipairs(names) do combo:addItem(name);if name==desired then combo.selectedItem=i end end
local status=win:addChild(GUI.label(3,15,62,2,0x333333,tr("Источник: официальный GitHub MineOS; изменения ZOS — ваш GitHub.","Source: official MineOS GitHub; ZOS changes: your repository.")))
local button=win:addChild(GUI.button(3,10,29,3,0x245EDB,0xFFFFFF,0x1941A5,0xFFFFFF,tr("Установить / открыть","Install / open")))
button.onTouch=function()
 local name=names[combo.selectedItem];if not name then return end
 local main="/Applications/"..name..".app/Main.lua"
 if fs.exists(main) then system.execute(main);return end
 button.disabled=true;ws:draw()
 local ok,result=software.install(name,function(i,total,path)
  status.text=i.."/"..total.." "..unicode.sub(path,1,52);ws:draw()
 end)
 button.disabled=false
 status.text=ok and tr("Установлено. Нажмите ещё раз, чтобы открыть.","Installed. Press again to open.") or unicode.sub(tostring(result),1,120)
 ws:draw()
end
win:addChild(GUI.button(35,10,30,3,0xDEDACA,0x222222,0x245EDB,0xFFFFFF,tr("Локальные пакеты .zpk","Local .zpk packages"))).onTouch=function()system.execute("/Applications/ZOS Packages.app/Main.lua")end
ws:draw()
