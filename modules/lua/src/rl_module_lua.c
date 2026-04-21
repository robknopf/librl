#include "rl_module_lua.h"
#include "rl_color.h"
#include "rl_camera3d.h"
#include "rl_loader.h"
#include "rl_font.h"
#include "rl_model.h"
#include "rl_music.h"
#include "rl_pick.h"
#include "rl_sound.h"
#include "rl_sprite2d.h"
#include "rl_sprite3d.h"
#include "rl_texture.h"
#include "rl_input.h"
#include "rl_window.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

#ifndef RL_LUA_CAMERA_PERSPECTIVE
#define RL_LUA_CAMERA_PERSPECTIVE 0
#endif

#ifndef RL_LUA_CAMERA_ORTHOGRAPHIC
#define RL_LUA_CAMERA_ORTHOGRAPHIC 1
#endif

#define RL_LUA_FLAG_VSYNC_HINT 0x00000040
#define RL_LUA_FLAG_FULLSCREEN_MODE 0x00000002
#define RL_LUA_FLAG_WINDOW_RESIZABLE 0x00000004
#define RL_LUA_FLAG_WINDOW_UNDECORATED 0x00000008
#define RL_LUA_FLAG_WINDOW_HIDDEN 0x00000080
#define RL_LUA_FLAG_WINDOW_MINIMIZED 0x00000200
#define RL_LUA_FLAG_WINDOW_MAXIMIZED 0x00000400
#define RL_LUA_FLAG_WINDOW_UNFOCUSED 0x00000800
#define RL_LUA_FLAG_WINDOW_TOPMOST 0x00001000
#define RL_LUA_FLAG_WINDOW_ALWAYS_RUN 0x00000100
#define RL_LUA_FLAG_WINDOW_TRANSPARENT 0x00000010
#define RL_LUA_FLAG_WINDOW_HIGHDPI 0x00002000
#define RL_LUA_FLAG_MSAA_4X_HINT 0x00000020
#define RL_LUA_FLAG_INTERLACED_HINT 0x00010000

#define RL_LUA_MODULE_MAX_CACHED_RESOURCES 128
#define RL_LUA_MODULE_MAX_EVENT_LISTENERS 128

struct rl_module_lua_state_t;
typedef struct rl_lua_event_listener_t {
    bool in_use;
    int callback_ref;
    char event_name[128];
    struct rl_module_lua_state_t *state;
} rl_lua_event_listener_t;
/*
 * The Lua module keeps its own small handle caches on top of librl's resource
 * systems for two reasons:
 *
 * 1. HCR / script reload stability.
 *    A script may run its init path again while the module and its native
 *    resources are still alive. If Lua simply called load/create every time,
 *    reloads would mint fresh handles for resources the script already asked
 *    for previously. Caching at the module layer lets repeated requests for
 *    the same logical resource return the same handle across reloads.
 *
 * 2. Lua-side ownership and teardown.
 *    librl may already cache the underlying asset data internally, but the Lua
 *    module still needs to know which handles it handed out so it can destroy
 *    exactly its own resources on module shutdown or explicit Lua destroy
 *    calls. The module cache is therefore about stable script-visible handle
 *    reuse and lifecycle bookkeeping, not just asset decode/upload reuse.
 */
typedef struct rl_lua_cached_resource_t {
    rl_handle_t handle;
    char path[256];
} rl_lua_cached_resource_t;

typedef struct rl_lua_cached_font_t {
    rl_handle_t handle;
    float size;
    char path[256];
} rl_lua_cached_font_t;

typedef struct rl_lua_cached_color_t {
    rl_handle_t handle;
    int r;
    int g;
    int b;
    int a;
} rl_lua_cached_color_t;

typedef struct rl_lua_vm_t {
    lua_State *state;
    char last_error[256];
    int frame_ref;
    int mouse_ref;
    int mouse_buttons_ref;
    int keyboard_ref;
    int keyboard_keys_ref;
} rl_lua_vm_t;

typedef struct rl_module_lua_state_t {
    rl_module_host_api_t host;
    rl_lua_vm_t vm;
    int serialized_state_ref;
    bool script_init_called;
    bool host_started;
    bool script_loaded;
    bool script_active;
    rl_lua_cached_resource_t sprite2d_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t sprite3d_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t model_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t music_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t sound_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t texture_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_font_t font_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_color_t color_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_event_listener_t event_listeners[RL_LUA_MODULE_MAX_EVENT_LISTENERS];
} rl_module_lua_state_t;

static void lua_module_on_do_string(void *payload, void *listener_user_data);
static void lua_module_on_do_file(void *payload, void *listener_user_data);
static void lua_module_on_add_path(void *payload, void *listener_user_data);
static void lua_module_on_set_path(void *payload, void *listener_user_data);
static void lua_module_on_add_cpath(void *payload, void *listener_user_data);
static void lua_module_on_set_cpath(void *payload, void *listener_user_data);
static int lua_module_log_binding(lua_State *L);
static int lua_module_clear_binding(lua_State *L);
static int lua_module_create_camera3d_binding(lua_State *L);
static int lua_module_set_camera3d_binding(lua_State *L);
static int lua_module_set_active_camera3d_binding(lua_State *L);
static int lua_module_get_active_camera3d_binding(lua_State *L);
static int lua_module_pick_model_binding(lua_State *L);
static int lua_module_pick_sprite3d_binding(lua_State *L);
static int lua_module_draw_text_binding(lua_State *L);
static int lua_module_draw_cube_binding(lua_State *L);
static int lua_module_draw_ground_texture_binding(lua_State *L);
static int lua_module_set_sprite3d_transform_binding(lua_State *L);
static int lua_module_draw_sprite3d_binding(lua_State *L);
static int lua_module_set_model_transform_binding(lua_State *L);
static int lua_module_draw_model_binding(lua_State *L);
static int lua_module_load_sprite2d_binding(lua_State *L);
static int lua_module_destroy_sprite2d_binding(lua_State *L);
static int lua_module_set_sprite2d_transform_binding(lua_State *L);
static int lua_module_draw_sprite2d_binding(lua_State *L);
static int lua_module_draw_texture_binding(lua_State *L);
static int lua_module_load_model_binding(lua_State *L);
static int lua_module_destroy_model_binding(lua_State *L);
static int lua_module_load_sprite3d_binding(lua_State *L);
static int lua_module_destroy_sprite3d_binding(lua_State *L);
static int lua_module_load_music_binding(lua_State *L);
static int lua_module_destroy_music_binding(lua_State *L);
static int lua_module_load_sound_binding(lua_State *L);
static int lua_module_destroy_sound_binding(lua_State *L);
static int lua_module_load_texture_binding(lua_State *L);
static int lua_module_destroy_texture_binding(lua_State *L);
static int lua_module_play_music_binding(lua_State *L);
static int lua_module_pause_music_binding(lua_State *L);
static int lua_module_stop_music_binding(lua_State *L);
static int lua_module_set_music_loop_binding(lua_State *L);
static int lua_module_set_music_volume_binding(lua_State *L);
static int lua_module_is_music_playing_binding(lua_State *L);
static int lua_module_play_sound_binding(lua_State *L);
static int lua_module_create_color_binding(lua_State *L);
static int lua_module_destroy_color_binding(lua_State *L);
static int lua_module_load_font_binding(lua_State *L);
static int lua_module_destroy_font_binding(lua_State *L);
static int lua_module_event_on_binding(lua_State *L);
static int lua_module_event_off_binding(lua_State *L);
static int lua_module_event_emit_binding(lua_State *L);
static int lua_module_require_searcher(lua_State *L);
static int lua_module_expand_template(const char *prefix, const char *token, const char *suffix, char *out, size_t out_size);
static const char *lua_module_debug_source(lua_Debug *ar, char *buffer, size_t buffer_size);
static int lua_vm_call_update(rl_module_lua_state_t *state, float dt_seconds);
static int lua_vm_call_init(rl_module_lua_state_t *state);
static int lua_vm_call_load(rl_module_lua_state_t *state);
static int lua_vm_call_unload(rl_module_lua_state_t *state);
static int lua_vm_call_serialize(rl_module_lua_state_t *state);
static int lua_vm_call_unserialize(rl_module_lua_state_t *state);
static int lua_vm_call_get_config(rl_module_lua_state_t *state, rl_module_config_t *out_config);
static int lua_vm_call_shutdown(rl_module_lua_state_t *state);
static rl_handle_t lua_module_cached_load(rl_lua_cached_resource_t *cache,
                                          int cache_count,
                                          const char *path,
                                          rl_handle_t (*create_fn)(const char *path));
static void lua_module_cached_destroy(rl_lua_cached_resource_t *cache,
                                      int cache_count,
                                      void (*destroy_fn)(rl_handle_t handle));
static bool lua_module_cached_destroy_handle(rl_lua_cached_resource_t *cache,
                                             int cache_count,
                                             rl_handle_t handle,
                                             void (*destroy_fn)(rl_handle_t handle));
static rl_handle_t lua_module_cached_load_font(rl_lua_cached_font_t *cache,
                                               int cache_count,
                                               const char *path,
                                               float size);
static void lua_module_cached_destroy_fonts(rl_lua_cached_font_t *cache,
                                            int cache_count);
static bool lua_module_cached_destroy_font_handle(rl_lua_cached_font_t *cache,
                                                  int cache_count,
                                                  rl_handle_t handle);
static rl_handle_t lua_module_cached_load_color(rl_lua_cached_color_t *cache,
                                                int cache_count,
                                                int r,
                                                int g,
                                                int b,
                                                int a);
static void lua_module_cached_destroy_colors(rl_lua_cached_color_t *cache,
                                             int cache_count);
static bool lua_module_cached_destroy_color_handle(rl_lua_cached_color_t *cache,
                                                   int cache_count,
                                                   rl_handle_t handle);
