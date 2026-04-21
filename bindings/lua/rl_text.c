/* rl_text.c - Lua text bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_text.h"

static int rl_text_draw_fps_lua(lua_State *L)
{
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    rl_text_draw_fps(x, y);
    return 0;
}

static int rl_text_draw_fps_ex_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    int x = (int)luaL_checkinteger(L, 2);
    int y = (int)luaL_checkinteger(L, 3);
    int font_size = (int)luaL_checkinteger(L, 4);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 5);
    rl_text_draw_fps_ex(font, x, y, font_size, color);
    return 0;
}

static int rl_text_draw_lua(lua_State *L)
{
    const char *text = luaL_checkstring(L, 1);
    int x = (int)luaL_checkinteger(L, 2);
    int y = (int)luaL_checkinteger(L, 3);
    int font_size = (int)luaL_checkinteger(L, 4);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 5);
    rl_text_draw(text, x, y, font_size, color);
    return 0;
}

static int rl_text_draw_ex_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    const char *text = luaL_checkstring(L, 2);
    int x = (int)luaL_checkinteger(L, 3);
    int y = (int)luaL_checkinteger(L, 4);
    float font_size = (float)luaL_checknumber(L, 5);
    float spacing = (float)luaL_checknumber(L, 6);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_text_draw_ex(font, text, x, y, font_size, spacing, color);
    return 0;
}

static int rl_text_measure_lua(lua_State *L)
{
    const char *text = luaL_checkstring(L, 1);
    int font_size = (int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, rl_text_measure(text, font_size));
    return 1;
}

static int rl_text_measure_ex_lua(lua_State *L)
{
    rl_handle_t font = (rl_handle_t)luaL_checkinteger(L, 1);
    const char *text = luaL_checkstring(L, 2);
    float font_size = (float)luaL_checknumber(L, 3);
    float spacing = (float)luaL_checknumber(L, 4);
    vec2_t size = rl_text_measure_ex(font, text, font_size, spacing);
    lua_pushnumber(L, size.x);
    lua_pushnumber(L, size.y);
    return 2;
}

void rl_register_text_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_text_draw_fps_lua);
    lua_setfield(L, -2, "text_draw_fps");

    lua_pushcfunction(L, rl_text_draw_fps_ex_lua);
    lua_setfield(L, -2, "text_draw_fps_ex");

    lua_pushcfunction(L, rl_text_draw_lua);
    lua_setfield(L, -2, "text_draw");

    lua_pushcfunction(L, rl_text_draw_ex_lua);
    lua_setfield(L, -2, "text_draw_ex");

    lua_pushcfunction(L, rl_text_measure_lua);
    lua_setfield(L, -2, "text_measure");

    lua_pushcfunction(L, rl_text_measure_ex_lua);
    lua_setfield(L, -2, "text_measure_ex");
}
