/* rl_lua_websocket.c - Lua WebSocket bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdbool.h>
#include <stdint.h>
#include <string.h>

#include "websocket/websocket.h"
#include "rl_lua_websocket.h"

#define RL_LUA_WS_MAX_HANDLES 16

typedef struct {
    int          in_use;
    int          id;
    websocket_t *ws;
    int          on_open_ref;
    int          on_message_ref;
    int          on_close_ref;
    int          on_error_ref;
} rl_lua_ws_entry_t;

static lua_State         *rl_lua_ws_state                       = NULL;
static int                rl_lua_ws_next_id                     = 1;
static rl_lua_ws_entry_t  rl_lua_ws_entries[RL_LUA_WS_MAX_HANDLES];

/* ── entry management ────────────────────────────────────────────────────── */

static rl_lua_ws_entry_t *rl_lua_ws_find(int id)
{
    int i;
    for (i = 0; i < RL_LUA_WS_MAX_HANDLES; i++) {
        if (rl_lua_ws_entries[i].in_use && rl_lua_ws_entries[i].id == id)
            return &rl_lua_ws_entries[i];
    }
    return NULL;
}

static void rl_lua_ws_unref_callbacks(rl_lua_ws_entry_t *e)
{
    if (rl_lua_ws_state == NULL) return;
    if (e->on_open_ref    != LUA_NOREF) { luaL_unref(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_open_ref);    e->on_open_ref    = LUA_NOREF; }
    if (e->on_message_ref != LUA_NOREF) { luaL_unref(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_message_ref); e->on_message_ref = LUA_NOREF; }
    if (e->on_close_ref   != LUA_NOREF) { luaL_unref(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_close_ref);   e->on_close_ref   = LUA_NOREF; }
    if (e->on_error_ref   != LUA_NOREF) { luaL_unref(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_error_ref);   e->on_error_ref   = LUA_NOREF; }
}

static void rl_lua_ws_release(rl_lua_ws_entry_t *e)
{
    rl_lua_ws_unref_callbacks(e);
    if (e->ws) { websocket_destroy(e->ws); e->ws = NULL; }
    e->in_use = 0;
}

/* ── C → Lua callback bridges ────────────────────────────────────────────── */

static void ws_cb_open(websocket_t *ws, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    (void)ws;
    if (!e || e->on_open_ref == LUA_NOREF) return;
    lua_rawgeti(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_open_ref);
    if (lua_pcall(rl_lua_ws_state, 0, 0, 0) != 0)
        lua_pop(rl_lua_ws_state, 1);
}

static void ws_cb_message(websocket_t *ws, const char *data, int len, bool is_text, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    (void)ws;
    if (!e || e->on_message_ref == LUA_NOREF) return;
    lua_rawgeti(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_message_ref);
    lua_pushlstring(rl_lua_ws_state, data, (size_t)len);
    lua_pushboolean(rl_lua_ws_state, is_text ? 1 : 0);
    if (lua_pcall(rl_lua_ws_state, 2, 0, 0) != 0)
        lua_pop(rl_lua_ws_state, 1);
}

static void ws_cb_close(websocket_t *ws, int code, const char *reason, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    (void)ws;
    if (!e || e->on_close_ref == LUA_NOREF) return;
    lua_rawgeti(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_close_ref);
    lua_pushinteger(rl_lua_ws_state, code);
    lua_pushstring(rl_lua_ws_state, reason ? reason : "");
    if (lua_pcall(rl_lua_ws_state, 2, 0, 0) != 0)
        lua_pop(rl_lua_ws_state, 1);
}

static void ws_cb_error(websocket_t *ws, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    (void)ws;
    if (!e || e->on_error_ref == LUA_NOREF) return;
    lua_rawgeti(rl_lua_ws_state, LUA_REGISTRYINDEX, e->on_error_ref);
    if (lua_pcall(rl_lua_ws_state, 0, 0, 0) != 0)
        lua_pop(rl_lua_ws_state, 1);
}

/* ── Lua API ─────────────────────────────────────────────────────────────── */

/*
 * rl.ws_create(url, on_open, on_message, on_close, on_error) -> handle | nil
 * All callbacks are optional (pass nil to omit).
 * Signatures:
 *   on_open()
 *   on_message(data: string, is_text: boolean)
 *   on_close(code: integer, reason: string)
 *   on_error()
 */