static int lua_vm_load_file_chunk(lua_State *L, const char *filename);
static void lua_vm_install_searcher(rl_module_lua_state_t *state);
static int lua_module_resolve_path(rl_module_lua_state_t *state, const char *filename, char *resolved_path, size_t resolved_path_size);
static int lua_module_is_explicit_path(const char *filename);
static void lua_module_push_pick_result(lua_State *L, rl_pick_result_t result);
static void lua_module_clear_serialized_state(rl_module_lua_state_t *state);
static int lua_module_prepare_reload(rl_module_lua_state_t *state);
static int lua_module_activate_script(rl_module_lua_state_t *state);
static void lua_module_clear_event_listeners(rl_module_lua_state_t *state);
static void lua_module_dispatch_script_event(void *payload, void *listener_user_data);
static int rl_module_lua_get_config_impl(void *module_state, rl_module_config_t *out_config);
static int rl_module_lua_start_impl(void *module_state);

static int parse_lua_log_level(lua_State *L, int idx, int *out_is_level)
{
    int type = lua_type(L, idx);
    if (out_is_level != NULL) {
        *out_is_level = 1;
    }

    if (type == LUA_TNUMBER) {
        return (int)lua_tointeger(L, idx);
    }

    if (type == LUA_TSTRING) {
        const char *level = lua_tostring(L, idx);
        if (level == NULL) {
            return RL_MODULE_LOG_INFO;
        }
        if (strcmp(level, "trace") == 0 || strcmp(level, "TRACE") == 0) return RL_MODULE_LOG_TRACE;
        if (strcmp(level, "debug") == 0 || strcmp(level, "DEBUG") == 0) return RL_MODULE_LOG_DEBUG;
        if (strcmp(level, "info") == 0 || strcmp(level, "INFO") == 0) return RL_MODULE_LOG_INFO;
        if (strcmp(level, "warn") == 0 || strcmp(level, "WARN") == 0 ||
            strcmp(level, "warning") == 0 || strcmp(level, "WARNING") == 0) return RL_MODULE_LOG_WARN;
        if (strcmp(level, "error") == 0 || strcmp(level, "ERROR") == 0) return RL_MODULE_LOG_ERROR;
    }

    if (out_is_level != NULL) {
        *out_is_level = 0;
    }
    return RL_MODULE_LOG_INFO;
}

static void set_error(rl_lua_vm_t *vm, const char *msg)
{
    if (vm == NULL) {
        return;
    }

    if (msg == NULL) {
        vm->last_error[0] = '\0';
        return;
    }

    (void)snprintf(vm->last_error, sizeof(vm->last_error), "%s", msg);
}

static void lua_vm_set_table_number(lua_State *L, int index, const char *key, lua_Number value)
{
    lua_pushstring(L, key);
    lua_pushnumber(L, value);
    lua_settable(L, index < 0 ? index - 2 : index);
}

static void lua_vm_set_table_integer(lua_State *L, int index, const char *key, lua_Integer value)
{
    lua_pushstring(L, key);
    lua_pushinteger(L, value);
    lua_settable(L, index < 0 ? index - 2 : index);
}

static int lua_module_abs_index(lua_State *L, int index)
{
    if (index > 0 || index <= LUA_REGISTRYINDEX) {
        return index;
    }
    return lua_gettop(L) + index + 1;
}

static void lua_vm_set_array_table_integers(lua_State *L, int index, const char *key, const int *values, int count)
{
    lua_pushstring(L, key);
    lua_newtable(L);
    for (int i = 0; i < count; i++) {
        lua_pushinteger(L, i + 1);
        lua_pushinteger(L, values[i]);
        lua_settable(L, -3);
    }
    lua_settable(L, index < 0 ? index - 2 : index);
}

static int lua_vm_init(rl_lua_vm_t *vm)
{
    lua_State *L = NULL;

    if (vm == NULL) {
        return -1;
    }

    memset(vm, 0, sizeof(*vm));

    L = luaL_newstate();
    if (L == NULL) {
        set_error(vm, "luaL_newstate failed");
        return -1;
    }

    luaL_openlibs(L);
    vm->state = L;
    vm->frame_ref = LUA_NOREF;
    vm->mouse_ref = LUA_NOREF;
    vm->mouse_buttons_ref = LUA_NOREF;
    vm->keyboard_ref = LUA_NOREF;

    lua_newtable(L);
    vm->frame_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    lua_newtable(L);
    vm->mouse_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    lua_newtable(L);
    vm->mouse_buttons_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    lua_newtable(L);
    vm->keyboard_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    lua_newtable(L);
    vm->keyboard_keys_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    set_error(vm, NULL);
    return 0;
}

static void lua_vm_bind_log(rl_module_lua_state_t *state)
{
    lua_State *L = NULL;

    if (state == NULL || state->vm.state == NULL) {
        return;
    }

    L = state->vm.state;
    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_log_binding, 1);
    lua_setglobal(L, "log");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_clear_binding, 1);
    lua_setglobal(L, "clear");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_create_camera3d_binding, 1);
    lua_setglobal(L, "create_camera3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_camera3d_binding, 1);
    lua_setglobal(L, "set_camera3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_active_camera3d_binding, 1);
    lua_setglobal(L, "set_active_camera3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_get_active_camera3d_binding, 1);
    lua_setglobal(L, "get_active_camera3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_pick_model_binding, 1);
    lua_setglobal(L, "pick_model");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_pick_sprite3d_binding, 1);
    lua_setglobal(L, "pick_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_text_binding, 1);
    lua_setglobal(L, "draw_text");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_cube_binding, 1);
    lua_setglobal(L, "draw_cube");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_ground_texture_binding, 1);
    lua_setglobal(L, "draw_ground_texture");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_sprite3d_transform_binding, 1);
    lua_setglobal(L, "set_sprite3d_transform");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_sprite3d_binding, 1);
    lua_setglobal(L, "draw_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_texture_binding, 1);
    lua_setglobal(L, "draw_texture");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_model_transform_binding, 1);
    lua_setglobal(L, "set_model_transform");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_model_binding, 1);
    lua_setglobal(L, "draw_model");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_sprite2d_binding, 1);
    lua_setglobal(L, "load_sprite2d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_sprite2d_binding, 1);
    lua_setglobal(L, "destroy_sprite2d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_sprite2d_transform_binding, 1);
    lua_setglobal(L, "set_sprite2d_transform");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_sprite2d_binding, 1);
    lua_setglobal(L, "draw_sprite2d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_model_binding, 1);
    lua_setglobal(L, "load_model");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_model_binding, 1);
    lua_setglobal(L, "destroy_model");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_sprite3d_binding, 1);
    lua_setglobal(L, "load_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_sprite3d_binding, 1);
    lua_setglobal(L, "destroy_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_music_binding, 1);
    lua_setglobal(L, "load_music");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_music_binding, 1);
    lua_setglobal(L, "destroy_music");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_sound_binding, 1);
    lua_setglobal(L, "load_sound");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_sound_binding, 1);
    lua_setglobal(L, "destroy_sound");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_texture_binding, 1);
    lua_setglobal(L, "load_texture");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_texture_binding, 1);
    lua_setglobal(L, "destroy_texture");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_play_music_binding, 1);
    lua_setglobal(L, "play_music");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_pause_music_binding, 1);
    lua_setglobal(L, "pause_music");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_stop_music_binding, 1);
    lua_setglobal(L, "stop_music");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_music_loop_binding, 1);
    lua_setglobal(L, "set_music_loop");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_set_music_volume_binding, 1);
    lua_setglobal(L, "set_music_volume");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_is_music_playing_binding, 1);
    lua_setglobal(L, "is_music_playing");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_play_sound_binding, 1);
    lua_setglobal(L, "play_sound");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_create_color_binding, 1);
    lua_setglobal(L, "create_color");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_color_binding, 1);
    lua_setglobal(L, "destroy_color");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_font_binding, 1);
    lua_setglobal(L, "load_font");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_destroy_font_binding, 1);
    lua_setglobal(L, "destroy_font");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_event_on_binding, 1);
    lua_setglobal(L, "event_on");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_event_off_binding, 1);
    lua_setglobal(L, "event_off");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_event_emit_binding, 1);
    lua_setglobal(L, "event_emit");

    lua_pushinteger(L, RL_FONT_DEFAULT);
    lua_setglobal(L, "FONT_DEFAULT");
    lua_pushinteger(L, RL_COLOR_WHITE);
    lua_setglobal(L, "COLOR_WHITE");
    lua_pushinteger(L, RL_COLOR_BLACK);
    lua_setglobal(L, "COLOR_BLACK");
    lua_pushinteger(L, RL_COLOR_BLUE);
    lua_setglobal(L, "COLOR_BLUE");
    lua_pushinteger(L, RL_COLOR_RAYWHITE);
    lua_setglobal(L, "COLOR_RAYWHITE");
    lua_pushinteger(L, RL_COLOR_DARKBLUE);
    lua_setglobal(L, "COLOR_DARKBLUE");
    lua_pushinteger(L, RL_LUA_CAMERA_PERSPECTIVE);
    lua_setglobal(L, "CAMERA_PERSPECTIVE");
    lua_pushinteger(L, RL_LUA_CAMERA_ORTHOGRAPHIC);
    lua_setglobal(L, "CAMERA_ORTHOGRAPHIC");
    lua_pushinteger(L, RL_CAMERA3D_DEFAULT);
    lua_setglobal(L, "CAMERA3D_DEFAULT");
    lua_pushinteger(L, RL_LUA_FLAG_VSYNC_HINT);
    lua_setglobal(L, "FLAG_VSYNC_HINT");
    lua_pushinteger(L, RL_LUA_FLAG_FULLSCREEN_MODE);
    lua_setglobal(L, "FLAG_FULLSCREEN_MODE");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_RESIZABLE);
    lua_setglobal(L, "FLAG_WINDOW_RESIZABLE");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_UNDECORATED);
    lua_setglobal(L, "FLAG_WINDOW_UNDECORATED");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_HIDDEN);
    lua_setglobal(L, "FLAG_WINDOW_HIDDEN");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_MINIMIZED);
    lua_setglobal(L, "FLAG_WINDOW_MINIMIZED");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_MAXIMIZED);
    lua_setglobal(L, "FLAG_WINDOW_MAXIMIZED");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_UNFOCUSED);
    lua_setglobal(L, "FLAG_WINDOW_UNFOCUSED");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_TOPMOST);
    lua_setglobal(L, "FLAG_WINDOW_TOPMOST");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_ALWAYS_RUN);
    lua_setglobal(L, "FLAG_WINDOW_ALWAYS_RUN");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_TRANSPARENT);
    lua_setglobal(L, "FLAG_WINDOW_TRANSPARENT");
    lua_pushinteger(L, RL_LUA_FLAG_WINDOW_HIGHDPI);
    lua_setglobal(L, "FLAG_WINDOW_HIGHDPI");
    lua_pushinteger(L, RL_LUA_FLAG_MSAA_4X_HINT);
    lua_setglobal(L, "FLAG_MSAA_4X_HINT");
    lua_pushinteger(L, RL_LUA_FLAG_INTERLACED_HINT);
    lua_setglobal(L, "FLAG_INTERLACED_HINT");
}

