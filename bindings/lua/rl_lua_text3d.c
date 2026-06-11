/* rl_lua_text3d.c - Lua text3d bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl_text3d.h"
#include "rl_lua_text3d.h"

static int rl_text3d_create_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    float size = (float)luaL_checknumber(L, 2);
    rl_handle_t handle = rl_text3d_create(font, size);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_text3d_set_font_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_text3d_set_font(handle, font);
    return 0;
}

static int rl_text3d_set_size_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    float size = (float)luaL_checknumber(L, 2);
    rl_text3d_set_size(handle, size);
    return 0;
}

static int rl_text3d_set_content_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    const char *content = luaL_checkstring(L, 2);
    rl_text3d_set_content(handle, content);
    return 0;
}

static int rl_text3d_set_transform_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    float x  = (float)luaL_checknumber(L, 2);
    float y  = (float)luaL_checknumber(L, 3);
    float z  = (float)luaL_checknumber(L, 4);
    float rx = (float)luaL_checknumber(L, 5);
    float ry = (float)luaL_checknumber(L, 6);
    float rz = (float)luaL_checknumber(L, 7);
    lua_pushboolean(L, rl_text3d_set_transform(handle, x, y, z, rx, ry, rz) ? 1 : 0);
    return 1;
}

static int rl_text3d_set_color_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_text3d_set_color(handle, color);
    return 0;
}

static int rl_text3d_set_facing_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    int facing = (int)luaL_checkinteger(L, 2);
    lua_pushboolean(L, rl_text3d_set_facing(handle, facing) ? 1 : 0);
    return 1;
}

static int rl_text3d_set_visible_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_text3d_set_visible(handle, lua_toboolean(L, 2) != 0) ? 1 : 0);
    return 1;
}

static int rl_text3d_set_pickable_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_text3d_set_pickable(handle, lua_toboolean(L, 2) != 0) ? 1 : 0);
    return 1;
}

static int rl_text3d_is_visible_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_text3d_is_visible(handle) ? 1 : 0);
    return 1;
}

static int rl_text3d_is_pickable_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_text3d_is_pickable(handle) ? 1 : 0);
    return 1;
}

static int rl_text3d_get_bounds_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    vec2_t bounds = rl_text3d_get_bounds(handle);
    lua_pushnumber(L, bounds.x);
    lua_pushnumber(L, bounds.y);
    return 2;
}

static int rl_text3d_draw_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_text3d_draw(handle);
    return 0;
}

static int rl_text3d_draw_text_lua(lua_State *L)
{
    const char *text = luaL_checkstring(L, 1);
    rl_handle_t font  = (rl_handle_t)luaL_checkinteger(L, 2);
    float x     = (float)luaL_checknumber(L, 3);
    float y     = (float)luaL_checknumber(L, 4);
    float z     = (float)luaL_checknumber(L, 5);
    float size  = (float)luaL_checknumber(L, 6);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_text3d_draw_text(text, font, x, y, z, size, color);
    return 0;
}

static int rl_text3d_destroy_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_text3d_destroy(handle);
    return 0;
}

void rl_register_text3d_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_text3d_create_lua);
    lua_setfield(L, -2, "text3d_create");

    lua_pushcfunction(L, rl_text3d_set_font_lua);
    lua_setfield(L, -2, "text3d_set_font");

    lua_pushcfunction(L, rl_text3d_set_size_lua);
    lua_setfield(L, -2, "text3d_set_size");

    lua_pushcfunction(L, rl_text3d_set_content_lua);
    lua_setfield(L, -2, "text3d_set_content");

    lua_pushcfunction(L, rl_text3d_set_transform_lua);
    lua_setfield(L, -2, "text3d_set_transform");

    lua_pushcfunction(L, rl_text3d_set_color_lua);
    lua_setfield(L, -2, "text3d_set_color");

    lua_pushcfunction(L, rl_text3d_set_facing_lua);
    lua_setfield(L, -2, "text3d_set_facing");

    lua_pushcfunction(L, rl_text3d_set_visible_lua);
    lua_setfield(L, -2, "text3d_set_visible");

    lua_pushcfunction(L, rl_text3d_set_pickable_lua);
    lua_setfield(L, -2, "text3d_set_pickable");

    lua_pushcfunction(L, rl_text3d_is_visible_lua);
    lua_setfield(L, -2, "text3d_is_visible");

    lua_pushcfunction(L, rl_text3d_is_pickable_lua);
    lua_setfield(L, -2, "text3d_is_pickable");

    lua_pushcfunction(L, rl_text3d_get_bounds_lua);
    lua_setfield(L, -2, "text3d_get_bounds");

    lua_pushcfunction(L, rl_text3d_draw_lua);
    lua_setfield(L, -2, "text3d_draw");

    lua_pushcfunction(L, rl_text3d_draw_text_lua);
    lua_setfield(L, -2, "text3d_draw_text");

    lua_pushcfunction(L, rl_text3d_destroy_lua);
    lua_setfield(L, -2, "text3d_destroy");
}
