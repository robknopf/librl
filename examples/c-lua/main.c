#include "rl_loader.h"
#include "rl_logger.h"

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

#define LUA_SCRIPT_ROOT "assets/scripts/lua"
#define LUA_ENTRY_MODULE "main"
#define LUA_PACKAGE_PATH LUA_SCRIPT_ROOT "/?.lua;" LUA_SCRIPT_ROOT "/?/init.lua"

typedef enum rt_result_t {
  RT_SUCCESS = 0,
  RT_FAILED = -1,
  RT_STOPPED = 1,
} rt_result_t;

typedef struct runtime_refs_t {
  int boot_ref;
  int init_ref;
  int tick_ref;
  int shutdown_ref;
} runtime_refs_t;

typedef struct lua_runtime_t {
  lua_State *state;
  runtime_refs_t refs;
  char error[256];
} lua_runtime_t;

int luaopen_rl(lua_State *L);
int rt_boot(void);
int rt_init(void *user_data);
int rt_tick(float host_dt);
void rt_shutdown(void);

static lua_runtime_t g_runtime_host = {
    NULL,
    {LUA_NOREF, LUA_NOREF, LUA_NOREF, LUA_NOREF},
    {0},
};

static void init_runtime_refs(runtime_refs_t *refs) {
  if (refs == NULL) {
    return;
  }

  refs->boot_ref = LUA_NOREF;
  refs->init_ref = LUA_NOREF;
  refs->tick_ref = LUA_NOREF;
  refs->shutdown_ref = LUA_NOREF;
}

static const char *get_asset_host(void) {
  const char *value = getenv("RL_ASSET_HOST");
  if (value != NULL && value[0] != '\0') {
    return value;
  }
  return ASSET_HOST;
}

static void clear_runtime_error(lua_runtime_t *runtime) {
  if (runtime == NULL) {
    return;
  }

  runtime->error[0] = '\0';
}

static void set_runtime_error(lua_runtime_t *runtime, const char *format, ...) {
  va_list args;

  if (runtime == NULL || format == NULL) {
    return;
  }

  va_start(args, format);
  (void)vsnprintf(runtime->error, sizeof(runtime->error), format, args);
  va_end(args);
}

static void clear_runtime_refs(lua_State *state, runtime_refs_t *refs) {
  if (state == NULL || refs == NULL) {
    return;
  }

  if (refs->boot_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, refs->boot_ref);
    refs->boot_ref = LUA_NOREF;
  }
  if (refs->init_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, refs->init_ref);
    refs->init_ref = LUA_NOREF;
  }
  if (refs->tick_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, refs->tick_ref);
    refs->tick_ref = LUA_NOREF;
  }
  if (refs->shutdown_ref != LUA_NOREF) {
    luaL_unref(state, LUA_REGISTRYINDEX, refs->shutdown_ref);
    refs->shutdown_ref = LUA_NOREF;
  }
}

static void free_runtime(lua_runtime_t *runtime) {
  if (runtime == NULL) {
    return;
  }

  if (runtime->state != NULL) {
    clear_runtime_refs(runtime->state, &runtime->refs);
    lua_close(runtime->state);
  }
  runtime->state = NULL;
  init_runtime_refs(&runtime->refs);
  clear_runtime_error(runtime);
}

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

static int require_module(lua_State *state, const char *module_name,
                          char *error, size_t error_size) {
  if (state == NULL || module_name == NULL || error == NULL ||
      error_size == 0) {
    return -1;
  }

  lua_getglobal(state, "require");
  lua_pushstring(state, module_name);
  if (lua_pcall(state, 1, 1, 0) != 0) {
    const char *message = lua_tostring(state, -1);
    (void)snprintf(error, error_size, "Failed to load Lua runtime '%s': %.220s",
                   module_name, message != NULL ? message : "unknown error");
    lua_pop(state, 1);
    return -1;
  }

  return 0;
}

static lua_State* create_lua_vm(char *error, size_t error_size) {
  lua_State *state = NULL;

  if (error == NULL || error_size == 0) {
    return NULL;
  }

  error[0] = '\0';
  state = luaL_newstate();
  if (state == NULL) {
    (void)snprintf(error, error_size, "Failed to create Lua state");
    return NULL;
  }

  luaL_openlibs(state);

  lua_getglobal(state, "package");
  lua_getfield(state, -1, "preload");
  lua_pushcfunction(state, luaopen_rl);
  lua_setfield(state, -2, "rl");
  lua_pop(state, 2);

  prepend_package_path(state, LUA_PACKAGE_PATH);
  return state;
}