static int lua_module_fetch_to_fileio(const char *relative_path)
{
    rl_loader_task_t *task = NULL;
    int rc = 0;

    if (relative_path == NULL || relative_path[0] == '\0') {
        return -1;
    }

    task = rl_loader_import_asset_async(relative_path);
    if (task == NULL) {
        return -1;
    }

    while (!rl_loader_poll_task(task)) {
        /* spin - fetch_url_async is synchronous on desktop so this should not iterate */
    }

    rc = rl_loader_finish_task(task);
    rl_loader_free_task(task);
    return rc;
}

static int lua_vm_load_file_chunk(lua_State *L, const char *filename)
{
    rl_loader_read_result_t read_result = {0};
    char chunk_name[512];
    int rc = 0;

    if (L == NULL || filename == NULL || filename[0] == '\0') {
        return LUA_ERRFILE;
    }

    read_result = rl_loader_read_local(filename);
    if (read_result.error != 0 || read_result.data == NULL || read_result.size == 0) {
        rl_loader_read_result_free(&read_result);
        return LUA_ERRFILE;
    }

    (void)snprintf(chunk_name, sizeof(chunk_name), "@%s", filename);
    rc = luaL_loadbuffer(L, (const char *)read_result.data, read_result.size, chunk_name);
    rl_loader_read_result_free(&read_result);
    return rc;
}

static int lua_module_resolve_path(rl_module_lua_state_t *state, const char *filename, char *resolved_path, size_t resolved_path_size)
{
    int explicit_path = 0;
    (void)state;

    if (resolved_path == NULL || resolved_path_size == 0 || filename == NULL || filename[0] == '\0') {
        return -1;
    }

    explicit_path = lua_module_is_explicit_path(filename);

    if (explicit_path) {
        rl_loader_normalize_path(filename, resolved_path, resolved_path_size);
        if (rl_loader_is_local(resolved_path)) {
            return 0;
        }
    }

    if (!explicit_path) {
        rl_loader_normalize_path(filename, resolved_path, resolved_path_size);
        if (rl_loader_is_local(resolved_path)) {
            return 0;
        }
    }

    resolved_path[0] = '\0';
    return -1;
}


static int lua_module_is_explicit_path(const char *filename)
{
    if (filename == NULL || filename[0] == '\0') {
        return 0;
    }

    return filename[0] == '/' ||
           strncmp(filename, "./", 2) == 0 ||
           strncmp(filename, "../", 3) == 0 ||
           strchr(filename, '/') != NULL;
}

static int lua_module_expand_template(const char *prefix, const char *token, const char *suffix,
                                      char *out, size_t out_size)
{
    size_t plen = strlen(prefix);
    size_t tlen = strlen(token);
    size_t slen = strlen(suffix);
    if (plen + tlen + slen + 1 > out_size) {
        return -1;
    }
    memcpy(out, prefix, plen);
    memcpy(out + plen, token, tlen);
    memcpy(out + plen + tlen, suffix, slen);
    out[plen + tlen + slen] = '\0';
    return 0;
}

static int lua_module_require_searcher(lua_State *L)
{
    const char *module_name = luaL_checkstring(L, 1);
    char module_token[2048];
    int rc = 0;

    if (module_name == NULL || module_name[0] == '\0') {
        lua_pushstring(L, "\n\tinvalid module name");
        return 1;
    }

    (void)snprintf(module_token, sizeof(module_token), "%s", module_name);
    for (char *p = module_token; *p != '\0'; ++p) {
        if (*p == '.') { *p = '/'; }
    }

    /* --- package.path: fetch missing Lua files and return a loader --- */
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    {
        const char *pkg_path = lua_tostring(L, -1);
        if (pkg_path != NULL) {
            char templates[2048];
            char *saveptr = NULL;
            char *templ = NULL;
            (void)snprintf(templates, sizeof(templates), "%s", pkg_path);
            templ = strtok_r(templates, ";", &saveptr);
            while (templ != NULL) {
                char *q = strchr(templ, '?');
                if (q != NULL) {
                    char candidate[2048];
                    const char *suffix = q + 1;
                    *q = '\0'; /* null-terminate at '?' in mutable templates buffer */
                    rc = lua_module_expand_template(templ, module_token, suffix,
                                                   candidate, sizeof(candidate));
                    *q = '?'; /* restore */
                    if (rc != 0) { templ = strtok_r(NULL, ";", &saveptr); continue; }
                    rl_loader_normalize_path(candidate, candidate, sizeof(candidate));
                    if (candidate[0] != '/' && !rl_loader_is_local(candidate)) {
                        (void)lua_module_fetch_to_fileio(candidate);
                    }
                    if (rl_loader_is_local(candidate)) {
                        lua_pop(L, 2); /* path, package */
                        rc = lua_vm_load_file_chunk(L, candidate);
                        if (rc == LUA_OK) {
                            return 1;
                        }
                        lua_settop(L, 1);
                        lua_pushfstring(L, "\n\terror loading '%s'", candidate);
                        return 1;
                    }
                }
                templ = strtok_r(NULL, ";", &saveptr);
            }
        }
    }
    lua_pop(L, 1); /* package.path */

    /* --- package.cpath: pre-fetch native modules for the stock C searcher --- */
    lua_getfield(L, -1, "cpath");
    {
        const char *pkg_cpath = lua_tostring(L, -1);
        int native_fetched = 0;
        if (pkg_cpath != NULL) {
            char templates[2048];
            char *saveptr = NULL;
            char *templ = NULL;
            (void)snprintf(templates, sizeof(templates), "%s", pkg_cpath);
            templ = strtok_r(templates, ";", &saveptr);
            while (templ != NULL && !native_fetched) {
                char *q = strchr(templ, '?');
                if (q != NULL) {
                    char candidate[2048];
                    const char *suffix = q + 1;
                    *q = '\0';
                    rc = lua_module_expand_template(templ, module_token, suffix,
                                                   candidate, sizeof(candidate));
                    *q = '?';
                    if (rc != 0) { templ = strtok_r(NULL, ";", &saveptr); continue; }
                    rl_loader_normalize_path(candidate, candidate, sizeof(candidate));
                    if (candidate[0] != '/') {
                        (void)lua_module_fetch_to_fileio(candidate);
                    }
                    if (rl_loader_is_local(candidate)) {
                        native_fetched = 1;
                    }
                }
                templ = strtok_r(NULL, ";", &saveptr);
            }
        }
        lua_pop(L, 2); /* cpath, package */
        if (native_fetched) {
            lua_pushfstring(L, "\n\tfetched native module candidate for '%s'", module_name);
            return 1;
        }
    }

    lua_pushfstring(L, "\n\tno module '%s' found in lua search paths", module_name);
    return 1;
}

static void lua_vm_install_searcher(rl_module_lua_state_t *state)
{
    lua_State *L = NULL;
    int len = 0;

    if (state == NULL || state->vm.state == NULL) {
        return;
    }

    L = state->vm.state;
    lua_getglobal(L, "package");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        return;
    }

    lua_getfield(L, -1, "searchers");
    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        lua_getfield(L, -1, "loaders");
    }
    if (!lua_istable(L, -1)) {
        lua_pop(L, 2);
        return;
    }

    len = (int)lua_objlen(L, -1);
    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_require_searcher, 1);
    lua_rawseti(L, -2, len + 1);
    lua_pop(L, 2);
}

static int lua_vm_exec_file(rl_lua_vm_t *vm, const char *filename)
{
    int rc = 0;
    const char *err = NULL;

    if (vm == NULL || vm->state == NULL || filename == NULL || filename[0] == '\0') {
        set_error(vm, "invalid lua do_file arguments");
        return -1;
    }

    rc = lua_vm_load_file_chunk(vm->state, filename);
    if (rc != LUA_OK) {
        set_error(vm, "lua do_file failed: fileio_read failed");
        return -1;
    }
    if (rc == LUA_OK) {
        rc = lua_pcall(vm->state, 0, LUA_MULTRET, 0);
    }

    if (rc != LUA_OK) {
        err = lua_tostring(vm->state, -1);
        set_error(vm, err != NULL ? err : "lua do_file failed");
        lua_pop(vm->state, 1);
        return -1;
    }

    set_error(vm, NULL);
    return 0;
}

