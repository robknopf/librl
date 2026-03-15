#include "rl.h"
#include "rl_window.h"

#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LUA_SCRIPT_ROOT "assets/scripts/lua"
#define LUA_BOOT_SCRIPT "boot.lua"
#define LUA_APP_MODULE "lua_demo"

typedef enum example_boot_state_t {
  EXAMPLE_BOOT_RESTORE = 0,
  EXAMPLE_BOOT_PREPARE = 1,
  EXAMPLE_BOOT_INIT_MODULE = 2,
  EXAMPLE_BOOT_RUNNING = 3,
  EXAMPLE_BOOT_ERROR = 4
} example_boot_state_t;

typedef enum example_resource_kind_t {
  EXAMPLE_RESOURCE_KIND_NONE = 0,
  EXAMPLE_RESOURCE_KIND_SCRIPT,
  EXAMPLE_RESOURCE_KIND_TEXTURE,
  EXAMPLE_RESOURCE_KIND_MODEL,
  EXAMPLE_RESOURCE_KIND_SPRITE3D,
  EXAMPLE_RESOURCE_KIND_FONT,
  EXAMPLE_RESOURCE_KIND_SOUND,
  EXAMPLE_RESOURCE_KIND_MUSIC
} example_resource_kind_t;

#define EXAMPLE_MAX_PENDING_RESOURCE_REQUESTS 64

static const char *const EXAMPLE_ASSET_MANIFEST[] = {
    LUA_SCRIPT_ROOT "/boot.lua",
    LUA_SCRIPT_ROOT "/lua_demo.lua",
    LUA_SCRIPT_ROOT "/input_mapping.lua",
    LUA_SCRIPT_ROOT "/model.lua",
    LUA_SCRIPT_ROOT "/music.lua",
    LUA_SCRIPT_ROOT "/resource_async.lua",
    LUA_SCRIPT_ROOT "/script_async.lua",
    LUA_SCRIPT_ROOT "/texture.lua",
    LUA_SCRIPT_ROOT "/sprite3d.lua",
    LUA_SCRIPT_ROOT "/sound.lua",
    LUA_SCRIPT_ROOT "/camera3d.lua",
    LUA_SCRIPT_ROOT "/font.lua",
    LUA_SCRIPT_ROOT "/color.lua",
    LUA_SCRIPT_ROOT "/shadow.lua",
};

typedef struct example_resource_request_t {
  bool in_use;
  int rid;
  example_resource_kind_t kind;
  rl_loader_task_t *loader_task;
  char path[256];
  float size;
} example_resource_request_t;

typedef struct example_context_t {
  rl_module_config_t script_config;
  rl_module_instance_t script_module;
  rl_module_host_api_t module_host;
  rl_loader_task_t *loader_task;
  example_resource_request_t resource_requests[EXAMPLE_MAX_PENDING_RESOURCE_REQUESTS];
  example_boot_state_t boot_state;
  char module_error[256];
  char boot_error[256];
} example_context_t;

// Keep the command buffer out of the wasm stack; the example only needs one
// app-wide instance.
static rl_frame_command_buffer_t g_frame_command_buffer = {0};
static example_context_t g_example_context = {0};
static const char *g_asset_host = NULL;

static void emit_resource_error(int rid, const char *message) {
  char payload[512];

  (void)snprintf(payload, sizeof(payload), "%d|%s", rid,
                 message != NULL ? message : "resource load failed");
  (void)rl_event_emit("resource.error", payload);
}

static void emit_script_error(int rid, const char *message) {
  char payload[512];

  (void)snprintf(payload, sizeof(payload), "%d|%s", rid,
                 message != NULL ? message : "script import failed");
  (void)rl_event_emit("script.error", payload);
}