static int rl_lua_ws_create(lua_State *L)
{
    const char *url = luaL_checkstring(L, 1);
    int on_open_ref    = LUA_NOREF;
    int on_message_ref = LUA_NOREF;
    int on_close_ref   = LUA_NOREF;
    int on_error_ref   = LUA_NOREF;
    int i;
    rl_lua_ws_entry_t *e = NULL;
    websocket_callbacks_t cbs;

    if (lua_isfunction(L, 2)) { lua_pushvalue(L, 2); on_open_ref    = luaL_ref(L, LUA_REGISTRYINDEX); }
    if (lua_isfunction(L, 3)) { lua_pushvalue(L, 3); on_message_ref = luaL_ref(L, LUA_REGISTRYINDEX); }
    if (lua_isfunction(L, 4)) { lua_pushvalue(L, 4); on_close_ref   = luaL_ref(L, LUA_REGISTRYINDEX); }
    if (lua_isfunction(L, 5)) { lua_pushvalue(L, 5); on_error_ref   = luaL_ref(L, LUA_REGISTRYINDEX); }

    for (i = 0; i < RL_LUA_WS_MAX_HANDLES; i++) {
        if (!rl_lua_ws_entries[i].in_use) { e = &rl_lua_ws_entries[i]; break; }
    }
    if (!e) {
        if (on_open_ref    != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, on_open_ref);
        if (on_message_ref != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, on_message_ref);
        if (on_close_ref   != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, on_close_ref);
        if (on_error_ref   != LUA_NOREF) luaL_unref(L, LUA_REGISTRYINDEX, on_error_ref);
        lua_pushnil(L);
        return 1;
    }

    e->in_use         = 1;
    e->id             = rl_lua_ws_next_id++;
    e->on_open_ref    = on_open_ref;
    e->on_message_ref = on_message_ref;
    e->on_close_ref   = on_close_ref;
    e->on_error_ref   = on_error_ref;

    memset(&cbs, 0, sizeof(cbs));
    cbs.on_open    = (on_open_ref    != LUA_NOREF) ? ws_cb_open    : NULL;
    cbs.on_message = (on_message_ref != LUA_NOREF) ? ws_cb_message : NULL;
    cbs.on_close   = (on_close_ref   != LUA_NOREF) ? ws_cb_close   : NULL;
    cbs.on_error   = (on_error_ref   != LUA_NOREF) ? ws_cb_error   : NULL;

    e->ws = websocket_create(url, &cbs, (void *)(uintptr_t)e->id);
    if (!e->ws) {
        rl_lua_ws_release(e);
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, e->id);
    return 1;
}

/* rl.ws_poll(handle) — process pending messages; call once per tick */
static int rl_lua_ws_poll(lua_State *L)
{
    int id = (int)luaL_checkinteger(L, 1);
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    if (e && e->ws) websocket_poll(e->ws);
    return 0;
}

/* rl.ws_send(handle, text) -> 0 on success */
static int rl_lua_ws_send(lua_State *L)
{
    int id = (int)luaL_checkinteger(L, 1);
    const char *text = luaL_checkstring(L, 2);
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    lua_pushinteger(L, (e && e->ws) ? websocket_send_text(e->ws, text) : -1);
    return 1;
}

/* rl.ws_close(handle [, code [, reason]]) */
static int rl_lua_ws_close(lua_State *L)
{
    int id            = (int)luaL_checkinteger(L, 1);
    int code          = (int)luaL_optinteger(L, 2, 1000);
    const char *reason = luaL_optstring(L, 3, "");
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    if (e && e->ws) websocket_close(e->ws, code, reason);
    return 0;
}

/* rl.ws_destroy(handle) */
static int rl_lua_ws_destroy(lua_State *L)
{
    int id = (int)luaL_checkinteger(L, 1);
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    if (e) rl_lua_ws_release(e);
    return 0;
}

/* rl.ws_is_connected(handle) -> boolean */
static int rl_lua_ws_is_connected(lua_State *L)
{
    int id = (int)luaL_checkinteger(L, 1);
    rl_lua_ws_entry_t *e = rl_lua_ws_find(id);
    lua_pushboolean(L, (e && e->ws && websocket_is_connected(e->ws)) ? 1 : 0);
    return 1;
}

/* ── registration ────────────────────────────────────────────────────────── */

void rl_register_websocket_bindings(lua_State *L)
{
    int i;

    rl_lua_ws_state = L;
    memset(rl_lua_ws_entries, 0, sizeof(rl_lua_ws_entries));
    for (i = 0; i < RL_LUA_WS_MAX_HANDLES; i++) {
        rl_lua_ws_entries[i].on_open_ref    = LUA_NOREF;
        rl_lua_ws_entries[i].on_message_ref = LUA_NOREF;
        rl_lua_ws_entries[i].on_close_ref   = LUA_NOREF;
        rl_lua_ws_entries[i].on_error_ref   = LUA_NOREF;
    }

    lua_pushcfunction(L, rl_lua_ws_create);       lua_setfield(L, -2, "ws_create");
    lua_pushcfunction(L, rl_lua_ws_poll);          lua_setfield(L, -2, "ws_poll");
    lua_pushcfunction(L, rl_lua_ws_send);          lua_setfield(L, -2, "ws_send");
    lua_pushcfunction(L, rl_lua_ws_close);         lua_setfield(L, -2, "ws_close");
    lua_pushcfunction(L, rl_lua_ws_destroy);       lua_setfield(L, -2, "ws_destroy");
    lua_pushcfunction(L, rl_lua_ws_is_connected);  lua_setfield(L, -2, "ws_is_connected");
}