static int lua_vm_exec_string(rl_lua_vm_t *vm, const char *source)
{
    int rc = 0;
    const char *err = NULL;

    if (vm == NULL || vm->state == NULL || source == NULL) {
        set_error(vm, "invalid lua do_string arguments");
        return -1;
    }

    rc = luaL_loadstring(vm->state, source);
    if (rc == LUA_OK) {
        rc = lua_pcall(vm->state, 0, LUA_MULTRET, 0);
    }

    if (rc != LUA_OK) {
        err = lua_tostring(vm->state, -1);
        set_error(vm, err != NULL ? err : "lua do_string failed");
        lua_pop(vm->state, 1);
        return -1;
    }

    set_error(vm, NULL);
    return 0;
}

static void lua_vm_deinit(rl_lua_vm_t *vm)
{
    lua_State *L = NULL;

    if (vm == NULL) {
        return;
    }

    L = vm->state;
    if (L != NULL) {
        if (vm->frame_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, vm->frame_ref);
        }
        if (vm->mouse_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, vm->mouse_ref);
        }
        if (vm->keyboard_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, vm->keyboard_ref);
        }
        if (vm->keyboard_keys_ref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, vm->keyboard_keys_ref);
        }
        lua_close(L);
    }
    memset(vm, 0, sizeof(*vm));
}

static bool lua_module_event_listener_matches(lua_State *L,
                                              rl_lua_event_listener_t *entry,
                                              const char *event_name,
                                              int callback_index)
{
    bool matches = false;

    if (L == NULL || entry == NULL || !entry->in_use || event_name == NULL) {
        return false;
    }
    if (strcmp(entry->event_name, event_name) != 0) {
        return false;
    }

    callback_index = lua_module_abs_index(L, callback_index);
    lua_rawgeti(L, LUA_REGISTRYINDEX, entry->callback_ref);
    lua_pushvalue(L, callback_index);
    matches = lua_rawequal(L, -1, -2) != 0;
    lua_pop(L, 2);
    return matches;
}

static rl_lua_event_listener_t *lua_module_find_event_listener(rl_module_lua_state_t *state,
                                                               lua_State *L,
                                                               const char *event_name,
                                                               int callback_index)
{
    int i = 0;

    if (state == NULL || L == NULL || event_name == NULL || event_name[0] == '\0') {
        return NULL;
    }

    for (i = 0; i < RL_LUA_MODULE_MAX_EVENT_LISTENERS; i++) {
        if (!state->event_listeners[i].in_use) {
            continue;
        }
        if (lua_module_event_listener_matches(L, &state->event_listeners[i], event_name, callback_index)) {
            return &state->event_listeners[i];
        }
    }

    return NULL;
}

static rl_lua_event_listener_t *lua_module_alloc_event_listener(rl_module_lua_state_t *state)
{
    int i = 0;

    if (state == NULL) {
        return NULL;
    }

    for (i = 0; i < RL_LUA_MODULE_MAX_EVENT_LISTENERS; i++) {
        if (!state->event_listeners[i].in_use) {
            return &state->event_listeners[i];
        }
    }

    return NULL;
}

static void lua_module_push_event_payload(lua_State *L, void *payload)
{
    if (payload == NULL) {
        lua_pushnil(L);
        return;
    }

    lua_pushstring(L, (const char *)payload);
}

static void lua_module_dispatch_script_event(void *payload, void *listener_user_data)
{
    rl_lua_event_listener_t *entry = (rl_lua_event_listener_t *)listener_user_data;
    rl_module_lua_state_t *state = NULL;
    lua_State *L = NULL;
    const char *err = NULL;

    if (entry == NULL || !entry->in_use) {
        return;
    }

    state = entry->state;
    if (state == NULL || state->vm.state == NULL || entry->callback_ref == LUA_NOREF) {
        return;
    }

    L = state->vm.state;
    lua_rawgeti(L, LUA_REGISTRYINDEX, entry->callback_ref);
    if (!lua_isfunction(L, -1)) {
        lua_pop(L, 1);
        return;
    }

    lua_module_push_event_payload(L, payload);
    if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
        err = lua_tostring(L, -1);
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, err != NULL ? err : "lua event listener failed");
        lua_pop(L, 1);
    }
}

static void lua_module_clear_event_listeners(rl_module_lua_state_t *state)
{
    int i = 0;

    if (state == NULL) {
        return;
    }

    for (i = 0; i < RL_LUA_MODULE_MAX_EVENT_LISTENERS; i++) {
        rl_lua_event_listener_t *entry = &state->event_listeners[i];

        if (!entry->in_use) {
            continue;
        }

        (void)rl_module_event_off(&state->host, entry->event_name, lua_module_dispatch_script_event, entry);
        if (state->vm.state != NULL && entry->callback_ref != LUA_NOREF) {
            luaL_unref(state->vm.state, LUA_REGISTRYINDEX, entry->callback_ref);
        }
        memset(entry, 0, sizeof(*entry));
        entry->callback_ref = LUA_NOREF;
    }
}

static rl_handle_t lua_module_cached_load(rl_lua_cached_resource_t *cache,
                                          int cache_count,
                                          const char *path,
                                          rl_handle_t (*create_fn)(const char *path))
{
    char normalized_path[256] = {0};
    int i = 0;

    if (cache == NULL || cache_count <= 0 || path == NULL || path[0] == '\0' ||
        create_fn == NULL) {
        return 0;
    }

    rl_loader_normalize_path(path, normalized_path, sizeof(normalized_path));

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != 0 && strcmp(cache[i].path, normalized_path) == 0) {
            return cache[i].handle;
        }
    }

    for (i = 0; i < cache_count; i++) {
        rl_handle_t handle = 0;

        if (cache[i].handle != 0) {
            continue;
        }

        handle = create_fn(normalized_path);
        if (handle == 0) {
            return 0;
        }

        cache[i].handle = handle;
        (void)snprintf(cache[i].path, sizeof(cache[i].path), "%s", normalized_path);
        return handle;
    }

    return 0;
}

static void lua_module_cached_destroy(rl_lua_cached_resource_t *cache,
                                      int cache_count,
                                      void (*destroy_fn)(rl_handle_t handle))
{
    int i = 0;

    if (cache == NULL || cache_count <= 0 || destroy_fn == NULL) {
        return;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle == 0) {
            continue;
        }

        destroy_fn(cache[i].handle);
        cache[i].handle = 0;
        cache[i].path[0] = '\0';
    }
}

static bool lua_module_cached_destroy_handle(rl_lua_cached_resource_t *cache,
                                             int cache_count,
                                             rl_handle_t handle,
                                             void (*destroy_fn)(rl_handle_t handle))
{
    int i = 0;

    if (cache == NULL || cache_count <= 0 || handle == 0 || destroy_fn == NULL) {
        return false;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != handle) {
            continue;
        }

        destroy_fn(cache[i].handle);
        cache[i].handle = 0;
        cache[i].path[0] = '\0';
        return true;
    }

    return false;
}

static rl_handle_t lua_module_cached_load_font(rl_lua_cached_font_t *cache,
                                               int cache_count,
                                               const char *path,
                                               float size)
{
    char normalized_path[256] = {0};
    int i = 0;

    if (cache == NULL || cache_count <= 0 || path == NULL || path[0] == '\0') {
        return 0;
    }

    rl_loader_normalize_path(path, normalized_path, sizeof(normalized_path));

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != 0 &&
            cache[i].size == size &&
            strcmp(cache[i].path, normalized_path) == 0) {
            return cache[i].handle;
        }
    }

    for (i = 0; i < cache_count; i++) {
        rl_handle_t handle = 0;

        if (cache[i].handle != 0) {
            continue;
        }

        handle = rl_font_create(normalized_path, size);
        if (handle == 0) {
            return 0;
        }

        cache[i].handle = handle;
        cache[i].size = size;
        (void)snprintf(cache[i].path, sizeof(cache[i].path), "%s", normalized_path);
        return handle;
    }

    return 0;
}

static void lua_module_cached_destroy_fonts(rl_lua_cached_font_t *cache,
                                            int cache_count)
{
    int i = 0;

    if (cache == NULL || cache_count <= 0) {
        return;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle == 0) {
            continue;
        }

        rl_font_destroy(cache[i].handle);
        cache[i].handle = 0;
        cache[i].size = 0.0f;
        cache[i].path[0] = '\0';
    }
}

static bool lua_module_cached_destroy_font_handle(rl_lua_cached_font_t *cache,
                                                  int cache_count,
                                                  rl_handle_t handle)
{
    int i = 0;

    if (cache == NULL || cache_count <= 0 || handle == 0) {
        return false;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != handle) {
            continue;
        }

        rl_font_destroy(cache[i].handle);
        cache[i].handle = 0;
        cache[i].size = 0.0f;
        cache[i].path[0] = '\0';
        return true;
    }

    return false;
}

static rl_handle_t lua_module_cached_load_color(rl_lua_cached_color_t *cache,
                                                int cache_count,
                                                int r,
                                                int g,
                                                int b,
                                                int a)
{
    int i = 0;

    if (cache == NULL || cache_count <= 0) {
        return 0;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != 0 &&
            cache[i].r == r &&
            cache[i].g == g &&
            cache[i].b == b &&
            cache[i].a == a) {
            return cache[i].handle;
        }
    }

    for (i = 0; i < cache_count; i++) {
        rl_handle_t handle = 0;

        if (cache[i].handle != 0) {
            continue;
        }

        handle = rl_color_create(r, g, b, a);
        if (handle == 0) {
            return 0;
        }

        cache[i].handle = handle;
        cache[i].r = r;
        cache[i].g = g;
        cache[i].b = b;
        cache[i].a = a;
        return handle;
    }

    return 0;
}

static void lua_module_cached_destroy_colors(rl_lua_cached_color_t *cache,
                                             int cache_count)
{
    int i = 0;

    if (cache == NULL || cache_count <= 0) {
        return;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle == 0) {
            continue;
        }

        rl_color_destroy(cache[i].handle);
        cache[i].handle = 0;
        cache[i].r = 0;
        cache[i].g = 0;
        cache[i].b = 0;
        cache[i].a = 0;
    }
}

