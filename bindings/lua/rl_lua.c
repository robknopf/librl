/* rl_lua.c - Lua bindings for librl (direct API, no frame commands) */

#include <lua.h>
#include <lauxlib.h>

#include <string.h>

#include "rl.h"
#include "rl_lua_camera3d.h"
#include "rl_lua_color.h"
#include "rl_lua_debug.h"
#include "rl_lua_event.h"
#include "rl_lua_font.h"
#include "rl_lua_frame_buffer.h"
#include "rl_lua_input.h"
#include "rl_lua_loader.h"
#include "rl_lua_logger.h"
#include "rl_lua_model.h"
#include "rl_lua_module.h"
#include "rl_lua_music.h"
#include "rl_lua_pick.h"
#include "rl_lua_searcher.h"
#include "rl_lua_task_group.h"
#include "rl_lua_shape.h"
#include "rl_lua_sound.h"
#include "rl_lua_sprite2d.h"
#include "rl_lua_sprite3d.h"
#include "rl_lua_text.h"
#include "rl_lua_texture.h"
#include "rl_lua_window.h"

/* Lua 5.1 compatibility: luaL_newlib was added in 5.2 */
#if LUA_VERSION_NUM < 502
#define luaL_newlib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))
#endif

/* ============================================================================
 * Individual function bindings for vanilla Lua
 * ============================================================================ */

/* Core lifecycle */
static int rl_init_lua(lua_State *L)
{
    rl_init_config_t cfg;
    const int have_table = lua_istable(L, 1);

    memset(&cfg, 0, sizeof(cfg));
    if (have_table) {
        lua_getfield(L, 1, "window_width");
        cfg.window_width = (int)luaL_optinteger(L, -1, 0);
        lua_pop(L, 1);

        lua_getfield(L, 1, "window_height");
        cfg.window_height = (int)luaL_optinteger(L, -1, 0);
        lua_pop(L, 1);

        lua_getfield(L, 1, "window_title");
        cfg.window_title = lua_isstring(L, -1) ? lua_tostring(L, -1) : NULL;
        lua_pop(L, 1);

        lua_getfield(L, 1, "window_flags");
        cfg.window_flags = (unsigned int)luaL_optinteger(L, -1, 0);
        lua_pop(L, 1);

        lua_getfield(L, 1, "asset_host");
        cfg.asset_host = lua_isstring(L, -1) ? lua_tostring(L, -1) : NULL;
        lua_pop(L, 1);

        lua_getfield(L, 1, "loader_cache_dir");
        cfg.loader_cache_dir = lua_isstring(L, -1) ? lua_tostring(L, -1) : NULL;
        lua_pop(L, 1);
    }

    lua_pushinteger(L, (lua_Integer)rl_init(have_table ? &cfg : NULL));
    return 1;
}

static int rl_deinit_lua(lua_State *L)
{
    (void)L;  /* Unused */
    rl_deinit();
    return 0;
}

static int rl_is_initialized_lua(lua_State *L)
{
    (void)L;
    lua_pushboolean(L, rl_is_initialized() ? 1 : 0);
    return 1;
}

static int rl_get_platform_lua(lua_State *L)
{
    (void)L;
    lua_pushstring(L, rl_get_platform());
    return 1;
}

static int rl_update_lua(lua_State *L)
{
    (void)L;  /* Unused */
    rl_update();
    return 0;
}

static int rl_begin_drawing_lua(lua_State *L)
{
    (void)L;  /* Unused */
    rl_render_begin();
    return 0;
}

static int rl_end_drawing_lua(lua_State *L)
{
    (void)L;  /* Unused */
    rl_render_end();
    return 0;
}

static int rl_clear_background_lua(lua_State *L)
{
    rl_handle_t color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_render_clear_background(color);
    return 0;
}

static int rl_render_begin_mode_2d_lua(lua_State *L)
{
    rl_handle_t camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_render_begin_mode_2d(camera);
    return 0;
}

static int rl_render_end_mode_2d_lua(lua_State *L)
{
    (void)L;
    rl_render_end_mode_2d();
    return 0;
}

static int rl_render_begin_mode_3d_lua(lua_State *L)
{
    (void)L;
    rl_render_begin_mode_3d();
    return 0;
}

static int rl_render_end_mode_3d_lua(lua_State *L)
{
    (void)L;
    rl_render_end_mode_3d();
    return 0;
}

static int rl_set_asset_host_lua(lua_State *L)
{
    const char *asset_host = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_set_asset_host(asset_host));
    return 1;
}

static int rl_get_asset_host_lua(lua_State *L)
{
    (void)L;
    lua_pushstring(L, rl_get_asset_host());
    return 1;
}

static int rl_enable_lighting_lua(lua_State *L)
{
    (void)L;
    rl_enable_lighting();
    return 0;
}

static int rl_disable_lighting_lua(lua_State *L)
{
    (void)L;
    rl_disable_lighting();
    return 0;
}

