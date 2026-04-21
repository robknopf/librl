/* rl_color.c - Lua color bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_color.h"

static int rl_color_create_lua(lua_State *L)
{
    int r = (int)luaL_checkinteger(L, 1);
    int g = (int)luaL_checkinteger(L, 2);
    int b = (int)luaL_checkinteger(L, 3);
    int a = (int)luaL_optinteger(L, 4, 255);
    rl_handle_t handle = rl_color_create(r, g, b, a);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_color_destroy_lua(lua_State *L)
{
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_color_destroy(color);
    return 0;
}

void rl_register_color_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_color_create_lua);
    lua_setfield(L, -2, "color_create");

    lua_pushcfunction(L, rl_color_destroy_lua);
    lua_setfield(L, -2, "color_destroy");

    lua_pushinteger(L, (lua_Integer)RL_COLOR_DEFAULT);
    lua_setfield(L, -2, "RL_COLOR_DEFAULT");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_LIGHTGRAY);
    lua_setfield(L, -2, "RL_COLOR_LIGHTGRAY");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_GRAY);
    lua_setfield(L, -2, "RL_COLOR_GRAY");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_DARKGRAY);
    lua_setfield(L, -2, "RL_COLOR_DARKGRAY");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_YELLOW);
    lua_setfield(L, -2, "RL_COLOR_YELLOW");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_GOLD);
    lua_setfield(L, -2, "RL_COLOR_GOLD");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_ORANGE);
    lua_setfield(L, -2, "RL_COLOR_ORANGE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_PINK);
    lua_setfield(L, -2, "RL_COLOR_PINK");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_RED);
    lua_setfield(L, -2, "RL_COLOR_RED");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_MAROON);
    lua_setfield(L, -2, "RL_COLOR_MAROON");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_GREEN);
    lua_setfield(L, -2, "RL_COLOR_GREEN");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_LIME);
    lua_setfield(L, -2, "RL_COLOR_LIME");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_DARKGREEN);
    lua_setfield(L, -2, "RL_COLOR_DARKGREEN");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_SKYBLUE);
    lua_setfield(L, -2, "RL_COLOR_SKYBLUE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_BLUE);
    lua_setfield(L, -2, "RL_COLOR_BLUE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_DARKBLUE);
    lua_setfield(L, -2, "RL_COLOR_DARKBLUE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_PURPLE);
    lua_setfield(L, -2, "RL_COLOR_PURPLE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_VIOLET);
    lua_setfield(L, -2, "RL_COLOR_VIOLET");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_DARKPURPLE);
    lua_setfield(L, -2, "RL_COLOR_DARKPURPLE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_BEIGE);
    lua_setfield(L, -2, "RL_COLOR_BEIGE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_BROWN);
    lua_setfield(L, -2, "RL_COLOR_BROWN");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_DARKBROWN);
    lua_setfield(L, -2, "RL_COLOR_DARKBROWN");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_WHITE);
    lua_setfield(L, -2, "RL_COLOR_WHITE");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_BLACK);
    lua_setfield(L, -2, "RL_COLOR_BLACK");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_BLANK);
    lua_setfield(L, -2, "RL_COLOR_BLANK");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_MAGENTA);
    lua_setfield(L, -2, "RL_COLOR_MAGENTA");
    lua_pushinteger(L, (lua_Integer)RL_COLOR_RAYWHITE);
    lua_setfield(L, -2, "RL_COLOR_RAYWHITE");
}
