local Sound = {}
Sound.__index = Sound
local ResourceAsync = require("resource_async")

local function load_sync(path)
  local handle = load_sound(path)
  if handle == nil or handle == 0 then
    return nil
  end

  return setmetatable({
    handle = handle,
  }, Sound)
end

function Sound.load(path, callback)
  if type(callback) == "function" then
    return ResourceAsync.request("sound", path, nil, function()
      return load_sync(path)
    end, callback)
  end

  return load_sync(path)
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
