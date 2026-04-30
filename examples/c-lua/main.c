#include "rl.h"

#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef PLATFORM_WEB
static const char *ASSET_HOST = "./";
#else
static const char *ASSET_HOST = "https://localhost:4444";
#endif

#define EXAMPLE_WINDOW_WIDTH 1024
#define EXAMPLE_WINDOW_HEIGHT 1280
#define EXAMPLE_WINDOW_TITLE "librl + raylib + lua(C example)"
#define LUA_SCRIPT_ROOT "assets/scripts/lua"
#define LUA_ENTRY_MODULE "simple"
#define LUA_PACKAGE_PATH LUA_SCRIPT_ROOT "/?.lua;" LUA_SCRIPT_ROOT "/?/init.lua"

typedef struct host_callback_state_t {
  int init_ref;
  int tick_ref;
  int shutdown_ref;
  int user_ref;
} host_callback_state_t;

typedef struct host_context_t {
  lua_State *lua_state;
  host_callback_state_t callbacks;
  int callbacks_installed;
  int lua_callback_depth;
  int shutdown_finalize_pending;
  int shutdown_finalized;
  int boot_failed;
  char boot_error[256];
} host_context_t;

static const char *g_asset_host = NULL;
static host_context_t g_host_context = {0};

int luaopen_rl(lua_State *L);

/* Registry refs for the Lua callbacks that the outer C host forwards to. */
static void callback_state_init(host_callback_state_t *state) {
  if (state == NULL) {
    return;
  }

  state->init_ref = LUA_NOREF;
  state->tick_ref = LUA_NOREF;
  state->shutdown_ref = LUA_NOREF;
  state->user_ref = LUA_NOREF;
}

/* Resolve the asset host for desktop runs; web uses relative assets. */
static const char *get_asset_host(void) {
  const char *value = getenv("RL_ASSET_HOST");
  if (value != NULL && value[0] != '\0') {
    return value;
  }
  return ASSET_HOST;
}

/* Record a host-visible boot error that can be rendered during early failure. */
static void set_boot_error(host_context_t *context, const char *format, ...) {
  va_list args;

  if (context == NULL || format == NULL) {
    return;
  }

  va_start(args, format);
  (void)vsnprintf(context->boot_error, sizeof(context->boot_error), format, args);
  va_end(args);
  context->boot_failed = 1;
}

/* Draw a simple status screen while booting or when boot fails. */
static void draw_boot_status(const char *title, const char *detail) {
  rl_render_begin();
  rl_render_clear_background(RL_COLOR_RAYWHITE);
  rl_text_draw(title != NULL ? title : "Booting...", 32, 32, 32,
               RL_COLOR_DARKGRAY);
  rl_text_draw(detail != NULL ? detail : "", 32, 80, 20, RL_COLOR_GRAY);
  rl_render_end();
}

/* Release any stored Lua callback refs from the registry. */
static void clear_callback_refs(lua_State *state, host_callback_state_t *callbacks) {
  if (state == NULL || callbacks == NULL) {
    return;
  }

  if (callbacks->init_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, callbacks->init_ref);
    callbacks->init_ref = LUA_NOREF;
  }
  if (callbacks->tick_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, callbacks->tick_ref);
    callbacks->tick_ref = LUA_NOREF;
  }
  if (callbacks->shutdown_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, callbacks->shutdown_ref);
    callbacks->shutdown_ref = LUA_NOREF;
  }
  if (callbacks->user_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, callbacks->user_ref);
    callbacks->user_ref = LUA_NOREF;
  }
}

/* Tear down the embedded Lua VM and librl runtime once the hosted app stops. */
static void finalize_runtime_shutdown(host_context_t *context) {
  if (context == NULL || context->shutdown_finalized) {
    return;
  }

  context->shutdown_finalized = 1;
  context->shutdown_finalize_pending = 0;
  if (context->lua_state != NULL) {
    clear_callback_refs(context->lua_state, &context->callbacks);
    lua_close(context->lua_state);
    context->lua_state = NULL;
  }
  rl_deinit();
}

/* Prepend the example asset script directory to package.path. */
static void prepend_package_path(lua_State *state, const char *prefix) {
  const char *current_path = NULL;
  char buffer[2048];

  if (state == NULL || prefix == NULL) {
    return;
  }

  lua_getglobal(state, "package");
  lua_getfield(state, -1, "path");
  current_path = lua_tostring(state, -1);
  (void)snprintf(buffer, sizeof(buffer), "%s;%s", prefix,
                 current_path != NULL ? current_path : "");
  lua_pop(state, 1);
  lua_pushstring(state, buffer);
  lua_setfield(state, -2, "path");
  lua_pop(state, 1);
}

