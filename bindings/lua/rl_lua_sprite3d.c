/* rl_sprite3d.c - Lua sprite3d bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl_sprite3d.h"
#include "rl_lua_sprite3d.h"

static int rl_sprite3d_get_default_texture_lua(lua_State *L)
{
    lua_pushinteger(L, rl_sprite3d_get_default_texture());
    return 1;
}

static int rl_sprite3d_create_lua(lua_State *L)
{
    rl_handle_t texture = (rl_handle_t)luaL_optinteger(L, 1, 0);
    rl_handle_t handle = rl_sprite3d_create(texture);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite3d_create_from_file_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_sprite3d_create_from_file(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_sprite3d_set_texture_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t texture = (rl_handle_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, rl_sprite3d_set_texture(sprite, texture) ? 1 : 0);
    return 1;
}

static int rl_sprite3d_set_transform_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);
    float size = (float)luaL_checknumber(L, 5);
    rl_sprite3d_set_transform(sprite, x, y, z, size);
    return 0;
}

static int rl_sprite3d_set_tint_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t color = (rl_handle_t)luaL_optinteger(L, 2, 0);
    lua_pushboolean(L, rl_sprite3d_set_tint(sprite, color) ? 1 : 0);
    return 1;
}

static int rl_sprite3d_draw_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_optinteger(L, 2, 0);
    rl_sprite3d_draw(sprite, tint);
    return 0;
}

static int rl_sprite3d_destroy_lua(lua_State *L)
{
    rl_handle_t sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_sprite3d_destroy(sprite);
    return 0;
}

void rl_register_sprite3d_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_sprite3d_get_default_texture_lua);
    lua_setfield(L, -2, "sprite3d_get_default_texture");

    lua_pushcfunction(L, rl_sprite3d_create_lua);
    lua_setfield(L, -2, "sprite3d_create");

    lua_pushcfunction(L, rl_sprite3d_create_from_file_lua);
    lua_setfield(L, -2, "sprite3d_create_from_file");

    lua_pushcfunction(L, rl_sprite3d_set_texture_lua);
    lua_setfield(L, -2, "sprite3d_set_texture");

    lua_pushcfunction(L, rl_sprite3d_set_transform_lua);
    lua_setfield(L, -2, "sprite3d_set_transform");

    lua_pushcfunction(L, rl_sprite3d_set_tint_lua);
    lua_setfield(L, -2, "sprite3d_set_tint");

    lua_pushcfunction(L, rl_sprite3d_draw_lua);
    lua_setfield(L, -2, "sprite3d_draw");

    lua_pushcfunction(L, rl_sprite3d_destroy_lua);
    lua_setfield(L, -2, "sprite3d_destroy");
}
