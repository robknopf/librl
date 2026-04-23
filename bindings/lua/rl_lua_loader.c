/* rl_loader.c - Lua loader bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "rl_loader.h"
#include "rl_lua_loader.h"

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

#define RL_LUA_LOADER_MAX_CALLBACKS 128
#define RL_LUA_LOADER_NORMALIZE_BUFFER 4096

typedef struct rl_lua_loader_callback_t {
    int in_use;
    int id;
    int success_ref;
    int failure_ref;
} rl_lua_loader_callback_t;

static lua_State *rl_lua_loader_state = NULL;
static int rl_lua_loader_next_id = 1;
static rl_lua_loader_callback_t rl_lua_loader_callbacks[RL_LUA_LOADER_MAX_CALLBACKS];

static rl_lua_loader_callback_t *rl_lua_loader_find_by_id(int id)
{
    int i = 0;
    for (i = 0; i < RL_LUA_LOADER_MAX_CALLBACKS; i++) {
        if (rl_lua_loader_callbacks[i].in_use && rl_lua_loader_callbacks[i].id == id) {
            return &rl_lua_loader_callbacks[i];
        }
    }
    return NULL;
}

static void rl_lua_loader_release_callback(rl_lua_loader_callback_t *entry)
{
    if (entry == NULL || !entry->in_use) {
        return;
    }

    if (rl_lua_loader_state != NULL) {
        if (entry->success_ref != LUA_NOREF) {
            luaL_unref(rl_lua_loader_state, LUA_REGISTRYINDEX, entry->success_ref);
        }
        if (entry->failure_ref != LUA_NOREF) {
            luaL_unref(rl_lua_loader_state, LUA_REGISTRYINDEX, entry->failure_ref);
        }
    }

    entry->in_use = 0;
    entry->id = 0;
    entry->success_ref = LUA_NOREF;
    entry->failure_ref = LUA_NOREF;
}

static rl_lua_loader_callback_t *rl_lua_loader_allocate_callback(int success_ref, int failure_ref)
{
    int i = 0;
    for (i = 0; i < RL_LUA_LOADER_MAX_CALLBACKS; i++) {
        if (!rl_lua_loader_callbacks[i].in_use) {
            rl_lua_loader_callbacks[i].in_use = 1;
            rl_lua_loader_callbacks[i].id = rl_lua_loader_next_id++;
            rl_lua_loader_callbacks[i].success_ref = success_ref;
            rl_lua_loader_callbacks[i].failure_ref = failure_ref;
            return &rl_lua_loader_callbacks[i];
        }
    }
    return NULL;
}

static void rl_lua_loader_invoke(int ref, const char *path)
{
    if (rl_lua_loader_state == NULL || ref == LUA_NOREF) {
        return;
    }

    lua_rawgeti(rl_lua_loader_state, LUA_REGISTRYINDEX, ref);
    lua_pushstring(rl_lua_loader_state, path ? path : "");
    if (lua_pcall(rl_lua_loader_state, 1, 0, 0) != 0) {
        lua_pop(rl_lua_loader_state, 1);
    }
}

static void rl_lua_loader_on_success(const char *path, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_loader_callback_t *entry = rl_lua_loader_find_by_id(id);
    if (entry == NULL) {
        return;
    }

    rl_lua_loader_invoke(entry->success_ref, path);
    rl_lua_loader_release_callback(entry);
}

static void rl_lua_loader_on_failure(const char *path, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_loader_callback_t *entry = rl_lua_loader_find_by_id(id);
    if (entry == NULL) {
        return;
    }

    rl_lua_loader_invoke(entry->failure_ref, path);
    rl_lua_loader_release_callback(entry);
}

static int rl_loader_set_asset_host_lua(lua_State *L)
{
    const char *asset_host = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_loader_set_asset_host(asset_host));
    return 1;
}

static int rl_loader_get_asset_host_lua(lua_State *L)
{
    (void)L;
    lua_pushstring(L, rl_loader_get_asset_host());
    return 1;
}

static int rl_loader_restore_fs_async_lua(lua_State *L)
{
    rl_loader_task_t *task = rl_loader_restore_fs_async();
    lua_pushinteger(L, (lua_Integer)(uintptr_t)task);
    return 1;
}

static int rl_loader_import_asset_async_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_loader_task_t *task = rl_loader_import_asset_async(filename);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)task);
    return 1;
}

static int rl_loader_import_assets_async_lua(lua_State *L)
{
    size_t count = 0;
    size_t i = 0;
    const char **filenames = NULL;
    rl_loader_task_t *task = NULL;

    luaL_checktype(L, 1, LUA_TTABLE);
    count = (size_t)lua_rawlen(L, 1);

    if (count == 0) {
        lua_pushinteger(L, 0);
        return 1;
    }

    filenames = (const char **)calloc(count, sizeof(const char *));
    if (filenames == NULL) {
        lua_pushinteger(L, 0);
        return 1;
    }

    for (i = 0; i < count; i++) {
        lua_rawgeti(L, 1, (int)i + 1);
        filenames[i] = luaL_checkstring(L, -1);
        lua_pop(L, 1);
    }

    task = rl_loader_import_assets_async(filenames, count);
    free(filenames);

    lua_pushinteger(L, (lua_Integer)(uintptr_t)task);
    return 1;
}

static int rl_loader_poll_task_lua(lua_State *L)
{
    rl_loader_task_t *task = (rl_loader_task_t *)(uintptr_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_loader_poll_task(task) ? 1 : 0);
    return 1;
}

static int rl_loader_finish_task_lua(lua_State *L)
{
    rl_loader_task_t *task = (rl_loader_task_t *)(uintptr_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_loader_finish_task(task));
    return 1;
}

static int rl_loader_free_task_lua(lua_State *L)
{
    rl_loader_task_t *task = (rl_loader_task_t *)(uintptr_t)luaL_checkinteger(L, 1);
    rl_loader_free_task(task);
    return 0;
}

static int rl_loader_get_task_path_lua(lua_State *L)
{
    rl_loader_task_t *task = (rl_loader_task_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const char *path = rl_loader_get_task_path(task);
    if (path == NULL) {
        lua_pushnil(L);
    } else {
        lua_pushstring(L, path);
    }
    return 1;
}

static int rl_loader_is_local_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushboolean(L, rl_loader_is_local(filename) ? 1 : 0);
    return 1;
}

static int rl_loader_read_local_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    rl_loader_read_result_t result = rl_loader_read_local(filename);

    if (result.error != 0 || result.data == NULL) {
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, result.error);
        rl_loader_read_result_free(&result);
        return 3;
    }

    lua_pushlstring(L, (const char *)result.data, result.size);
    lua_pushinteger(L, (lua_Integer)result.size);
    lua_pushinteger(L, result.error);

    rl_loader_read_result_free(&result);
    return 3;
}

static int rl_loader_normalize_path_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    char buffer[RL_LUA_LOADER_NORMALIZE_BUFFER];
    buffer[0] = '\0';
    rl_loader_normalize_path(path, buffer, sizeof(buffer));
    lua_pushstring(L, buffer);
    return 1;
}

static int rl_loader_uncache_file_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_loader_uncache_file(filename));
    return 1;
}

static int rl_loader_clear_cache_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_loader_clear_cache());
    return 1;
}

static int rl_loader_queue_task_lua(lua_State *L)
{
    rl_loader_task_t *task = (rl_loader_task_t *)(uintptr_t)luaL_checkinteger(L, 1);
    const char *path = luaL_checkstring(L, 2);
    int success_ref = LUA_NOREF;
    int failure_ref = LUA_NOREF;
    rl_lua_loader_callback_t *entry = NULL;
    rl_loader_queue_task_result_t rc;

    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TFUNCTION);
        lua_pushvalue(L, 3);
        success_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    if (!lua_isnoneornil(L, 4)) {
        luaL_checktype(L, 4, LUA_TFUNCTION);
        lua_pushvalue(L, 4);
        failure_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    entry = rl_lua_loader_allocate_callback(success_ref, failure_ref);
    if (entry == NULL) {
        if (success_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, success_ref);
        if (failure_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, failure_ref);
        lua_pushinteger(L, RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL);
        return 1;
    }

    rc = rl_loader_queue_task(task,
                            path,
                            success_ref == LUA_NOREF ? NULL : rl_lua_loader_on_success,
                            failure_ref == LUA_NOREF ? NULL : rl_lua_loader_on_failure,
                            (void *)(uintptr_t)entry->id);

    if (rc != RL_LOADER_QUEUE_TASK_OK) {
        rl_lua_loader_release_callback(entry);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_loader_tick_lua(lua_State *L)
{
    (void)L;
    rl_loader_tick();
    return 0;
}

void rl_register_loader_bindings(lua_State *L)
{
    rl_lua_loader_state = L;

    lua_pushcfunction(L, rl_loader_set_asset_host_lua);
    lua_setfield(L, -2, "loader_set_asset_host");

    lua_pushcfunction(L, rl_loader_get_asset_host_lua);
    lua_setfield(L, -2, "loader_get_asset_host");

    lua_pushcfunction(L, rl_loader_restore_fs_async_lua);
    lua_setfield(L, -2, "loader_restore_fs_async");

    lua_pushcfunction(L, rl_loader_import_asset_async_lua);
    lua_setfield(L, -2, "loader_import_asset_async");

    lua_pushcfunction(L, rl_loader_import_assets_async_lua);
    lua_setfield(L, -2, "loader_import_assets_async");

    lua_pushcfunction(L, rl_loader_poll_task_lua);
    lua_setfield(L, -2, "loader_poll_task");

    lua_pushcfunction(L, rl_loader_finish_task_lua);
    lua_setfield(L, -2, "loader_finish_task");

    lua_pushcfunction(L, rl_loader_free_task_lua);
    lua_setfield(L, -2, "loader_free_task");

    lua_pushcfunction(L, rl_loader_get_task_path_lua);
    lua_setfield(L, -2, "loader_get_task_path");

    lua_pushcfunction(L, rl_loader_is_local_lua);
    lua_setfield(L, -2, "loader_is_local");

    lua_pushcfunction(L, rl_loader_read_local_lua);
    lua_setfield(L, -2, "loader_read_local");

    lua_pushcfunction(L, rl_loader_normalize_path_lua);
    lua_setfield(L, -2, "loader_normalize_path");

    lua_pushcfunction(L, rl_loader_uncache_file_lua);
    lua_setfield(L, -2, "loader_uncache_file");

    lua_pushcfunction(L, rl_loader_clear_cache_lua);
    lua_setfield(L, -2, "loader_clear_cache");

    lua_pushcfunction(L, rl_loader_queue_task_lua);
    lua_setfield(L, -2, "loader_queue_task");

    lua_pushcfunction(L, rl_loader_tick_lua);
    lua_setfield(L, -2, "loader_tick");
}
