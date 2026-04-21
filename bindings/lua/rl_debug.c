/* rl_debug.c - Lua debug bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_debug.h"

static int rl_debug_enable_fps_lua(lua_State *L)
{
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    int font_size = (int)luaL_checkinteger(L, 3);
    const char *font_path = luaL_checkstring(L, 4);
    rl_debug_enable_fps(x, y, font_size, font_path);
    return 0;
}

static int rl_debug_disable_lua(lua_State *L)
{
    (void)L;
    rl_debug_disable();
    return 0;
}

void rl_register_debug_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_debug_enable_fps_lua);
    lua_setfield(L, -2, "debug_enable_fps");

    lua_pushcfunction(L, rl_debug_disable_lua);
    lua_setfield(L, -2, "debug_disable");
}
