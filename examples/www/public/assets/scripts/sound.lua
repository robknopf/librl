local Sound = {}
Sound.__index = Sound

function Sound.load(path)
  local handle = load_sound(path)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
  }, Sound)
end

function Sound:play()
  if self.handle ~= nil and self.handle ~= 0 then
    play_sound(self.handle)
  end
end

function Sound:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_sound(self.handle)
    self.handle = 0
  end
end

return Sound
