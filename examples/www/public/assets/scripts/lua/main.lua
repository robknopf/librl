local app = require("lua_demo")

function get_config()
  return {
    title = "librl + raylib + lua(C example)",
    width = 1024,
    height = 1280,
    target_fps = 60,
    flags = FLAG_MSAA_4X_HINT,
  }
end

function init()
  if app.init then app.init() end
end

function load()
  if app.load then app.load() end
end

function serialize()
  if app.serialize then return app.serialize() end
end

function unserialize(state)
  if app.unserialize then app.unserialize(state) end
end

function unload()
  if app.unload then app.unload() end
end

function shutdown()
  if app.shutdown then app.shutdown() end
end

function update(frame)
  if app.update then app.update(frame) end
end
