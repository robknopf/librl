/* rl_pick.c - Lua pick bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_pick.h"

static void rl_push_pick_result(lua_State *L, rl_pick_result_t result)
{
    lua_newtable(L);

    lua_pushboolean(L, result.hit ? 1 : 0);
    lua_setfield(L, -2, "hit");

    lua_pushnumber(L, result.distance);
    lua_setfield(L, -2, "distance");

    lua_newtable(L);
    lua_pushnumber(L, result.point.x);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, result.point.y);
    lua_setfield(L, -2, "y");
    lua_pushnumber(L, result.point.z);
    lua_setfield(L, -2, "z");
    lua_setfield(L, -2, "point");

    lua_newtable(L);
    lua_pushnumber(L, result.normal.x);
    lua_setfield(L, -2, "x");
    lua_pushnumber(L, result.normal.y);
    lua_setfield(L, -2, "y");
    lua_pushnumber(L, result.normal.z);
    lua_setfield(L, -2, "z");
    lua_setfield(L, -2, "normal");
}

static int rl_pick_model_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 2);
    float mouse_x = (float)luaL_checknumber(L, 3);
    float mouse_y = (float)luaL_checknumber(L, 4);
    float position_x = (float)luaL_checknumber(L, 5);
    float position_y = (float)luaL_checknumber(L, 6);
    float position_z = (float)luaL_checknumber(L, 7);
    float scale = (float)luaL_checknumber(L, 8);
    float rotation_x = (float)luaL_checknumber(L, 9);
    float rotation_y = (float)luaL_checknumber(L, 10);
    float rotation_z = (float)luaL_checknumber(L, 11);

    rl_pick_result_t result = rl_pick_model(camera, model, mouse_x, mouse_y,
                                            position_x, position_y, position_z,
                                            scale, rotation_x, rotation_y, rotation_z);
    rl_push_pick_result(L, result);
    return 1;
}

static int rl_pick_sprite3d_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t sprite3d = (rl_handle_t)luaL_checkinteger(L, 2);
    float mouse_x = (float)luaL_checknumber(L, 3);
    float mouse_y = (float)luaL_checknumber(L, 4);
    float position_x = (float)luaL_checknumber(L, 5);
    float position_y = (float)luaL_checknumber(L, 6);
    float position_z = (float)luaL_checknumber(L, 7);
    float size = (float)luaL_checknumber(L, 8);

    rl_pick_result_t result = rl_pick_sprite3d(camera, sprite3d, mouse_x, mouse_y,
                                               position_x, position_y, position_z, size);
    rl_push_pick_result(L, result);
    return 1;
}

static int rl_pick_reset_stats_lua(lua_State *L)
{
    (void)L;
    rl_pick_reset_stats();
    return 0;
}

static int rl_pick_get_broadphase_tests_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_pick_get_broadphase_tests());
    return 1;
}

static int rl_pick_get_broadphase_rejects_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_pick_get_broadphase_rejects());
    return 1;
}

static int rl_pick_get_narrowphase_tests_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_pick_get_narrowphase_tests());
    return 1;
}

static int rl_pick_get_narrowphase_hits_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_pick_get_narrowphase_hits());
    return 1;
}

void rl_register_pick_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_pick_model_lua);
    lua_setfield(L, -2, "pick_model");

    lua_pushcfunction(L, rl_pick_sprite3d_lua);
    lua_setfield(L, -2, "pick_sprite3d");

    lua_pushcfunction(L, rl_pick_reset_stats_lua);
    lua_setfield(L, -2, "pick_reset_stats");

    lua_pushcfunction(L, rl_pick_get_broadphase_tests_lua);
    lua_setfield(L, -2, "pick_get_broadphase_tests");

    lua_pushcfunction(L, rl_pick_get_broadphase_rejects_lua);
    lua_setfield(L, -2, "pick_get_broadphase_rejects");

    lua_pushcfunction(L, rl_pick_get_narrowphase_tests_lua);
    lua_setfield(L, -2, "pick_get_narrowphase_tests");

    lua_pushcfunction(L, rl_pick_get_narrowphase_hits_lua);
    lua_setfield(L, -2, "pick_get_narrowphase_hits");
}
