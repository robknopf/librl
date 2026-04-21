local Sprite2D = {}
Sprite2D.__index = Sprite2D
local ResourceAsync = require("resource_async")

local transform_fields = { x=true, y=true, scale=true, rotation=true }

local function wrap_handle(handle)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
    x = 0.0,
    y = 0.0,
    scale = 1.0,
    rotation = 0.0,
    _transform_dirty = true,
  }, Sprite2D)
end

function Sprite2D:__newindex(k, v)
  rawset(self, k, v)
  if transform_fields[k] then
    rawset(self, "_transform_dirty", true)
  end
end

local function load_sync(path)
  return wrap_handle(load_sprite2d(path))
end

function Sprite2D.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("sprite2d", path, nil, wrap_handle, callback)
  end

  return load_sync(path)
end

function Sprite2D:sync()
  if self.handle == nil or self.handle == 0 then
    return
  end
  if not self._transform_dirty then
    return
  end
  set_sprite2d_transform(self.handle, self.x, self.y, self.scale, self.rotation)
  self._transform_dirty = false
end

function Sprite2D:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end
  self:sync()
  draw_sprite2d(self.handle, tint or COLOR_WHITE)
end

function Sprite2D:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_sprite2d(self.handle)
    self.handle = 0
  end
end

return Sprite2D
