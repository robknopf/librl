#include "rl_lua_module.h"
#include "fileio/fileio.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

typedef struct rl_lua_vm_t {
    lua_State *state;
    char last_error[256];
} rl_lua_vm_t;

typedef struct rl_lua_module_state_t {
    rl_module_host_api_t host;
    rl_lua_vm_t vm;
} rl_lua_module_state_t;

static void lua_module_on_do_string(void *payload, void *listener_user_data);
static void lua_module_on_do_file(void *payload, void *listener_user_data);
static int lua_module_log_binding(lua_State *L);
static const char *lua_module_debug_source(lua_Debug *ar, char *buffer, size_t buffer_size);

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
        lua_close(L);
    }
    memset(vm, 0, sizeof(*vm));
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
    lua_vm_deinit(&state->vm);
    rl_module_log(&state->host, RL_MODULE_LOG_INFO, "lua module deinitialized");
    rl_module_free(&state->host, state);
}

static int rl_lua_module_update_impl(void *module_state, float dt_seconds)
{
    (void)module_state;
    (void)dt_seconds;
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