static int rl_is_lighting_enabled_lua(lua_State *L)
{
    (void)L;
    lua_pushboolean(L, rl_is_lighting_enabled() ? 1 : 0);
    return 1;
}

static int rl_set_light_direction_lua(lua_State *L)
{
    float x = (float)luaL_checknumber(L, 1);
    float y = (float)luaL_checknumber(L, 2);
    float z = (float)luaL_checknumber(L, 3);
    rl_set_light_direction(x, y, z);
    return 0;
}

static int rl_set_light_ambient_lua(lua_State *L)
{
    float ambient = (float)luaL_checknumber(L, 1);
    rl_set_light_ambient(ambient);
    return 0;
}

static int rl_set_target_fps_lua(lua_State *L)
{
    int fps = (int)luaL_checkinteger(L, 1);
    rl_set_target_fps(fps);
    return 0;
}

static int rl_get_delta_time_lua(lua_State *L)
{
    (void)L;
    lua_pushnumber(L, rl_get_delta_time());
    return 1;
}

static int rl_get_time_lua(lua_State *L)
{
    (void)L;
    lua_pushnumber(L, rl_get_time());
    return 1;
}

static int rl_tick_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, (lua_Integer)rl_tick());
    return 1;
}

static const luaL_Reg rl_functions[] = {
    /* Core */
    {"init", rl_init_lua},
    {"deinit", rl_deinit_lua},
    {"is_initialized", rl_is_initialized_lua},
    {"get_platform", rl_get_platform_lua},
    {"update", rl_update_lua},
    {"begin_drawing", rl_begin_drawing_lua},
    {"end_drawing", rl_end_drawing_lua},
    {"clear_background", rl_clear_background_lua},
    {"render_begin_mode_2d", rl_render_begin_mode_2d_lua},
    {"render_end_mode_2d", rl_render_end_mode_2d_lua},
    {"render_begin_mode_3d", rl_render_begin_mode_3d_lua},
    {"render_end_mode_3d", rl_render_end_mode_3d_lua},
    {"set_asset_host", rl_set_asset_host_lua},
    {"get_asset_host", rl_get_asset_host_lua},
    {"enable_lighting", rl_enable_lighting_lua},
    {"disable_lighting", rl_disable_lighting_lua},
    {"is_lighting_enabled", rl_is_lighting_enabled_lua},
    {"set_light_direction", rl_set_light_direction_lua},
    {"set_light_ambient", rl_set_light_ambient_lua},
    {"set_target_fps", rl_set_target_fps_lua},
    {"get_delta_time", rl_get_delta_time_lua},
    {"get_time", rl_get_time_lua},
    {"tick", rl_tick_lua},

    {NULL, NULL}
};

int luaopen_rl(lua_State *L)
{
    luaL_newlib(L, rl_functions);
    lua_pushinteger(L, RL_INIT_OK);
    lua_setfield(L, -2, "RL_INIT_OK");
    lua_pushinteger(L, RL_INIT_ERR_UNKNOWN);
    lua_setfield(L, -2, "RL_INIT_ERR_UNKNOWN");
    lua_pushinteger(L, RL_INIT_ERR_ALREADY_INITIALIZED);
    lua_setfield(L, -2, "RL_INIT_ERR_ALREADY_INITIALIZED");
    lua_pushinteger(L, RL_INIT_ERR_LOADER);
    lua_setfield(L, -2, "RL_INIT_ERR_LOADER");
    lua_pushinteger(L, RL_INIT_ERR_ASSET_HOST);
    lua_setfield(L, -2, "RL_INIT_ERR_ASSET_HOST");
    lua_pushinteger(L, RL_INIT_ERR_WINDOW);
    lua_setfield(L, -2, "RL_INIT_ERR_WINDOW");
    lua_pushinteger(L, RL_TICK_RUNNING);
    lua_setfield(L, -2, "RL_TICK_RUNNING");
    lua_pushinteger(L, RL_TICK_WAITING);
    lua_setfield(L, -2, "RL_TICK_WAITING");
    lua_pushinteger(L, RL_TICK_FAILED);
    lua_setfield(L, -2, "RL_TICK_FAILED");
    rl_register_camera3d_bindings(L);
    rl_register_color_bindings(L);
    rl_register_debug_bindings(L);
    rl_register_event_bindings(L);
    rl_register_font_bindings(L);
    rl_register_logger_bindings(L);
    rl_register_frame_buffer_bindings(L);
    rl_register_input_bindings(L);
    rl_register_loader_bindings(L);
    rl_register_model_bindings(L);
    rl_register_module_bindings(L);
    rl_register_music_bindings(L);
    rl_register_pick_bindings(L);
    rl_register_shape_bindings(L);
    rl_register_sound_bindings(L);
    rl_register_sprite2d_bindings(L);
    rl_register_sprite3d_bindings(L);
    rl_register_text_bindings(L);
    rl_register_texture_bindings(L);
    rl_register_window_bindings(L);
    rl_register_lua_task_group(L);
    rl_lua_install_searcher(L);
    return 1;
}
