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

if rl.INIT_OK ~= 0 or rl.INIT_ERR_UNKNOWN ~= -1 or rl.INIT_ERR_ALREADY_INITIALIZED ~= -2 then
    print("FAIL: Expected rl init result constants")
    os.exit(1)
end
print("OK: init result constants available")

if rl.BOOT_OK ~= 0 or rl.BOOT_ERR_UNKNOWN ~= -10 or rl.BOOT_ERR_LOADER ~= -11 or rl.BOOT_ERR_VERSION_MISMATCH ~= -12 then
    print("FAIL: Expected rl boot result constants")
    os.exit(1)
end
if rl.boot() ~= rl.BOOT_OK then
    print("FAIL: rl.boot() should return BOOT_OK")
    os.exit(1)
end
print("OK: boot result constants and rl.boot()")

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

if type(rl.asset_create_task_group) ~= "function" then
    print("FAIL: Expected rl.asset_create_task_group (Haxe: RL.fileioCreateTaskGroup)")
    os.exit(1)
end
if type(rl.asset_ping_host) ~= "function" then
    print("FAIL: Expected rl.asset_ping_host function")
    os.exit(1)
end
if type(rl.asset_ensure) ~= "function" then
    print("FAIL: Expected rl.asset_ensure function")
    os.exit(1)
end
local g = rl.asset_create_task_group()
if g == nil or type(g.remaining_tasks) ~= "function" then
    print("FAIL: asset_create_task_group should return a group with :remaining_tasks()")
    os.exit(1)
end
print("OK: fileio task group (empty remaining:", g:remaining_tasks(), ")")

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

if rl.TICK_RUNNING ~= 0 or rl.TICK_WAITING ~= 1 or rl.TICK_FAILED ~= -1 then
    print("FAIL: Expected rl.TICK_* tick result constants")
    os.exit(1)
end
if type(rl.tick) ~= "function" then
    print("FAIL: Expected rl.tick function")
    os.exit(1)
end
local tick_rc = rl.tick()
if tick_rc ~= rl.TICK_FAILED then
    print("FAIL: rl.tick before init should return TICK_FAILED, got", tick_rc)
    os.exit(1)
end
print("OK: core tick API and TICK_* constants available")

-- Test text2d API availability
print("\n=== Text2D API Test ===")
local text2d_fns = {"text2d_create","text2d_set_font","text2d_set_size","text2d_set_content","text2d_set_position","text2d_set_color","text2d_draw","text2d_destroy"}
for _, fn in ipairs(text2d_fns) do
    if type(rl[fn]) ~= "function" then
        print("FAIL: expected rl." .. fn .. " to be a function")
        os.exit(1)
    end
end
-- lifecycle: requires rl.init() to initialize the handle pool
if rl.boot() ~= rl.BOOT_OK then
    print("FAIL: rl.boot() failed before text2d lifecycle test")
    os.exit(1)
end
if rl.init() ~= rl.INIT_OK then
    print("FAIL: rl.init() failed before text2d lifecycle test")
    os.exit(1)
end
local label = rl.text2d_create(rl.font_get_default(), 16)
if label == 0 then
    print("FAIL: text2d_create returned 0")
    rl.deinit()
    os.exit(1)
end
rl.text2d_set_content(label, "hello text2d")
rl.text2d_set_position(label, 10, 20)
rl.text2d_set_color(label, 0)
rl.text2d_set_size(label, 24)
rl.text2d_set_font(label, rl.font_get_default())
rl.text2d_destroy(label)
rl.deinit()
print("OK: text2d API available and lifecycle works")

-- Test text3d API availability
print("\n=== Text3D API Test ===")
local text3d_fns = {"text3d_create","text3d_set_font","text3d_set_size","text3d_set_content","text3d_set_transform","text3d_set_color","text3d_set_facing","text3d_set_visible","text3d_set_pickable","text3d_is_visible","text3d_is_pickable","text3d_get_bounds","text3d_draw","text3d_draw_text","text3d_destroy"}
for _, fn in ipairs(text3d_fns) do
    if type(rl[fn]) ~= "function" then
        print("FAIL: expected rl." .. fn .. " to be a function")
        os.exit(1)
    end
end
if rl.boot() ~= rl.BOOT_OK then
    print("FAIL: rl.boot() failed before text3d lifecycle test")
    os.exit(1)
end
if rl.init() ~= rl.INIT_OK then
    print("FAIL: rl.init() failed before text3d lifecycle test")
    os.exit(1)
end
local t3 = rl.text3d_create(rl.font_get_default(), 1.0)
if t3 == 0 then
    print("FAIL: text3d_create returned 0")
    rl.deinit()
    os.exit(1)
end
rl.text3d_set_content(t3, "hello 3d")
rl.text3d_set_transform(t3, 0, 1, 0, 0, 0, 0)
rl.text3d_set_color(t3, 0)
rl.text3d_set_size(t3, 2.0)
rl.text3d_set_font(t3, rl.font_get_default())
rl.text3d_set_facing(t3, 0)
rl.text3d_set_visible(t3, true)
rl.text3d_set_pickable(t3, true)
if not rl.text3d_is_visible(t3) then
    print("FAIL: text3d_is_visible should be true")
    rl.deinit()
    os.exit(1)
end
if not rl.text3d_is_pickable(t3) then
    print("FAIL: text3d_is_pickable should be true")
    rl.deinit()
    os.exit(1)
end
rl.text3d_destroy(t3)
rl.deinit()
print("OK: text3d API available and lifecycle works")

print("\n=== All Tests Passed ===")
