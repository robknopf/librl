/* rl_module.c - Lua module ABI bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdint.h>

#include "rl.h"
#include "rl_lua_module.h"

#define RL_LUA_MODULE_ERROR_BUFFER_SIZE 1024

static int rl_module_log_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    int level = (int)luaL_checkinteger(L, 2);
    const char *message = luaL_checkstring(L, 3);
    rl_module_log(host, level, message);
    return 0;
}

static int rl_module_log_source_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    int level = (int)luaL_checkinteger(L, 2);
    const char *source_file = luaL_checkstring(L, 3);
    int source_line = (int)luaL_checkinteger(L, 4);
    const char *message = luaL_checkstring(L, 5);
    rl_module_log_source(host, level, source_file, source_line, message);
    return 0;
}

static int rl_module_alloc_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    size_t size = (size_t)luaL_checkinteger(L, 2);
    void *ptr = rl_module_alloc(host, size);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)ptr);
    return 1;
}

static int rl_module_free_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    void *ptr = (void *)(uintptr_t)luaL_checkinteger(L, 2);
    rl_module_free(host, ptr);
    return 0;
}

static int rl_module_event_on_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const char *event_name = luaL_checkstring(L, 2);
    rl_module_event_listener_fn listener = (rl_module_event_listener_fn)(uintptr_t)luaL_checkinteger(L, 3);
    void *listener_user_data = (void *)(uintptr_t)luaL_optinteger(L, 4, 0);
    lua_pushinteger(L, rl_module_event_on(host, event_name, listener, listener_user_data));
    return 1;
}

static int rl_module_event_off_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const char *event_name = luaL_checkstring(L, 2);
    rl_module_event_listener_fn listener = (rl_module_event_listener_fn)(uintptr_t)luaL_checkinteger(L, 3);
    void *listener_user_data = (void *)(uintptr_t)luaL_optinteger(L, 4, 0);
    lua_pushinteger(L, rl_module_event_off(host, event_name, listener, listener_user_data));
    return 1;
}

static int rl_module_event_emit_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const char *event_name = luaL_checkstring(L, 2);
    void *payload = (void *)(uintptr_t)luaL_optinteger(L, 3, 0);
    lua_pushinteger(L, rl_module_event_emit(host, event_name, payload));
    return 1;
}

static int rl_module_frame_command_lua(lua_State *L)
{
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const rl_render_command_t *command = (const rl_render_command_t *)(uintptr_t)luaL_checkinteger(L, 2);
    rl_module_frame_command(host, command);
    return 0;
}

static int rl_module_api_validate_lua(lua_State *L)
{
    const rl_module_api_t *api = (const rl_module_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    char error[RL_LUA_MODULE_ERROR_BUFFER_SIZE];
    int rc = rl_module_api_validate(api, error, sizeof(error));
    lua_pushinteger(L, rc);
    lua_pushstring(L, error);
    return 2;
}

static int rl_module_init_instance_lua(lua_State *L)
{
    const rl_module_api_t *api = (const rl_module_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 2);
    void *module_state = NULL;
    char error[RL_LUA_MODULE_ERROR_BUFFER_SIZE];
    int rc = rl_module_init_instance(api, host, &module_state, error, sizeof(error));
    lua_pushinteger(L, rc);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)module_state);
    lua_pushstring(L, error);
    return 3;
}

static int rl_module_get_config_instance_lua(lua_State *L)
{
    const rl_module_api_t *api = (const rl_module_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    void *module_state = (void *)(uintptr_t)luaL_checkinteger(L, 2);
    rl_module_config_t config;
    int rc = rl_module_get_config_instance(api, module_state, &config);

    lua_pushinteger(L, rc);
    lua_newtable(L);

    lua_pushinteger(L, config.width);
    lua_setfield(L, -2, "width");

    lua_pushinteger(L, config.height);
    lua_setfield(L, -2, "height");

    lua_pushinteger(L, config.target_fps);
    lua_setfield(L, -2, "target_fps");

    lua_pushinteger(L, (lua_Integer)config.flags);
    lua_setfield(L, -2, "flags");

    lua_pushstring(L, config.title);
    lua_setfield(L, -2, "title");

    return 2;
}

static int rl_module_start_instance_lua(lua_State *L)
{
    const rl_module_api_t *api = (const rl_module_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    void *module_state = (void *)(uintptr_t)luaL_checkinteger(L, 2);
    lua_pushinteger(L, rl_module_start_instance(api, module_state));
    return 1;
}

static int rl_module_deinit_instance_lua(lua_State *L)
{
    const rl_module_api_t *api = (const rl_module_api_t *)(uintptr_t)luaL_checkinteger(L, 1);
    void *module_state = (void *)(uintptr_t)luaL_checkinteger(L, 2);
    rl_module_deinit_instance(api, module_state);
    return 0;
}

static int rl_module_get_api_lua(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    const rl_module_api_t *api = rl_module_get_api(name);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)api);
    return 1;
}

static int rl_module_init_lua(lua_State *L)
{
    const char *name = luaL_checkstring(L, 1);
    const rl_module_host_api_t *host = (const rl_module_host_api_t *)(uintptr_t)luaL_checkinteger(L, 2);
    const rl_module_api_t *out_api = NULL;
    void *module_state = NULL;
    char error[RL_LUA_MODULE_ERROR_BUFFER_SIZE];
    int rc = rl_module_init(name, host, &out_api, &module_state, error, sizeof(error));

    lua_pushinteger(L, rc);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)out_api);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)module_state);
    lua_pushstring(L, error);
    return 4;
}

void rl_register_module_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_module_log_lua);
    lua_setfield(L, -2, "module_log");

    lua_pushcfunction(L, rl_module_log_source_lua);
    lua_setfield(L, -2, "module_log_source");

    lua_pushcfunction(L, rl_module_alloc_lua);
    lua_setfield(L, -2, "module_alloc");

    lua_pushcfunction(L, rl_module_free_lua);
    lua_setfield(L, -2, "module_free");

    lua_pushcfunction(L, rl_module_event_on_lua);
    lua_setfield(L, -2, "module_event_on");

    lua_pushcfunction(L, rl_module_event_off_lua);
    lua_setfield(L, -2, "module_event_off");

    lua_pushcfunction(L, rl_module_event_emit_lua);
    lua_setfield(L, -2, "module_event_emit");

    lua_pushcfunction(L, rl_module_frame_command_lua);
    lua_setfield(L, -2, "module_frame_command");

    lua_pushcfunction(L, rl_module_api_validate_lua);
    lua_setfield(L, -2, "module_api_validate");

    lua_pushcfunction(L, rl_module_init_instance_lua);
    lua_setfield(L, -2, "module_init_instance");

    lua_pushcfunction(L, rl_module_get_config_instance_lua);
    lua_setfield(L, -2, "module_get_config_instance");

    lua_pushcfunction(L, rl_module_start_instance_lua);
    lua_setfield(L, -2, "module_start_instance");

    lua_pushcfunction(L, rl_module_deinit_instance_lua);
    lua_setfield(L, -2, "module_deinit_instance");

    lua_pushcfunction(L, rl_module_get_api_lua);
    lua_setfield(L, -2, "module_get_api");

    lua_pushcfunction(L, rl_module_init_lua);
    lua_setfield(L, -2, "module_init");
}
