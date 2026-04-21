local Model = {}
Model.__index = Model
local ResourceAsync = require("resource_async")

local transform_fields = { x=true, y=true, z=true, scale=true, rot_x=true, rot_y=true, rot_z=true }

local function wrap_handle(handle)
  if handle == nil or handle == 0 then
    return nil
  end

  local data = {
    handle = handle,
    x = 0.0,
    y = 0.0,
    z = 0.0,
    scale = 1.0,
    rot_x = 0.0,
    rot_y = 0.0,
    rot_z = 0.0,
    animation_index = -1,
    animation_frame = 0,
    _transform_dirty = true,
  }

  return setmetatable(data, Model)
end

function Model:__newindex(k, v)
  rawset(self, k, v)
  if transform_fields[k] then
    rawset(self, "_transform_dirty", true)
  end
end

local function load_sync(path)
  return wrap_handle(load_model(path))
end

function Model.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("model", path, nil, wrap_handle, callback)
  end

  return load_sync(path)
end

function Model:sync()
  if self.handle == nil or self.handle == 0 then
    return
  end
  if not self._transform_dirty then
    return
  end
  set_model_transform(self.handle,
                      self.x, self.y, self.z,
                      self.rot_x, self.rot_y, self.rot_z,
                      self.scale, self.scale, self.scale)
  self._transform_dirty = false
end

function Model:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end
  self:sync()
  draw_model(self.handle, tint or COLOR_WHITE,
             self.animation_index, self.animation_frame)
end

function Model:pick(mouse_x, mouse_y, camera)
  if self.handle == nil or self.handle == 0 then
    return nil
  end

  if camera ~= nil and camera ~= 0 then
    return pick_model(self.handle,
                      mouse_x, mouse_y,
                      self.x, self.y, self.z,
                      self.scale,
                      self.rot_x, self.rot_y, self.rot_z,
                      camera)
  end

  return pick_model(self.handle,
                    mouse_x, mouse_y,
                    self.x, self.y, self.z,
                    self.scale,
                    self.rot_x, self.rot_y, self.rot_z)
end

function Model:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_model(self.handle)
    self.handle = 0
  end
end

return Model
