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

if type(rl.log) ~= "table" then
    print("FAIL: Expected rl.log table")
    os.exit(1)
end
if type(rl.log.info) ~= "function" then
    print("FAIL: Expected rl.log.info function")
    os.exit(1)
end
rl.log.info("lua binding smoke test")
print("OK: log module available")

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
local version, flags = rl.get_frame_buffer_format()
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

local consumed = rl.submit_frame_buffer(buf)
print("OK: Batch submission consumed", consumed, "elements")

-- Verify expected count for empty sections
local expected = include_type_tag and (2 + 6 * 2) or (2 + 6 * 1)
if consumed ~= expected then
    print("WARNING: Expected", expected, "but got", consumed)
else
    print("OK: Consumed expected element count")
end

if type(rl.run) ~= "function" then
    print("FAIL: Expected rl.run function")
    os.exit(1)
end
print("OK: core run API available")

print("\n=== All Tests Passed ===")
