local Texture = {}
Texture.__index = Texture
local ResourceAsync = require("resource_async")

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
  }, Texture)
end

local function load_sync(path)
  return wrap_handle(load_texture(path))
end

function Texture.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("texture", path, nil, wrap_handle, callback)
  end

  return load_sync(path)
end

function Texture:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end

  draw_texture(self.handle,
               self.x, self.y,
               self.scale,
               self.rotation,
               tint or COLOR_WHITE)
end

function Texture:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_texture(self.handle)
    self.handle = 0
  end
end

return Texture