static example_resource_kind_t parse_resource_kind(const char *kind) {
  if (kind == NULL) {
    return EXAMPLE_RESOURCE_KIND_NONE;
  }
  if (strcmp(kind, "texture") == 0) return EXAMPLE_RESOURCE_KIND_TEXTURE;
  if (strcmp(kind, "model") == 0) return EXAMPLE_RESOURCE_KIND_MODEL;
  if (strcmp(kind, "sprite3d") == 0) return EXAMPLE_RESOURCE_KIND_SPRITE3D;
  if (strcmp(kind, "font") == 0) return EXAMPLE_RESOURCE_KIND_FONT;
  if (strcmp(kind, "sound") == 0) return EXAMPLE_RESOURCE_KIND_SOUND;
  if (strcmp(kind, "music") == 0) return EXAMPLE_RESOURCE_KIND_MUSIC;
  return EXAMPLE_RESOURCE_KIND_NONE;
}

static int parse_script_request_payload(const char *payload, int *out_rid,
                                        char *path, size_t path_size) {
  char buffer[512];
  char *cursor = NULL;
  char *rid_text = NULL;
  char *path_text = NULL;

  if (payload == NULL || out_rid == NULL || path == NULL || path_size == 0) {
    return -1;
  }

  (void)snprintf(buffer, sizeof(buffer), "%s", payload);
  rid_text = buffer;
  cursor = strchr(rid_text, '|');
  if (cursor == NULL) return -1;
  *cursor++ = '\0';
  path_text = cursor;
  if (path_text == NULL || path_text[0] == '\0') {
    return -1;
  }

  *out_rid = atoi(rid_text);
  (void)snprintf(path, path_size, "%s", path_text);
  return 0;
}

static rl_handle_t create_resource_handle(const example_resource_request_t *request) {
  if (request == NULL) {
    return 0;
  }

  switch (request->kind) {
  case EXAMPLE_RESOURCE_KIND_TEXTURE:
    return rl_texture_create(request->path);
  case EXAMPLE_RESOURCE_KIND_MODEL:
    return rl_model_create(request->path);
  case EXAMPLE_RESOURCE_KIND_SPRITE3D:
    return rl_sprite3d_create(request->path);
  case EXAMPLE_RESOURCE_KIND_FONT:
    return rl_font_create(request->path, request->size);
  case EXAMPLE_RESOURCE_KIND_SOUND:
    return rl_sound_create(request->path);
  case EXAMPLE_RESOURCE_KIND_MUSIC:
    return rl_music_create(request->path);
  case EXAMPLE_RESOURCE_KIND_NONE:
  default:
    return 0;
  }
}

static int parse_resource_request_payload(const char *payload, int *out_rid,
                                          char *kind, size_t kind_size,
                                          char *path, size_t path_size,
                                          float *out_size) {
  char buffer[512];
  char *cursor = NULL;
  char *rid_text = NULL;
  char *kind_text = NULL;
  char *path_text = NULL;
  char *size_text = NULL;

  if (payload == NULL || out_rid == NULL || kind == NULL || path == NULL) {
    return -1;
  }

  (void)snprintf(buffer, sizeof(buffer), "%s", payload);
  rid_text = buffer;
  cursor = strchr(rid_text, '|');
  if (cursor == NULL) return -1;
  *cursor++ = '\0';
  kind_text = cursor;
  cursor = strchr(kind_text, '|');
  if (cursor == NULL) return -1;
  *cursor++ = '\0';
  path_text = cursor;
  cursor = strchr(path_text, '|');
  if (cursor != NULL) {
    *cursor++ = '\0';
    size_text = cursor;
  }

  *out_rid = atoi(rid_text);
  (void)snprintf(kind, kind_size, "%s", kind_text);
  (void)snprintf(path, path_size, "%s", path_text);
  if (out_size != NULL) {
    *out_size = size_text != NULL && size_text[0] != '\0'
                    ? (float)strtod(size_text, NULL)
                    : 0.0f;
  }
  return 0;
}

