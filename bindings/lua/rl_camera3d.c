/* rl_camera3d.c - Lua camera3d bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_camera3d.h"

static int rl_camera3d_create_lua(lua_State *L)
{
    float pos_x = (float)luaL_checknumber(L, 1);
    float pos_y = (float)luaL_checknumber(L, 2);
    float pos_z = (float)luaL_checknumber(L, 3);
    float target_x = (float)luaL_checknumber(L, 4);
    float target_y = (float)luaL_checknumber(L, 5);
    float target_z = (float)luaL_checknumber(L, 6);
    float up_x = (float)luaL_checknumber(L, 7);
    float up_y = (float)luaL_checknumber(L, 8);
    float up_z = (float)luaL_checknumber(L, 9);
    float fovy = (float)luaL_checknumber(L, 10);
    int projection = (int)luaL_checkinteger(L, 11);
    rl_handle_t handle = rl_camera3d_create(pos_x, pos_y, pos_z, target_x, target_y, target_z,
                                            up_x, up_y, up_z, fovy, projection);
    lua_pushinteger(L, handle);
    return 1;
}

static int rl_camera3d_get_default_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_camera3d_get_default());
    return 1;
}

static int rl_camera3d_set_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    float pos_x = (float)luaL_checknumber(L, 2);
    float pos_y = (float)luaL_checknumber(L, 3);
    float pos_z = (float)luaL_checknumber(L, 4);
    float target_x = (float)luaL_checknumber(L, 5);
    float target_y = (float)luaL_checknumber(L, 6);
    float target_z = (float)luaL_checknumber(L, 7);
    float up_x = (float)luaL_checknumber(L, 8);
    float up_y = (float)luaL_checknumber(L, 9);
    float up_z = (float)luaL_checknumber(L, 10);
    float fovy = (float)luaL_checknumber(L, 11);
    int projection = (int)luaL_checkinteger(L, 12);
    lua_pushboolean(L, rl_camera3d_set(camera, pos_x, pos_y, pos_z, target_x, target_y, target_z,
                                       up_x, up_y, up_z, fovy, projection) ? 1 : 0);
    return 1;
}

static int rl_camera3d_set_active_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_camera3d_set_active(camera) ? 1 : 0);
    return 1;
}

static int rl_camera3d_get_active_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_camera3d_get_active());
    return 1;
}

static int rl_camera3d_destroy_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_camera3d_destroy(camera);
    return 0;
}

void rl_register_camera3d_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_camera3d_create_lua);
    lua_setfield(L, -2, "camera3d_create");

    lua_pushcfunction(L, rl_camera3d_get_default_lua);
    lua_setfield(L, -2, "camera3d_get_default");

    lua_pushcfunction(L, rl_camera3d_set_lua);
    lua_setfield(L, -2, "camera3d_set");

    lua_pushcfunction(L, rl_camera3d_set_active_lua);
    lua_setfield(L, -2, "camera3d_set_active");

    lua_pushcfunction(L, rl_camera3d_get_active_lua);
    lua_setfield(L, -2, "camera3d_get_active");

    lua_pushcfunction(L, rl_camera3d_destroy_lua);
    lua_setfield(L, -2, "camera3d_destroy");
}
