local ResourceAsync = {}

local next_rid = 1
local pending = {}

local function parse_loaded_payload(payload)
  local rid = tonumber(payload)
  if rid == nil then
    return nil
  end
  return rid
end

local function parse_error_payload(payload)
  local text = tostring(payload or "")
  local sep = string.find(text, "|", 1, true)
  if sep == nil then
    return tonumber(text), "resource load failed"
  end

  local rid = tonumber(string.sub(text, 1, sep - 1))
  local message = string.sub(text, sep + 1)
  if message == "" then
    message = "resource load failed"
  end
  return rid, message
end

event_on("resource.loaded", function(payload)
  local rid = parse_loaded_payload(payload)
  local request = rid ~= nil and pending[rid] or nil
  local resource = nil

  if request == nil then
    return
  end

  pending[rid] = nil
  resource = request.resolve()
  if resource == nil then
    request.callback(nil, "resource create failed")
    return
  end

  request.callback(resource, nil)
end)

event_on("resource.error", function(payload)
  local rid, message = parse_error_payload(payload)
  local request = rid ~= nil and pending[rid] or nil

  if request == nil then
    return
  end

  pending[rid] = nil
  request.callback(nil, message)
end)

function ResourceAsync.request(kind, path, options, resolve, callback)
  local rid = next_rid
  local parts = nil

  if type(callback) ~= "function" then
    return nil
  end

  next_rid = next_rid + 1
  pending[rid] = {
    resolve = resolve,
    callback = callback,
  }

  parts = { tostring(rid), tostring(kind), tostring(path) }
  if options ~= nil and options.size ~= nil then
    parts[#parts + 1] = tostring(options.size)
  end

  if not event_emit("resource.load", table.concat(parts, "|")) then
    pending[rid] = nil
    callback(nil, "resource request emit failed")
    return nil
  end

  return rid
end

return ResourceAsync