static example_resource_request_t *alloc_resource_request(
    example_context_t *context) {
  int i = 0;

  if (context == NULL) return NULL;

  for (i = 0; i < EXAMPLE_MAX_PENDING_RESOURCE_REQUESTS; i++) {
    if (!context->resource_requests[i].in_use) {
      memset(&context->resource_requests[i], 0,
             sizeof(context->resource_requests[i]));
      context->resource_requests[i].in_use = true;
      return &context->resource_requests[i];
    }
  }

  return NULL;
}

static void free_resource_request(example_resource_request_t *request) {
  if (request == NULL) return;
  if (request->loader_task != NULL) {
    rl_loader_free_task(request->loader_task);
  }
  memset(request, 0, sizeof(*request));
}

static const char *get_asset_host(void) {
  const char *value = getenv("RL_ASSET_HOST");
  if (value && value[0] != '\0') {
    return value;
  }
  return "https://192.168.1.100:4444";
}

static void module_log(void *user_data, int level, const char *message) {
  (void)user_data;
  rl_logger_message_source((rl_log_level_t)level, "module", 0, "%s",
                           message != NULL ? message : "(null)");
}

static void module_log_source(void *user_data, int level,
                              const char *source_file, int source_line,
                              const char *message) {
  (void)user_data;
  rl_logger_message_source((rl_log_level_t)level,
                           source_file != NULL && source_file[0] != '\0'
                               ? source_file
                               : "module",
                           source_line, "%s",
                           message != NULL ? message : "(null)");
}

static int module_event_on(void *host_user_data, const char *event_name,
                           rl_module_event_listener_fn listener,
                           void *listener_user_data) {
  (void)host_user_data;
  return rl_event_on(event_name, listener, listener_user_data);
}

static int module_event_off(void *host_user_data, const char *event_name,
                            rl_module_event_listener_fn listener,
                            void *listener_user_data) {
  (void)host_user_data;
  return rl_event_off(event_name, listener, listener_user_data);
}

static int module_event_emit(void *host_user_data, const char *event_name,
                             void *payload) {
  (void)host_user_data;
  return rl_event_emit(event_name, payload);
}

static void on_module_ready(void *payload, void *user_data) {
  (void)payload;
  (void)user_data;
  log_info("Lua module ready");
}

static void on_module_error(void *payload, void *user_data) {
  const char *error = (const char *)payload;
  (void)user_data;
  log_error("Lua module error: %s", error != NULL ? error : "(unknown)");
}

static void on_resource_load(void *payload, void *user_data) {
  example_context_t *context = (example_context_t *)user_data;
  example_resource_request_t *request = NULL;
  char kind[32];
  char path[256];
  int rid = 0;
  float size = 0.0f;

  if (context == NULL) {
    return;
  }

  if (parse_resource_request_payload((const char *)payload, &rid, kind,
                                     sizeof(kind), path, sizeof(path),
                                     &size) != 0) {
    emit_resource_error(rid, "invalid resource request");
    return;
  }

  request = alloc_resource_request(context);
  if (request == NULL) {
    emit_resource_error(rid, "resource request queue is full");
    return;
  }

  request->rid = rid;
  request->kind = parse_resource_kind(kind);
  request->size = size;
  (void)snprintf(request->path, sizeof(request->path), "%s", path);

  switch (request->kind) {
  case EXAMPLE_RESOURCE_KIND_MODEL:
    request->loader_task = rl_loader_import_asset_async(request->path);
    break;
  case EXAMPLE_RESOURCE_KIND_SPRITE3D:
  case EXAMPLE_RESOURCE_KIND_TEXTURE:
  case EXAMPLE_RESOURCE_KIND_FONT:
  case EXAMPLE_RESOURCE_KIND_SOUND:
  case EXAMPLE_RESOURCE_KIND_MUSIC:
    request->loader_task = rl_loader_import_asset_async(request->path);
    break;
  case EXAMPLE_RESOURCE_KIND_NONE:
  default:
    emit_resource_error(rid, "unsupported resource kind");
    free_resource_request(request);
    return;
  }

  if (request->loader_task == NULL) {
    emit_resource_error(rid, "failed to start resource prepare");
    free_resource_request(request);
  }
}

