local rl = require("rl")

local Music = {}
Music.__index = Music
local ResourceAsync = require("resource_async")

local function wrap_handle(handle)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
  }, Music)
end

local function load_sync(path)
  return wrap_handle(rl.music_create(path))
end

function Music.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("music", path, nil, wrap_handle, callback)
  end

  return load_sync(path)
end

function Music:play()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_play(self.handle)
  end
end

function Music:pause()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_pause(self.handle)
  end
end

function Music:stop()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_stop(self.handle)
  end
end

function Music:is_playing()
  if self.handle == nil or self.handle == 0 then
    return false
  end

  return rl.music_is_playing(self.handle)
end

function Music:set_loop(loop)
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_set_loop(self.handle, loop)
  end
end

function Music:set_volume(volume)
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_set_volume(self.handle, volume)
  end
end

function Music:destroy()
  if self.handle ~= nil and self.handle ~= 0 then
    rl.music_destroy(self.handle)
    self.handle = 0
  end
end

return Music
