local rl = require("rl")

local Camera3D = {}
Camera3D.__index = Camera3D

function Camera3D.create(px, py, pz,
                         tx, ty, tz,
                         ux, uy, uz,
                         fovy, projection)
  local handle = rl.camera3d_create(px, py, pz,
                                    tx, ty, tz,
                                    ux, uy, uz,
                                    fovy, projection)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
    position = { x = px, y = py, z = pz },
    target = { x = tx, y = ty, z = tz },
    up = { x = ux, y = uy, z = uz },
    fovy = fovy,
    projection = projection,
    _transform_dirty = true,
  }, Camera3D)
end

function Camera3D:apply()
  if self.handle == nil or self.handle == 0 then
    return
  end
  if not self._transform_dirty then
    return
  end
  rl.camera3d_set(self.handle,
                  self.position.x, self.position.y, self.position.z,
                  self.target.x, self.target.y, self.target.z,
                  self.up.x, self.up.y, self.up.z,
                  self.fovy, self.projection)
  self._transform_dirty = false
end

function Camera3D:set_active()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.camera3d_set_active(self.handle)
  end
end

function Camera3D:mark_dirty()
  self._transform_dirty = true
end

return Camera3D