static void on_script_import(void *payload, void *user_data) {
  example_context_t *context = (example_context_t *)user_data;
  example_resource_request_t *request = NULL;
  char path[256];
  int rid = 0;

  if (context == NULL) {
    return;
  }

  if (parse_script_request_payload((const char *)payload, &rid, path,
                                   sizeof(path)) != 0) {
    emit_script_error(rid, "invalid script import request");
    return;
  }

  request = alloc_resource_request(context);
  if (request == NULL) {
    emit_script_error(rid, "script request queue is full");
    return;
  }

  request->rid = rid;
  request->kind = EXAMPLE_RESOURCE_KIND_SCRIPT;
  (void)snprintf(request->path, sizeof(request->path), "%s", path);
  request->loader_task = rl_loader_import_asset_async(request->path);
  if (request->loader_task == NULL) {
    emit_script_error(rid, "failed to start script import");
    free_resource_request(request);
  }
}

static void set_boot_error(example_context_t *context, const char *format, ...) {
  va_list args;

  if (context == NULL || format == NULL) {
    return;
  }

  va_start(args, format);
  (void)vsnprintf(context->boot_error, sizeof(context->boot_error), format, args);
  va_end(args);
  context->boot_state = EXAMPLE_BOOT_ERROR;
}

static void draw_boot_status(const char *title, const char *detail) {
  rl_frame_begin();
  rl_frame_clear_background(RL_COLOR_RAYWHITE);
  rl_text_draw(title != NULL ? title : "Booting...", 32, 32, 32,
               RL_COLOR_DARKGRAY);
  rl_text_draw(detail != NULL ? detail : "", 32, 80, 20, RL_COLOR_GRAY);
  rl_frame_end();
}

static void handle_boot_restore(example_context_t *context) {
  if (context->loader_task != NULL && rl_loader_poll_task(context->loader_task)) {
    int rc = rl_loader_finish_task(context->loader_task);
    rl_loader_free_task(context->loader_task);
    context->loader_task = NULL;

    if (rc != 0) {
      set_boot_error(context, "Loader bootstrap failed (%d)", rc);
      return;
    }

    // debugging, clear the cache so we don't use stale assets
    rl_loader_clear_cache();
    //
    
    context->loader_task = rl_loader_import_assets_async(
        EXAMPLE_ASSET_MANIFEST,
        sizeof(EXAMPLE_ASSET_MANIFEST) / sizeof(EXAMPLE_ASSET_MANIFEST[0]));
    if (context->loader_task == NULL) {
      set_boot_error(context, "Failed to start asset prepare");
      return;
    }

    context->boot_state = EXAMPLE_BOOT_PREPARE;
  }

  draw_boot_status("Loading assets", "Restoring cache...");
}

static void handle_boot_prepare(example_context_t *context) {
  if (context->loader_task != NULL && rl_loader_poll_task(context->loader_task)) {
    int rc = rl_loader_finish_task(context->loader_task);
    rl_loader_free_task(context->loader_task);
    context->loader_task = NULL;

    if (rc != 0) {
      set_boot_error(context, "Loader bootstrap failed (%d)", rc);
      return;
    }

    context->boot_state = EXAMPLE_BOOT_INIT_MODULE;
  }

  draw_boot_status("Loading assets", "Preparing assets...");
}

