/* rl_texture.c - Lua texture bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_texture.h"

static int rl_texture_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_texture_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_texture_destroy_lua(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_texture_destroy(texture);
    return 0;
}

static int rl_texture_draw_ex_lua(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float scale = (float)luaL_checknumber(L, 4);
    float rotation = (float)luaL_checknumber(L, 5);
    rl_handle_t tint = (rl_handle_t)luaL_checkinteger(L, 6);
    rl_texture_draw_ex(texture, x, y, scale, rotation, tint);
    return 0;
}

static int rl_texture_draw_ground_lua(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    float position_x = (float)luaL_checknumber(L, 2);
    float position_y = (float)luaL_checknumber(L, 3);
    float position_z = (float)luaL_checknumber(L, 4);
    float width = (float)luaL_checknumber(L, 5);
    float length = (float)luaL_checknumber(L, 6);
    rl_handle_t tint = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_texture_draw_ground(texture, position_x, position_y, position_z, width, length, tint);
    return 0;
}

void rl_register_texture_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_texture_create_lua);
    lua_setfield(L, -2, "texture_create");

    lua_pushcfunction(L, rl_texture_destroy_lua);
    lua_setfield(L, -2, "texture_destroy");

    lua_pushcfunction(L, rl_texture_draw_ex_lua);
    lua_setfield(L, -2, "texture_draw_ex");

    lua_pushcfunction(L, rl_texture_draw_ground_lua);
    lua_setfield(L, -2, "texture_draw_ground");
}
