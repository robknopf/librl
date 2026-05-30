local rl = require("rl")

local Sprite3D = {}
Sprite3D.__index = Sprite3D
local ResourceAsync = require("resource_async")

local transform_fields = { x=true, y=true, z=true, rotation_x=true, rotation_y=true, rotation_z=true, scale_x=true, scale_y=true, scale_z=true, size=true }

local function wrap_handle(handle)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
    x = 0.0,
    y = 0.0,
    z = 0.0,
    rotation_x = 0.0,
    rotation_y = 0.0,
    rotation_z = 0.0,
    scale_x = 1.0,
    scale_y = 1.0,
    scale_z = 1.0,
    size = 1.0,
    _transform_dirty = true,
  }, Sprite3D)
end

function Sprite3D:__newindex(k, v)
  rawset(self, k, v)
  if transform_fields[k] then
    rawset(self, "_transform_dirty", true)
  end
end

local function load_sync(path)
  return wrap_handle(rl.sprite3d_create_from_file(path))
end

function Sprite3D.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("sprite3d", path, nil, wrap_handle, callback)
  end

  return load_sync(path)
end

function Sprite3D:sync()
  if self.handle == nil or self.handle == 0 then
    return
  end
  if not self._transform_dirty then
    return
  end
  rl.sprite3d_set_transform(self.handle, self.x, self.y, self.z, self.rotation_x, self.rotation_y, self.rotation_z, self.scale_x, self.scale_y, self.scale_z)
  rl.sprite3d_set_size(self.handle, self.size)
  self._transform_dirty = false
end

function Sprite3D:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end
  self:sync()
  rl.sprite3d_draw(self.handle, tint or rl.COLOR_WHITE)
end

function Sprite3D:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.sprite3d_destroy(self.handle)
    self.handle = 0
  end
end

return Sprite3D
