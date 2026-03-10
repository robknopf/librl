#include "rl_lua_addon.h"
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

typedef struct rl_lua_addon_state_t {
    rl_addon_host_api_t host;
    rl_lua_vm_t vm;
} rl_lua_addon_state_t;

static void lua_addon_on_do_string(void *payload, void *listener_user_data);
static void lua_addon_on_do_file(void *payload, void *listener_user_data);

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

static int lua_vm_exec_file(rl_lua_vm_t *vm, const char *filename)
{
    fileio_read_result_t read_result = {0};
    const char *chunk_name = NULL;
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

    chunk_name = filename;
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

static int rl_lua_addon_init_impl(const rl_addon_host_api_t *host, void **addon_state)
{
    rl_lua_addon_state_t *state = NULL;
    int rc = 0;

    if (addon_state == NULL) {
        return -1;
    }

    state = (rl_lua_addon_state_t *)rl_addon_alloc(host, sizeof(*state));
    if (state == NULL) {
        rl_addon_log(host, RL_ADDON_LOG_ERROR, "lua addon init: allocation failed");
        return -1;
    }
    memset(state, 0, sizeof(*state));

    if (host != NULL) {
        state->host = *host;
    }

    rc = lua_vm_init(&state->vm);
    if (rc != 0) {
        rl_addon_log(host, RL_ADDON_LOG_ERROR, state->vm.last_error);
        rl_addon_free(host, state);
        return -1;
    }

    *addon_state = (void *)state;
    (void)rl_addon_event_on(&state->host, "lua.do_string", lua_addon_on_do_string, state);
    (void)rl_addon_event_on(&state->host, "lua.do_file", lua_addon_on_do_file, state);
    (void)rl_addon_event_emit(&state->host, "lua.ready", state);
    rl_addon_log(host, RL_ADDON_LOG_INFO, "lua addon initialized");
    return 0;
}

static void rl_lua_addon_deinit_impl(void *addon_state)
{
    rl_lua_addon_state_t *state = (rl_lua_addon_state_t *)addon_state;

    if (state == NULL) {
        return;
    }

    (void)rl_addon_event_off(&state->host, "lua.do_string", lua_addon_on_do_string, state);
    (void)rl_addon_event_off(&state->host, "lua.do_file", lua_addon_on_do_file, state);
    (void)rl_addon_event_emit(&state->host, "lua.deinit", state);
    lua_vm_deinit(&state->vm);
    rl_addon_log(&state->host, RL_ADDON_LOG_INFO, "lua addon deinitialized");
    rl_addon_free(&state->host, state);
}

static int rl_lua_addon_update_impl(void *addon_state, float dt_seconds)
{
    (void)addon_state;
    (void)dt_seconds;
    return 0;
}

static void lua_addon_on_do_file(void *payload, void *listener_user_data)
{
    rl_lua_addon_state_t *state = (rl_lua_addon_state_t *)listener_user_data;
    const char *filename = (const char *)payload;
    int rc = 0;

    if (state == NULL) {
        return;
    }

    rc = lua_vm_exec_file(&state->vm, filename);
    if (rc != 0) {
        rl_addon_log(&state->host, RL_ADDON_LOG_ERROR, state->vm.last_error);
        (void)rl_addon_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    else {
        (void)rl_addon_event_emit(&state->host, "lua.ok", state);
    }
}

static void lua_addon_on_do_string(void *payload, void *listener_user_data)
{
    rl_lua_addon_state_t *state = (rl_lua_addon_state_t *)listener_user_data;
    const char *source = (const char *)payload;
    int rc = 0;

    if (state == NULL) {
        return;
    }
    rc = lua_vm_exec_string(&state->vm, source);
    if (rc != 0) {
        rl_addon_log(&state->host, RL_ADDON_LOG_ERROR, state->vm.last_error);
        (void)rl_addon_event_emit(&state->host, "lua.error", (void *)state->vm.last_error);
    }
    else {
        (void)rl_addon_event_emit(&state->host, "lua.ok", state);
    }
}

RL_ADDON_DEFINE(rl_lua_addon_get_api, "lua", rl_lua_addon_init_impl, rl_lua_addon_deinit_impl,
                rl_lua_addon_update_impl)
