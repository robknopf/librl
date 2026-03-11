#include <raylib.h>

#include "logger/log.h"
#include "rl.h"
#include "rl_loader.h"
#include "rl_lua_module.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#define LUA_FRAME_COMMAND_CAPACITY 128

typedef struct lua_frame_buffer_t {
  rl_module_frame_command_t commands[LUA_FRAME_COMMAND_CAPACITY];
  int count;
} lua_frame_buffer_t;

typedef struct example_app_context_t {
  lua_frame_buffer_t lua_frame;
} example_app_context_t;

// Keep the command buffer out of the wasm stack; the example only needs one
// app-wide instance.
static example_app_context_t g_app = {0};

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

static void module_frame_command(void *host_user_data,
                                 const rl_module_frame_command_t *command) {
  example_app_context_t *app = (example_app_context_t *)host_user_data;
  lua_frame_buffer_t *frame = NULL;

  if (app == NULL || command == NULL) {
    return;
  }

  frame = &app->lua_frame;
  if (frame->count < LUA_FRAME_COMMAND_CAPACITY) {
    frame->commands[frame->count++] = *command;
  }
}

static void lua_frame_reset(lua_frame_buffer_t *frame) {
  if (frame == NULL) {
    return;
  }
  frame->count = 0;
}

static void lua_frame_execute_clear(const lua_frame_buffer_t *frame) {
  int i = 0;

  if (frame == NULL) {
    return;
  }

  for (i = 0; i < frame->count; i++) {
    const rl_module_frame_command_t *command = &frame->commands[i];
    switch (command->type) {
    case RL_MODULE_FRAME_CMD_CLEAR:
      rl_clear_background(command->data.clear.color);
      break;
    default:
      break;
    }
  }
}

static void lua_frame_execute_audio(const lua_frame_buffer_t *frame) {
  int i = 0;

  if (frame == NULL) {
    return;
  }

  for (i = 0; i < frame->count; i++) {
    const rl_module_frame_command_t *command = &frame->commands[i];
    switch (command->type) {
    case RL_MODULE_FRAME_CMD_PLAY_SOUND:
      (void)rl_sound_play(command->data.play_sound.sound);
      break;
    default:
      break;
    }
  }
}

static void lua_frame_execute_3d(const lua_frame_buffer_t *frame) {
  int i = 0;

  if (frame == NULL) {
    return;
  }

  for (i = 0; i < frame->count; i++) {
    const rl_module_frame_command_t *command = &frame->commands[i];
    switch (command->type) {
    case RL_MODULE_FRAME_CMD_DRAW_MODEL:
      if (command->data.draw_model.animation_index >= 0) {
        rl_model_animation_update(command->data.draw_model.model,
                                  command->data.draw_model.animation_index,
                                  command->data.draw_model.animation_frame);
      }
      rl_model_draw(command->data.draw_model.model, command->data.draw_model.x,
                    command->data.draw_model.y, command->data.draw_model.z,
                    command->data.draw_model.scale,
                    command->data.draw_model.rotation_x,
                    command->data.draw_model.rotation_y,
                    command->data.draw_model.rotation_z,
                    command->data.draw_model.tint);
      break;
    case RL_MODULE_FRAME_CMD_DRAW_SPRITE3D:
      rl_sprite3d_draw(command->data.draw_sprite3d.sprite,
                       command->data.draw_sprite3d.x,
                       command->data.draw_sprite3d.y,
                       command->data.draw_sprite3d.z,
                       command->data.draw_sprite3d.size,
                       command->data.draw_sprite3d.tint);
      break;
    default:
      break;
    }
  }
}

static void lua_frame_execute_2d(const lua_frame_buffer_t *frame) {
  int i = 0;

  if (frame == NULL) {
    return;
  }

  for (i = 0; i < frame->count; i++) {
    const rl_module_frame_command_t *command = &frame->commands[i];
    switch (command->type) {
    case RL_MODULE_FRAME_CMD_DRAW_TEXTURE:
      rl_draw_texture_ex(command->data.draw_texture.texture,
                         command->data.draw_texture.x,
                         command->data.draw_texture.y,
                         command->data.draw_texture.scale,
                         command->data.draw_texture.rotation,
                         command->data.draw_texture.tint);
      break;
    case RL_MODULE_FRAME_CMD_DRAW_TEXT:
      rl_draw_text_ex(
          command->data.draw_text.font, command->data.draw_text.text,
          (int)command->data.draw_text.x, (int)command->data.draw_text.y,
          command->data.draw_text.font_size, command->data.draw_text.spacing,
          command->data.draw_text.color);
      break;
    default:
      break;
    }
  }
}

