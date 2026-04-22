/* rl_music.c - Lua music bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_music.h"

static int rl_music_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_music_create(filename));
    return 1;
}

static int rl_music_destroy_lua(lua_State *L)
{
    rl_music_destroy((rl_handle_t)luaL_checkinteger(L, 1));
    return 0;
}

static int rl_music_play_lua(lua_State *L)
{
    lua_pushboolean(L, rl_music_play((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_music_pause_lua(lua_State *L)
{
    lua_pushboolean(L, rl_music_pause((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_music_stop_lua(lua_State *L)
{
    lua_pushboolean(L, rl_music_stop((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_music_set_loop_lua(lua_State *L)
{
    rl_handle_t music = (rl_handle_t)luaL_checkinteger(L, 1);
    int should_loop = lua_toboolean(L, 2);
    lua_pushboolean(L, rl_music_set_loop(music, should_loop != 0) ? 1 : 0);
    return 1;
}

static int rl_music_set_volume_lua(lua_State *L)
{
    rl_handle_t music = (rl_handle_t)luaL_checkinteger(L, 1);
    float volume = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_music_set_volume(music, volume) ? 1 : 0);
    return 1;
}

static int rl_music_is_playing_lua(lua_State *L)
{
    lua_pushboolean(L, rl_music_is_playing((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_music_update_lua(lua_State *L)
{
    lua_pushboolean(L, rl_music_update((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_music_update_all_lua(lua_State *L)
{
    (void)L;
    rl_music_update_all();
    return 0;
}

void rl_register_music_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_music_create_lua);
    lua_setfield(L, -2, "music_create");
    lua_pushcfunction(L, rl_music_destroy_lua);
    lua_setfield(L, -2, "music_destroy");
    lua_pushcfunction(L, rl_music_play_lua);
    lua_setfield(L, -2, "music_play");
    lua_pushcfunction(L, rl_music_pause_lua);
    lua_setfield(L, -2, "music_pause");
    lua_pushcfunction(L, rl_music_stop_lua);
    lua_setfield(L, -2, "music_stop");
    lua_pushcfunction(L, rl_music_set_loop_lua);
    lua_setfield(L, -2, "music_set_loop");
    lua_pushcfunction(L, rl_music_set_volume_lua);
    lua_setfield(L, -2, "music_set_volume");
    lua_pushcfunction(L, rl_music_is_playing_lua);
    lua_setfield(L, -2, "music_is_playing");
    lua_pushcfunction(L, rl_music_update_lua);
    lua_setfield(L, -2, "music_update");
    lua_pushcfunction(L, rl_music_update_all_lua);
    lua_setfield(L, -2, "music_update_all");
}
