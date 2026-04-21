/* rl_sprite2d.c - Lua sprite2d bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_sprite2d.h"

static int rl_sprite2d_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_sprite2d_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite2d_create_from_texture_lua(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t handle = rl_sprite2d_create_from_texture(texture);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite2d_set_transform_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float scale = (float)luaL_checknumber(L, 4);
    float rotation = (float)luaL_checknumber(L, 5);
    rl_sprite2d_set_transform(sprite, x, y, scale, rotation);
    return 0;
}

static int rl_sprite2d_draw_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_sprite2d_draw(sprite, tint);
    return 0;
}

static int rl_sprite2d_destroy_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_sprite2d_destroy(sprite);
    return 0;
}

void rl_register_sprite2d_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_sprite2d_create_lua);
    lua_setfield(L, -2, "sprite2d_create");

    lua_pushcfunction(L, rl_sprite2d_create_from_texture_lua);
    lua_setfield(L, -2, "sprite2d_create_from_texture");

    lua_pushcfunction(L, rl_sprite2d_set_transform_lua);
    lua_setfield(L, -2, "sprite2d_set_transform");

    lua_pushcfunction(L, rl_sprite2d_draw_lua);
    lua_setfield(L, -2, "sprite2d_draw");

    lua_pushcfunction(L, rl_sprite2d_destroy_lua);
    lua_setfield(L, -2, "sprite2d_destroy");
}
