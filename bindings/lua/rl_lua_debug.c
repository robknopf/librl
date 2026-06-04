/* rl_debug.c - Lua debug bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl_debug.h"
#include "rl_lua_debug.h"

static int rl_debug_enable_fps_lua(lua_State *L)
{
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    int font_size = (int)luaL_checkinteger(L, 3);
    rl_handle_t font = 0;

    if (!lua_isnoneornil(L, 4)) {
        font = (rl_handle_t)luaL_checkinteger(L, 4);
    }

    rl_debug_enable_fps(x, y, font_size, font);
    return 0;
}

static int rl_debug_disable_fps_lua(lua_State *L)
{
    (void)L;
    rl_debug_disable_fps();
    return 0;
}

void rl_register_debug_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_debug_enable_fps_lua);
    lua_setfield(L, -2, "debug_enable_fps");

    lua_pushcfunction(L, rl_debug_disable_fps_lua);
    lua_setfield(L, -2, "debug_disable_fps");
}
