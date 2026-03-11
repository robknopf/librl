local Shadow = {}

local function clamp(v, lo, hi)
  if v < lo then
    return lo
  end
  if v > hi then
    return hi
  end
  return v
end

function Shadow.draw_blob(texture, entity, base_size, tint, ground_y)
  local x = 0.0
  local y = 0.0
  local z = 0.0
  local size = 1.0
  local height = 0.0
  local t = 0.0
  local width = 0.0
  local depth = 0.0
  local texture_handle = 0

  if texture == nil or entity == nil or tint == nil then
    return
  end

  texture_handle = texture.handle or texture
  if texture_handle == nil or texture_handle == 0 then
    return
  end

  x = entity.x or 0.0
  y = entity.y or 0.0
  z = entity.z or 0.0
  size = entity.size or entity.scale or 1.0
  ground_y = ground_y or 0.0
  base_size = base_size or 1.0

  height = math.max(0.0, y - ground_y)
  t = clamp(height / (base_size * 2.5 + 0.0001), 0.0, 1.0)

  -- squished
  --width = base_size * size * (1.25 - t * 0.55)
  --depth = base_size * size * (0.95 - t * 0.40)

  -- square for now, with a larger falloff
  width = math.max(base_size * size * ((1 - t) * (1 - t)), 0.05)
  depth = width

  draw_ground_texture(texture_handle,
    x,
    ground_y + 0.01,
    z,
    math.max(width, 0.05),
    math.max(depth, 0.05),
    tint)
end

return Shadow
