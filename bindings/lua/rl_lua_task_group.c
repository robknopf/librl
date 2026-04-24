/* Task group for async loader tasks — mirrors Haxe RL.loaderCreateTaskGroup / Nim loaderCreateTaskGroup. */

#include <lauxlib.h>
#include <lua.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "rl_loader.h"
#include "rl_lua_task_group.h"

#define RL_TASK_GROUP_MT "librl.task_group"

#if LUA_VERSION_NUM < 502
#define lua_rawlen lua_objlen
#endif

#ifndef LUA_NOREF
#define LUA_NOREF (-2)
#endif

typedef struct rl_tg_entry_t {
    rl_loader_task_t *task;
    char *path;
    int done;
    int rc;
    int on_success_ref;
    int on_error_ref;
} rl_tg_entry_t;

typedef struct rl_task_group_ud_t {
    rl_tg_entry_t *entries;
    size_t n;
    size_t cap;
    int on_complete_ref;
    int on_error_ref;
    int ctx_ref;
    int terminal_invoked;
    int failed_count;
    int completed_count;
} rl_task_group_ud_t;

static rl_task_group_ud_t *rl_tg_check(lua_State *L, int i)
{
    return (rl_task_group_ud_t *)luaL_checkudata(L, i, RL_TASK_GROUP_MT);
}

static void rl_tg_entry_clear(lua_State *L, rl_tg_entry_t *e)
{
    if (e->on_success_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, e->on_success_ref);
    }
    if (e->on_error_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, e->on_error_ref);
    }
    e->on_success_ref = LUA_NOREF;
    e->on_error_ref = LUA_NOREF;
    free(e->path);
    e->path = NULL;
    e->task = NULL;
    e->done = 0;
    e->rc = 0;
}

static int rl_tg_grow(rl_task_group_ud_t *g)
{
    size_t ncap;
    void *nxt;

    if (g->n < g->cap) {
        return 0;
    }
    ncap = g->cap ? g->cap * 2U : 8U;
    nxt = realloc(g->entries, ncap * sizeof(g->entries[0]));
    if (nxt == NULL) {
        return -1;
    }
    g->entries = (rl_tg_entry_t *)nxt;
    g->cap = ncap;
    return 0;
}

static void call_path_ctx(lua_State *L, int fn_ref, const char *path, int ctx_ref)
{
    if (fn_ref == LUA_NOREF) {
        return;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, fn_ref);
    lua_pushstring(L, path != NULL ? path : "");
    if (ctx_ref != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ctx_ref);
    } else {
        lua_pushnil(L);
    }
    if (lua_pcall(L, 2, 0, 0) != 0) {
        lua_pop(L, 1);
    }
}

static void call_group_ctx(lua_State *L, int fn_ref, int self_idx, int ctx_ref)
{
    if (fn_ref == LUA_NOREF) {
        return;
    }
    lua_rawgeti(L, LUA_REGISTRYINDEX, fn_ref);
    lua_pushvalue(L, self_idx);
    if (ctx_ref != LUA_NOREF) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ctx_ref);
    } else {
        lua_pushnil(L);
    }
    if (lua_pcall(L, 2, 0, 0) != 0) {
        lua_pop(L, 1);
    }
}

/* returns 0 = ok, -1 = oom (entries), -2 = oom (path) */
static int rl_tg_append_entry(lua_State *L, rl_task_group_ud_t *g, rl_loader_task_t *task, int sref, int eref)
{
    const char *p;
    rl_tg_entry_t *e;

    if (rl_tg_grow(g) != 0) {
        if (sref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, sref);
        }
        if (eref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, eref);
        }
        return -1;
    }
    e = &g->entries[g->n];
    memset(e, 0, sizeof(*e));
    p = rl_loader_get_task_path(task);
    e->path = (p != NULL && p[0] != '\0') ? strdup(p) : strdup("");
    if (e->path == NULL) {
        if (sref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, sref);
        }
        if (eref != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, eref);
        }
        return -2;
    }
    e->task = task;
    e->on_success_ref = sref;
    e->on_error_ref = eref;
    g->n++;
    return 0;
}

