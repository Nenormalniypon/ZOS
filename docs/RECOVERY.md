# Возврат сохранённой EEPROM

Сначала сделайте резервную копию мира. Вставьте OpenOS, при необходимости выньте
диск ZOS и выберите OpenOS в ZOS EFI по F2. На исходном диске найдите каталог
`EEPROM-backup-<адрес>/` внутри распакованного дистрибутива.

Создайте в OpenOS файл restore-efi.lua со следующим содержимым:

```lua
local component = require("component")
local args = {...}
local folder = assert(args[1], "Pass absolute backup folder")
if folder:sub(-1) ~= "/" then folder = folder .. "/" end
local function read(name)
  local h = assert(io.open(folder .. name, "rb"))
  local s = h:read("*a")
  h:close()
  return s
end
local code = read("EEPROM.lua")
local data = read("EEPROM-data.txt")
local label = read("EEPROM-label.txt")
local e = component.eeprom
assert(#code <= e.getSize(), "EEPROM too small")
print("Restore saved firmware? Type RESTORE")
assert(io.read() == "RESTORE", "Cancelled")
e.set(code)
e.setData(data)
e.setLabel(label)
print("Restored. Reboot when ready.")
```

Запустите с реальным абсолютным путём:

```sh
restore-efi.lua /ZOS-0.1.0/EEPROM-backup-12345678
```

`12345678` — пример, замените его своим именем каталога. Восстановление boot data
предполагает, что старый загрузочный диск с тем же UUID по-прежнему подключён.
Не прошивайте случайную копию и не делайте EEPROM read-only.
