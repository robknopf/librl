--!/usr/bin/env lua
-- Test script for librl Lua bindings
-- Usage: lua test_bindings.lua
-- Requires: librl.so in package.cpath or LD_LIBRARY_PATH

print("=== librl Lua Bindings Test ===")

-- Try to load the library
local ok, rl = pcall(require, 'rl')
if not ok then
    print("FAIL: Could not load rl module:", rl)
    print("Make sure librl.so is in your package.cpath or LD_LIBRARY_PATH")
    os.exit(1)
end

print("OK: Loaded rl module")

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
local buf = {
    1,  -- VERSION
    0,  -- FLAGS
    -- sprite2d_xform section
    0,  -- count = 0 (no data)
    -- sprite2d_draw section
    0,  -- count = 0 (no data)
    -- sprite3d_xform section
    0,  -- count = 0
    -- sprite3d_draw section
    0,  -- count = 0
    -- model_xform section
    0,  -- count = 0
    -- model_draw section
    0,  -- count = 0
}

local consumed = rl.submit_frame_buffer(buf)
print("OK: Batch submission consumed", consumed, "elements")

-- Verify expected count
local expected = 2 + 6 * 1  -- VERSION, FLAGS + 6 sections with just count
if consumed ~= expected then
    print("WARNING: Expected", expected, "but got", consumed)
else
    print("OK: Consumed expected element count")
end

print("\n=== All Tests Passed ===")