static bool lua_module_cached_destroy_color_handle(rl_lua_cached_color_t *cache,
                                                   int cache_count,
                                                   rl_handle_t handle)
{
    int i = 0;

    if (cache == NULL || cache_count <= 0 || handle == 0) {
        return false;
    }

    for (i = 0; i < cache_count; i++) {
        if (cache[i].handle != handle) {
            continue;
        }

        rl_color_destroy(cache[i].handle);
        cache[i].handle = 0;
        cache[i].r = 0;
        cache[i].g = 0;
        cache[i].b = 0;
        cache[i].a = 0;
        return true;
    }

    return false;
}

static int rl_module_lua_init_impl(const rl_module_host_api_t *host, void **module_state)
{
    rl_module_lua_state_t *state = NULL;
    int rc = 0;

    if (module_state == NULL) {
        return -1;
    }

    state = (rl_module_lua_state_t *)rl_module_alloc(host, sizeof(*state));
    if (state == NULL) {
        rl_module_log(host, RL_MODULE_LOG_ERROR, "lua module init: allocation failed");
        return -1;
    }
    memset(state, 0, sizeof(*state));
    state->serialized_state_ref = LUA_NOREF;

    if (host != NULL) {
        state->host = *host;
    }

    rc = lua_vm_init(&state->vm);
    if (rc != 0) {
        rl_module_log(host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        rl_module_free(host, state);
        return -1;
    }

    lua_vm_bind_log(state);
    lua_vm_install_searcher(state);

    *module_state = (void *)state;
    (void)rl_module_event_on(&state->host, "lua.add_path",  lua_module_on_add_path,  state);
    (void)rl_module_event_on(&state->host, "lua.set_path",  lua_module_on_set_path,  state);
    (void)rl_module_event_on(&state->host, "lua.add_cpath", lua_module_on_add_cpath, state);
    (void)rl_module_event_on(&state->host, "lua.set_cpath", lua_module_on_set_cpath, state);
    (void)rl_module_event_on(&state->host, "lua.do_string", lua_module_on_do_string, state);
    (void)rl_module_event_on(&state->host, "lua.do_file", lua_module_on_do_file, state);
    (void)rl_module_event_emit(&state->host, "lua.ready", state);
    rl_module_log(host, RL_MODULE_LOG_INFO, "lua module initialized");
    return 0;
}

static void rl_module_lua_deinit_impl(void *module_state)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)module_state;

    if (state == NULL) {
        return;
    }

    (void)rl_module_event_off(&state->host, "lua.add_path",  lua_module_on_add_path,  state);
    (void)rl_module_event_off(&state->host, "lua.set_path",  lua_module_on_set_path,  state);
    (void)rl_module_event_off(&state->host, "lua.add_cpath", lua_module_on_add_cpath, state);
    (void)rl_module_event_off(&state->host, "lua.set_cpath", lua_module_on_set_cpath, state);
    (void)rl_module_event_off(&state->host, "lua.do_string", lua_module_on_do_string, state);
    (void)rl_module_event_off(&state->host, "lua.do_file", lua_module_on_do_file, state);
    if (state->script_active && lua_vm_call_unload(state) != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    state->script_active = false;
    lua_module_clear_serialized_state(state);
    if (state->script_init_called && lua_vm_call_shutdown(state) != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    (void)rl_module_event_emit(&state->host, "lua.deinit", state);
    lua_module_clear_event_listeners(state);
    lua_module_cached_destroy(state->model_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_model_destroy);
    lua_module_cached_destroy(state->sprite2d_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_sprite2d_destroy);
    lua_module_cached_destroy(state->sprite3d_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_sprite3d_destroy);
    lua_module_cached_destroy(state->music_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_music_destroy);
    lua_module_cached_destroy(state->sound_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_sound_destroy);
    lua_module_cached_destroy(state->texture_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_texture_destroy);
    lua_module_cached_destroy_fonts(state->font_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES);
    lua_module_cached_destroy_colors(state->color_cache,
                                     RL_LUA_MODULE_MAX_CACHED_RESOURCES);
    lua_vm_deinit(&state->vm);
    rl_module_log(&state->host, RL_MODULE_LOG_INFO, "lua module deinitialized");
    rl_module_free(&state->host, state);
}

static int rl_module_lua_update_impl(void *module_state, float dt_seconds)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)module_state;

    if (state == NULL) {
        return -1;
    }

    if (lua_vm_call_update(state, dt_seconds) != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
        return -1;
    }
    return 0;
}

static const char *lua_module_debug_source(lua_Debug *ar, char *buffer, size_t buffer_size)
{
    const char *source = NULL;
    size_t len = 0;

    if (ar == NULL || buffer == NULL || buffer_size == 0) {
        return "lua";
    }

    buffer[0] = '\0';

    source = ar->source;
    if (source == NULL || source[0] == '\0') {
        source = ar->short_src;
    }
    if (source == NULL || source[0] == '\0') {
        return "lua";
    }

    if (source[0] == '@') {
        source += 1;
    } else if (strncmp(source, "[string \"", 9) == 0) {
        source += 9;
        len = strlen(source);
        if (len >= 2 && source[len - 2] == '"' && source[len - 1] == ']') {
            len -= 2;
        }
        if (len >= buffer_size) {
            len = buffer_size - 1;
        }
        memcpy(buffer, source, len);
        buffer[len] = '\0';
        return buffer;
    }

    (void)snprintf(buffer, buffer_size, "%s", source);
    return buffer;
}

static int lua_vm_call_update(rl_module_lua_state_t *state, float dt_seconds)
{
    lua_State *L = NULL;
    rl_mouse_state_t mouse_state = {0};
    rl_keyboard_state_t keyboard_state = {0};
    vec2_t screen_size = {0};
    int top = 0;
    int rc = 0;
    const char *err = NULL;

    if (state == NULL || state->vm.state == NULL) {
        return -1;
    }

    L = state->vm.state;
    top = lua_gettop(L);
    lua_getglobal(L, "update");
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        set_error(&state->vm, NULL);
        return 0;
    }

    mouse_state = rl_input_get_mouse_state();
    keyboard_state = rl_input_get_keyboard_state();
    screen_size = rl_window_get_screen_size();

    lua_rawgeti(L, LUA_REGISTRYINDEX, state->vm.frame_ref);
    lua_vm_set_table_number(L, -1, "dt", (lua_Number)dt_seconds);
    lua_vm_set_table_integer(L, -1, "screen_w", (lua_Integer)screen_size.x);
    lua_vm_set_table_integer(L, -1, "screen_h", (lua_Integer)screen_size.y);

    lua_rawgeti(L, LUA_REGISTRYINDEX, state->vm.mouse_ref);
    lua_vm_set_table_integer(L, -1, "x", mouse_state.x);
    lua_vm_set_table_integer(L, -1, "y", mouse_state.y);
    lua_vm_set_table_integer(L, -1, "wheel", mouse_state.wheel);
    lua_vm_set_table_integer(L, -1, "left", mouse_state.left);
    lua_vm_set_table_integer(L, -1, "right", mouse_state.right);
    lua_vm_set_table_integer(L, -1, "middle", mouse_state.middle);
    lua_rawgeti(L, LUA_REGISTRYINDEX, state->vm.mouse_buttons_ref);
    for (int i = 0; i < 3; i++) {
        lua_pushinteger(L, i);
        lua_pushinteger(L, mouse_state.buttons[i]);
        lua_settable(L, -3);
    }
    lua_setfield(L, -2, "buttons");
    lua_setfield(L, -2, "mouse");

    lua_rawgeti(L, LUA_REGISTRYINDEX, state->vm.keyboard_ref);
    lua_rawgeti(L, LUA_REGISTRYINDEX, state->vm.keyboard_keys_ref);
    for (int i = 0; i < keyboard_state.max_num_keys; i++) {
        lua_pushinteger(L, i);
        lua_pushinteger(L, keyboard_state.keys[i]);
        lua_settable(L, -3);
    }
    lua_setfield(L, -2, "keys");
    lua_vm_set_table_integer(L, -1, "pressed_key", keyboard_state.pressed_key);
    lua_vm_set_table_integer(L, -1, "pressed_char", keyboard_state.pressed_char);
    lua_vm_set_table_integer(L, -1, "num_pressed_keys", keyboard_state.num_pressed_keys);
    lua_vm_set_table_integer(L, -1, "num_pressed_chars", keyboard_state.num_pressed_chars);
    lua_vm_set_array_table_integers(L, -1, "pressed_keys", keyboard_state.pressed_keys, keyboard_state.num_pressed_keys);
    lua_vm_set_array_table_integers(L, -1, "pressed_chars", keyboard_state.pressed_chars, keyboard_state.num_pressed_chars);
    lua_setfield(L, -2, "keyboard");

    rc = lua_pcall(L, 1, 0, 0);
    if (rc != LUA_OK) {
        err = lua_tostring(L, -1);
        set_error(&state->vm, err != NULL ? err : "lua update failed");
        lua_pop(L, 1);
        return -1;
    }

    set_error(&state->vm, NULL);
    return 0;
}

static int lua_vm_call_lifecycle_noargs(rl_module_lua_state_t *state,
                                        const char *function_name,
                                        const char *error_message)
{
    lua_State *L = NULL;
    int top = 0;
    int rc = 0;
    const char *err = NULL;

    if (state == NULL || state->vm.state == NULL || function_name == NULL) {
        return -1;
    }

    L = state->vm.state;
    top = lua_gettop(L);
    lua_getglobal(L, function_name);
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        set_error(&state->vm, NULL);
        return 0;
    }

    rc = lua_pcall(L, 0, 0, 0);
    if (rc != LUA_OK) {
        err = lua_tostring(L, -1);
        set_error(&state->vm, err != NULL ? err : error_message);
        lua_pop(L, 1);
        return -1;
    }

    set_error(&state->vm, NULL);
    return 0;
}

