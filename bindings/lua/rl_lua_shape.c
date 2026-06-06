/* rl_shape.c - Lua shape bindings for librl */

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>

#include "rl.h"
#include "rl_lua_shape.h"

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

static int rl_shape_draw_rectangle_lua(lua_State *L)
{
    int x = (int)luaL_checkinteger(L, 1);
    int y = (int)luaL_checkinteger(L, 2);
    int width = (int)luaL_checkinteger(L, 3);
    int height = (int)luaL_checkinteger(L, 4);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 5);
    rl_shape_draw_rectangle(x, y, width, height, color);
    return 0;
}

static int rl_shape_draw_cube_lua(lua_State *L)
{
    float x = (float)luaL_checknumber(L, 1);
    float y = (float)luaL_checknumber(L, 2);
    float z = (float)luaL_checknumber(L, 3);
    float width = (float)luaL_checknumber(L, 4);
    float height = (float)luaL_checknumber(L, 5);
    float length = (float)luaL_checknumber(L, 6);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_shape_draw_cube(x, y, z, width, height, length, color);
    return 0;
}

static int rl_shape_draw_circle_3d_lua(lua_State *L)
{
    float center_x      = (float)luaL_checknumber(L, 1);
    float center_y      = (float)luaL_checknumber(L, 2);
    float center_z      = (float)luaL_checknumber(L, 3);
    float radius        = (float)luaL_checknumber(L, 4);
    float rot_axis_x    = (float)luaL_checknumber(L, 5);
    float rot_axis_y    = (float)luaL_checknumber(L, 6);
    float rot_axis_z    = (float)luaL_checknumber(L, 7);
    float rot_angle     = (float)luaL_checknumber(L, 8);
    rl_handle_t color   = (rl_handle_t)luaL_checkinteger(L, 9);
    rl_shape_draw_circle_3d(center_x, center_y, center_z, radius,
                             rot_axis_x, rot_axis_y, rot_axis_z, rot_angle,
                             color);
    return 0;
}

static int rl_shape_draw_line_3d_lua(lua_State *L)
{
    float start_x = (float)luaL_checknumber(L, 1);
    float start_y = (float)luaL_checknumber(L, 2);
    float start_z = (float)luaL_checknumber(L, 3);
    float end_x   = (float)luaL_checknumber(L, 4);
    float end_y   = (float)luaL_checknumber(L, 5);
    float end_z   = (float)luaL_checknumber(L, 6);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_shape_draw_line_3d(start_x, start_y, start_z, end_x, end_y, end_z, color);
    return 0;
}

static int rl_shape_draw_line_strip_3d_lua(lua_State *L)
{
    luaL_checktype(L, 1, LUA_TTABLE);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 2);

    int n = (int)lua_rawlen(L, 1);
    if (n % 3 != 0) {
        return luaL_error(L, "Point array length must be multiple of 3 (x,y,z)");
    }

    float* points = (float*)malloc(n * sizeof(float));
    if (!points) {
        return luaL_error(L, "Failed to allocate memory for points");
    }

    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, 1, i + 1);
        points[i] = (float)luaL_checknumber(L, -1);
        lua_pop(L, 1);
    }

    rl_shape_draw_line_strip_3d(points, n / 3, color);
    free(points);
    return 0;
}

void rl_register_shape_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_shape_draw_rectangle_lua);
    lua_setfield(L, -2, "shape_draw_rectangle");

    lua_pushcfunction(L, rl_shape_draw_cube_lua);
    lua_setfield(L, -2, "shape_draw_cube");

    lua_pushcfunction(L, rl_shape_draw_circle_3d_lua);
    lua_setfield(L, -2, "shape_draw_circle_3d");

    lua_pushcfunction(L, rl_shape_draw_line_3d_lua);
    lua_setfield(L, -2, "shape_draw_line_3d");

    lua_pushcfunction(L, rl_shape_draw_line_strip_3d_lua);
    lua_setfield(L, -2, "shape_draw_line_strip_3d");
}
