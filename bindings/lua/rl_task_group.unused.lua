-- Reference: native implementation is bindings/lua/rl_lua_task_group.c (rl.loader_create_task_group).
local rl = require("rl")

local task_group = {}
task_group.__index = task_group

function task_group:new(on_complete, on_error, ctx)
  local group = {
    entries = {},
    callback_context = ctx,
    on_complete_callback = on_complete,
    on_error_callback = on_error,
    terminal_callback_invoked = false,
    failed_count = 0,
    completed_count = 0,
  }
  return setmetatable(group, task_group)
end

function task_group:add_task(task, on_success, on_error)
  if task == nil or task == 0 then
    return
  end
  table.insert(self.entries, {
    task = task,
    path = rl.loader_get_task_path(task),
    done = false,
    rc = 1,
    on_success = on_success,
    on_error = on_error,
  })
end

function task_group:add_import_task(path, on_success, on_error)
  self:add_task(rl.loader_import_asset_async(path), on_success, on_error)
end

function task_group:add_import_tasks(paths, on_success, on_error)
  for _, path in ipairs(paths) do
    self:add_import_task(path, on_success, on_error)
  end
end

function task_group:remaining_tasks()
  return #self.entries - self.completed_count
end

function task_group:is_done()
  return self:remaining_tasks() == 0
end

function task_group:has_failures()
  return self.failed_count > 0
end

function task_group:tick()
  rl.loader_tick()
  for _, entry in ipairs(self.entries) do
    if not entry.done and rl.loader_poll_task(entry.task) then
      entry.rc = rl.loader_finish_task(entry.task)
      rl.loader_free_task(entry.task)
      entry.done = true
      self.completed_count = self.completed_count + 1
      if entry.rc ~= 0 then
        self.failed_count = self.failed_count + 1
        if entry.on_error ~= nil then
          entry.on_error(entry.path, self.callback_context)
        end
      elseif entry.on_success ~= nil then
        entry.on_success(entry.path, self.callback_context)
      end
    end
  end
  return self:remaining_tasks() > 0
end

function task_group:process()
  self:tick()
  if (not self.terminal_callback_invoked) and self:remaining_tasks() == 0 then
    self.terminal_callback_invoked = true
    if self:has_failures() then
      if self.on_error_callback ~= nil then
        self.on_error_callback(self, self.callback_context)
      end
    elseif self.on_complete_callback ~= nil then
      self.on_complete_callback(self, self.callback_context)
    end
  end
  return self:remaining_tasks()
end

function task_group:failed_paths()
  local out = {}
  for _, entry in ipairs(self.entries) do
    if entry.done and entry.rc ~= 0 then
      table.insert(out, entry.path)
    end
  end
  return out
end

return {
  create = function(on_complete, on_error, ctx)
    return task_group:new(on_complete, on_error, ctx)
  end,
}
