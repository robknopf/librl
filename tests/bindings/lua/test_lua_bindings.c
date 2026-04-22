/*
 * test_lua_bindings.c - Simple test for Lua bindings
 * Builds a Lua interpreter with librl bindings embedded
 */

#include <stdio.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

/* Lua 5.1 compatibility: LUA_OK was added in 5.2 */
#ifndef LUA_OK
#define LUA_OK 0
#endif

/* Forward declaration from rl_lua.c */
int luaopen_rl(lua_State *L);

int main(int argc, char *argv[])
{
    (void)argc;
    (void)argv;
    lua_State *L;
    int status;

    printf("=== librl Lua Bindings Test ===\n\n");

    /* Create Lua state */
    L = luaL_newstate();
    if (!L) {
        fprintf(stderr, "Error: Cannot create Lua state\n");
        return 1;
    }

    luaL_openlibs(L);
    printf("OK: Lua state created and standard libraries loaded\n");

    /* Load rl bindings */
    lua_pushcfunction(L, luaopen_rl);
    lua_call(L, 0, 1);
    lua_setglobal(L, "rl");
    printf("OK: rl bindings loaded\n");

    /* Test 1: Check rl table exists */
    status = luaL_dostring(L, "print('rl table:', type(rl))");
    if (status != LUA_OK) {
        fprintf(stderr, "Error: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 2: Create and destroy colors */
    status = luaL_dostring(L,
        "local white = rl.color_create(255, 255, 255, 255)\n"
        "print('OK: Created white color with handle:', white)\n"
        "local red = rl.color_create(255, 0, 0)\n"
        "print('OK: Created red color with default alpha, handle:', red)\n"
        "rl.color_destroy(white)\n"
        "rl.color_destroy(red)\n"
        "print('OK: Destroyed both colors')"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error with colors: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 3: Query frame buffer format */
    status = luaL_dostring(L,
        "local version, flags = rl.get_frame_buffer_format()\n"
        "print('OK: Frame buffer format - version:', version, 'flags:', flags)\n"
        "if version == 1 then\n"
        "    print('OK: Version 1 supported')\n"
        "end\n"
        "if flags == 2 then\n"
        "    print('OK: type_tag enabled (RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG)')\n"
        "elseif flags == 0 then\n"
        "    print('OK: type_tag disabled (fast mode)')\n"
        "end"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error querying format: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 4: Batch submission - use queried format */
    status = luaL_dostring(L,
        "local buf = {\n"
        "    1,   -- VERSION\n"
        "    2,   -- type_tag flag (RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG)\n"
        "    10,  -- TYPE_SPRITE2D_XFORM\n"
        "    0,   -- count\n"
        "    11,  -- TYPE_SPRITE2D_DRAW\n"
        "    0,   -- count\n"
        "    12,  -- TYPE_SPRITE3D_XFORM\n"
        "    0,   -- count\n"
        "    13,  -- TYPE_SPRITE3D_DRAW\n"
        "    0,   -- count\n"
        "    14,  -- TYPE_MODEL_XFORM\n"
        "    0,   -- count\n"
        "    15,  -- TYPE_MODEL_DRAW\n"
        "    0,   -- count\n"
        "}\n"
        "local consumed = rl.submit_frame_buffer(buf)\n"
        "print('OK: Type-included mode consumed', consumed, 'elements')\n"
        "if consumed == 14 then\n"
        "    print('OK: Type-included mode element count correct (2 header + 6*[type+count])')\n"
        "else\n"
        "    print('WARNING: Expected 14 but got', consumed)\n"
        "end"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error in batch submission (type-included mode): %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 5: Stride verification - pack actual data with type_tag */
    status = luaL_dostring(L,
        "local white = rl.color_create(255, 255, 255, 255)\n"
        "local sprite = rl.sprite2d_create('test.png')  -- will fail but gives us a handle\n"
        "local buf = {\n"
        "    1,        -- VERSION\n"
        "    2,        -- type_tag flag (RL_SUBMIT_FLAG_INCLUDES_TYPE_TAG)\n"
        "    10,       -- TYPE_SPRITE2D_XFORM\n"
        "    1,        -- sprite2d_xform count = 1\n"
        "    sprite,   -- handle\n"
        "    white,    -- tint\n"
        "    100,      -- x\n"
        "    200,      -- y\n"
        "    1.5,      -- scale\n"
        "    45,       -- rotation\n"
        "    11,       -- TYPE_SPRITE2D_DRAW\n"
        "    1,        -- sprite2d_draw count = 1\n"
        "    sprite,   -- handle\n"
        "    white,    -- tint\n"
        "    12, 0,    -- TYPE_SPRITE3D_XFORM, count=0\n"
        "    13, 0,    -- TYPE_SPRITE3D_DRAW, count=0\n"
        "    14, 0,    -- TYPE_MODEL_XFORM, count=0\n"
        "    15, 0,    -- TYPE_MODEL_DRAW, count=0\n"
        "}\n"
        "local consumed = rl.submit_frame_buffer(buf)\n"
        "print('OK: Stride test consumed', consumed, 'elements')\n"
        "-- Expected: 2 header + 6*[type+count] + 6+2 (data) = 22\n"
        "if consumed == 22 then\n"
        "    print('OK: Stride verification passed (strides: xform=6, draw=2)')\n"
        "else\n"
        "    print('WARNING: Expected 22 but got', consumed)\n"
        "end\n"
        "rl.color_destroy(white)"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error in stride verification: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 6: Check available functions */
    status = luaL_dostring(L,
        "local functions = {}\n"
        "for k, v in pairs(rl) do\n"
        "    if type(v) == 'function' then\n"
        "        table.insert(functions, k)\n"
        "    end\n"
        "end\n"
        "table.sort(functions)\n"
        "print('')\n"
        "print('Available functions:')\n"
        "for _, name in ipairs(functions) do\n"
        "    print('  - ' .. name)\n"
        "end\n"
        "print('')\n"
        "print('Total functions: ' .. #functions)"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error listing functions: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    printf("\n=== All Tests Completed ===\n");

    lua_close(L);
    return 0;
}
