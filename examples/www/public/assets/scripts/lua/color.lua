local rl = require("rl")

local Color = {}
Color.__index = Color

function Color.create(r, g, b, a)
  local handle = rl.color_create(r, g, b, a or 255)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
  }, Color)
end

function Color:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.color_destroy(self.handle)
    self.handle = 0
  end
end

return Color
