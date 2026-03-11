#include "rl_lua_module.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl.h"
#include "rl_sound.h"
#include "rl_sprite3d.h"
#include "fileio/fileio.h"
#include "path/path.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

#define RL_LUA_MODULE_MAX_CACHED_RESOURCES 128
typedef struct rl_lua_cached_resource_t {
    rl_handle_t handle;
    char path[256];
} rl_lua_cached_resource_t;

typedef struct rl_lua_cached_font_t {
    rl_handle_t handle;
    float size;
    char path[256];
} rl_lua_cached_font_t;

typedef struct rl_lua_vm_t {
    lua_State *state;
    char last_error[256];
    int frame_ref;
    int mouse_ref;
    int mouse_buttons_ref;
    int keyboard_ref;
    int keyboard_keys_ref;
} rl_lua_vm_t;

typedef struct rl_lua_module_state_t {
    rl_module_host_api_t host;
    rl_lua_vm_t vm;
    rl_lua_cached_resource_t sprite3d_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_resource_t sound_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
    rl_lua_cached_font_t font_cache[RL_LUA_MODULE_MAX_CACHED_RESOURCES];
} rl_lua_module_state_t;

static void lua_module_on_do_string(void *payload, void *listener_user_data);
static void lua_module_on_do_file(void *payload, void *listener_user_data);
static int lua_module_log_binding(lua_State *L);
static int lua_module_clear_binding(lua_State *L);
static int lua_module_draw_text_binding(lua_State *L);
static int lua_module_draw_sprite3d_binding(lua_State *L);
static int lua_module_load_sprite3d_binding(lua_State *L);
static int lua_module_load_sound_binding(lua_State *L);
static int lua_module_play_sound_binding(lua_State *L);
static int lua_module_load_font_binding(lua_State *L);
static const char *lua_module_debug_source(lua_Debug *ar, char *buffer, size_t buffer_size);
static int lua_vm_call_update(rl_lua_module_state_t *state, float dt_seconds);
static rl_handle_t lua_module_cached_load(rl_lua_cached_resource_t *cache,
                                          int cache_count,
                                          const char *path,
                                          rl_handle_t (*create_fn)(const char *path));
static void lua_module_cached_destroy(rl_lua_cached_resource_t *cache,
                                      int cache_count,
                                      void (*destroy_fn)(rl_handle_t handle));
static rl_handle_t lua_module_cached_load_font(rl_lua_cached_font_t *cache,
                                               int cache_count,
                                               const char *path,
                                               float size);
static void lua_module_cached_destroy_fonts(rl_lua_cached_font_t *cache,
                                            int cache_count);

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

static void lua_vm_bind_log(rl_lua_module_state_t *state)
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
    lua_pushcclosure(L, lua_module_draw_text_binding, 1);
    lua_setglobal(L, "draw_text");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_draw_sprite3d_binding, 1);
    lua_setglobal(L, "draw_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_sprite3d_binding, 1);
    lua_setglobal(L, "load_sprite3d");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_sound_binding, 1);
    lua_setglobal(L, "load_sound");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_play_sound_binding, 1);
    lua_setglobal(L, "play_sound");

    lua_pushlightuserdata(L, state);
    lua_pushcclosure(L, lua_module_load_font_binding, 1);
    lua_setglobal(L, "load_font");

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
}