static int cache_runtime_function(lua_State *state, int table_index,
                                  const char *field_name, int *ref_out,
                                  char *error, size_t error_size) {
  int absolute_index = table_index;

  if (state == NULL || field_name == NULL || ref_out == NULL || error == NULL ||
      error_size == 0) {
    return -1;
  }

  if (absolute_index < 0) {
    absolute_index = lua_gettop(state) + absolute_index + 1;
  }

  lua_getfield(state, absolute_index, field_name);
  if (!lua_isfunction(state, -1)) {
    (void)snprintf(error, error_size,
                   "Runtime module field '%s' is not a function", field_name);
    lua_pop(state, 1);
    return -1;
  }

  *ref_out = luaL_ref(state, LUA_REGISTRYINDEX);
  return 0;
}

static int load_runtime_module(lua_runtime_t *runtime, char *error,
                               size_t error_size) {
  int status = RT_FAILED;
  const char *asset_host = NULL;
  lua_State *state = NULL;

  if (runtime == NULL || runtime->state == NULL || error == NULL ||
      error_size == 0) {
    return RT_FAILED;
  }
  state = runtime->state;
  if (rl_loader_init("cache") != 0) {
    (void)snprintf(error, error_size, "rl_loader_init failed");
    return RT_FAILED;
  }

  asset_host = get_asset_host();
  if (asset_host != NULL && asset_host[0] != '\0') {
    if (rl_loader_set_asset_host(asset_host) != 0) {
      (void)snprintf(error, error_size, "rl_loader_set_asset_host failed");
      goto cleanup;
    }
  }

  // debugging, clear the cache first
  rl_loader_clear_cache();

  if (require_module(state, "rl", error, error_size) != 0) {
    goto cleanup;
  }
  lua_pop(state, 1);

  if (require_module(state, LUA_ENTRY_MODULE, error, error_size) != 0) {
    goto cleanup;
  }

  if (!lua_istable(state, -1)) {
    (void)snprintf(error, error_size, "Lua runtime '%s' did not return a table",
                   LUA_ENTRY_MODULE);
    lua_pop(state, 1);
    goto cleanup;
  }

  if (cache_runtime_function(state, -1, "rt_boot", &runtime->refs.boot_ref, error,
                             error_size) != 0 ||
      cache_runtime_function(state, -1, "rt_init", &runtime->refs.init_ref, error,
                             error_size) != 0 ||
      cache_runtime_function(state, -1, "rt_tick", &runtime->refs.tick_ref, error,
                             error_size) != 0 ||
      cache_runtime_function(state, -1, "rt_shutdown", &runtime->refs.shutdown_ref,
                             error, error_size) != 0) {
    clear_runtime_refs(state, &runtime->refs);
    lua_pop(state, 1);
    goto cleanup;
  }

  lua_pop(state, 1);
  status = RT_SUCCESS;

cleanup:
  rl_loader_deinit();
  return status;
}

static int parse_runtime_result(lua_runtime_t *runtime, const char *callback_name,
                                int arg_count) {
  int rc = RT_SUCCESS;
  const char *message = NULL;
  lua_State *state = NULL;

  if (runtime == NULL || runtime->state == NULL) {
    return RT_FAILED;
  }
  state = runtime->state;

  if (lua_pcall(state, arg_count, 1, 0) != 0) {
    message = lua_tostring(state, -1);
    set_runtime_error(runtime, "%s failed: %.220s",
                      callback_name != NULL ? callback_name : "runtime callback",
                      message != NULL ? message : "unknown Lua error");
    lua_pop(state, 1);
    return RT_FAILED;
  }

  if (!lua_isnumber(state, -1)) {
    set_runtime_error(runtime, "%s must return an integer result code",
                      callback_name != NULL ? callback_name : "runtime callback");
    lua_pop(state, 1);
    return RT_FAILED;
  }

  rc = (int)lua_tointeger(state, -1);
  lua_pop(state, 1);
  return rc;
}