static void on_lua_ready(void *payload, void *user_data) {
  (void)payload;
  (void)user_data;
  log_info("Lua module ready");
}

static void on_lua_error(void *payload, void *user_data) {
  const char *error = (const char *)payload;
  (void)user_data;
  log_error("Lua module error: %s", error != NULL ? error : "(unknown)");
}

int main(void) {
  SetTraceLogLevel(LOG_LEVEL_DEBUG); // let raylib log everything, we'll filter
                                     // it in our callback
  log_set_log_level(LOG_LEVEL_DEBUG);

  const char *asset_host = get_asset_host();
  const char *komika_font_path = "assets/fonts/Komika/KOMIKAH_.ttf";
  const float small_font_size = 16.0f;
  rl_module_config_t script_config = {800, 600, 60, FLAG_MSAA_4X_HINT,
                                      "librl + raylib + lua(C example)"};
  rl_module_instance_t lua_module = {0};
  rl_module_host_api_t module_host = {0};
  char module_error[256] = {0};

  rl_init();
  if (rl_set_asset_host(asset_host) != 0) {
    fprintf(stderr, "Failed to set asset host: %s\n", asset_host);
    rl_deinit();
    return 1;
  }

  // Debugging: clear any persisted asset cache before we repopulate it.
  rl_loader_clear_cache();

  module_host.user_data = &g_app;
  module_host.log = module_log;
  module_host.log_source = module_log_source;
  module_host.event_on = module_event_on;
  module_host.event_off = module_event_off;
  module_host.event_emit = module_event_emit;
  // Lua pushes transient draw commands into this host-owned buffer.
  module_host.frame_command = module_frame_command;

  if (rl_module_init("lua", &module_host, &lua_module.api, &lua_module.state,
                     module_error, sizeof(module_error)) == 0) {
    (void)rl_event_on("lua.ready", on_lua_ready, NULL);
    (void)rl_event_on("lua.error", on_lua_error, NULL);
    (void)rl_event_emit("lua.add_path", "assets/scripts");
    (void)rl_event_emit("lua.do_file", "lua_demo.lua");
    if (rl_module_get_config_instance(lua_module.api, lua_module.state, &script_config) != 0) {
      log_warn("Lua script get_config failed");
    }
  } else {
    log_warn("Lua module init failed: %s", module_error);
  }

  SetConfigFlags(script_config.flags);
  InitWindow(script_config.width, script_config.height, script_config.title);
  SetTargetFPS(script_config.target_fps > 0 ? script_config.target_fps : 60);

  rl_handle_t komika_small = rl_font_create(komika_font_path, small_font_size);
  if (lua_module.api != NULL && rl_module_start_instance(lua_module.api, lua_module.state) != 0) {
    log_warn("Lua script start failed");
  }

  while (!WindowShouldClose()) {
    const float dt = GetFrameTime();
    rl_music_update_all();
    // Script-generated frame commands are rebuilt from scratch every tick.
    lua_frame_reset(&g_app.lua_frame);
    if (lua_module.api != NULL && lua_module.api->update != NULL) {
      (void)lua_module.api->update(lua_module.state, dt);
    }
    lua_frame_execute_audio(&g_app.lua_frame);
    BeginDrawing();
    // Drain scripted commands in the same passes the host uses: clear, 3D,
    // then 2D/UI.
    
    // clear to some neutral color in case lua doesn't clear
    ClearBackground(RAYWHITE);  

    // lua frame clear pass
    lua_frame_execute_clear(&g_app.lua_frame);

    // lua frame 3d pass
    rl_begin_mode_3d();
    lua_frame_execute_3d(&g_app.lua_frame);
    rl_end_mode_3d();

    // lua frame 2d pass
    lua_frame_execute_2d(&g_app.lua_frame);

    // draw the fps in the top left corner
    rl_draw_fps_ex(komika_small, 10, 10, (int)small_font_size,
                   RL_COLOR_BLACK);

    EndDrawing();
  }

  rl_font_destroy(komika_small);
  if (lua_module.api != NULL) {
    rl_module_deinit_instance(lua_module.api, lua_module.state);
  }
  (void)rl_event_off("lua.ready", on_lua_ready, NULL);
  (void)rl_event_off("lua.error", on_lua_error, NULL);
  rl_deinit();
  CloseWindow();
  return 0;
}
