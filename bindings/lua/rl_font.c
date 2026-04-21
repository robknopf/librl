/* rl_font.c - Lua font bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_font.h"

static int rl_font_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    float font_size = (float)luaL_checknumber(L, 2);
    rl_handle_t handle = rl_font_create(filename, font_size);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_font_destroy_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_font_destroy(font);
    return 0;
}

static int rl_font_get_default_lua(lua_State *L)
{
    lua_pushinteger(L, rl_font_get_default());
    return 1;
}

void rl_register_font_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_font_create_lua);
    lua_setfield(L, -2, "font_create");

    lua_pushcfunction(L, rl_font_destroy_lua);
    lua_setfield(L, -2, "font_destroy");

    lua_pushcfunction(L, rl_font_get_default_lua);
    lua_setfield(L, -2, "font_get_default");
}
