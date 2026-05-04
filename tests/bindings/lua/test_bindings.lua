--!/usr/bin/env lua
-- Test script for librl Lua bindings
-- Usage: lua test_bindings.lua
-- Optional arg[1]: absolute path to rl module shared object (e.g. /.../lib/rl.so)

print("=== librl Lua Bindings Test ===")

local module_path = arg and arg[1] or nil
if module_path and #module_path > 0 then
    local module_dir = module_path:match("(.+)/[^/]+$")
    if module_dir then
        package.cpath = module_dir .. "/?.so;" .. package.cpath
    end
end

-- Try to load the library
local ok, rl = pcall(require, 'rl')
if not ok then
    if module_path and #module_path > 0 and package.loadlib then
        local loader, load_err = package.loadlib(module_path, "luaopen_rl")
        if not loader then
            print("FAIL: Could not load rl module via package.loadlib:", load_err)
            os.exit(1)
        end
        package.preload["rl"] = loader
        ok, rl = pcall(require, "rl")
    end
    if not ok then
        print("FAIL: Could not load rl module:", rl)
        print("Make sure rl.so is in package.cpath or provide module path as arg[1]")
        os.exit(1)
    end
end

print("OK: Loaded rl module")

if rl.RL_INIT_OK ~= 0 or rl.RL_INIT_ERR_UNKNOWN ~= -1 or rl.RL_INIT_ERR_ALREADY_INITIALIZED ~= -2 then
    print("FAIL: Expected rl init result constants")
    os.exit(1)
end
print("OK: init result constants available")

if type(rl.is_initialized) ~= "function" or rl.is_initialized() ~= false then
    print("FAIL: Expected rl.is_initialized function returning false before init")
    os.exit(1)
end
print("OK: is_initialized available")

if type(rl.get_platform) ~= "function" or (rl.get_platform() ~= "desktop" and rl.get_platform() ~= "web") then
    print("FAIL: Expected rl.get_platform function returning desktop or web")
    os.exit(1)
end
print("OK: get_platform available:", rl.get_platform())

if type(rl.logger_info) ~= "function" then
    print("FAIL: Expected rl.logger_info function")
    os.exit(1)
end
rl.logger_info("lua binding smoke test")
print("OK: logger functions available")

if type(rl.log) ~= "function" then
    print("FAIL: Expected rl.log alias (same as logger_info)")
    os.exit(1)
end
if type(rl.debug) ~= "function" then
    print("FAIL: Expected rl.debug alias (same as logger_debug)")
    os.exit(1)
end
rl.log("logger alias: log")
rl.debug("logger alias: debug")
print("OK: logger log/debug aliases")

if type(rl.loader_create_task_group) ~= "function" then
    print("FAIL: Expected rl.loader_create_task_group (Haxe: RL.loaderCreateTaskGroup)")
    os.exit(1)
end
if type(rl.loader_ping_asset_host) ~= "function" then
    print("FAIL: Expected rl.loader_ping_asset_host function")
    os.exit(1)
end
local g = rl.loader_create_task_group()
if g == nil or type(g.remaining_tasks) ~= "function" then
    print("FAIL: loader_create_task_group should return a group with :remaining_tasks()")
    os.exit(1)
end
print("OK: loader task group (empty remaining:", g:remaining_tasks(), ")")

-- Test color creation
local white = rl.color_create(255, 255, 255, 255)
print("OK: Created color handle:", white)

local red = rl.color_create(255, 0, 0)
print("OK: Created color with default alpha:", red)

-- Test texture creation (requires test asset)
print("\nNOTE: Skipping texture/sprite tests (need assets)")
-- local tex = rl.texture_create("test.png")
-- print("OK: Created texture handle:", tex)

-- Test batch submission format
print("\n=== Batch Submission Format Test ===")
local version, flags = rl.frame_buffer_get_format()
print("OK: frame buffer format version:", version, "flags:", flags)

local include_type_tag = (flags % 4) >= 2 -- RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG (0x02)
local buf = {
    version,
    flags,
}

if include_type_tag then
    -- [type_tag, count] per section
    -- sprite2d_xform, sprite2d_draw, sprite3d_xform, sprite3d_draw, model_xform, model_draw
    table.insert(buf, 10); table.insert(buf, 0)
    table.insert(buf, 11); table.insert(buf, 0)
    table.insert(buf, 12); table.insert(buf, 0)
    table.insert(buf, 13); table.insert(buf, 0)
    table.insert(buf, 14); table.insert(buf, 0)
    table.insert(buf, 15); table.insert(buf, 0)
else
    -- [count] per section
    table.insert(buf, 0)
    table.insert(buf, 0)
    table.insert(buf, 0)
    table.insert(buf, 0)
    table.insert(buf, 0)
    table.insert(buf, 0)
end

local consumed = rl.frame_buffer_submit(buf)
print("OK: Batch submission consumed", consumed, "elements")

-- Verify expected count for empty sections
local expected = include_type_tag and (2 + 6 * 2) or (2 + 6 * 1)
if consumed ~= expected then
    print("WARNING: Expected", expected, "but got", consumed)
else
    print("OK: Consumed expected element count")
end

if rl.RL_TICK_RUNNING ~= 0 or rl.RL_TICK_WAITING ~= 1 or rl.RL_TICK_FAILED ~= -1 then
    print("FAIL: Expected rl.RL_TICK_* tick result constants")
    os.exit(1)
end
if type(rl.tick) ~= "function" then
    print("FAIL: Expected rl.tick function")
    os.exit(1)
end
local tick_rc = rl.tick()
if tick_rc ~= rl.RL_TICK_FAILED then
    print("FAIL: rl.tick before init should return RL_TICK_FAILED, got", tick_rc)
    os.exit(1)
end
print("OK: core tick API and RL_TICK_* constants available")

print("\n=== All Tests Passed ===")
