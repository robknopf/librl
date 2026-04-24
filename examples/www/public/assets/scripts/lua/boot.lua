local ScriptAsync = require("script_async")

---@diagnostic disable-next-line: deprecated
local table_unpack = table.unpack or unpack

local app = nil
local pending_calls = {}
local BOOT_CONFIG = {
  width = 1024,
  height = 1280,
  title = "librl + raylib + lua(C example)",
  target_fps = 60,
  flags = FLAG_MSAA_4X_HINT,
}

local function log_import_error(err)
  log("error", "main import failed: " .. tostring(err))
end

local function call_if_ready(method_name, ...)
  if app == nil or type(app[method_name]) ~= "function" then
    return nil, false
  end

  return app[method_name](...), true
end

local function call_or_queue(method_name, ...)
  local args = {...}

  -- init/load/unserialize may arrive before the real app module has been
  -- imported, so defer them until the bootstrap import completes.
  if app == nil then
    pending_calls[#pending_calls + 1] = {
      name = method_name,
      args = args,
    }
    return
  end

  call_if_ready(method_name, table_unpack(args))
end

local function drain_pending_calls()
  local i = 0

  if app == nil then
    return
  end

  for i = 1, #pending_calls do
    local pending_call = pending_calls[i]
    call_if_ready(pending_call.name, table_unpack(pending_call.args))
  end

  pending_calls = {}
end

local function normalize_lua_file_name(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end

  if string.match(name, "%.lua$") then
    return name
  end

  return name .. ".lua"
end

local function resolve_boot_lua_file(script_root, name)
  local lua_file = normalize_lua_file_name(name)

  if type(script_root) ~= "string" or script_root == "" or lua_file == nil then
    return nil
  end

  return script_root .. "/" .. lua_file, lua_file:gsub("%.lua$", "")
end

-- The host always enters through boot.lua, then explicitly tells it which app
-- module to import by calling boot("<script_root>", "<name>").
function boot(script_root, name)
  print("boot", script_root, name)
  local path, module_name = resolve_boot_lua_file(script_root, name)
  local thread = nil

  if path == nil or module_name == nil then
    log_import_error("invalid boot arguments")
    return
  end

  thread = coroutine.create(function()
    local module, err = import_lua_file(path, module_name)

    if err ~= nil then
      log_import_error(err)
      return
    end

    if type(module) ~= "table" then
      log_import_error("imported app did not return a table")
      return
    end

    app = module
    drain_pending_calls()
  end)

  local ok, err = coroutine.resume(thread)
  if not ok then
    log_import_error(err)
  end
end

function get_config()
  return BOOT_CONFIG
end

function init()
  call_or_queue("init")
end

function load()
  call_or_queue("load")
end

function serialize()
  local state = call_if_ready("serialize")
  if state ~= nil then
    return state
  end

  -- Before the app is ready there is no meaningful state to serialize yet.
  return nil
end

function unserialize(state)
  call_or_queue("unserialize", state)
end

function unload()
  pending_calls = {}

  if app ~= nil then
    call_if_ready("unload")
  end
end

function shutdown()
  pending_calls = {}

  if app ~= nil then
    call_if_ready("shutdown")
  end
end

function update(frame)
  import_pump()

  -- Frame updates are intentionally dropped until the app is ready; replaying
  -- stale frames later would be incorrect.
  if app ~= nil then
    call_if_ready("update", frame)
  end
end
