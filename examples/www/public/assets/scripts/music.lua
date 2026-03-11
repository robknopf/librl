local Music = {}
Music.__index = Music

function Music.load(path)
  local handle = load_music(path)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
  }, Music)
end

function Music:play()
  if self.handle ~= nil and self.handle ~= 0 then
    play_music(self.handle)
  end
end

function Music:pause()
  if self.handle ~= nil and self.handle ~= 0 then
    pause_music(self.handle)
  end
end

function Music:stop()
  if self.handle ~= nil and self.handle ~= 0 then
    stop_music(self.handle)
  end
end

function Music:is_playing()
  if self.handle == nil or self.handle == 0 then
    return false
  end

  return is_music_playing(self.handle)
end

function Music:set_loop(loop)
  if self.handle ~= nil and self.handle ~= 0 then
    set_music_loop(self.handle, loop)
  end
end

function Music:set_volume(volume)
  if self.handle ~= nil and self.handle ~= 0 then
    set_music_volume(self.handle, volume)
  end
end

function Music:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    destroy_music(self.handle)
    self.handle = 0
  end
end

return Music
