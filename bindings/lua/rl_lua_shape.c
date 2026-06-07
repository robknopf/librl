/* rl_shape.c - Lua shape bindings for librl */

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>

#include "rl.h"
#include "rl_lua_shape.h"

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

static int rl_shape_create_lua(lua_State *L)
{
    lua_pushinteger(L, (lua_Integer)rl_shape_create());
    return 1;
}

static int rl_shape_destroy_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_shape_destroy(shape);
    return 0;
}

static int rl_shape_set_visible_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    int visible = lua_toboolean(L, 2);
    lua_pushboolean(L, rl_shape_set_visible(shape, visible != 0));
    return 1;
}

static int rl_shape_is_visible_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_shape_is_visible(shape));
    return 1;
}

static int rl_shape_set_pickable_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    int pickable = lua_toboolean(L, 2);
    lua_pushboolean(L, rl_shape_set_pickable(shape, pickable != 0));
    return 1;
}

static int rl_shape_is_pickable_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_shape_is_pickable(shape));
    return 1;
}

static int rl_shape_set_stroke_color_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 2);
    lua_pushboolean(L, rl_shape_set_stroke_color(shape, color));
    return 1;
}

static int rl_shape_set_line_3d_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float start_x = (float)luaL_checknumber(L, 2);
    float start_y = (float)luaL_checknumber(L, 3);
    float start_z = (float)luaL_checknumber(L, 4);
    float end_x = (float)luaL_checknumber(L, 5);
    float end_y = (float)luaL_checknumber(L, 6);
    float end_z = (float)luaL_checknumber(L, 7);
    lua_pushboolean(L, rl_shape_set_line_3d(shape, start_x, start_y, start_z, end_x, end_y, end_z));
    return 1;
}

static int rl_shape_set_line_strip_3d_lua(lua_State *L)
{
    luaL_checktype(L, 2, LUA_TTABLE);
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);

    int n = (int)lua_rawlen(L, 2);
    if (n % 3 != 0) {
        return luaL_error(L, "Point array length must be multiple of 3 (x,y,z)");
    }

    float* points = NULL;
    if (n > 0) {
        points = (float*)malloc((size_t)n * sizeof(float));
        if (!points) {
            return luaL_error(L, "Failed to allocate memory for points");
        }
    }

    for (int i = 0; i < n; i++) {
        lua_rawgeti(L, 2, i + 1);
        points[i] = (float)luaL_checknumber(L, -1);
        lua_pop(L, 1);
    }

    lua_pushboolean(L, rl_shape_set_line_strip_3d(shape, points, n / 3));
    free(points);
    return 1;
}

static int rl_shape_set_rectangle_3d_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float center_x = (float)luaL_checknumber(L, 2);
    float center_y = (float)luaL_checknumber(L, 3);
    float center_z = (float)luaL_checknumber(L, 4);
    float width = (float)luaL_checknumber(L, 5);
    float height = (float)luaL_checknumber(L, 6);
    float rot_axis_x = (float)luaL_checknumber(L, 7);
    float rot_axis_y = (float)luaL_checknumber(L, 8);
    float rot_axis_z = (float)luaL_checknumber(L, 9);
    float rot_angle = (float)luaL_checknumber(L, 10);
    lua_pushboolean(L, rl_shape_set_rectangle_3d(shape, center_x, center_y, center_z,
                                                  width, height,
                                                  rot_axis_x, rot_axis_y, rot_axis_z,
                                                  rot_angle));
    return 1;
}

static int rl_shape_draw_rectangle_3d_lua(lua_State *L)
{
    float center_x = (float)luaL_checknumber(L, 1);
    float center_y = (float)luaL_checknumber(L, 2);
    float center_z = (float)luaL_checknumber(L, 3);
    float width = (float)luaL_checknumber(L, 4);
    float height = (float)luaL_checknumber(L, 5);
    float rot_axis_x = (float)luaL_checknumber(L, 6);
    float rot_axis_y = (float)luaL_checknumber(L, 7);
    float rot_axis_z = (float)luaL_checknumber(L, 8);
    float rot_angle = (float)luaL_checknumber(L, 9);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 10);
    rl_shape_draw_rectangle_3d(center_x, center_y, center_z, width, height,
                               rot_axis_x, rot_axis_y, rot_axis_z, rot_angle,
                               color);
    return 0;
}

static int rl_shape_set_cube_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float position_x = (float)luaL_checknumber(L, 2);
    float position_y = (float)luaL_checknumber(L, 3);
    float position_z = (float)luaL_checknumber(L, 4);
    float width = (float)luaL_checknumber(L, 5);
    float height = (float)luaL_checknumber(L, 6);
    float length = (float)luaL_checknumber(L, 7);
    lua_pushboolean(L, rl_shape_set_cube(shape, position_x, position_y, position_z,
                                         width, height, length));
    return 1;
}

static int rl_shape_set_circle_3d_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float center_x = (float)luaL_checknumber(L, 2);
    float center_y = (float)luaL_checknumber(L, 3);
    float center_z = (float)luaL_checknumber(L, 4);
    float radius = (float)luaL_checknumber(L, 5);
    float rot_axis_x = (float)luaL_checknumber(L, 6);
    float rot_axis_y = (float)luaL_checknumber(L, 7);
    float rot_axis_z = (float)luaL_checknumber(L, 8);
    float rot_angle = (float)luaL_checknumber(L, 9);
    lua_pushboolean(L, rl_shape_set_circle_3d(shape, center_x, center_y, center_z,
                                               radius,
                                               rot_axis_x, rot_axis_y, rot_axis_z,
                                               rot_angle));
    return 1;
}

