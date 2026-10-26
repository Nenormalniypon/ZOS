local screen = require("Screen")
local workspace, wallpaper = ...
wallpaper.zosStatic = true
wallpaper.draw = function(w)
 screen.drawRectangle(w.x, w.y, w.width, w.height, 0x008080, 0, " ")

end
