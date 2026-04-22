/* rl_model.c - Lua model bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_model.h"

static int rl_model_create_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_handle_t handle = rl_model_create(filename);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_model_set_transform_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    float x = (float)luaL_checknumber(L, 2);
    float y = (float)luaL_checknumber(L, 3);
    float z = (float)luaL_checknumber(L, 4);
    float rot_x = (float)luaL_checknumber(L, 5);
    float rot_y = (float)luaL_checknumber(L, 6);
    float rot_z = (float)luaL_checknumber(L, 7);
    float scale_x = (float)luaL_checknumber(L, 8);
    float scale_y = (float)luaL_checknumber(L, 9);
    float scale_z = (float)luaL_checknumber(L, 10);
    rl_model_set_transform(model, x, y, z, rot_x, rot_y, rot_z, scale_x, scale_y, scale_z);
    return 0;
}

static int rl_model_draw_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t tint = (rl_handle_t)luaL_optinteger(L, 2, 0);
    rl_model_draw(model, tint);
    return 0;
}

static int rl_model_is_valid_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_model_is_valid(model) ? 1 : 0);
    return 1;
}

static int rl_model_is_valid_strict_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_model_is_valid_strict(model) ? 1 : 0);
    return 1;
}

static int rl_model_animation_count_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_model_animation_count(model));
    return 1;
}

static int rl_model_animation_frame_count_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    int animation_index = (int)luaL_checkinteger(L, 2);
    lua_pushinteger(L, rl_model_animation_frame_count(model, animation_index));
    return 1;
}

static int rl_model_animation_update_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    int animation_index = (int)luaL_checkinteger(L, 2);
    int frame = (int)luaL_checkinteger(L, 3);
    rl_model_animation_update(model, animation_index, frame);
    return 0;
}

static int rl_model_set_animation_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    int animation_index = (int)luaL_checkinteger(L, 2);
    lua_pushboolean(L, rl_model_set_animation(model, animation_index) ? 1 : 0);
    return 1;
}

static int rl_model_set_animation_speed_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    float speed = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_model_set_animation_speed(model, speed) ? 1 : 0);
    return 1;
}

static int rl_model_set_animation_loop_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    int should_loop = lua_toboolean(L, 2);
    lua_pushboolean(L, rl_model_set_animation_loop(model, should_loop != 0) ? 1 : 0);
    return 1;
}

static int rl_model_animate_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    float delta_seconds = (float)luaL_checknumber(L, 2);
    lua_pushboolean(L, rl_model_animate(model, delta_seconds) ? 1 : 0);
    return 1;
}

static int rl_model_destroy_lua(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_model_destroy(model);
    return 0;
}

void rl_register_model_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_model_create_lua);
    lua_setfield(L, -2, "model_create");

    lua_pushcfunction(L, rl_model_set_transform_lua);
    lua_setfield(L, -2, "model_set_transform");

    lua_pushcfunction(L, rl_model_draw_lua);
    lua_setfield(L, -2, "model_draw");

    lua_pushcfunction(L, rl_model_is_valid_lua);
    lua_setfield(L, -2, "model_is_valid");

    lua_pushcfunction(L, rl_model_is_valid_strict_lua);
    lua_setfield(L, -2, "model_is_valid_strict");

    lua_pushcfunction(L, rl_model_animation_count_lua);
    lua_setfield(L, -2, "model_animation_count");

    lua_pushcfunction(L, rl_model_animation_frame_count_lua);
    lua_setfield(L, -2, "model_animation_frame_count");

    lua_pushcfunction(L, rl_model_animation_update_lua);
    lua_setfield(L, -2, "model_animation_update");

    lua_pushcfunction(L, rl_model_set_animation_lua);
    lua_setfield(L, -2, "model_set_animation");

    lua_pushcfunction(L, rl_model_set_animation_speed_lua);
    lua_setfield(L, -2, "model_set_animation_speed");

    lua_pushcfunction(L, rl_model_set_animation_loop_lua);
    lua_setfield(L, -2, "model_set_animation_loop");

    lua_pushcfunction(L, rl_model_animate_lua);
    lua_setfield(L, -2, "model_animate");

    lua_pushcfunction(L, rl_model_destroy_lua);
    lua_setfield(L, -2, "model_destroy");
}
