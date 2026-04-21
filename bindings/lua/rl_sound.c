/* rl_sound.c - Lua sound bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_sound.h"

static int rl_sound_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_sound_create(filename));
    return 1;
}

static int rl_sound_destroy_lua(lua_State *L)
{
    rl_sound_destroy((rl_handle_t)luaL_checkinteger(L, 1));
    return 0;
}

static int rl_sound_play_lua(lua_State *L)
{
    lua_pushboolean(L, rl_sound_play((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_sound_pause_lua(lua_State *L)
{
    lua_pushboolean(L, rl_sound_pause((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_sound_resume_lua(lua_State *L)
{
    lua_pushboolean(L, rl_sound_resume((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_sound_stop_lua(lua_State *L)
{
    lua_pushboolean(L, rl_sound_stop((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

static int rl_sound_set_volume_lua(lua_State *L)
{
    rl_handle_t sound = (rl_handle_t)luaL_checkinteger(L, 1);
    float volume = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_sound_set_volume(sound, volume) ? 1 : 0);
    return 1;
}

static int rl_sound_set_pitch_lua(lua_State *L)
{
    rl_handle_t sound = (rl_handle_t)luaL_checkinteger(L, 1);
    float pitch = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_sound_set_pitch(sound, pitch) ? 1 : 0);
    return 1;
}

static int rl_sound_set_pan_lua(lua_State *L)
{
    rl_handle_t sound = (rl_handle_t)luaL_checkinteger(L, 1);
    float pan = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_sound_set_pan(sound, pan) ? 1 : 0);
    return 1;
}

static int rl_sound_is_playing_lua(lua_State *L)
{
    lua_pushboolean(L, rl_sound_is_playing((rl_handle_t)luaL_checkinteger(L, 1)) ? 1 : 0);
    return 1;
}

void rl_register_sound_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_sound_create_lua);
    lua_setfield(L, -2, "sound_create");
    lua_pushcfunction(L, rl_sound_destroy_lua);
    lua_setfield(L, -2, "sound_destroy");
    lua_pushcfunction(L, rl_sound_play_lua);
    lua_setfield(L, -2, "sound_play");
    lua_pushcfunction(L, rl_sound_pause_lua);
    lua_setfield(L, -2, "sound_pause");
    lua_pushcfunction(L, rl_sound_resume_lua);
    lua_setfield(L, -2, "sound_resume");
    lua_pushcfunction(L, rl_sound_stop_lua);
    lua_setfield(L, -2, "sound_stop");
    lua_pushcfunction(L, rl_sound_set_volume_lua);
    lua_setfield(L, -2, "sound_set_volume");
    lua_pushcfunction(L, rl_sound_set_pitch_lua);
    lua_setfield(L, -2, "sound_set_pitch");
    lua_pushcfunction(L, rl_sound_set_pan_lua);
    lua_setfield(L, -2, "sound_set_pan");
    lua_pushcfunction(L, rl_sound_is_playing_lua);
    lua_setfield(L, -2, "sound_is_playing");
}
