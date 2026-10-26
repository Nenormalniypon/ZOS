-- Compatibility entry point for standard OpenComputers EEPROMs.
local eeprom=component.proxy(component.list("eeprom")())
local address=computer.getBootAddress and computer.getBootAddress() or eeprom.getData()
local disk=component.proxy(address)
eeprom.setData(address)
local stream=assert(disk.open("/OS.lua","rb"))
local chunks={}
while true do local s=disk.read(stream,4096);if not s then break end;chunks[#chunks+1]=s end
disk.close(stream)
assert(load(table.concat(chunks),"=/OS.lua","t",_G))()
