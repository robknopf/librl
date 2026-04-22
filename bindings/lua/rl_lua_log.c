/* rl_log.c - Lua ergonomic logging bindings for librl */

#include <lua.h>
#include <lauxlib.h>

#include "rl.h"
#include "rl_lua_log.h"

static int rl_log_set_level_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    rl_logger_set_level((rl_log_level_t)level);
    return 0;
}

static int rl_log_message_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    const char *message = luaL_checkstring(L, 2);
    rl_logger_message((rl_log_level_t)level, "%s", message);
    return 0;
}

static int rl_log_message_source_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    const char *source_file = luaL_checkstring(L, 2);
    int source_line = (int)luaL_checkinteger(L, 3);
    const char *message = luaL_checkstring(L, 4);
    rl_logger_message_source((rl_log_level_t)level, source_file, source_line, "%s", message);
    return 0;
}

static int rl_log_trace_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_TRACE, "%s", message);
    return 0;
}

static int rl_log_debug_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_DEBUG, "%s", message);
    return 0;
}

static int rl_log_info_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_INFO, "%s", message);
    return 0;
}

static int rl_log_warn_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_WARN, "%s", message);
    return 0;
}

static int rl_log_error_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_ERROR, "%s", message);
    return 0;
}

static int rl_log_fatal_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_FATAL, "%s", message);
    return 0;
}

void rl_register_log_bindings(lua_State *L)
{
    lua_newtable(L); /* log */

    lua_pushcfunction(L, rl_log_set_level_lua);
    lua_setfield(L, -2, "set_level");

    lua_pushcfunction(L, rl_log_message_lua);
    lua_setfield(L, -2, "message");

    lua_pushcfunction(L, rl_log_message_source_lua);
    lua_setfield(L, -2, "message_source");

    lua_pushcfunction(L, rl_log_trace_lua);
    lua_setfield(L, -2, "trace");

    lua_pushcfunction(L, rl_log_debug_lua);
    lua_setfield(L, -2, "debug");

    lua_pushcfunction(L, rl_log_info_lua);
    lua_setfield(L, -2, "info");

    lua_pushcfunction(L, rl_log_warn_lua);
    lua_setfield(L, -2, "warn");

    lua_pushcfunction(L, rl_log_error_lua);
    lua_setfield(L, -2, "error");

    lua_pushcfunction(L, rl_log_fatal_lua);
    lua_setfield(L, -2, "fatal");

    lua_pushcfunction(L, rl_log_info_lua);
    lua_setfield(L, -2, "log");

    lua_pushinteger(L, RL_LOGGER_LEVEL_TRACE);
    lua_setfield(L, -2, "LEVEL_TRACE");

    lua_pushinteger(L, RL_LOGGER_LEVEL_DEBUG);
    lua_setfield(L, -2, "LEVEL_DEBUG");

    lua_pushinteger(L, RL_LOGGER_LEVEL_INFO);
    lua_setfield(L, -2, "LEVEL_INFO");

    lua_pushinteger(L, RL_LOGGER_LEVEL_WARN);
    lua_setfield(L, -2, "LEVEL_WARN");

    lua_pushinteger(L, RL_LOGGER_LEVEL_ERROR);
    lua_setfield(L, -2, "LEVEL_ERROR");

    lua_pushinteger(L, RL_LOGGER_LEVEL_FATAL);
    lua_setfield(L, -2, "LEVEL_FATAL");

    lua_setfield(L, -2, "log");
}