/* Require a Lua module and leave no return value on the stack. */
static int require_module(lua_State *state, const char *module_name) {
  if (state == NULL || module_name == NULL) {
    return -1;
  }

  lua_getglobal(state, "require");
  lua_pushstring(state, module_name);
  if (lua_pcall(state, 1, 1, 0) != 0) {
    return -1;
  }

  lua_pop(state, 1);
  return 0;
}

/* Hosted-only Lua API: register callbacks that the C springboard will invoke. */
static int example_rl_set_callbacks(lua_State *L) {
  host_context_t *context = NULL;
  host_callback_state_t *callbacks = NULL;

  /* `rl.set_callbacks(...)` is a C closure with the host context stored as an
   * upvalue, not a normal Lua argument. */
  context = (host_context_t *)lua_touserdata(L, lua_upvalueindex(1));
  if (context == NULL) {
    return luaL_error(L, "invalid hosted Lua context");
  }

  luaL_checktype(L, 1, LUA_TFUNCTION);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  if (!lua_isnoneornil(L, 3)) {
    luaL_checktype(L, 3, LUA_TFUNCTION);
  }

  callbacks = &context->callbacks;
  clear_callback_refs(L, callbacks);

  lua_pushvalue(L, 1);
  callbacks->init_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  lua_pushvalue(L, 2);
  callbacks->tick_ref = luaL_ref(L, LUA_REGISTRYINDEX);

  if (!lua_isnoneornil(L, 3)) {
    lua_pushvalue(L, 3);
    callbacks->shutdown_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  } else {
    callbacks->shutdown_ref = LUA_NOREF;
  }

  if (!lua_isnoneornil(L, 4)) {
    lua_pushvalue(L, 4);
    callbacks->user_ref = luaL_ref(L, LUA_REGISTRYINDEX);
  } else {
    callbacks->user_ref = LUA_NOREF;
  }

  context->callbacks_installed = 1;
  return 0;
}

/* Load `rl` and inject the hosted-only helper used by embedded mode. */
static int install_rl_helpers(host_context_t *context, char *error,
                              size_t error_size) {
  lua_State *state = NULL;

  if (context == NULL || context->lua_state == NULL ||
      error == NULL || error_size == 0) {
    return -1;
  }

  state = context->lua_state;
  if (require_module(state, "rl") != 0) {
    const char *message = lua_tostring(state, -1);
    (void)snprintf(error, error_size, "Failed to require rl: %.220s",
                   message != NULL ? message : "unknown error");
    lua_pop(state, 1);
    return -1;
  }

  lua_getglobal(state, "package");
  lua_getfield(state, -1, "loaded");
  lua_getfield(state, -1, "rl");
  if (!lua_istable(state, -1)) {
    lua_pop(state, 3);
    (void)snprintf(error, error_size, "Loaded rl module is not a table");
    return -1;
  }

  /* Inject a hosted-only helper into the `rl` table. The C function keeps a
   * pointer to the host context as a closure upvalue so Lua can register the
   * callbacks that the outer C lifecycle will springboard into later. */
  lua_pushlightuserdata(state, context);
  lua_pushcclosure(state, example_rl_set_callbacks, 1);
  lua_setfield(state, -2, "set_callbacks");

  lua_pop(state, 3);
  return 0;
}

/* Create the Lua VM used by the host and prepare it for hosted script loading. */
static int create_lua_vm(host_context_t *context, char *error,
                         size_t error_size) {
  lua_State *state = NULL;

  if (context == NULL || error == NULL || error_size == 0) {
    return -1;
  }

  error[0] = '\0';
  state = luaL_newstate();
  if (state == NULL) {
    (void)snprintf(error, error_size, "Failed to create Lua state");
    return -1;
  }

  callback_state_init(&context->callbacks);
  context->callbacks_installed = 0;
  context->lua_state = state;
  luaL_openlibs(state);

  lua_getglobal(state, "package");
  lua_getfield(state, -1, "preload");
  lua_pushcfunction(state, luaopen_rl);
  lua_setfield(state, -2, "rl");
  lua_pop(state, 2);

  lua_pushboolean(state, 1);
  lua_setglobal(state, "__LIBRL_HOSTED");

  prepend_package_path(state, LUA_PACKAGE_PATH);

  if (install_rl_helpers(context, error, error_size) != 0) {
    return -1;
  }

  return 0;
}

