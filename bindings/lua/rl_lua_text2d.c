/* rl_lua_text2d.c - Lua text2d bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_text2d.h"

static int rl_text2d_create_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    float size = (float)luaL_checknumber(L, 2);
    rl_handle_t handle = rl_text2d_create(font, size);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_text2d_set_font_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_text2d_set_font(handle, font);
    return 0;
}

static int rl_text2d_set_size_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    float size = (float)luaL_checknumber(L, 2);
    rl_text2d_set_size(handle, size);
    return 0;
}

static int rl_text2d_set_content_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    const char *content = luaL_checkstring(L, 2);
    rl_text2d_set_content(handle, content);
    return 0;
}

static int rl_text2d_set_position_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    rl_text2d_set_position(handle, x, y);
    return 0;
}

static int rl_text2d_set_color_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_text2d_set_color(handle, color);
    return 0;
}

static int rl_text2d_draw_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_text2d_draw(handle);
    return 0;
}

static int rl_text2d_destroy_lua(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_text2d_destroy(handle);
    return 0;
}

void rl_register_text2d_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_text2d_create_lua);
    lua_setfield(L, -2, "text2d_create");

    lua_pushcfunction(L, rl_text2d_set_font_lua);
    lua_setfield(L, -2, "text2d_set_font");

    lua_pushcfunction(L, rl_text2d_set_size_lua);
    lua_setfield(L, -2, "text2d_set_size");

    lua_pushcfunction(L, rl_text2d_set_content_lua);
    lua_setfield(L, -2, "text2d_set_content");

    lua_pushcfunction(L, rl_text2d_set_position_lua);
    lua_setfield(L, -2, "text2d_set_position");

    lua_pushcfunction(L, rl_text2d_set_color_lua);
    lua_setfield(L, -2, "text2d_set_color");

    lua_pushcfunction(L, rl_text2d_draw_lua);
    lua_setfield(L, -2, "text2d_draw");

    lua_pushcfunction(L, rl_text2d_destroy_lua);
    lua_setfield(L, -2, "text2d_destroy");
}
