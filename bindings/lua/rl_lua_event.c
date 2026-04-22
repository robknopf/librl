/* rl_event.c - Lua event bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "rl.h"
#include "rl_lua_event.h"

#define RL_LUA_EVENT_MAX_LISTENERS 256

typedef struct rl_lua_event_listener_t {
    int in_use;
    int id;
    int callback_ref;
    int once;
    char *event_name;
} rl_lua_event_listener_t;

static lua_State *rl_lua_event_state = NULL;
static int rl_lua_event_next_id = 1;
static rl_lua_event_listener_t rl_lua_event_listeners[RL_LUA_EVENT_MAX_LISTENERS];

static char *rl_lua_strdup(const char *s)
{
    size_t n = 0;
    char *out = NULL;

    if (s == NULL) {
        return NULL;
    }

    n = strlen(s) + 1;
    out = (char *)malloc(n);
    if (out == NULL) {
        return NULL;
    }

    memcpy(out, s, n);
    return out;
}

static rl_lua_event_listener_t *rl_lua_event_find_by_id(int id)
{
    int i = 0;
    for (i = 0; i < RL_LUA_EVENT_MAX_LISTENERS; i++) {
        if (rl_lua_event_listeners[i].in_use && rl_lua_event_listeners[i].id == id) {
            return &rl_lua_event_listeners[i];
        }
    }
    return NULL;
}

static void rl_lua_event_release_listener(rl_lua_event_listener_t *listener)
{
    if (listener == NULL || !listener->in_use) {
        return;
    }

    if (rl_lua_event_state != NULL && listener->callback_ref != LUA_NOREF) {
        luaL_unref(rl_lua_event_state, LUA_REGISTRYINDEX, listener->callback_ref);
    }

    if (listener->event_name != NULL) {
        free(listener->event_name);
        listener->event_name = NULL;
    }

    listener->in_use = 0;
    listener->id = 0;
    listener->callback_ref = LUA_NOREF;
    listener->once = 0;
}

static rl_lua_event_listener_t *rl_lua_event_allocate_listener(const char *event_name, int callback_ref, int once)
{
    int i = 0;
    rl_lua_event_listener_t *listener = NULL;

    for (i = 0; i < RL_LUA_EVENT_MAX_LISTENERS; i++) {
        if (!rl_lua_event_listeners[i].in_use) {
            listener = &rl_lua_event_listeners[i];
            break;
        }
    }

    if (listener == NULL) {
        return NULL;
    }

    listener->event_name = rl_lua_strdup(event_name);
    if (listener->event_name == NULL) {
        return NULL;
    }

    listener->in_use = 1;
    listener->id = rl_lua_event_next_id++;
    listener->callback_ref = callback_ref;
    listener->once = once;
    return listener;
}

static int rl_lua_event_find_by_name_and_callback(lua_State *L, const char *event_name, int callback_index)
{
    int i = 0;
    for (i = 0; i < RL_LUA_EVENT_MAX_LISTENERS; i++) {
        rl_lua_event_listener_t *listener = &rl_lua_event_listeners[i];
        if (!listener->in_use || listener->event_name == NULL) {
            continue;
        }
        if (strcmp(listener->event_name, event_name) != 0) {
            continue;
        }

        lua_rawgeti(L, LUA_REGISTRYINDEX, listener->callback_ref);
        lua_pushvalue(L, callback_index);
        if (lua_rawequal(L, -1, -2)) {
            lua_pop(L, 2);
            return listener->id;
        }
        lua_pop(L, 2);
    }
    return 0;
}

static void rl_lua_event_callback_trampoline(void *payload, void *user_data)
{
    int id = (int)(uintptr_t)user_data;
    rl_lua_event_listener_t *listener = rl_lua_event_find_by_id(id);

    if (listener == NULL || rl_lua_event_state == NULL) {
        return;
    }

    lua_rawgeti(rl_lua_event_state, LUA_REGISTRYINDEX, listener->callback_ref);
    lua_pushinteger(rl_lua_event_state, (lua_Integer)(uintptr_t)payload);

    if (lua_pcall(rl_lua_event_state, 1, 0, 0) != 0) {
        lua_pop(rl_lua_event_state, 1);
    }

    if (listener->once) {
        rl_lua_event_release_listener(listener);
    }
}

static int rl_event_on_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    rl_lua_event_listener_t *listener = NULL;
    int callback_ref = LUA_NOREF;
    int rc = 0;

    luaL_checktype(L, 2, LUA_TFUNCTION);

    if (rl_lua_event_find_by_name_and_callback(L, event_name, 2) != 0) {
        lua_pushinteger(L, 0);
        return 1;
    }

    lua_pushvalue(L, 2);
    callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    listener = rl_lua_event_allocate_listener(event_name, callback_ref, 0);
    if (listener == NULL) {
        luaL_unref(L, LUA_REGISTRYINDEX, callback_ref);
        lua_pushinteger(L, -1);
        return 1;
    }

    rc = rl_event_on(event_name, rl_lua_event_callback_trampoline, (void *)(uintptr_t)listener->id);
    if (rc != 0) {
        rl_lua_event_release_listener(listener);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_event_once_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    rl_lua_event_listener_t *listener = NULL;
    int callback_ref = LUA_NOREF;
    int rc = 0;

    luaL_checktype(L, 2, LUA_TFUNCTION);

    if (rl_lua_event_find_by_name_and_callback(L, event_name, 2) != 0) {
        lua_pushinteger(L, 0);
        return 1;
    }

    lua_pushvalue(L, 2);
    callback_ref = luaL_ref(L, LUA_REGISTRYINDEX);

    listener = rl_lua_event_allocate_listener(event_name, callback_ref, 1);
    if (listener == NULL) {
        luaL_unref(L, LUA_REGISTRYINDEX, callback_ref);
        lua_pushinteger(L, -1);
        return 1;
    }

    rc = rl_event_once(event_name, rl_lua_event_callback_trampoline, (void *)(uintptr_t)listener->id);
    if (rc != 0) {
        rl_lua_event_release_listener(listener);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_event_off_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    int id = 0;
    int rc = 0;
    rl_lua_event_listener_t *listener = NULL;

    luaL_checktype(L, 2, LUA_TFUNCTION);

    id = rl_lua_event_find_by_name_and_callback(L, event_name, 2);
    if (id == 0) {
        lua_pushinteger(L, 0);
        return 1;
    }

    rc = rl_event_off(event_name, rl_lua_event_callback_trampoline, (void *)(uintptr_t)id);
    if (rc == 0) {
        listener = rl_lua_event_find_by_id(id);
        rl_lua_event_release_listener(listener);
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_event_off_all_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    int rc = rl_event_off_all(event_name);
    int i = 0;

    if (rc == 0) {
        for (i = 0; i < RL_LUA_EVENT_MAX_LISTENERS; i++) {
            rl_lua_event_listener_t *listener = &rl_lua_event_listeners[i];
            if (listener->in_use && listener->event_name != NULL && strcmp(listener->event_name, event_name) == 0) {
                rl_lua_event_release_listener(listener);
            }
        }
    }

    lua_pushinteger(L, rc);
    return 1;
}

static int rl_event_emit_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    uintptr_t payload = (uintptr_t)luaL_optinteger(L, 2, 0);
    lua_pushinteger(L, rl_event_emit(event_name, (void *)payload));
    return 1;
}

static int rl_event_listener_count_lua(lua_State *L)
{
    const char *event_name = luaL_checkstring(L, 1);
    lua_pushinteger(L, rl_event_listener_count(event_name));
    return 1;
}

void rl_register_event_bindings(lua_State *L)
{
    rl_lua_event_state = L;

    lua_pushcfunction(L, rl_event_on_lua);
    lua_setfield(L, -2, "event_on");

    lua_pushcfunction(L, rl_event_once_lua);
    lua_setfield(L, -2, "event_once");

    lua_pushcfunction(L, rl_event_off_lua);
    lua_setfield(L, -2, "event_off");

    lua_pushcfunction(L, rl_event_off_all_lua);
    lua_setfield(L, -2, "event_off_all");

    lua_pushcfunction(L, rl_event_emit_lua);
    lua_setfield(L, -2, "event_emit");

    lua_pushcfunction(L, rl_event_listener_count_lua);
    lua_setfield(L, -2, "event_listener_count");
}