static int rl_shape_set_sphere_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float center_x = (float)luaL_checknumber(L, 2);
    float center_y = (float)luaL_checknumber(L, 3);
    float center_z = (float)luaL_checknumber(L, 4);
    float radius = (float)luaL_checknumber(L, 5);
    lua_pushboolean(L, rl_shape_set_sphere(shape, center_x, center_y, center_z, radius));
    return 1;
}

static int rl_shape_draw_sphere_lua(lua_State *L)
{
    float center_x = (float)luaL_checknumber(L, 1);
    float center_y = (float)luaL_checknumber(L, 2);
    float center_z = (float)luaL_checknumber(L, 3);
    float radius = (float)luaL_checknumber(L, 4);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 5);
    rl_shape_draw_sphere(center_x, center_y, center_z, radius, color);
    return 0;
}

static int rl_shape_set_transform_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    float position_x = (float)luaL_checknumber(L, 2);
    float position_y = (float)luaL_checknumber(L, 3);
    float position_z = (float)luaL_checknumber(L, 4);
    float rotation_x = (float)luaL_checknumber(L, 5);
    float rotation_y = (float)luaL_checknumber(L, 6);
    float rotation_z = (float)luaL_checknumber(L, 7);
    float scale_x = (float)luaL_checknumber(L, 8);
    float scale_y = (float)luaL_checknumber(L, 9);
    float scale_z = (float)luaL_checknumber(L, 10);
    lua_pushboolean(L, rl_shape_set_transform(shape, position_x, position_y, position_z,
                                               rotation_x, rotation_y, rotation_z,
                                               scale_x, scale_y, scale_z));
    return 1;
}

static int rl_shape_draw_lua(lua_State *L)
{
    rl_handle_t shape = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_shape_draw(shape);
    return 0;
}

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
    float center_x = (float)luaL_checknumber(L, 1);
    float center_y = (float)luaL_checknumber(L, 2);
    float center_z = (float)luaL_checknumber(L, 3);
    float radius = (float)luaL_checknumber(L, 4);
    float rot_axis_x = (float)luaL_checknumber(L, 5);
    float rot_axis_y = (float)luaL_checknumber(L, 6);
    float rot_axis_z = (float)luaL_checknumber(L, 7);
    float rot_angle = (float)luaL_checknumber(L, 8);
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 9);
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
    float end_x = (float)luaL_checknumber(L, 4);
    float end_y = (float)luaL_checknumber(L, 5);
    float end_z = (float)luaL_checknumber(L, 6);
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

    float* points = NULL;
    if (n > 0) {
        points = (float*)malloc((size_t)n * sizeof(float));
        if (!points) {
            return luaL_error(L, "Failed to allocate memory for points");
        }
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
    lua_pushcfunction(L, rl_shape_create_lua);
    lua_setfield(L, -2, "shape_create");

    lua_pushcfunction(L, rl_shape_destroy_lua);
    lua_setfield(L, -2, "shape_destroy");

    lua_pushcfunction(L, rl_shape_set_visible_lua);
    lua_setfield(L, -2, "shape_set_visible");

    lua_pushcfunction(L, rl_shape_is_visible_lua);
    lua_setfield(L, -2, "shape_is_visible");

    lua_pushcfunction(L, rl_shape_set_pickable_lua);
    lua_setfield(L, -2, "shape_set_pickable");

    lua_pushcfunction(L, rl_shape_is_pickable_lua);
    lua_setfield(L, -2, "shape_is_pickable");

    lua_pushcfunction(L, rl_shape_set_stroke_color_lua);
    lua_setfield(L, -2, "shape_set_stroke_color");

    lua_pushcfunction(L, rl_shape_set_line_3d_lua);
    lua_setfield(L, -2, "shape_set_line_3d");

    lua_pushcfunction(L, rl_shape_set_line_strip_3d_lua);
    lua_setfield(L, -2, "shape_set_line_strip_3d");

    lua_pushcfunction(L, rl_shape_set_rectangle_3d_lua);
    lua_setfield(L, -2, "shape_set_rectangle_3d");

    lua_pushcfunction(L, rl_shape_draw_rectangle_3d_lua);
    lua_setfield(L, -2, "shape_draw_rectangle_3d");

    lua_pushcfunction(L, rl_shape_set_cube_lua);
    lua_setfield(L, -2, "shape_set_cube");

    lua_pushcfunction(L, rl_shape_set_circle_3d_lua);
    lua_setfield(L, -2, "shape_set_circle_3d");

    lua_pushcfunction(L, rl_shape_set_sphere_lua);
    lua_setfield(L, -2, "shape_set_sphere");

    lua_pushcfunction(L, rl_shape_set_transform_lua);
    lua_setfield(L, -2, "shape_set_transform");

    lua_pushcfunction(L, rl_shape_draw_lua);
    lua_setfield(L, -2, "shape_draw");

    lua_pushcfunction(L, rl_shape_draw_rectangle_lua);
    lua_setfield(L, -2, "shape_draw_rectangle");

    lua_pushcfunction(L, rl_shape_draw_cube_lua);
    lua_setfield(L, -2, "shape_draw_cube");

    lua_pushcfunction(L, rl_shape_draw_sphere_lua);
    lua_setfield(L, -2, "shape_draw_sphere");

    lua_pushcfunction(L, rl_shape_draw_circle_3d_lua);
    lua_setfield(L, -2, "shape_draw_circle_3d");

    lua_pushcfunction(L, rl_shape_draw_line_3d_lua);
    lua_setfield(L, -2, "shape_draw_line_3d");

    lua_pushcfunction(L, rl_shape_draw_line_strip_3d_lua);
    lua_setfield(L, -2, "shape_draw_line_strip_3d");
}
