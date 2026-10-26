local screen = require("Screen")
local workspace, wallpaper = ...
wallpaper.zosStatic = true
wallpaper.draw = function(w)
 screen.drawRectangle(w.x, w.y, w.width, w.height, 0x3A83CB, 0, " ")
 for column = 0, w.width - 1 do
  local ridge = math.floor(w.height * (0.58 + 0.1 * math.sin(column / w.width * 6)))
  screen.drawRectangle(w.x + column, w.y + ridge, 1, w.height - ridge, 0x66A837, 0, " ")
  local near = math.floor(w.height * (0.81 + 0.05 * math.cos(column / w.width * 7)))
  screen.drawRectangle(w.x + column, w.y + near, 1, w.height - near, 0x41892E, 0, " ")
 end
end
