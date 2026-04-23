/* rl_window.c - Lua window bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl_window.h"
#include "rl_lua_window.h"

static int rl_window_set_title_lua(lua_State *L)
{
    const char *title = luaL_checkstring(L, 1);
    rl_window_set_title(title);
    return 0;
}

static int rl_window_set_size_lua(lua_State *L)
{
    int width = (int)luaL_checkinteger(L, 1);
    int height = (int)luaL_checkinteger(L, 2);
    rl_window_set_size(width, height);
    return 0;
}

static int rl_window_get_screen_size_lua(lua_State *L)
{
    vec2_t size = rl_window_get_screen_size();
    lua_pushnumber(L, size.x);
    lua_pushnumber(L, size.y);
    return 2;
}

static int rl_window_get_monitor_count_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_window_get_monitor_count());
    return 1;
}

static int rl_window_get_current_monitor_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_window_get_current_monitor());
    return 1;
}

static int rl_window_set_monitor_lua(lua_State *L)
{
    int monitor = (int)luaL_checkinteger(L, 1);
    rl_window_set_monitor(monitor);
    return 0;
}

static int rl_window_get_monitor_width_lua(lua_State *L)
{
    int monitor = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_window_get_monitor_width(monitor));
    return 1;
}

static int rl_window_get_monitor_height_lua(lua_State *L)
{
    int monitor = (int)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_window_get_monitor_height(monitor));
    return 1;
}

static int rl_window_get_monitor_position_lua(lua_State *L)
{
    int monitor = (int)luaL_checkinteger(L, 1);
    vec2_t pos = rl_window_get_monitor_position(monitor);
    lua_pushnumber(L, pos.x);
    lua_pushnumber(L, pos.y);
    return 2;
}

static int rl_window_get_position_lua(lua_State *L)
{
    vec2_t pos = rl_window_get_position();
    lua_pushnumber(L, pos.x);
    lua_pushnumber(L, pos.y);
    return 2;
}

static int rl_window_set_position_lua(lua_State *L)
{
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    rl_window_set_position(x, y);
    return 0;
}

void rl_register_window_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_window_set_title_lua);
    lua_setfield(L, -2, "window_set_title");

    lua_pushcfunction(L, rl_window_set_size_lua);
    lua_setfield(L, -2, "window_set_size");

    lua_pushcfunction(L, rl_window_get_screen_size_lua);
    lua_setfield(L, -2, "window_get_screen_size");

    lua_pushcfunction(L, rl_window_get_monitor_count_lua);
    lua_setfield(L, -2, "window_get_monitor_count");

    lua_pushcfunction(L, rl_window_get_current_monitor_lua);
    lua_setfield(L, -2, "window_get_current_monitor");

    lua_pushcfunction(L, rl_window_set_monitor_lua);
    lua_setfield(L, -2, "window_set_monitor");

    lua_pushcfunction(L, rl_window_get_monitor_width_lua);
    lua_setfield(L, -2, "window_get_monitor_width");

    lua_pushcfunction(L, rl_window_get_monitor_height_lua);
    lua_setfield(L, -2, "window_get_monitor_height");

    lua_pushcfunction(L, rl_window_get_monitor_position_lua);
    lua_setfield(L, -2, "window_get_monitor_position");

    lua_pushcfunction(L, rl_window_get_position_lua);
    lua_setfield(L, -2, "window_get_position");

    lua_pushcfunction(L, rl_window_set_position_lua);
    lua_setfield(L, -2, "window_set_position");
}