static int lua_vm_call_init(rl_module_lua_state_t *state)
{
    return lua_vm_call_lifecycle_noargs(state, "init", "lua init failed");
}

static int lua_vm_call_load(rl_module_lua_state_t *state)
{
    return lua_vm_call_lifecycle_noargs(state, "load", "lua load failed");
}

static int lua_vm_call_unload(rl_module_lua_state_t *state)
{
    return lua_vm_call_lifecycle_noargs(state, "unload", "lua unload failed");
}

static int lua_vm_call_get_config(rl_module_lua_state_t *state, rl_module_config_t *out_config)
{
    lua_State *L = NULL;
    int top = 0;
    int rc = 0;
    const char *err = NULL;

    if (state == NULL || state->vm.state == NULL || out_config == NULL) {
        return -1;
    }

    L = state->vm.state;
    top = lua_gettop(L);
    lua_getglobal(L, "get_config");
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        set_error(&state->vm, NULL);
        return 0;
    }

    rc = lua_pcall(L, 0, 1, 0);
    if (rc != LUA_OK) {
        err = lua_tostring(L, -1);
        set_error(&state->vm, err != NULL ? err : "lua get_config failed");
        lua_pop(L, 1);
        return -1;
    }

    if (!lua_istable(L, -1)) {
        lua_pop(L, 1);
        set_error(&state->vm, "lua get_config must return a table");
        return -1;
    }

    lua_getfield(L, -1, "width");
    if (lua_isnumber(L, -1)) {
        out_config->width = (int)lua_tointeger(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, -1, "height");
    if (lua_isnumber(L, -1)) {
        out_config->height = (int)lua_tointeger(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, -1, "target_fps");
    if (lua_isnumber(L, -1)) {
        out_config->target_fps = (int)lua_tointeger(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, -1, "flags");
    if (lua_isnumber(L, -1)) {
        out_config->flags = (unsigned int)lua_tointeger(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, -1, "title");
    if (lua_isstring(L, -1)) {
        const char *title = lua_tostring(L, -1);
        if (title != NULL) {
            (void)snprintf(out_config->title, sizeof(out_config->title), "%s", title);
        }
    }
    lua_pop(L, 1);

    lua_pop(L, 1);
    set_error(&state->vm, NULL);
    return 0;
}

static int lua_vm_call_serialize(rl_module_lua_state_t *state)
{
    lua_State *L = NULL;
    int top = 0;
    int rc = 0;
    const char *err = NULL;

    if (state == NULL || state->vm.state == NULL) {
        return -1;
    }

    lua_module_clear_serialized_state(state);

    L = state->vm.state;
    top = lua_gettop(L);
    lua_getglobal(L, "serialize");
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        set_error(&state->vm, NULL);
        return 0;
    }

    rc = lua_pcall(L, 0, 1, 0);
    if (rc != LUA_OK) {
        err = lua_tostring(L, -1);
        set_error(&state->vm, err != NULL ? err : "lua serialize failed");
        lua_pop(L, 1);
        return -1;
    }

    if (!lua_isnil(L, -1)) {
        state->serialized_state_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    } else {
        lua_pop(L, 1);
        state->serialized_state_ref = LUA_NOREF;
    }

    set_error(&state->vm, NULL);
    return 0;
}

static int lua_vm_call_unserialize(rl_module_lua_state_t *state)
{
    lua_State *L = NULL;
    int top = 0;
    int rc = 0;
    const char *err = NULL;

    if (state == NULL || state->vm.state == NULL || state->serialized_state_ref == LUA_NOREF) {
        return 0;
    }

    L = state->vm.state;
    top = lua_gettop(L);
    lua_getglobal(L, "unserialize");
    if (!lua_isfunction(L, -1)) {
        lua_settop(L, top);
        set_error(&state->vm, NULL);
        lua_module_clear_serialized_state(state);
        return 0;
    }

    lua_rawgeti(L, LUA_REGISTRYINDEX, state->serialized_state_ref);
    rc = lua_pcall(L, 1, 0, 0);
    if (rc != LUA_OK) {
        err = lua_tostring(L, -1);
        set_error(&state->vm, err != NULL ? err : "lua unserialize failed");
        lua_pop(L, 1);
        return -1;
    }

    lua_module_clear_serialized_state(state);
    set_error(&state->vm, NULL);
    return 0;
}

static int lua_vm_call_shutdown(rl_module_lua_state_t *state)
{
    return lua_vm_call_lifecycle_noargs(state, "shutdown", "lua shutdown failed");
}

static void lua_module_clear_serialized_state(rl_module_lua_state_t *state)
{
    if (state == NULL || state->vm.state == NULL || state->serialized_state_ref == LUA_NOREF) {
        return;
    }

    luaL_unref(state->vm.state, LUA_REGISTRYINDEX, state->serialized_state_ref);
    state->serialized_state_ref = LUA_NOREF;
}

static int lua_module_prepare_reload(rl_module_lua_state_t *state)
{
    if (state == NULL || !state->script_active) {
        return 0;
    }

    if (lua_vm_call_serialize(state) != 0) {
        return -1;
    }
    if (lua_vm_call_unload(state) != 0) {
        return -1;
    }

    /*
     * TODO: track Lua event listener ownership by script/generation so reload
     * cleanup can be selective.
     *
     * For now we intentionally do not auto-clear all Lua listeners here.
     * Wiping the module-level listener table on root-script reload breaks
     * non-reloaded dependency modules that previously registered listeners and
     * expect them to keep firing. Until ownership tracking exists, listener
     * bookkeeping is script-managed via explicit event_off() / shutdown.
     */
    state->script_active = false;
    return 0;
}

static int lua_module_activate_script(rl_module_lua_state_t *state)
{
    if (state == NULL || !state->host_started || !state->script_loaded || state->script_active) {
        return 0;
    }

    if (!state->script_init_called) {
        if (lua_vm_call_init(state) != 0) {
            return -1;
        }
        state->script_init_called = true;
    }

    if (lua_vm_call_load(state) != 0) {
        return -1;
    }
    if (lua_vm_call_unserialize(state) != 0) {
        return -1;
    }

    state->script_active = true;
    return 0;
}

static int rl_module_lua_get_config_impl(void *module_state, rl_module_config_t *out_config)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)module_state;

    if (state == NULL || out_config == NULL) {
        return -1;
    }

    return lua_vm_call_get_config(state, out_config);
}

static int rl_module_lua_start_impl(void *module_state)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)module_state;

    if (state == NULL) {
        return -1;
    }

    state->host_started = true;
    return lua_module_activate_script(state);
}

static int lua_module_log_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    lua_Debug ar;
    char source_file_buffer[512];
    const char *source_file = "lua";
    int source_line = 0;
    int level = RL_MODULE_LOG_INFO;
    int message_idx = 1;
    int parsed_level = 0;
    const char *message = NULL;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    if (lua_gettop(L) >= 2) {
        level = parse_lua_log_level(L, 1, &parsed_level);
        if (parsed_level) {
            message_idx = 2;
        }
    }

    if (!parsed_level && lua_gettop(L) >= 1) {
        message_idx = 1;
    }

    message = lua_tostring(L, message_idx);
    if (message == NULL) {
        message = "(null)";
    }

    if (lua_getstack(L, 1, &ar) != 0) {
        if (lua_getinfo(L, "Sl", &ar) != 0) {
            source_file = lua_module_debug_source(&ar, source_file_buffer, sizeof(source_file_buffer));
            if (ar.currentline > 0) {
                source_line = ar.currentline;
            }
        }
    }

    rl_module_log_source(&state->host, level, source_file, source_line, message);
    return 0;
}

