local rl = require("rl")

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
  return wrap_handle(rl.model_create_from_file(path))
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
  rl.model_set_transform(self.handle,
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
  if self.animation_index ~= nil and self.animation_index >= 0 then
    rl.model_update_animation(self.handle, self.animation_index, self.animation_frame)
  end
  rl.model_draw(self.handle, tint or rl.COLOR_WHITE)
end

function Model:pick(mouse_x, mouse_y, camera)
  if self.handle == nil or self.handle == 0 then
    return nil
  end

  self:sync()
  if camera ~= nil and camera ~= 0 then
    return rl.pick_model(camera, self.handle, mouse_x, mouse_y)
  end

  local active = rl.camera3d_get_active()
  if active == nil or active == 0 then
    return nil
  end
  return rl.pick_model(active, self.handle, mouse_x, mouse_y)
end

function Model:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.model_destroy(self.handle)
    self.handle = 0
  end
end

return Model