static void handle_boot_init_module(example_context_t *context) {
  int w = 0;
  int h = 0;
  int current_monitor = 0;
  int mon_width = 0;
  int mon_height = 0;
  float margin_scalar = 0.9f;
  float width_scale = 1.0f;
  float height_scale = 1.0f;
  float scale = 1.0f;
  rl_module_config_t *script_config = &context->script_config;
  rl_module_instance_t *script_module = &context->script_module;
  rl_module_host_api_t *module_host = &context->module_host;

  if (rl_module_init("lua", module_host, &script_module->api,
                     &script_module->state, context->module_error,
                     sizeof(context->module_error)) != 0) {
    set_boot_error(context, "Lua module init failed: %.220s",
                   context->module_error);
    return;
  }

  (void)rl_event_on("lua.ready", on_module_ready, NULL);
  (void)rl_event_on("lua.error", on_module_error, NULL);
  (void)rl_event_emit("lua.add_path", LUA_SCRIPT_ROOT);
  (void)rl_event_emit("lua.do_file", LUA_BOOT_SCRIPT);
  {
    char boot_command[256];
    (void)snprintf(boot_command, sizeof(boot_command), "boot('%s', '%s')",
                   LUA_SCRIPT_ROOT, LUA_APP_MODULE);
    (void)rl_event_emit("lua.do_string", boot_command);
  }
  if (rl_module_get_config_instance(script_module->api, script_module->state,
                                    script_config) != 0) {
    log_warn("Lua script get_config failed");
  }

  rl_window_set_title(script_config->title);
  rl_frame_runner_set_target_fps(script_config->target_fps > 0
                                     ? script_config->target_fps
                                     : 60);
  w = script_config->width;
  h = script_config->height;

  current_monitor = rl_window_get_current_monitor();
  mon_width = rl_window_get_monitor_width(current_monitor);
  mon_height = rl_window_get_monitor_height(current_monitor);
  width_scale = ((float)mon_width * margin_scalar) / (float)w;
  height_scale = ((float)mon_height * margin_scalar) / (float)h;
  scale = width_scale < height_scale ? width_scale : height_scale;
  w = (int)((float)w * scale);
  h = (int)((float)h * scale);
  rl_window_set_size(w > 0 ? w : 1, h > 0 ? h : 1);

  rl_debug_enable_fps(10, 10, 16, NULL);
  if (script_module->api != NULL &&
      rl_module_start_instance(script_module->api, script_module->state) != 0) {
    log_warn("Lua script start failed");
  }

  context->boot_state = EXAMPLE_BOOT_RUNNING;
}

static void poll_resource_requests(example_context_t *context) {
  int i = 0;

  if (context == NULL) {
    return;
  }

  for (i = 0; i < EXAMPLE_MAX_PENDING_RESOURCE_REQUESTS; i++) {
    char payload[64];
    int rc = 0;
    example_resource_request_t *request = &context->resource_requests[i];

    if (!request->in_use || request->loader_task == NULL) {
      continue;
    }

    if (!rl_loader_poll_task(request->loader_task)) {
      continue;
    }

    rc = rl_loader_finish_task(request->loader_task);
    rl_loader_free_task(request->loader_task);
    request->loader_task = NULL;

    if (rc != 0) {
      if (request->kind == EXAMPLE_RESOURCE_KIND_SCRIPT) {
        emit_script_error(request->rid, "script import failed");
      } else {
        emit_resource_error(request->rid, "resource prepare failed");
      }
      free_resource_request(request);
      continue;
    }

    if (request->kind == EXAMPLE_RESOURCE_KIND_SCRIPT) {
      (void)snprintf(payload, sizeof(payload), "%d", request->rid);
      (void)rl_event_emit("script.loaded", payload);
      free_resource_request(request);
      continue;
    }

    {
      rl_handle_t handle = create_resource_handle(request);
      if (handle == 0) {
        emit_resource_error(request->rid, "resource create failed");
        free_resource_request(request);
        continue;
      }

      (void)snprintf(payload, sizeof(payload), "%d|%u", request->rid,
                     (unsigned int)handle);
      (void)rl_event_emit("resource.loaded", payload);
    }

    free_resource_request(request);
  }
}

