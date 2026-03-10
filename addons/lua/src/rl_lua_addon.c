#include "rl_lua_addon.h"

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
    rl_addon_log(host, RL_ADDON_LOG_INFO, "lua addon initialized");
    return 0;
}

static void rl_lua_addon_deinit_impl(void *addon_state)
{
    rl_lua_addon_state_t *state = (rl_lua_addon_state_t *)addon_state;

    if (state == NULL) {
        return;
    }

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

RL_ADDON_DEFINE(rl_lua_addon_get_api, "lua", rl_lua_addon_init_impl, rl_lua_addon_deinit_impl,
                rl_lua_addon_update_impl)
