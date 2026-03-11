local Sprite3D = {}
Sprite3D.__index = Sprite3D

function Sprite3D.load(path)
  local handle = load_sprite3d(path)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
    x = 0.0,
    y = 0.0,
    z = 0.0,
    size = 1.0,
  }, Sprite3D)
end

function Sprite3D:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end

  draw_sprite3d(self.handle,
                self.x, self.y, self.z,
                self.size,
                tint or COLOR_WHITE)
end

function Sprite3D:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_sprite3d(self.handle)
    self.handle = 0
  end
end

return Sprite3D
