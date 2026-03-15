local ScriptAsync = {}

local next_rid = 1
local pending = {}
local ready_resumes = {}

local function next_request_id()
  local rid = next_rid
  next_rid = next_rid + 1
  return rid
end

local function module_name_to_path(module_name)
  if type(module_name) ~= "string" or module_name == "" then
    return nil
  end

  return module_name:gsub("%.", "/") .. ".lua"
end

local function path_to_module_name(path)
  local module_name = nil

  if type(path) ~= "string" or path == "" then
    return nil
  end

  module_name = path:gsub("%.lua$", "")
  if module_name == path then
    return nil
  end

  module_name = module_name:gsub("/", ".")
  if module_name == "" then
    return nil
  end

  return module_name
end

local function emit_script_import(path, module_name, callback, thread)
  local rid = nil

  rid = next_request_id()
  pending[rid] = {
    module_name = module_name,
    callback = callback,
    thread = thread,
  }

  if not event_emit("script.import", tostring(rid) .. "|" .. path) then
    pending[rid] = nil
    if callback ~= nil then
      callback(nil, "failed to emit script.import event")
    end
    return nil
  end

  return rid
end

local function parse_error_payload(payload)
  if type(payload) ~= "string" then
    return nil, "script import failed"
  end

  local sep = payload:find("|", 1, true)
  if not sep then
    return tonumber(payload), "script import failed"
  end

  local rid = tonumber(payload:sub(1, sep - 1))
  local message = payload:sub(sep + 1)
  if message == "" then
    message = "script import failed"
  end
  return rid, message
end

event_on("script.loaded", function(payload)
  local rid = tonumber(payload)
  local request = rid ~= nil and pending[rid] or nil
  local ok, result

  if request == nil or rid == nil then
    return
  end

  pending[rid] = nil
  ok, result = pcall(require, request.module_name)
  if request.callback ~= nil then
    if ok then
      request.callback(result, nil)
    else
      request.callback(nil, tostring(result))
    end
    return
  end

  ready_resumes[#ready_resumes + 1] = {
    thread = request.thread,
    ok = ok,
    value = ok and result or tostring(result),
  }
end)

event_on("script.error", function(payload)
  local rid, message = parse_error_payload(payload)
  local request = rid ~= nil and pending[rid] or nil

  if request == nil or rid == nil then
    return
  end

  pending[rid] = nil
  if request.callback ~= nil then
    request.callback(nil, message)
    return
  end

  ready_resumes[#ready_resumes + 1] = {
    thread = request.thread,
    ok = false,
    value = message,
  }
end)

local function import_with_callback(path, module_name, callback)
  return emit_script_import(path, module_name, callback, nil)
end

local function import_with_coroutine(path, module_name)
  local thread = coroutine.running()

  if thread == nil then
    error("ScriptAsync import requires a callback or a running coroutine", 3)
  end

  if emit_script_import(path, module_name, nil, thread) == nil then
    return nil, "failed to emit script.import event"
  end

  return coroutine.yield()
end

local function resolve_local_module(module_name)
  local ok, result = pcall(require, module_name)

  if ok then
    return result, nil, true
  end

  return nil, tostring(result), false
end

function ScriptAsync.import(module_name, callback)
  local path
  local result = nil
  local err = nil
  local is_local = false

  if type(module_name) ~= "string" or module_name == "" then
    if type(callback) == "function" then
      callback(nil, "module_name is required")
    end
    return nil
  end

  path = module_name_to_path(module_name)
  if path == nil then
    if type(callback) == "function" then
      callback(nil, "invalid module_name")
      return nil
    end
    return nil, "invalid module_name"
  end

  result, err, is_local = resolve_local_module(module_name)
  if is_local then
    if type(callback) == "function" then
      callback(result, nil)
      return nil
    end
    return result, nil
  end

  if type(callback) == "function" then
    return import_with_callback(path, module_name, callback)
  end

  return import_with_coroutine(path, module_name)
end

function ScriptAsync.import_lua_file(path, module_name, callback)
  local result = nil
  local err = nil
  local is_local = false

  if type(module_name) == "function" and callback == nil then
    callback = module_name
    module_name = nil
  end

  if module_name == nil then
    module_name = path_to_module_name(path)
  end

  if module_name == nil then
    if type(callback) == "function" then
      callback(nil, "invalid lua file path")
      return nil
    end
    return nil, "invalid lua file path"
  end

  result, err, is_local = resolve_local_module(module_name)
  if is_local then
    if type(callback) == "function" then
      callback(result, nil)
      return nil
    end
    return result, nil
  end

  if type(callback) == "function" then
    return import_with_callback(path, module_name, callback)
  end

  return import_with_coroutine(path, module_name)
end

function ScriptAsync.pump()
  while #ready_resumes > 0 do
    local entry = table.remove(ready_resumes, 1)
    local ok = false
    local err = nil

    if entry.thread ~= nil and coroutine.status(entry.thread) ~= "dead" then
      if entry.ok then
        ok, err = coroutine.resume(entry.thread, entry.value, nil)
      else
        ok, err = coroutine.resume(entry.thread, nil, entry.value)
      end

      if not ok then
        log("error", "script import resume failed: " .. tostring(err))
      end
    end
  end
end

function ScriptAsync.import_or_nil(module_name)
  local ok, result = pcall(require, module_name)
  if ok then
    return result
  end

  return nil
end

function ScriptAsync.import_lua_file_or_nil(path)
  local module_name = path_to_module_name(path)
  if module_name == nil then
    return nil
  end

  return ScriptAsync.import_or_nil(module_name)
end

-- Expose the import helpers globally so boot/app code can treat import as the
-- first-class script-loading API instead of reaching through ScriptAsync.
import = ScriptAsync.import
import_lua_file = ScriptAsync.import_lua_file
import_or_nil = ScriptAsync.import_or_nil
import_lua_file_or_nil = ScriptAsync.import_lua_file_or_nil
import_pump = ScriptAsync.pump

return ScriptAsync
