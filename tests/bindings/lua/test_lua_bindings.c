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

/* Forward declaration from lua_rl.c */
int luaopen_rl(lua_State *L);

int main(int argc, char *argv[])
{
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

    /* Test 2: Create a color */
    status = luaL_dostring(L,
        "local white = rl.color_create(255, 255, 255, 255)\n"
        "print('OK: Created white color with handle:', white)\n"
        "local red = rl.color_create(255, 0, 0)\n"
        "print('OK: Created red color with default alpha, handle:', red)"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error creating colors: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 3: Batch submission with empty buffer */
    status = luaL_dostring(L,
        "local buf = {\n"
        "    1,  -- VERSION\n"
        "    0,  -- FLAGS\n"
        "    0,  -- sprite2d_xform count\n"
        "    0,  -- sprite2d_draw count\n"
        "    0,  -- sprite3d_xform count\n"
        "    0,  -- sprite3d_draw count\n"
        "    0,  -- model_xform count\n"
        "    0,  -- model_draw count\n"
        "}\n"
        "local consumed = rl.submit_frame_buffer(buf)\n"
        "print('OK: Batch submission consumed', consumed, 'elements')\n"
        "if consumed == 8 then\n"
        "    print('OK: Consumed expected element count')\n"
        "else\n"
        "    print('WARNING: Expected 8 but got', consumed)\n"
        "end"
    );
    if (status != LUA_OK) {
        fprintf(stderr, "Error in batch submission: %s\n", lua_tostring(L, -1));
        lua_pop(L, 1);
    }

    /* Test 4: Check available functions */
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
