/* rl_lua_logger.c - Lua bindings for rl_logger */

#include <lua.h>
#include <lauxlib.h>

//#include "rl.h"
#include "rl_logger.h"
#include "rl_lua_logger.h"

static int rl_logger_set_level_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    rl_logger_set_level((rl_log_level_t)level);
    return 0;
}

static int rl_logger_message_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    const char *message = luaL_checkstring(L, 2);
    rl_logger_message((rl_log_level_t)level, "%s", message);
    return 0;
}

static int rl_logger_message_source_lua(lua_State *L)
{
    int level = (int)luaL_checkinteger(L, 1);
    const char *source_file = luaL_checkstring(L, 2);
    int source_line = (int)luaL_checkinteger(L, 3);
    const char *message = luaL_checkstring(L, 4);
    rl_logger_message_source((rl_log_level_t)level, source_file, source_line, "%s", message);
    return 0;
}

static int rl_logger_trace_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_TRACE, "%s", message);
    return 0;
}

static int rl_logger_debug_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_DEBUG, "%s", message);
    return 0;
}

static int rl_logger_info_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_INFO, "%s", message);
    return 0;
}

static int rl_logger_warn_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_WARN, "%s", message);
    return 0;
}

static int rl_logger_error_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_ERROR, "%s", message);
    return 0;
}

static int rl_logger_fatal_lua(lua_State *L)
{
    const char *message = luaL_checkstring(L, 1);
    rl_logger_message((rl_log_level_t)RL_LOGGER_LEVEL_FATAL, "%s", message);
    return 0;
}

void rl_register_logger_bindings(lua_State *L)
{
    lua_pushcfunction(L, rl_logger_set_level_lua);
    lua_setfield(L, -2, "logger_set_level");

    lua_pushcfunction(L, rl_logger_message_lua);
    lua_setfield(L, -2, "logger_message");

    lua_pushcfunction(L, rl_logger_message_source_lua);
    lua_setfield(L, -2, "logger_message_source");

    lua_pushcfunction(L, rl_logger_trace_lua);
    lua_setfield(L, -2, "logger_trace");

    lua_pushcfunction(L, rl_logger_debug_lua);
    lua_setfield(L, -2, "logger_debug");

    lua_pushcfunction(L, rl_logger_info_lua);
    lua_setfield(L, -2, "logger_info");

    lua_pushcfunction(L, rl_logger_warn_lua);
    lua_setfield(L, -2, "logger_warn");

    lua_pushcfunction(L, rl_logger_error_lua);
    lua_setfield(L, -2, "logger_error");

    lua_pushcfunction(L, rl_logger_fatal_lua);
    lua_setfield(L, -2, "logger_fatal");

    lua_pushinteger(L, RL_LOGGER_LEVEL_TRACE);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_TRACE");

    lua_pushinteger(L, RL_LOGGER_LEVEL_DEBUG);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_DEBUG");

    lua_pushinteger(L, RL_LOGGER_LEVEL_INFO);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_INFO");

    lua_pushinteger(L, RL_LOGGER_LEVEL_WARN);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_WARN");

    lua_pushinteger(L, RL_LOGGER_LEVEL_ERROR);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_ERROR");

    lua_pushinteger(L, RL_LOGGER_LEVEL_FATAL);
    lua_setfield(L, -2, "RL_LOGGER_LEVEL_FATAL");

    // alias for log_info, allows for `rl.log("Hello, world!")`
    lua_pushcfunction(L, rl_logger_info_lua);
    lua_setfield(L, -2, "log");

    // alias for log_error, allows for `rl.error("Hello, world!")`
    lua_pushcfunction(L, rl_logger_error_lua);
    lua_setfield(L, -2, "error");

    // alias for log_warn, allows for `rl.warn("Hello, world!")`
    lua_pushcfunction(L, rl_logger_warn_lua);
    lua_setfield(L, -2, "warn");

    // alias for log_fatal, allows for `rl.fatal("Hello, world!")`
    lua_pushcfunction(L, rl_logger_fatal_lua);
    lua_setfield(L, -2, "fatal");

    // alias for log_trace, allows for `rl.trace("Hello, world!")`
    lua_pushcfunction(L, rl_logger_trace_lua);
    lua_setfield(L, -2, "trace");

    // alias for log_debug, allows for `rl.debug("Hello, world!")`
    lua_pushcfunction(L, rl_logger_debug_lua);
    lua_setfield(L, -2, "debug");

    // alias for log_info, allows for `rl.info("Hello, world!")`
    lua_pushcfunction(L, rl_logger_info_lua);
    lua_setfield(L, -2, "info");
    
}