static void call_runtime_shutdown(lua_runtime_t *runtime) {
  const char *message = NULL;
  lua_State *state = NULL;

  if (runtime == NULL || runtime->state == NULL ||
      runtime->refs.shutdown_ref == LUA_NOREF) {
    return;
  }
  state = runtime->state;

  lua_rawgeti(state, LUA_REGISTRYINDEX, runtime->refs.shutdown_ref);
  if (lua_pcall(state, 0, 0, 0) != 0) {
    message = lua_tostring(state, -1);
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s",
                             message != NULL ? message : "rt_shutdown failed");
    lua_pop(state, 1);
  }
}

int rt_boot(void) {
  char error[256];
  int rc = RT_SUCCESS;
  lua_runtime_t *runtime = &g_runtime_host;
  lua_State *state = NULL;

  free_runtime(runtime);
  rl_logger_set_level(RL_LOGGER_LEVEL_DEBUG);

  state = create_lua_vm(error, sizeof(error));
  if (state == NULL)  {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s", error);
    free_runtime(runtime);
    return RT_FAILED;
  }
  runtime->state = state;

  if (load_runtime_module(runtime, error, sizeof(error)) != 0) {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s", error);
    free_runtime(runtime);
    return RT_FAILED;
  }

  lua_rawgeti(state, LUA_REGISTRYINDEX, runtime->refs.boot_ref);
  rc = parse_runtime_result(runtime, "rt_boot", 0);
  if (rc < RT_SUCCESS) {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s",
                             runtime->error);
    free_runtime(runtime);
    return rc;
  }

  return rc;
}

int rt_init(void *user_data) {
  int rc = RT_SUCCESS;
  lua_runtime_t *runtime = &g_runtime_host;
  lua_State *state = runtime->state;

  if (state == NULL) {
    return RT_FAILED;
  }

  lua_rawgeti(state, LUA_REGISTRYINDEX, runtime->refs.init_ref);
  if (user_data != NULL) {
    lua_pushlightuserdata(state, user_data);
  } else {
    lua_pushnil(state);
  }
  rc = parse_runtime_result(runtime, "rt_init", 1);
  if (rc < RT_SUCCESS) {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "lua", 0, "%s",
                             runtime->error);
  }
  return rc;
}

int rt_tick(float host_dt) {
  lua_runtime_t *runtime = &g_runtime_host;
  lua_State *state = runtime->state;

  if (state == NULL) {
    return RT_FAILED;
  }

  lua_rawgeti(state, LUA_REGISTRYINDEX, runtime->refs.tick_ref);
  lua_pushnumber(state, (lua_Number)host_dt);
  return parse_runtime_result(runtime, "rt_tick", 1);
}

void rt_shutdown(void) {
  lua_runtime_t *runtime = &g_runtime_host;

  call_runtime_shutdown(runtime);
  free_runtime(runtime);
}

///////////////////
// For desktop, we ARE the host
#ifdef PLATFORM_WEB
int main(void) {
  // any main inits here for wasm
  return 0;
}
#else
#include <time.h>
#include <unistd.h>

static double now_seconds(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (double)ts.tv_sec + ((double)ts.tv_nsec / 1000000000.0);
}

int main(void) {
  int rc = RT_SUCCESS;

  if (rt_boot() != 0) {
    return RT_FAILED;
  }

  if (rt_init(NULL) != 0) {
    rt_shutdown();
    return RT_FAILED;
  }

  double last_time = now_seconds();
  double current_time = last_time;
  float dt_seconds = 0;

  for (;;) {
    current_time = now_seconds();
    dt_seconds = (float)(current_time - last_time);
    last_time = current_time;

    rc = rt_tick(dt_seconds);
    if (rc > RT_SUCCESS) {
      fprintf(stderr, "[host] rt_tick requested stop (>0), exiting loop\n");
      // stop set, exit
      fprintf(stderr, "[host] calling rt_shutdown...\n");
      rt_shutdown();
      return rc;
    }
    if (rc < RT_SUCCESS) {
      fprintf(stderr, "[host] rt_tick failed: %d\n", rc);
      fprintf(stderr, "[host] calling rt_shutdown...\n");
      rt_shutdown();
      return rc;
    }

    // rt_tick succeeded, give the os a little time, then keep ticking
    usleep(1000);
  }
}

#endif
