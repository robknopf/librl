local Model = {}
Model.__index = Model

function Model.load(path)
  local handle = load_model(path)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
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
  }, Model)
end

function Model:draw(tint)
  if self.handle == nil or self.handle == 0 then
    return
  end

  draw_model(self.handle,
             self.x, self.y, self.z,
             self.scale,
             tint or COLOR_WHITE,
             self.rot_x, self.rot_y, self.rot_z,
             self.animation_index,
             self.animation_frame)
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