static int lua_module_clear_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_CLEAR;
    command.data.clear.color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_create_camera3d_binding(lua_State *L)
{
    rl_handle_t handle = rl_camera3d_create(
        (float)luaL_checknumber(L, 1), (float)luaL_checknumber(L, 2), (float)luaL_checknumber(L, 3),
        (float)luaL_checknumber(L, 4), (float)luaL_checknumber(L, 5), (float)luaL_checknumber(L, 6),
        (float)luaL_checknumber(L, 7), (float)luaL_checknumber(L, 8), (float)luaL_checknumber(L, 9),
        (float)luaL_checknumber(L, 10), (int)luaL_checkinteger(L, 11));
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_set_camera3d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushboolean(L, 0);
        return 1;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_CAMERA3D;
    command.data.set_camera3d.camera = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_camera3d.position_x = (float)luaL_checknumber(L, 2);
    command.data.set_camera3d.position_y = (float)luaL_checknumber(L, 3);
    command.data.set_camera3d.position_z = (float)luaL_checknumber(L, 4);
    command.data.set_camera3d.target_x = (float)luaL_checknumber(L, 5);
    command.data.set_camera3d.target_y = (float)luaL_checknumber(L, 6);
    command.data.set_camera3d.target_z = (float)luaL_checknumber(L, 7);
    command.data.set_camera3d.up_x = (float)luaL_checknumber(L, 8);
    command.data.set_camera3d.up_y = (float)luaL_checknumber(L, 9);
    command.data.set_camera3d.up_z = (float)luaL_checknumber(L, 10);
    command.data.set_camera3d.fovy = (float)luaL_checknumber(L, 11);
    command.data.set_camera3d.projection = (int)luaL_checkinteger(L, 12);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_set_active_camera3d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushboolean(L, 0);
        return 1;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_ACTIVE_CAMERA3D;
    command.data.set_active_camera3d.camera = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_get_active_camera3d_binding(lua_State *L)
{
    lua_pushinteger(L, (lua_Integer)rl_camera3d_get_active());
    return 1;
}

static void lua_module_push_pick_result(lua_State *L, rl_pick_result_t result)
{
    lua_newtable(L);

    lua_pushboolean(L, result.hit);
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

static int lua_module_pick_model_binding(lua_State *L)
{
    rl_handle_t model = (rl_handle_t)luaL_checkinteger(L, 1);
    float mouse_x = (float)luaL_checknumber(L, 2);
    float mouse_y = (float)luaL_checknumber(L, 3);
    float x = (float)luaL_checknumber(L, 4);
    float y = (float)luaL_checknumber(L, 5);
    float z = (float)luaL_checknumber(L, 6);
    float scale = (float)luaL_checknumber(L, 7);
    float rotation_x = 0.0f;
    float rotation_y = 0.0f;
    float rotation_z = 0.0f;
    rl_handle_t camera = 0;
    rl_pick_result_t result = {0};

    if (lua_gettop(L) >= 8 && !lua_isnil(L, 8)) {
        rotation_x = (float)luaL_checknumber(L, 8);
    }
    if (lua_gettop(L) >= 9 && !lua_isnil(L, 9)) {
        rotation_y = (float)luaL_checknumber(L, 9);
    }
    if (lua_gettop(L) >= 10 && !lua_isnil(L, 10)) {
        rotation_z = (float)luaL_checknumber(L, 10);
    }
    if (lua_gettop(L) >= 11 && !lua_isnil(L, 11)) {
        camera = (rl_handle_t)luaL_checkinteger(L, 11);
    } else {
        camera = rl_camera3d_get_active();
    }

    result = rl_pick_model(camera, model, mouse_x, mouse_y, x, y, z, scale,
                           rotation_x, rotation_y, rotation_z);
    lua_module_push_pick_result(L, result);
    return 1;
}

static int lua_module_pick_sprite3d_binding(lua_State *L)
{
    rl_handle_t sprite3d = (rl_handle_t)luaL_checkinteger(L, 1);
    float mouse_x = (float)luaL_checknumber(L, 2);
    float mouse_y = (float)luaL_checknumber(L, 3);
    float x = (float)luaL_checknumber(L, 4);
    float y = (float)luaL_checknumber(L, 5);
    float z = (float)luaL_checknumber(L, 6);
    float size = (float)luaL_checknumber(L, 7);
    rl_handle_t camera = 0;
    rl_pick_result_t result = {0};

    if (lua_gettop(L) >= 8 && !lua_isnil(L, 8)) {
        camera = (rl_handle_t)luaL_checkinteger(L, 8);
    } else {
        camera = rl_camera3d_get_active();
    }

    result = rl_pick_sprite3d(camera, sprite3d, mouse_x, mouse_y, x, y, z, size);
    lua_module_push_pick_result(L, result);
    return 1;
}

static int lua_module_draw_text_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;
    const char *text = NULL;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    text = luaL_checkstring(L, 2);
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_TEXT;
    command.data.draw_text.font = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_text.color = (rl_handle_t)luaL_checkinteger(L, 7);
    command.data.draw_text.x = (float)luaL_checknumber(L, 3);
    command.data.draw_text.y = (float)luaL_checknumber(L, 4);
    command.data.draw_text.font_size = (float)luaL_checknumber(L, 5);
    command.data.draw_text.spacing = (float)luaL_optnumber(L, 6, 1.0);
    (void)snprintf(command.data.draw_text.text, sizeof(command.data.draw_text.text), "%s", text);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_cube_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_CUBE;
    command.data.draw_cube.x = (float)luaL_checknumber(L, 1);
    command.data.draw_cube.y = (float)luaL_checknumber(L, 2);
    command.data.draw_cube.z = (float)luaL_checknumber(L, 3);
    command.data.draw_cube.width = (float)luaL_checknumber(L, 4);
    command.data.draw_cube.height = (float)luaL_checknumber(L, 5);
    command.data.draw_cube.length = (float)luaL_checknumber(L, 6);
    command.data.draw_cube.color = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_ground_texture_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_GROUND_TEXTURE;
    command.data.draw_ground_texture.texture = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_ground_texture.x = (float)luaL_checknumber(L, 2);
    command.data.draw_ground_texture.y = (float)luaL_checknumber(L, 3);
    command.data.draw_ground_texture.z = (float)luaL_checknumber(L, 4);
    command.data.draw_ground_texture.width = (float)luaL_checknumber(L, 5);
    command.data.draw_ground_texture.length = (float)luaL_checknumber(L, 6);
    command.data.draw_ground_texture.tint = (rl_handle_t)luaL_checkinteger(L, 7);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_set_sprite3d_transform_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_SPRITE3D_TRANSFORM;
    command.data.set_sprite3d_transform.sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_sprite3d_transform.position_x = (float)luaL_checknumber(L, 2);
    command.data.set_sprite3d_transform.position_y = (float)luaL_checknumber(L, 3);
    command.data.set_sprite3d_transform.position_z = (float)luaL_checknumber(L, 4);
    command.data.set_sprite3d_transform.size = (float)luaL_checknumber(L, 5);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_sprite3d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_SPRITE3D;
    command.data.draw_sprite3d.sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_sprite3d.tint = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_texture_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_TEXTURE;
    command.data.draw_texture.texture = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_texture.x = (float)luaL_checknumber(L, 2);
    command.data.draw_texture.y = (float)luaL_checknumber(L, 3);
    command.data.draw_texture.scale = (float)luaL_checknumber(L, 4);
    command.data.draw_texture.rotation = (float)luaL_optnumber(L, 5, 0.0f);
    command.data.draw_texture.tint = (rl_handle_t)luaL_checkinteger(L, 6);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_set_model_transform_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_MODEL_TRANSFORM;
    command.data.set_model_transform.model = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_model_transform.position_x = (float)luaL_checknumber(L, 2);
    command.data.set_model_transform.position_y = (float)luaL_checknumber(L, 3);
    command.data.set_model_transform.position_z = (float)luaL_checknumber(L, 4);
    command.data.set_model_transform.rotation_x = (float)luaL_checknumber(L, 5);
    command.data.set_model_transform.rotation_y = (float)luaL_checknumber(L, 6);
    command.data.set_model_transform.rotation_z = (float)luaL_checknumber(L, 7);
    command.data.set_model_transform.scale_x = (float)luaL_checknumber(L, 8);
    command.data.set_model_transform.scale_y = (float)luaL_checknumber(L, 9);
    command.data.set_model_transform.scale_z = (float)luaL_checknumber(L, 10);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_model_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_MODEL;
    command.data.draw_model.model = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_model.tint = (rl_handle_t)luaL_checkinteger(L, 2);
    command.data.draw_model.animation_index = (int)luaL_optinteger(L, 3, -1);
    command.data.draw_model.animation_frame = (int)luaL_optinteger(L, 4, 0);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_load_sprite2d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->sprite2d_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_sprite2d_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_sprite2d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->sprite2d_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_sprite2d_destroy));
    return 1;
}

static int lua_module_set_sprite2d_transform_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_SPRITE2D_TRANSFORM;
    command.data.set_sprite2d_transform.sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_sprite2d_transform.x = (float)luaL_checknumber(L, 2);
    command.data.set_sprite2d_transform.y = (float)luaL_checknumber(L, 3);
    command.data.set_sprite2d_transform.scale = (float)luaL_checknumber(L, 4);
    command.data.set_sprite2d_transform.rotation = (float)luaL_optnumber(L, 5, 0.0f);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_sprite2d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_DRAW_SPRITE2D;
    command.data.draw_sprite2d.sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_sprite2d.tint = (rl_handle_t)luaL_checkinteger(L, 2);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_load_model_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->model_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_model_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_model_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->model_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_model_destroy));
    return 1;
}

static int lua_module_load_sprite3d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->sprite3d_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_sprite3d_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_sprite3d_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->sprite3d_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_sprite3d_destroy));
    return 1;
}

static int lua_module_load_music_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->music_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_music_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_music_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->music_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_music_destroy));
    return 1;
}

static int lua_module_load_sound_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->sound_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_sound_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_sound_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->sound_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_sound_destroy));
    return 1;
}

static int lua_module_load_texture_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    handle = lua_module_cached_load(state->texture_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES, path,
                                    rl_texture_create);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_texture_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_handle(state->texture_cache,
                                                            RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                            handle,
                                                            rl_texture_destroy));
    return 1;
}

static int lua_module_play_music_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_render_command_t command;

    if (state == NULL) { lua_pushboolean(L, 0); return 1; }
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_PLAY_MUSIC;
    command.data.play_music.music = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_pause_music_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_render_command_t command;

    if (state == NULL) { lua_pushboolean(L, 0); return 1; }
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_PAUSE_MUSIC;
    command.data.pause_music.music = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_stop_music_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_render_command_t command;

    if (state == NULL) { lua_pushboolean(L, 0); return 1; }
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_STOP_MUSIC;
    command.data.stop_music.music = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_set_music_loop_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_render_command_t command;

    if (state == NULL) { lua_pushboolean(L, 0); return 1; }
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_MUSIC_LOOP;
    command.data.set_music_loop.music = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_music_loop.loop = lua_toboolean(L, 2) != 0;
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_set_music_volume_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_render_command_t command;

    if (state == NULL) { lua_pushboolean(L, 0); return 1; }
    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_SET_MUSIC_VOLUME;
    command.data.set_music_volume.music = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.set_music_volume.volume = (float)luaL_checknumber(L, 2);
    rl_module_frame_command(&state->host, &command);
    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_is_music_playing_binding(lua_State *L)
{
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_music_is_playing(handle));
    return 1;
}

static int lua_module_play_sound_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_render_command_t command;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_RENDER_CMD_PLAY_SOUND;
    command.data.play_sound.sound = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_create_color_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    int r = (int)luaL_checkinteger(L, 1);
    int g = (int)luaL_checkinteger(L, 2);
    int b = (int)luaL_checkinteger(L, 3);
    int a = (int)luaL_optinteger(L, 4, 255);

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    lua_pushinteger(L, (lua_Integer)lua_module_cached_load_color(state->color_cache,
                                                                 RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                                 r, g, b, a));
    return 1;
}

static int lua_module_destroy_color_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_color_handle(state->color_cache,
                                                                  RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                                  handle));
    return 1;
}

