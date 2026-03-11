local Font = {}
Font.__index = Font

function Font.load(path, size)
  local handle = load_font(path, size)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
    size = size,
  }, Font)
end

function Font:draw(text, x, y, size, scale, tint)
  if self.handle == nil or self.handle == 0 then
    return
  end

  draw_text(self.handle,
            text,
            x, y,
            size or self.size,
            scale or 1.0,
            tint or COLOR_WHITE)
end

function Font:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_font(self.handle)
    self.handle = 0
  end
end

return Font
