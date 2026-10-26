local GUI=require("GUI")
local system=require("System")
local paths=require("Paths")
local packages=require("ZOSPackages")
local ru=system.getUserSettings().localizationLanguage=="Russian"
local function tr(a,b) return ru and a or b end
local ws,win=system.addWindow(GUI.titledWindow(1,1,66,17,"ZOS Packages",true))
win:addChild(GUI.label(3,3,60,1,0x333333,tr("Локальный пакет .zpk — полный путь:","Local .zpk package — full path:")))
local field=win:addChild(GUI.input(3,5,60,3,0xFFFFFF,0x222222,0x888888,0xFFFFFF,0x222222,"","/Users/Guest/Downloads/Hello.zpk"))
local status=win:addChild(GUI.label(3,13,60,2,0x333333,tr("Устанавливайте только доверенные приложения.","Install trusted applications only.")))
win:addChild(GUI.button(3,9,27,3,0x245EDB,0xFFFFFF,0x1941A5,0xFFFFFF,tr("Установить .zpk","Install .zpk"))).onTouch=function()
 local ok,result=packages.install(field.text)
 status.text=ok and tr("Установлено. Откройте Пуск → Все программы.","Installed. Open Start → All programs.") or unicode.sub(tostring(result),1,115)
 if ok then computer.pushSignal("system","updateFileList") end
 ws:draw()
end
win:addChild(GUI.button(33,9,30,3,0xDEDACA,0x222222,0x245EDB,0xFFFFFF,"MineOS App Market")).onTouch=function() system.execute(paths.system.applicationAppMarket) end
ws:draw()