static void on_shutdown(void *user_data) {
  example_context_t *context = (example_context_t *)user_data;
  int i = 0;

  if (context == NULL) {
    return;
  }

  if (context->loader_task != NULL) {
    rl_loader_free_task(context->loader_task);
    context->loader_task = NULL;
  }
  for (i = 0; i < EXAMPLE_MAX_PENDING_RESOURCE_REQUESTS; i++) {
    free_resource_request(&context->resource_requests[i]);
  }
  rl_debug_disable();
  if (context->script_module.api != NULL) {
    rl_module_deinit_instance(context->script_module.api,
                              context->script_module.state);
    context->script_module.api = NULL;
    context->script_module.state = NULL;
  }
  (void)rl_event_off("lua.ready", on_module_ready, NULL);
  (void)rl_event_off("lua.error", on_module_error, NULL);
  (void)rl_event_off("resource.load", on_resource_load, context);
  (void)rl_event_off("script.import", on_script_import, context);
  rl_window_close();
}

static void on_init(void *user_data) {
  example_context_t *context = (example_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  if (rl_set_asset_host(g_asset_host) != 0) {
    set_boot_error(context, "Failed to set asset host: %s",
                   g_asset_host != NULL ? g_asset_host : "(null)");
    return;
  }

  (void)rl_event_on("resource.load", on_resource_load, context);
  (void)rl_event_on("script.import", on_script_import, context);

  rl_window_open(context->script_config.width, context->script_config.height,
                 context->script_config.title, context->script_config.flags);
  rl_frame_runner_set_target_fps(context->script_config.target_fps > 0
                                     ? context->script_config.target_fps
                                     : 60);

  context->module_host.user_data = &g_frame_command_buffer;
  context->module_host.log = module_log;
  context->module_host.log_source = module_log_source;
  context->module_host.event_on = module_event_on;
  context->module_host.event_off = module_event_off;
  context->module_host.event_emit = module_event_emit;
  context->module_host.frame_command = rl_frame_commands_append;
  context->loader_task = rl_loader_restore_fs_async();
  if (context->loader_task == NULL) {
    set_boot_error(context, "Failed to start cache restore");
  }
}

static void on_tick(void *user_data) {
  example_context_t *context = (example_context_t *)user_data;
  rl_module_instance_t *script_module = NULL;
  const float dt = rl_frame_get_delta_time();

  if (context == NULL) {
    return;
  }

  script_module = &context->script_module;
  switch (context->boot_state) {
  case EXAMPLE_BOOT_RESTORE:
    handle_boot_restore(context);
    return;
  case EXAMPLE_BOOT_PREPARE:
    handle_boot_prepare(context);
    return;
  case EXAMPLE_BOOT_INIT_MODULE:
    handle_boot_init_module(context);
    return;
  case EXAMPLE_BOOT_ERROR:
    draw_boot_status("Boot failed", context->boot_error);
    return;
  case EXAMPLE_BOOT_RUNNING:
    break;
  }

  poll_resource_requests(context);
  rl_frame_commands_reset(&g_frame_command_buffer);
  if (script_module->api != NULL && script_module->api->update != NULL) {
    (void)script_module->api->update(script_module->state, dt);
  }
  rl_frame_commands_execute_audio(&g_frame_command_buffer);
  rl_frame_begin();
  rl_frame_clear_background(RL_COLOR_RAYWHITE);
  rl_frame_commands_execute_clear(&g_frame_command_buffer);
  rl_begin_mode_3d();
  rl_frame_commands_execute_3d(&g_frame_command_buffer);
  rl_end_mode_3d();
  rl_frame_commands_execute_2d(&g_frame_command_buffer);
  rl_frame_end();
}

int main(void) {
  g_asset_host = get_asset_host();
  rl_logger_set_level(RL_LOGGER_LEVEL_DEBUG);

  g_example_context.script_config =
      (rl_module_config_t){800, 600, 60, RL_WINDOW_FLAG_MSAA_4X_HINT,
                           "librl + raylib + lua(C example)"};
  g_example_context.boot_state = EXAMPLE_BOOT_RESTORE;

  rl_init();
  rl_frame_runner_run(on_init, on_tick, on_shutdown,
                      &g_example_context);

  return 0;
}