/* Invoke one registered Lua callback, deferring final shutdown until unwind. */
static int call_lua_callback(host_context_t *context, int callback_ref,
                             const char *callback_name) {
  int arg_count = 0;
  const char *message = NULL;

  if (context == NULL || context->lua_state == NULL ||
      callback_ref == LUA_NOREF) {
    return 0;
  }

  lua_rawgeti(context->lua_state, LUA_REGISTRYINDEX, callback_ref);
  if (context->callbacks.user_ref != LUA_NOREF) {
    lua_rawgeti(context->lua_state, LUA_REGISTRYINDEX,
                context->callbacks.user_ref);
    arg_count = 1;
  }

  context->lua_callback_depth++;
  if (lua_pcall(context->lua_state, arg_count, 0, 0) != 0) {
    context->lua_callback_depth--;
    message = lua_tostring(context->lua_state, -1);
    set_boot_error(context, "%s failed: %.220s",
                   callback_name != NULL ? callback_name : "callback",
                   message != NULL ? message : "unknown Lua error");
    lua_pop(context->lua_state, 1);
    if (context->lua_callback_depth == 0 &&
        context->shutdown_finalize_pending) {
      finalize_runtime_shutdown(context);
    }
    return -1;
  }

  context->lua_callback_depth--;
  if (context->lua_callback_depth == 0 &&
      context->shutdown_finalize_pending) {
    finalize_runtime_shutdown(context);
  }

  return 0;
}

/* Outer init callback: require the Lua entry module after loader readiness. */
static void host_init(void *user_data) {
  host_context_t *context = (host_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  if (context->boot_failed) {
    return;
  }

  if (require_module(context->lua_state, LUA_ENTRY_MODULE) != 0) {
    const char *message = lua_tostring(context->lua_state, -1);
    set_boot_error(context, "Failed to load Lua app '%s': %.220s",
                   LUA_ENTRY_MODULE, message != NULL ? message : "unknown error");
    lua_pop(context->lua_state, 1);
    return;
  }

  if (!context->callbacks_installed) {
    set_boot_error(context, "Hosted Lua app '%s' did not call rl.set_callbacks(...)",
                   LUA_ENTRY_MODULE);
    return;
  }

  (void)call_lua_callback(context, context->callbacks.init_ref, "init");
}

/* Outer tick callback: render boot errors or forward ticks into Lua. */
static void host_tick(void *user_data) {
  host_context_t *context = (host_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  if (context->boot_failed) {
    draw_boot_status("Boot failed", context->boot_error);
    return;
  }

  (void)call_lua_callback(context, context->callbacks.tick_ref, "tick");
}

/* Outer shutdown callback: forward to Lua and finalize once callbacks unwind. */
static void host_shutdown(void *user_data) {
  host_context_t *context = (host_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  context->shutdown_finalize_pending = 1;
  if (context->callbacks.shutdown_ref != LUA_NOREF) {
    char error_before[sizeof(context->boot_error)];

    (void)snprintf(error_before, sizeof(error_before), "%s", context->boot_error);
    if (call_lua_callback(context, context->callbacks.shutdown_ref, "shutdown") !=
        0) {
      rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s",
                               context->boot_error);
      (void)snprintf(context->boot_error, sizeof(context->boot_error), "%s",
                     error_before);
    }
  }

  if (context->lua_callback_depth == 0 &&
      context->shutdown_finalize_pending) {
    finalize_runtime_shutdown(context);
  }
}

int main(void) {
  char error[256];
  rl_init_config_t init_cfg;

  memset(&g_host_context, 0, sizeof(g_host_context));
  callback_state_init(&g_host_context.callbacks);

  g_asset_host = get_asset_host();
  rl_logger_set_level(RL_LOGGER_LEVEL_DEBUG);

  memset(&init_cfg, 0, sizeof(init_cfg));
  init_cfg.window_width = EXAMPLE_WINDOW_WIDTH;
  init_cfg.window_height = EXAMPLE_WINDOW_HEIGHT;
  init_cfg.window_title = EXAMPLE_WINDOW_TITLE;
  init_cfg.window_flags = RL_WINDOW_FLAG_MSAA_4X_HINT;
  init_cfg.asset_host = g_asset_host;
  if (rl_init(&init_cfg) != 0) {
    return 1;
  }

  if (create_lua_vm(&g_host_context, error, sizeof(error)) != 0) {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s", error);
    finalize_runtime_shutdown(&g_host_context);
    return 1;
  }

  rl_loader_clear_cache();

#ifdef PLATFORM_WEB
  /* On web, JS owns the frame pump and drives exported `rl_tick()` through
   * JSPI. We only arm the outer host lifecycle here. */
  if (rl_start(host_init, host_tick, host_shutdown, &g_host_context) != 0) {
    finalize_runtime_shutdown(&g_host_context);
    return 1;
  }
#else
  /* On desktop, librl owns the frame loop directly through `rl_run()`. */
  rl_run(host_init, host_tick, host_shutdown, &g_host_context);
  if (!g_host_context.shutdown_finalized) {
    finalize_runtime_shutdown(&g_host_context);
  }
#endif

  return 0;
}