static int lua_module_load_font_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *path = NULL;
    float size = 0.0f;
    rl_handle_t handle = 0;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    path = luaL_checkstring(L, 1);
    size = (float)luaL_checknumber(L, 2);
    handle = lua_module_cached_load_font(state->font_cache,
                                         RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                         path, size);
    lua_pushinteger(L, (lua_Integer)handle);
    return 1;
}

static int lua_module_destroy_font_binding(lua_State *L)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    rl_handle_t handle = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, state != NULL &&
                           lua_module_cached_destroy_font_handle(state->font_cache,
                                                                 RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                                                                 handle));
    return 1;
}

static int lua_module_event_on_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *event_name = NULL;
    rl_lua_event_listener_t *entry = NULL;
    int callback_ref = LUA_NOREF;
    int rc = -1;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    event_name = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    if (state == NULL || event_name == NULL || event_name[0] == '\0') {
        lua_pushboolean(L, 0);
        return 1;
    }

    if (lua_module_find_event_listener(state, L, event_name, 2) != NULL) {
        lua_pushboolean(L, 1);
        return 1;
    }

    entry = lua_module_alloc_event_listener(state);
    if (entry == NULL) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, "lua event listener table is full");
        lua_pushboolean(L, 0);
        return 1;
    }

    lua_pushvalue(L, 2);
    callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    memset(entry, 0, sizeof(*entry));
    entry->in_use = true;
    entry->callback_ref = callback_ref;
    entry->state = state;
    (void)snprintf(entry->event_name, sizeof(entry->event_name), "%s", event_name);

    rc = rl_module_event_on(&state->host, entry->event_name, lua_module_dispatch_script_event, entry);
    if (rc != 0) {
        luaL_unref(L, LUA_REGISTRYINDEX, callback_ref);
        memset(entry, 0, sizeof(*entry));
        entry->callback_ref = LUA_NOREF;
        lua_pushboolean(L, 0);
        return 1;
    }

    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_event_off_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *event_name = NULL;
    rl_lua_event_listener_t *entry = NULL;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    event_name = luaL_checkstring(L, 1);
    luaL_checktype(L, 2, LUA_TFUNCTION);

    if (state == NULL || event_name == NULL || event_name[0] == '\0') {
        lua_pushboolean(L, 0);
        return 1;
    }

    entry = lua_module_find_event_listener(state, L, event_name, 2);
    if (entry == NULL) {
        lua_pushboolean(L, 0);
        return 1;
    }

    (void)rl_module_event_off(&state->host, entry->event_name, lua_module_dispatch_script_event, entry);
    luaL_unref(L, LUA_REGISTRYINDEX, entry->callback_ref);
    memset(entry, 0, sizeof(*entry));
    entry->callback_ref = LUA_NOREF;

    lua_pushboolean(L, 1);
    return 1;
}

static int lua_module_event_emit_binding(lua_State *L)
{
    rl_module_lua_state_t *state = NULL;
    const char *event_name = NULL;
    const char *payload = NULL;
    int rc = -1;

    state = (rl_module_lua_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    event_name = luaL_checkstring(L, 1);
    if (!lua_isnoneornil(L, 2)) {
        payload = luaL_checkstring(L, 2);
    }

    if (state == NULL || event_name == NULL || event_name[0] == '\0') {
        lua_pushboolean(L, 0);
        return 1;
    }

    rc = rl_module_event_emit(&state->host, event_name, (void *)payload);
    lua_pushboolean(L, rc == 0);
    return 1;
}

static void lua_module_on_do_file(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *filename = (const char *)payload;
    char resolved_path[512] = {0};
    int rc = 0;

    if (state == NULL || filename == NULL || filename[0] == '\0') {
        return;
    }

    if (lua_module_resolve_path(state, filename, resolved_path, sizeof(resolved_path)) != 0) {
        char normalized[512] = {0};
        rl_loader_normalize_path(filename, normalized, sizeof(normalized));
        (void)lua_module_fetch_to_fileio(normalized);
        if (lua_module_resolve_path(state, filename, resolved_path, sizeof(resolved_path)) != 0) {
            set_error(&state->vm, "lua do_file path resolution failed");
            rl_module_log(&state->host, RL_MODULE_LOG_ERROR, "lua do_file path resolution failed");
            (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
            return;
        }
    }

    if (lua_module_prepare_reload(state) != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
        return;
    }

    rc = lua_vm_exec_file(&state->vm, resolved_path);
    if (rc != 0) {
        state->script_loaded = false;
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    } else {
        state->script_loaded = true;
        if (lua_module_activate_script(state) != 0) {
            rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
            (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
            return;
        }
        (void)rl_module_event_emit(&state->host, "lua.ok", state);
    }
}

static void lua_module_pkg_set(lua_State *L, const char *field, const char *value)
{
    lua_getglobal(L, "package");
    lua_pushstring(L, value);
    lua_setfield(L, -2, field);
    lua_pop(L, 1);
}

static void lua_module_pkg_append(lua_State *L, const char *field, const char *value)
{
    const char *existing = NULL;
    char appended[1024] = {0};
    lua_getglobal(L, "package");
    lua_getfield(L, -1, field);
    existing = lua_tostring(L, -1);
    if (existing != NULL && strstr(existing, value) != NULL) {
        lua_pop(L, 2);
        return;
    }
    if (existing != NULL && existing[0] != '\0') {
        (void)snprintf(appended, sizeof(appended), "%s;%s", existing, value);
    } else {
        (void)snprintf(appended, sizeof(appended), "%s", value);
    }
    lua_pop(L, 1);
    lua_pushstring(L, appended);
    lua_setfield(L, -2, field);
    lua_pop(L, 1);
}

static void lua_module_build_path_templates(const char *path,
                                            char *tmpl_lua, size_t lua_sz,
                                            char *tmpl_dir, size_t dir_sz,
                                            char *tmpl_init, size_t init_sz)
{
    char normalized[256] = {0};
    rl_loader_normalize_path(path, normalized, sizeof(normalized));
    (void)snprintf(tmpl_lua,  lua_sz,  "%s/?.lua",     normalized);
    (void)snprintf(tmpl_dir,  dir_sz,  "%s/?/?.lua",   normalized);
    (void)snprintf(tmpl_init, init_sz, "%s/?/init.lua", normalized);
}

static void lua_module_build_cpath_templates(const char *path,
                                             char *tmpl_so, size_t so_sz)
{
    char normalized[256] = {0};
    rl_loader_normalize_path(path, normalized, sizeof(normalized));
    (void)snprintf(tmpl_so, so_sz, "%s/?.so", normalized);
}

static void lua_module_on_add_path(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *path = (const char *)payload;
    char tmpl_lua[320], tmpl_dir[320], tmpl_init[320];
    char combined[1024] = {0};
    lua_State *L = NULL;

    if (state == NULL || path == NULL || path[0] == '\0') { return; }
    L = state->vm.state;
    if (L == NULL) { return; }

    lua_module_build_path_templates(path, tmpl_lua, sizeof(tmpl_lua),
                                    tmpl_dir, sizeof(tmpl_dir),
                                    tmpl_init, sizeof(tmpl_init));
    (void)snprintf(combined, sizeof(combined), "%s;%s;%s", tmpl_lua, tmpl_dir, tmpl_init);
    lua_module_pkg_append(L, "path", combined);
}

static void lua_module_on_set_path(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *path = (const char *)payload;
    char tmpl_lua[320], tmpl_dir[320], tmpl_init[320];
    char new_path[1024] = {0};
    lua_State *L = NULL;

    if (state == NULL || path == NULL || path[0] == '\0') { return; }
    L = state->vm.state;
    if (L == NULL) { return; }

    lua_module_build_path_templates(path, tmpl_lua, sizeof(tmpl_lua),
                                    tmpl_dir, sizeof(tmpl_dir),
                                    tmpl_init, sizeof(tmpl_init));
    (void)snprintf(new_path, sizeof(new_path), "%s;%s;%s", tmpl_lua, tmpl_dir, tmpl_init);
    lua_module_pkg_set(L, "path", new_path);
}

static void lua_module_on_add_cpath(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *path = (const char *)payload;
    char tmpl_so[320];
    lua_State *L = NULL;

    if (state == NULL || path == NULL || path[0] == '\0') { return; }
    L = state->vm.state;
    if (L == NULL) { return; }

    lua_module_build_cpath_templates(path, tmpl_so, sizeof(tmpl_so));
    lua_module_pkg_append(L, "cpath", tmpl_so);
}

static void lua_module_on_set_cpath(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *path = (const char *)payload;
    char tmpl_so[320];
    lua_State *L = NULL;

    if (state == NULL || path == NULL || path[0] == '\0') { return; }
    L = state->vm.state;
    if (L == NULL) { return; }

    lua_module_build_cpath_templates(path, tmpl_so, sizeof(tmpl_so));
    lua_module_pkg_set(L, "cpath", tmpl_so);
}

static void lua_module_on_do_string(void *payload, void *listener_user_data)
{
    rl_module_lua_state_t *state = (rl_module_lua_state_t *)listener_user_data;
    const char *source = (const char *)payload;
    int rc = 0;

    if (state == NULL) {
        return;
    }
    if (lua_module_prepare_reload(state) != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
        return;
    }
    rc = lua_vm_exec_string(&state->vm, source);
    if (rc != 0) {
        state->script_loaded = false;
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    else {
        state->script_loaded = true;
        if (lua_module_activate_script(state) != 0) {
            rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
            (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
            return;
        }
        (void)rl_module_event_emit(&state->host, "lua.ok", state);
    }
}

RL_MODULE_DEFINE(rl_module_lua_get_api, "lua", rl_module_lua_init_impl, rl_module_lua_deinit_impl,
                rl_module_lua_get_config_impl, rl_module_lua_start_impl, rl_module_lua_update_impl)
