/* rl_lua.c - Lua bindings for librl (direct API, no frame commands) */

#include <lua.h>
#include <lauxlib.h>

#include <stdio.h>
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

typedef struct rl_lua_run_state_t {
    lua_State *L;
    int init_ref;
    int tick_ref;
    int shutdown_ref;
    int user_ref;
    int active;
    int callback_depth;
    int in_run;
    int reset_pending;
    char error_message[256];
} rl_lua_run_state_t;

static rl_lua_run_state_t rl_lua_run_state = {0};
static void rl_lua_run_reset(lua_State *L);

static int rl_lua_run_call(int callback_ref)
{
    int arg_count = 0;

    if (callback_ref == LUA_NOREF || rl_lua_run_state.L == NULL) {
        return 0;
    }

    lua_rawgeti(rl_lua_run_state.L, LUA_REGISTRYINDEX, callback_ref);
    if (rl_lua_run_state.user_ref != LUA_NOREF) {
        lua_rawgeti(rl_lua_run_state.L, LUA_REGISTRYINDEX, rl_lua_run_state.user_ref);
        arg_count = 1;
    }

    rl_lua_run_state.callback_depth++;
    if (lua_pcall(rl_lua_run_state.L, arg_count, 0, 0) != 0) {
        rl_lua_run_state.callback_depth--;
        const char *message = lua_tostring(rl_lua_run_state.L, -1);
        if (message == NULL) {
            message = "unknown error";
        }
        snprintf(rl_lua_run_state.error_message, sizeof(rl_lua_run_state.error_message), "%s", message);
        lua_pop(rl_lua_run_state.L, 1);
        rl_stop();
        return -1;
    }
    rl_lua_run_state.callback_depth--;
    if (rl_lua_run_state.callback_depth == 0 && rl_lua_run_state.reset_pending) {
        rl_lua_run_reset(rl_lua_run_state.L);
    }

    return 0;
}

static void rl_lua_run_init_callback(void *user_data)
{
    (void)user_data;
    rl_lua_run_call(rl_lua_run_state.init_ref);
}

static void rl_lua_run_tick_callback(void *user_data)
{
    (void)user_data;
    rl_lua_run_call(rl_lua_run_state.tick_ref);
}

static void rl_lua_run_shutdown_callback(void *user_data)
{
    (void)user_data;
    rl_lua_run_call(rl_lua_run_state.shutdown_ref);
}

static void rl_lua_run_reset(lua_State *L)
{
    if (rl_lua_run_state.init_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, rl_lua_run_state.init_ref);
    }
    if (rl_lua_run_state.tick_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, rl_lua_run_state.tick_ref);
    }
    if (rl_lua_run_state.shutdown_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, rl_lua_run_state.shutdown_ref);
    }
    if (rl_lua_run_state.user_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, rl_lua_run_state.user_ref);
    }

    rl_lua_run_state.L = NULL;
    rl_lua_run_state.init_ref = LUA_NOREF;
    rl_lua_run_state.tick_ref = LUA_NOREF;
    rl_lua_run_state.shutdown_ref = LUA_NOREF;
    rl_lua_run_state.user_ref = LUA_NOREF;
    rl_lua_run_state.active = 0;
    rl_lua_run_state.callback_depth = 0;
    rl_lua_run_state.in_run = 0;
    rl_lua_run_state.reset_pending = 0;
    rl_lua_run_state.error_message[0] = '\0';
}

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

static int rl_stop_lua(lua_State *L)
{
    (void)L;
    rl_stop();
    if (!rl_lua_run_state.active) {
        return 0;
    }
    if (rl_lua_run_state.callback_depth == 0) {
        rl_lua_run_reset(L);
    } else if (!rl_lua_run_state.in_run) {
        rl_lua_run_state.reset_pending = 1;
    }
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

static int rl_lua_prepare_run_state(lua_State *L)
{
    if (rl_lua_run_state.active) {
        return -1;
    }

    luaL_checktype(L, 2, LUA_TFUNCTION);

    rl_lua_run_state.L = L;
    rl_lua_run_state.init_ref = LUA_NOREF;
    rl_lua_run_state.tick_ref = LUA_NOREF;
    rl_lua_run_state.shutdown_ref = LUA_NOREF;
    rl_lua_run_state.user_ref = LUA_NOREF;
    rl_lua_run_state.active = 1;
    rl_lua_run_state.callback_depth = 0;
    rl_lua_run_state.in_run = 0;
    rl_lua_run_state.reset_pending = 0;
    rl_lua_run_state.error_message[0] = '\0';

    if (!lua_isnoneornil(L, 1)) {
        luaL_checktype(L, 1, LUA_TFUNCTION);
        lua_pushvalue(L, 1);
        rl_lua_run_state.init_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    lua_pushvalue(L, 2);
    rl_lua_run_state.tick_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TFUNCTION);
        lua_pushvalue(L, 3);
        rl_lua_run_state.shutdown_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    if (!lua_isnoneornil(L, 4)) {
        lua_pushvalue(L, 4);
        rl_lua_run_state.user_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    return 0;
}

static int rl_start_lua(lua_State *L)
{
    int rc = 0;

    if (rl_lua_prepare_run_state(L) != 0) {
        return luaL_error(L, "start already active");
    }

    rc = rl_start(rl_lua_run_state.init_ref == LUA_NOREF ? NULL : rl_lua_run_init_callback,
                  rl_lua_run_tick_callback,
                  rl_lua_run_state.shutdown_ref == LUA_NOREF ? NULL : rl_lua_run_shutdown_callback,
                  NULL);
    if (rc != 0) {
        rl_lua_run_reset(L);
        return luaL_error(L, "start failed");
    }
    return 0;
}

static int rl_tick_lua(lua_State *L)
{
    int rc = 0;
    if (!rl_lua_run_state.active) {
        lua_pushinteger(L, -1);
        return 1;
    }

    rc = rl_tick();

    if (rl_lua_run_state.error_message[0] != '\0') {
        char message[256];
        snprintf(message, sizeof(message), "%s", rl_lua_run_state.error_message);
        rl_lua_run_reset(L);
        return luaL_error(L, "run callback error: %s", message);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_run_lua(lua_State *L)
{
    if (rl_lua_prepare_run_state(L) != 0) {
        return luaL_error(L, "run already active");
    }

    rl_lua_run_state.in_run = 1;
    rl_run(rl_lua_run_state.init_ref == LUA_NOREF ? NULL : rl_lua_run_init_callback,
           rl_lua_run_tick_callback,
           rl_lua_run_state.shutdown_ref == LUA_NOREF ? NULL : rl_lua_run_shutdown_callback,
           NULL);
    rl_lua_run_state.in_run = 0;

    if (rl_lua_run_state.error_message[0] != '\0') {
        char message[256];
        snprintf(message, sizeof(message), "%s", rl_lua_run_state.error_message);
        rl_lua_run_reset(L);
        return luaL_error(L, "run callback error: %s", message);
    }

    rl_lua_run_reset(L);
    return 0;
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
    {"stop", rl_stop_lua},
    {"set_target_fps", rl_set_target_fps_lua},
    {"get_delta_time", rl_get_delta_time_lua},
    {"get_time", rl_get_time_lua},
    {"start", rl_start_lua},
    {"tick", rl_tick_lua},
    {"run", rl_run_lua},

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
