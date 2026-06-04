/* rl_scene.c - Lua scene bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl_scene.h"
#include "rl_lua_scene.h"


static void rl_lua_push_pick_result(lua_State *L, rl_pick_result_t result)
{
    lua_newtable(L);

    lua_pushboolean(L, result.hit ? 1 : 0);
    lua_setfield(L, -2, "hit");

    lua_pushinteger(L, (lua_Integer)result.handle);
    lua_setfield(L, -2, "handle");

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

static int rl_scene_create_lua(lua_State *L)
{
    lua_pushinteger(L, rl_scene_create());
    return 1;
}

static int rl_scene_destroy_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_scene_destroy(scene);
    return 0;
}

static int rl_scene_add_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t drawable = (rl_handle_t)luaL_checkinteger(L, 2);
    int layer = (int)luaL_optinteger(L, 3, 0);
    lua_pushboolean(L, rl_scene_add(scene, drawable, layer) ? 1 : 0);
    return 1;
}

static int rl_scene_set_layer_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t drawable = (rl_handle_t)luaL_checkinteger(L, 2);
    int layer = (int)luaL_checkinteger(L, 3);
    lua_pushboolean(L, rl_scene_set_layer(scene, drawable, layer) ? 1 : 0);
    return 1;
}

static int rl_scene_remove_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t drawable = (rl_handle_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, rl_scene_remove(scene, drawable) ? 1 : 0);
    return 1;
}

static int rl_scene_clear_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_scene_clear(scene);
    return 0;
}

static int rl_scene_set_active_camera_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t camera = (rl_handle_t)luaL_optinteger(L, 2, 0);
    rl_scene_set_active_camera(scene, camera);
    return 0;
}

static int rl_scene_draw_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_scene_draw(scene);
    return 0;
}

static int rl_scene_pick_lua(lua_State *L)
{
    rl_handle_t scene = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t camera = (rl_handle_t)luaL_optinteger(L, 2, 0);
    float mouse_x = (float)luaL_checknumber(L, 3);
    float mouse_y = (float)luaL_checknumber(L, 4);
    rl_pick_result_t result = rl_scene_pick(scene, camera, mouse_x, mouse_y);
    rl_lua_push_pick_result(L, result);
    return 1;
}

void rl_register_scene_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_scene_create_lua);
    lua_setfield(L, -2, "scene_create");

    lua_pushcfunction(L, rl_scene_destroy_lua);
    lua_setfield(L, -2, "scene_destroy");

    lua_pushcfunction(L, rl_scene_add_lua);
    lua_setfield(L, -2, "scene_add");

    lua_pushcfunction(L, rl_scene_set_layer_lua);
    lua_setfield(L, -2, "scene_set_layer");

    lua_pushcfunction(L, rl_scene_remove_lua);
    lua_setfield(L, -2, "scene_remove");

    lua_pushcfunction(L, rl_scene_clear_lua);
    lua_setfield(L, -2, "scene_clear");

    lua_pushcfunction(L, rl_scene_set_active_camera_lua);
    lua_setfield(L, -2, "scene_set_active_camera");

    lua_pushcfunction(L, rl_scene_draw_lua);
    lua_setfield(L, -2, "scene_draw");

    lua_pushcfunction(L, rl_scene_pick_lua);
    lua_setfield(L, -2, "scene_pick");
}
