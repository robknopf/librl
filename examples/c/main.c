#include "rl.h"
#include "rl_window.h"

#include <stdbool.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>

typedef enum example_boot_state_t {
  EXAMPLE_BOOT_RESTORE = 0,
  EXAMPLE_BOOT_PREPARE = 1,
  EXAMPLE_BOOT_INIT_MODULE = 2,
  EXAMPLE_BOOT_RUNNING = 3,
  EXAMPLE_BOOT_ERROR = 4
} example_boot_state_t;

static const char *const EXAMPLE_ASSET_MANIFEST[] = {
    "assets/scripts/lua/lua_demo.lua",
    "assets/scripts/lua/input_mapping.lua",
    "assets/scripts/lua/model.lua",
    "assets/scripts/lua/music.lua",
    "assets/scripts/lua/texture.lua",
    "assets/scripts/lua/sprite3d.lua",
    "assets/scripts/lua/sound.lua",
    "assets/scripts/lua/camera3d.lua",
    "assets/scripts/lua/font.lua",
    "assets/scripts/lua/color.lua",
    "assets/scripts/lua/shadow.lua",
    "assets/fonts/Komika/KOMIKAH_.ttf",
    "assets/sprites/logo/wg-logo-bw-alpha.png",
    "assets/textures/blobshadow.png",
    "assets/models/gumshoe/gumshoe.glb",
    "assets/music/ethernight_club.mp3",
    "assets/sounds/click_004.ogg",
};

typedef struct example_context_t {
  rl_module_config_t script_config;
  rl_module_instance_t script_module;
  rl_module_host_api_t module_host;
  rl_loader_op_t *loader_op;
  example_boot_state_t boot_state;
  char module_error[256];
  char boot_error[256];
} example_context_t;

// Keep the command buffer out of the wasm stack; the example only needs one
// app-wide instance.
static rl_frame_command_buffer_t g_frame_command_buffer = {0};
static example_context_t g_example_context = {0};
static const char *g_asset_host = NULL;

static const char *get_asset_host(void) {
  const char *value = getenv("RL_ASSET_HOST");
  if (value && value[0] != '\0') {
    return value;
  }
  return "https://192.168.1.100:4444";
}

static void module_log(void *user_data, int level, const char *message) {
  (void)user_data;
  log_message(level, "module", 0, "%s", message != NULL ? message : "(null)");
}

static void module_log_source(void *user_data, int level,
                              const char *source_file, int source_line,
                              const char *message) {
  (void)user_data;
  log_message(level,
              source_file != NULL && source_file[0] != '\0' ? source_file
                                                            : "module",
              source_line, "%s", message != NULL ? message : "(null)");
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
  if (context->loader_op != NULL && rl_loader_poll_op(context->loader_op)) {
    int rc = rl_loader_finish_op(context->loader_op);
    rl_loader_free_op(context->loader_op);
    context->loader_op = NULL;

    if (rc != 0) {
      set_boot_error(context, "Loader bootstrap failed (%d)", rc);
      return;
    }

    context->loader_op = rl_loader_begin_prepare_paths(
        EXAMPLE_ASSET_MANIFEST,
        sizeof(EXAMPLE_ASSET_MANIFEST) / sizeof(EXAMPLE_ASSET_MANIFEST[0]));
    if (context->loader_op == NULL) {
      set_boot_error(context, "Failed to start asset prepare");
      return;
    }

    context->boot_state = EXAMPLE_BOOT_PREPARE;
  }

  draw_boot_status("Loading assets", "Restoring cache...");
}

static void handle_boot_prepare(example_context_t *context) {
  if (context->loader_op != NULL && rl_loader_poll_op(context->loader_op)) {
    int rc = rl_loader_finish_op(context->loader_op);
    rl_loader_free_op(context->loader_op);
    context->loader_op = NULL;

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
  (void)rl_event_emit("lua.add_path", "assets/scripts/lua");
  (void)rl_event_emit("lua.do_file", "lua_demo.lua");
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

  rl_debug_enable_fps(10, 10, 16, "assets/fonts/Komika/KOMIKAH_.ttf");
  if (script_module->api != NULL &&
      rl_module_start_instance(script_module->api, script_module->state) != 0) {
    log_warn("Lua script start failed");
  }

  context->boot_state = EXAMPLE_BOOT_RUNNING;
}

static void on_shutdown(void *user_data) {
  example_context_t *context = (example_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  if (context->loader_op != NULL) {
    rl_loader_free_op(context->loader_op);
    context->loader_op = NULL;
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
  rl_deinit();
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

  rl_loader_clear_cache();

  rl_window_init(context->script_config.width, context->script_config.height,
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
  context->loader_op = rl_loader_begin_restore();
  if (context->loader_op == NULL) {
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
  rl_logger_set_level(LOG_LEVEL_DEBUG);

  g_example_context.script_config =
      (rl_module_config_t){800, 600, 60, RL_WINDOW_FLAG_MSAA_4X_HINT,
                           "librl + raylib + lua(C example)"};
  g_example_context.boot_state = EXAMPLE_BOOT_RESTORE;

  rl_init();
  rl_frame_runner_run(on_init, on_tick, on_shutdown,
                      &g_example_context);

  return 0;
}