static int task_group_add_task(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    rl_loader_task_t *task;
    int sref;
    int eref;
    int rc;

    if (lua_gettop(L) < 2 || lua_isnoneornil(L, 2)) {
        return 0;
    }
    task = (rl_loader_task_t *)(uintptr_t)(lua_Integer)luaL_checkinteger(L, 2);
    if ((uintptr_t)task == 0) {
        return 0;
    }

    sref = LUA_NOREF;
    eref = LUA_NOREF;
    if (lua_gettop(L) >= 3 && !lua_isnil(L, 3) && lua_isfunction(L, 3)) {
        lua_pushvalue(L, 3);
        sref = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    if (lua_gettop(L) >= 4 && !lua_isnil(L, 4) && lua_isfunction(L, 4)) {
        lua_pushvalue(L, 4);
        eref = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    rc = rl_tg_append_entry(L, g, task, sref, eref);
    if (rc == -1) {
        return luaL_error(L, "out of memory (task group entries)");
    }
    if (rc == -2) {
        return luaL_error(L, "out of memory (path)");
    }
    return 0;
}

static int task_group_add_import_task(lua_State *L)
{
    const char *path;
    rl_loader_task_t *task;
    (void)rl_tg_check(L, 1);
    path = luaL_checkstring(L, 2);
    task = rl_loader_import_asset_async(path);
    if (task == NULL) {
        return 0;
    }
    lua_settop(L, 4);
    lua_pushinteger(L, (lua_Integer)(uintptr_t)task);
    lua_replace(L, 2);
    return task_group_add_task(L);
}

static int task_group_add_import_tasks(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    size_t i;
    int n;
    int rc;

    luaL_checktype(L, 2, LUA_TTABLE);
    n = (int)lua_rawlen(L, 2);
    for (i = 1; i <= (size_t)n; i++) {
        const char *path;
        rl_loader_task_t *task;
        int sref;
        int eref;

        lua_rawgeti(L, 2, (int)i);
        path = luaL_checkstring(L, -1);
        lua_pop(L, 1);
        task = rl_loader_import_asset_async(path);
        if (task == NULL) {
            continue;
        }
        sref = LUA_NOREF;
        eref = LUA_NOREF;
        if (lua_gettop(L) >= 3 && !lua_isnil(L, 3) && lua_isfunction(L, 3)) {
            lua_pushvalue(L, 3);
            sref = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        if (lua_gettop(L) >= 4 && !lua_isnil(L, 4) && lua_isfunction(L, 4)) {
            lua_pushvalue(L, 4);
            eref = luaL_ref(L, LUA_REGISTRYINDEX);
        }
        rc = rl_tg_append_entry(L, g, task, sref, eref);
        if (rc == -1) {
            return luaL_error(L, "out of memory (task group entries)");
        }
        if (rc == -2) {
            return luaL_error(L, "out of memory (path)");
        }
    }
    return 0;
}

static int task_group_remaining_tasks(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    int rem = (int)g->n - g->completed_count;
    if (rem < 0) {
        rem = 0;
    }
    lua_pushinteger(L, rem);
    return 1;
}

static int task_group_is_done(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    int rem = (int)g->n - g->completed_count;
    lua_pushboolean(L, rem <= 0 ? 1 : 0);
    return 1;
}

static int task_group_has_failures(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    lua_pushboolean(L, g->failed_count > 0 ? 1 : 0);
    return 1;
}

static int task_group_tick(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    size_t j;
    int rem;

    rl_loader_tick();
    for (j = 0; j < g->n; j++) {
        rl_tg_entry_t *e = &g->entries[j];

        if (e->done) {
            continue;
        }
        if (!rl_loader_poll_task(e->task)) {
            continue;
        }
        e->rc = rl_loader_finish_task(e->task);
        rl_loader_free_task(e->task);
        e->task = NULL;
        e->done = 1;
        g->completed_count++;
        if (e->rc != 0) {
            g->failed_count++;
            call_path_ctx(L, e->on_error_ref, e->path, g->ctx_ref);
        } else {
            call_path_ctx(L, e->on_success_ref, e->path, g->ctx_ref);
        }
    }
    rem = (int)g->n - g->completed_count;
    if (rem < 0) {
        rem = 0;
    }
    lua_pushboolean(L, rem > 0);
    return 1;
}

static int task_group_process(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    int rem;

    (void)task_group_tick(L);
    lua_pop(L, 1);
    rem = (int)g->n - g->completed_count;
    if (rem < 0) {
        rem = 0;
    }
    if (!g->terminal_invoked && rem == 0) {
        g->terminal_invoked = 1;
        if (g->failed_count > 0) {
            call_group_ctx(L, g->on_error_ref, 1, g->ctx_ref);
        } else {
            call_group_ctx(L, g->on_complete_ref, 1, g->ctx_ref);
        }
    }
    rem = (int)g->n - g->completed_count;
    if (rem < 0) {
        rem = 0;
    }
    lua_pushinteger(L, rem);
    return 1;
}

static int task_group_failed_paths(lua_State *L)
{
    rl_task_group_ud_t *g = rl_tg_check(L, 1);
    size_t j;
    int k;

    lua_newtable(L);
    k = 1;
    for (j = 0; j < g->n; j++) {
        if (g->entries[j].done && g->entries[j].rc != 0) {
            lua_pushstring(L, g->entries[j].path);
            lua_rawseti(L, -2, k);
            k++;
        }
    }
    return 1;
}

static int task_group_gc(lua_State *L)
{
    rl_task_group_ud_t *g = (rl_task_group_ud_t *)luaL_checkudata(L, 1, RL_TASK_GROUP_MT);
    size_t j;

    if (g->on_complete_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, g->on_complete_ref);
    }
    if (g->on_error_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, g->on_error_ref);
    }
    if (g->ctx_ref != LUA_NOREF) {
        luaL_unref(L, LUA_REGISTRYINDEX, g->ctx_ref);
    }
    g->on_complete_ref = LUA_NOREF;
    g->on_error_ref = LUA_NOREF;
    g->ctx_ref = LUA_NOREF;

    for (j = 0; j < g->n; j++) {
        rl_tg_entry_t *e = &g->entries[j];
        if (!e->done && e->task != NULL) {
            rl_loader_free_task(e->task);
            e->task = NULL;
        }
        rl_tg_entry_clear(L, e);
    }
    free(g->entries);
    g->entries = NULL;
    g->n = 0;
    g->cap = 0;
    return 0;
}

static int loader_create_task_group(lua_State *L)
{
    int narg;
    int oc;
    int oe;
    int ctx;
    rl_task_group_ud_t *g;

    narg = lua_gettop(L);
    oc = LUA_NOREF;
    oe = LUA_NOREF;
    ctx = LUA_NOREF;
    if (narg >= 1 && !lua_isnil(L, 1) && lua_isfunction(L, 1)) {
        lua_pushvalue(L, 1);
        oc = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    if (narg >= 2 && !lua_isnil(L, 2) && lua_isfunction(L, 2)) {
        lua_pushvalue(L, 2);
        oe = luaL_ref(L, LUA_REGISTRYINDEX);
    }
    if (narg >= 3 && !lua_isnil(L, 3)) {
        lua_pushvalue(L, 3);
        ctx = luaL_ref(L, LUA_REGISTRYINDEX);
    }

    g = (rl_task_group_ud_t *)lua_newuserdata(L, sizeof(rl_task_group_ud_t));
    memset(g, 0, sizeof(*g));
    g->on_complete_ref = oc;
    g->on_error_ref = oe;
    g->ctx_ref = ctx;
    g->terminal_invoked = 0;
    g->failed_count = 0;
    g->completed_count = 0;
    g->n = 0;
    g->cap = 0;
    g->entries = NULL;

    luaL_getmetatable(L, RL_TASK_GROUP_MT);
    lua_setmetatable(L, -2);
    return 1;
}

static void task_group_ensure_meta(lua_State *L)
{
    if (luaL_newmetatable(L, RL_TASK_GROUP_MT)) {
        static const struct luaL_Reg methods[] = {
            {"add_task", task_group_add_task},
            {"add_import_task", task_group_add_import_task},
            {"add_import_tasks", task_group_add_import_tasks},
            {"remaining_tasks", task_group_remaining_tasks},
            {"is_done", task_group_is_done},
            {"has_failures", task_group_has_failures},
            {"tick", task_group_tick},
            {"process", task_group_process},
            {"failed_paths", task_group_failed_paths},
            {NULL, NULL}
        };
#if LUA_VERSION_NUM >= 502
        luaL_setfuncs(L, methods, 0);
#else
        luaL_register(L, NULL, methods);
#endif
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_pushcfunction(L, task_group_gc);
        lua_setfield(L, -2, "__gc");
    }
    lua_pop(L, 1);
}

void rl_register_lua_task_group(lua_State *L)
{
    /* Module table at -1; under require() modname is at 1 (Lua 5.1) — use -2 like other rl_register_*. */
    task_group_ensure_meta(L);
    lua_pushcfunction(L, loader_create_task_group);
    lua_setfield(L, -2, "loader_create_task_group");
}