static int lua_vm_exec_file(rl_lua_vm_t *vm, const char *filename)
{
    fileio_read_result_t read_result = {0};
    char chunk_name[512];
    int rc = 0;
    const char *err = NULL;

    if (vm == NULL || vm->state == NULL || filename == NULL || filename[0] == '\0') {
        set_error(vm, "invalid lua do_file arguments");
        return -1;
    }

    read_result = fileio_read(filename);
    if (read_result.error != 0 || read_result.data == NULL || read_result.size == 0) {
        set_error(vm, "lua do_file failed: fileio_read failed");
        if (read_result.data != NULL) {
            free(read_result.data);
        }
        return -1;
    }

    (void)snprintf(chunk_name, sizeof(chunk_name), "@%s", filename);
    rc = luaL_loadbuffer(vm->state, (const char *)read_result.data, read_result.size, chunk_name);
    if (rc == LUA_OK) {
        rc = lua_pcall(vm->state, 0, LUA_MULTRET, 0);
    }

    free(read_result.data);

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

    path_normalize(path, normalized_path, sizeof(normalized_path));

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

    path_normalize(path, normalized_path, sizeof(normalized_path));

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

static int rl_lua_module_init_impl(const rl_module_host_api_t *host, void **module_state)
{
    rl_lua_module_state_t *state = NULL;
    int rc = 0;

    if (module_state == NULL) {
        return -1;
    }

    state = (rl_lua_module_state_t *)rl_module_alloc(host, sizeof(*state));
    if (state == NULL) {
        rl_module_log(host, RL_MODULE_LOG_ERROR, "lua module init: allocation failed");
        return -1;
    }
    memset(state, 0, sizeof(*state));

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

    *module_state = (void *)state;
    (void)rl_module_event_on(&state->host, "lua.do_string", lua_module_on_do_string, state);
    (void)rl_module_event_on(&state->host, "lua.do_file", lua_module_on_do_file, state);
    (void)rl_module_event_emit(&state->host, "lua.ready", state);
    rl_module_log(host, RL_MODULE_LOG_INFO, "lua module initialized");
    return 0;
}

static void rl_lua_module_deinit_impl(void *module_state)
{
    rl_lua_module_state_t *state = (rl_lua_module_state_t *)module_state;

    if (state == NULL) {
        return;
    }

    (void)rl_module_event_off(&state->host, "lua.do_string", lua_module_on_do_string, state);
    (void)rl_module_event_off(&state->host, "lua.do_file", lua_module_on_do_file, state);
    (void)rl_module_event_emit(&state->host, "lua.deinit", state);
    lua_module_cached_destroy(state->sprite3d_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_sprite3d_destroy);
    lua_module_cached_destroy(state->sound_cache, RL_LUA_MODULE_MAX_CACHED_RESOURCES,
                              rl_sound_destroy);
    lua_module_cached_destroy_fonts(state->font_cache,
                                    RL_LUA_MODULE_MAX_CACHED_RESOURCES);
    lua_vm_deinit(&state->vm);
    rl_module_log(&state->host, RL_MODULE_LOG_INFO, "lua module deinitialized");
    rl_module_free(&state->host, state);
}

static int rl_lua_module_update_impl(void *module_state, float dt_seconds)
{
    rl_lua_module_state_t *state = (rl_lua_module_state_t *)module_state;

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

static int lua_vm_call_update(rl_lua_module_state_t *state, float dt_seconds)
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

    mouse_state = rl_get_mouse_state();
    keyboard_state = rl_get_keyboard_state();
    screen_size = rl_get_screen_size();

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

static int lua_module_log_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    lua_Debug ar;
    char source_file_buffer[512];
    const char *source_file = "lua";
    int source_line = 0;
    int level = RL_MODULE_LOG_INFO;
    int message_idx = 1;
    int parsed_level = 0;
    const char *message = NULL;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
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
    rl_lua_module_state_t *state = NULL;
    rl_module_frame_command_t command;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_MODULE_FRAME_CMD_CLEAR;
    command.data.clear.color = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_draw_text_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    rl_module_frame_command_t command;
    const char *text = NULL;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    text = luaL_checkstring(L, 2);
    memset(&command, 0, sizeof(command));
    command.type = RL_MODULE_FRAME_CMD_DRAW_TEXT;
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

static int lua_module_draw_sprite3d_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    rl_module_frame_command_t command;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_MODULE_FRAME_CMD_DRAW_SPRITE3D;
    command.data.draw_sprite3d.sprite = (rl_handle_t)luaL_checkinteger(L, 1);
    command.data.draw_sprite3d.x = (float)luaL_checknumber(L, 2);
    command.data.draw_sprite3d.y = (float)luaL_checknumber(L, 3);
    command.data.draw_sprite3d.z = (float)luaL_checknumber(L, 4);
    command.data.draw_sprite3d.size = (float)luaL_checknumber(L, 5);
    command.data.draw_sprite3d.tint = (rl_handle_t)luaL_checkinteger(L, 6);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_load_sprite3d_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
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

static int lua_module_load_sound_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    const char *path = NULL;
    rl_handle_t handle = 0;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
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

static int lua_module_play_sound_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    rl_module_frame_command_t command;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
    if (state == NULL) {
        return 0;
    }

    memset(&command, 0, sizeof(command));
    command.type = RL_MODULE_FRAME_CMD_PLAY_SOUND;
    command.data.play_sound.sound = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_module_frame_command(&state->host, &command);
    return 0;
}

static int lua_module_load_font_binding(lua_State *L)
{
    rl_lua_module_state_t *state = NULL;
    const char *path = NULL;
    float size = 0.0f;
    rl_handle_t handle = 0;

    state = (rl_lua_module_state_t *)lua_touserdata(L, lua_upvalueindex(1));
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

static void lua_module_on_do_file(void *payload, void *listener_user_data)
{
    rl_lua_module_state_t *state = (rl_lua_module_state_t *)listener_user_data;
    const char *filename = (const char *)payload;
    int rc = 0;

    if (state == NULL) {
        return;
    }

    rc = lua_vm_exec_file(&state->vm, filename);
    if (rc != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    else {
        (void)rl_module_event_emit(&state->host, "lua.ok", state);
    }
}

static void lua_module_on_do_string(void *payload, void *listener_user_data)
{
    rl_lua_module_state_t *state = (rl_lua_module_state_t *)listener_user_data;
    const char *source = (const char *)payload;
    int rc = 0;

    if (state == NULL) {
        return;
    }
    rc = lua_vm_exec_string(&state->vm, source);
    if (rc != 0) {
        rl_module_log(&state->host, RL_MODULE_LOG_ERROR, state->vm.last_error);
        (void)rl_module_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    else {
        (void)rl_module_event_emit(&state->host, "lua.ok", state);
    }
}

RL_MODULE_DEFINE(rl_lua_module_get_api, "lua", rl_lua_module_init_impl, rl_lua_module_deinit_impl,
                rl_lua_module_update_impl)
