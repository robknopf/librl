/* rl_lua_fileio.c - Lua fileio bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "rl_fileio.h"
#include "rl_lua_fileio.h"

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

#define RL_LUA_FILEIO_MAX_CALLBACKS 128
#define RL_LUA_FILEIO_NORMALIZE_BUFFER 4096

typedef struct rl_lua_fileio_callback_t {
    int in_use;
    int id;
    int success_ref;
    int failure_ref;
    int ctx_ref;
} rl_lua_fileio_callback_t;

static lua_State *rl_lua_fileio_state = NULL;
static int rl_lua_fileio_next_id = 1;
static rl_lua_fileio_callback_t rl_lua_fileio_callbacks[RL_LUA_FILEIO_MAX_CALLBACKS];

static rl_lua_fileio_callback_t *rl_lua_fileio_find_by_id(int id)
{
    int i = 0;
    for (i = 0; i < RL_LUA_FILEIO_MAX_CALLBACKS; i++) {
        if (rl_lua_fileio_callbacks[i].in_use && rl_lua_fileio_callbacks[i].id == id) {
            return &rl_lua_fileio_callbacks[i];
        }
    }
    return NULL;
}

static void rl_lua_fileio_release_callback(rl_lua_fileio_callback_t *entry)
{
    if (entry == NULL || !entry->in_use) {
        return;
    }

    if (rl_lua_fileio_state != NULL) {
        if (entry->success_ref != LUA_NOREF) {
            luaL_unref(rl_lua_fileio_state, LUA_REGISTRYINDEX, entry->success_ref);
        }
        if (entry->failure_ref != LUA_NOREF) {
            luaL_unref(rl_lua_fileio_state, LUA_REGISTRYINDEX, entry->failure_ref);
        }
        if (entry->ctx_ref != LUA_NOREF) {
            luaL_unref(rl_lua_fileio_state, LUA_REGISTRYINDEX, entry->ctx_ref);
        }
    }

    entry->in_use = 0;
    entry->id = 0;
    entry->success_ref = LUA_NOREF;
    entry->failure_ref = LUA_NOREF;
    entry->ctx_ref = LUA_NOREF;
}

static rl_lua_fileio_callback_t *rl_lua_fileio_allocate_callback(int success_ref, int failure_ref, int ctx_ref)
{
    int i = 0;
    for (i = 0; i < RL_LUA_FILEIO_MAX_CALLBACKS; i++) {
        if (!rl_lua_fileio_callbacks[i].in_use) {
            rl_lua_fileio_callbacks[i].in_use = 1;
            rl_lua_fileio_callbacks[i].id = rl_lua_fileio_next_id++;
            rl_lua_fileio_callbacks[i].success_ref = success_ref;
            rl_lua_fileio_callbacks[i].failure_ref = failure_ref;
            rl_lua_fileio_callbacks[i].ctx_ref = ctx_ref;
            return &rl_lua_fileio_callbacks[i];
        }
    }
    return NULL;
}

static void rl_lua_fileio_invoke(int ref, int ctx_ref, const char *path)
{
    if (rl_lua_fileio_state == NULL || ref == LUA_NOREF) {
        return;
    }

    lua_rawgeti(rl_lua_fileio_state, LUA_REGISTRYINDEX, ref);
    lua_pushstring(rl_lua_fileio_state, path ? path : "");
    if (ctx_ref != LUA_NOREF) {
        lua_rawgeti(rl_lua_fileio_state, LUA_REGISTRYINDEX, ctx_ref);
    } else {
        lua_pushnil(rl_lua_fileio_state);
    }
    if (lua_pcall(rl_lua_fileio_state, 2, 0, 0) != 0) {
        lua_pop(rl_lua_fileio_state, 1);
    }
}

static void rl_lua_fileio_on_success(const char *path, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_fileio_callback_t *entry = rl_lua_fileio_find_by_id(id);
    if (entry == NULL) {
        return;
    }

    rl_lua_fileio_invoke(entry->success_ref, entry->ctx_ref, path);
    rl_lua_fileio_release_callback(entry);
}

static void rl_lua_fileio_on_failure(const char *path, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_fileio_callback_t *entry = rl_lua_fileio_find_by_id(id);
    if (entry == NULL) {
        return;
    }

    rl_lua_fileio_invoke(entry->failure_ref, entry->ctx_ref, path);
    rl_lua_fileio_release_callback(entry);
}

static int rl_fileio_set_asset_host_lua(lua_State *L)
{
    const char *asset_host = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_fileio_set_asset_host(asset_host));
    return 1;
}

static int rl_fileio_init_lua(lua_State *L)
{
    const char *base_dir = NULL;

    if (!lua_isnoneornil(L, 1)) {
        base_dir = luaL_checkstring(L, 1);
    }

    lua_pushinteger(L, rl_fileio_init(base_dir));
    return 1;
}

static int rl_fileio_init_async_lua(lua_State *L)
{
    const char *base_dir = NULL;

    if (!lua_isnoneornil(L, 1)) {
        base_dir = luaL_checkstring(L, 1);
    }

    lua_pushinteger(L, rl_fileio_init_async(base_dir));
    return 1;
}

static int rl_fileio_deinit_lua(lua_State *L)
{
    (void)L;
    rl_fileio_deinit();
    return 0;
}

static int rl_fileio_deinit_async_lua(lua_State *L)
{
    (void)L;
    rl_handle_t task = rl_fileio_deinit_async();
    lua_pushinteger(L, (lua_Integer)task);
    return 1;
}

static int rl_fileio_get_asset_host_lua(lua_State *L)
{
    (void)L;
    lua_pushstring(L, rl_fileio_get_asset_host());
    return 1;
}

static int rl_fileio_get_base_dir_lua(lua_State *L)
{
    (void)L;
    lua_pushstring(L, rl_fileio_get_base_dir());
    return 1;
}

static int rl_fileio_ping_asset_host_lua(lua_State *L)
{
    const char *asset_host = NULL;
    double rtt_ms = 0.0;

    if (!lua_isnoneornil(L, 1)) {
        asset_host = luaL_checkstring(L, 1);
    }
    rtt_ms = (double)rl_fileio_ping_asset_host(asset_host);
    lua_pushnumber(L, rtt_ms);
    return 1;
}

static int rl_fileio_is_initialized_lua(lua_State *L)
{
    (void)L;
    lua_pushboolean(L, rl_fileio_is_initialized() ? 1 : 0);
    return 1;
}

static int rl_fileio_is_ready_lua(lua_State *L)
{
    (void)L;
    lua_pushboolean(L, rl_fileio_is_ready() ? 1 : 0);
    return 1;
}

static int rl_fileio_flush_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_fileio_flush());
    return 1;
}

static int rl_fileio_restore_async_lua(lua_State *L)
{
    (void)L;
    rl_handle_t task = rl_fileio_restore_async();
    lua_pushinteger(L, (lua_Integer)task);
    return 1;
}

static int rl_fileio_ensure_async_lua(lua_State *L)
{
    const char *local_path = luaL_checkstring(L, 1);
    const char *src = NULL;

    if (!lua_isnoneornil(L, 2)) {
        src = luaL_checkstring(L, 2);
    }

    rl_handle_t task = rl_fileio_ensure_async(local_path, src);
    lua_pushinteger(L, (lua_Integer)task);
    return 1;
}

static int rl_fileio_ensure_lua(lua_State *L)
{
    const char *local_path = luaL_checkstring(L, 1);
    const char *src = NULL;

    if (!lua_isnoneornil(L, 2)) {
        src = luaL_checkstring(L, 2);
    }

    lua_pushinteger(L, rl_fileio_ensure(local_path, src));
    return 1;
}

static int rl_fileio_ensure_group_async_lua(lua_State *L)
{
    size_t count = 0;
    size_t i = 0;
    const char **filenames = NULL;
    rl_handle_t task = 0;

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

    task = rl_fileio_ensure_group_async(filenames, count);
    free(filenames);

    lua_pushinteger(L, (lua_Integer)task);
    return 1;
}

static int rl_fileio_poll_lua(lua_State *L)
{
    rl_handle_t task = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushboolean(L, rl_fileio_poll_task(task) ? 1 : 0);
    return 1;
}

static int rl_fileio_finish_lua(lua_State *L)
{
    rl_handle_t task = (rl_handle_t)luaL_checkinteger(L, 1);
    lua_pushinteger(L, rl_fileio_finish_task(task));
    return 1;
}

static int rl_fileio_free_lua(lua_State *L)
{
    rl_handle_t task = (rl_handle_t)luaL_checkinteger(L, 1);
    rl_fileio_free_task(task);
    return 0;
}

static int rl_fileio_get_path_lua(lua_State *L)
{
    rl_handle_t task = (rl_handle_t)luaL_checkinteger(L, 1);
    const char *path = rl_fileio_get_task_path(task);
    if (path == NULL) {
        lua_pushnil(L);
    } else {
        lua_pushstring(L, path);
    }
    return 1;
}

static int rl_fileio_exists_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushboolean(L, rl_fileio_exists(filename) ? 1 : 0);
    return 1;
}

static int rl_fileio_read_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    unsigned char *data = NULL;
    size_t size = 0;
    int rc = rl_fileio_read(filename, &data, &size);

    if (rc != 0 || data == NULL) {
        rl_fileio_read_free(data);
        lua_pushnil(L);
        lua_pushinteger(L, 0);
        lua_pushinteger(L, rc);
        return 3;
    }

    lua_pushlstring(L, (const char *)data, size);
    lua_pushinteger(L, (lua_Integer)size);
    lua_pushinteger(L, 0);

    rl_fileio_read_free(data);
    return 3;
}

static int rl_fileio_write_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    size_t size = 0;
    const char *data = luaL_checklstring(L, 2, &size);
    lua_pushinteger(L, rl_fileio_write(path, (const unsigned char *)data, size));
    return 1;
}

static int rl_fileio_remove_lua(lua_State *L)
{
    const char *filename = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_fileio_remove(filename));
    return 1;
}

static int rl_fileio_mkdir_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_fileio_mkdir(path));
    return 1;
}

static int rl_fileio_rmdir_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_fileio_rmdir(path));
    return 1;
}

static int rl_fileio_clear_lua(lua_State *L)
{
    (void)L;
    lua_pushinteger(L, rl_fileio_clear());
    return 1;
}

static int rl_fileio_normalize_path_lua(lua_State *L)
{
    const char *path = luaL_checkstring(L, 1);
    char buffer[RL_LUA_FILEIO_NORMALIZE_BUFFER];
    buffer[0] = '\0';
    rl_fileio_normalize_path(path, buffer, sizeof(buffer));
    lua_pushstring(L, buffer);
    return 1;
}

static int rl_fileio_add_task_lua(lua_State *L)
{
    rl_handle_t task = (rl_handle_t)luaL_checkinteger(L, 1);
    int success_ref = LUA_NOREF;
    int failure_ref = LUA_NOREF;
    int ctx_ref = LUA_NOREF;
    rl_lua_fileio_callback_t *entry = NULL;
    int rc;

    if (!lua_isnoneornil(L, 2)) {
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        success_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    if (!lua_isnoneornil(L, 3)) {
        luaL_checktype(L, 3, LUA_TFUNCTION);
        lua_pushvalue(L, 3);
        failure_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    if (!lua_isnoneornil(L, 4)) {
        lua_pushvalue(L, 4);
        ctx_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    entry = rl_lua_fileio_allocate_callback(success_ref, failure_ref, ctx_ref);
    if (entry == NULL) {
        if (success_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, success_ref);
        if (failure_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, failure_ref);
        if (ctx_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, ctx_ref);
        rl_fileio_free_task(task);
        lua_pushinteger(L, -2);
        return 1;
    }

    rc = rl_fileio_add_task(task,
                            success_ref == LUA_NOREF ? NULL : rl_lua_fileio_on_success,
                            failure_ref == LUA_NOREF ? NULL : rl_lua_fileio_on_failure,
                            (void *)(uintptr_t)entry->id);

    if (rc != 0) {
        rl_lua_fileio_release_callback(entry);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_fileio_tick_lua(lua_State *L)
{
    (void)L;
    rl_fileio_tick();
    return 0;
}

void rl_register_fileio_bindings(lua_State *L)
{
    rl_lua_fileio_state = L;

    lua_pushinteger(L, RL_FILEIO_ADD_TASK_OK);
    lua_setfield(L, -2, "RL_FILEIO_ADD_TASK_OK");

    lua_pushinteger(L, RL_FILEIO_ADD_TASK_ERR_INVALID);
    lua_setfield(L, -2, "RL_FILEIO_ADD_TASK_ERR_INVALID");

    lua_pushinteger(L, RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL);
    lua_setfield(L, -2, "RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL");

    lua_pushcfunction(L, rl_fileio_init_lua);
    lua_setfield(L, -2, "fileio_init");

    lua_pushcfunction(L, rl_fileio_init_async_lua);
    lua_setfield(L, -2, "fileio_init_async");

    lua_pushcfunction(L, rl_fileio_deinit_lua);
    lua_setfield(L, -2, "fileio_deinit");

    lua_pushcfunction(L, rl_fileio_deinit_async_lua);
    lua_setfield(L, -2, "fileio_deinit_async");

    lua_pushcfunction(L, rl_fileio_set_asset_host_lua);
    lua_setfield(L, -2, "fileio_set_asset_host");

    lua_pushcfunction(L, rl_fileio_get_asset_host_lua);
    lua_setfield(L, -2, "fileio_get_asset_host");

    lua_pushcfunction(L, rl_fileio_get_base_dir_lua);
    lua_setfield(L, -2, "fileio_get_base_dir");

    lua_pushcfunction(L, rl_fileio_ping_asset_host_lua);
    lua_setfield(L, -2, "fileio_ping_asset_host");

    lua_pushcfunction(L, rl_fileio_is_initialized_lua);
    lua_setfield(L, -2, "fileio_is_initialized");

    lua_pushcfunction(L, rl_fileio_is_ready_lua);
    lua_setfield(L, -2, "fileio_is_ready");

    lua_pushcfunction(L, rl_fileio_flush_lua);
    lua_setfield(L, -2, "fileio_flush");

    lua_pushcfunction(L, rl_fileio_restore_async_lua);
    lua_setfield(L, -2, "fileio_restore_async");

    lua_pushcfunction(L, rl_fileio_ensure_async_lua);
    lua_setfield(L, -2, "fileio_ensure_async");

    lua_pushcfunction(L, rl_fileio_ensure_lua);
    lua_setfield(L, -2, "fileio_ensure");

    lua_pushcfunction(L, rl_fileio_ensure_group_async_lua);
    lua_setfield(L, -2, "fileio_ensure_group_async");

    lua_pushcfunction(L, rl_fileio_poll_lua);
    lua_setfield(L, -2, "fileio_poll_task");

    lua_pushcfunction(L, rl_fileio_finish_lua);
    lua_setfield(L, -2, "fileio_finish_task");

    lua_pushcfunction(L, rl_fileio_free_lua);
    lua_setfield(L, -2, "fileio_free_task");

    lua_pushcfunction(L, rl_fileio_get_path_lua);
    lua_setfield(L, -2, "fileio_get_task_path");

    lua_pushcfunction(L, rl_fileio_exists_lua);
    lua_setfield(L, -2, "fileio_exists");

    lua_pushcfunction(L, rl_fileio_read_lua);
    lua_setfield(L, -2, "fileio_read");

    lua_pushcfunction(L, rl_fileio_write_lua);
    lua_setfield(L, -2, "fileio_write");

    lua_pushcfunction(L, rl_fileio_remove_lua);
    lua_setfield(L, -2, "fileio_remove");

    lua_pushcfunction(L, rl_fileio_mkdir_lua);
    lua_setfield(L, -2, "fileio_mkdir");

    lua_pushcfunction(L, rl_fileio_rmdir_lua);
    lua_setfield(L, -2, "fileio_rmdir");

    lua_pushcfunction(L, rl_fileio_clear_lua);
    lua_setfield(L, -2, "fileio_clear");

    lua_pushcfunction(L, rl_fileio_normalize_path_lua);
    lua_setfield(L, -2, "fileio_normalize_path");

    lua_pushcfunction(L, rl_fileio_add_task_lua);
    lua_setfield(L, -2, "fileio_add_task");

    lua_pushcfunction(L, rl_fileio_tick_lua);
    lua_setfield(L, -2, "fileio_tick");
}
