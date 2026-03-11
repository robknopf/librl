#include <raylib.h>

#include "logger/log.h"
#include "rl.h"
#include "rl_loader.h"
#include "rl_model.h"

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
  bool *ready = (bool *)user_data;
  (void)payload;
  if (ready != NULL) {
    *ready = true;
  }
  log_info("Lua module ready");
}

static void on_lua_ok(void *payload, void *user_data) {
  int *ok_count = (int *)user_data;
  (void)payload;
  if (ok_count != NULL) {
    (*ok_count)++;
  }
}

static void on_lua_error(void *payload, void *user_data) {
  const char *error = (const char *)payload;
  int *error_count = (int *)user_data;
  if (error_count != NULL) {
    (*error_count)++;
  }
  log_error("Lua module error: %s", error != NULL ? error : "(unknown)");
}

int main(void) {
  SetTraceLogLevel(LOG_LEVEL_DEBUG); // let raylib log everything, we'll filter
                                     // it in our callback
  log_set_log_level(LOG_LEVEL_DEBUG);

  const char *asset_host = get_asset_host();
  const char *font_path = "assets/fonts/Komika/KOMIKAH_.ttf";
  const char *model_path = "assets/models/gumshoe/gumshoe.glb";
  const char *sprite3d_path = "assets/sprites/logo/wg-logo-bw-alpha.png";
  const char *sfx_path = "assets/sounds/click_004.ogg";
  const float font_size = 24.0f;
  const float small_font_size = 16.0f;
  rl_handle_t sfx = 0;
  rl_handle_t model = 0;
  rl_handle_t sprite3d = 0;
  rl_pick_result_t last_pick = {0};
  bool has_pick = false;
  bool lua_ready = false;
  int lua_ok_count = 0;
  int lua_error_count = 0;
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

  SetConfigFlags(FLAG_MSAA_4X_HINT);

  InitWindow(800, 600, "librl + raylib + lua(C example)");
  SetTargetFPS(60);

  rl_handle_t komika = rl_font_create(font_path, font_size);
  rl_handle_t komika_small = rl_font_create(font_path, small_font_size);
  rl_handle_t text_shadow = rl_color_create(0, 0, 0, 160);
  rl_handle_t camera =
      rl_camera3d_create(12.0f, 12.0f, 12.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
                         0.0f, 45.0f, CAMERA_PERSPECTIVE);

  (void)rl_event_on("lua.ready", on_lua_ready, &lua_ready);
  (void)rl_event_on("lua.ok", on_lua_ok, &lua_ok_count);
  (void)rl_event_on("lua.error", on_lua_error, &lua_error_count);

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
    (void)rl_event_emit("lua.add_path", "assets/scripts");
    (void)rl_event_emit("lua.do_file", "lua_demo.lua");
  } else {
    log_warn("Lua module init failed: %s", module_error);
  }

  //sfx = rl_sound_create(sfx_path);
  if (sfx == 0) {
    log_warn("Failed to load sfx from %s", sfx_path);
  }

  //model = rl_model_create(model_path);
  if (model == 0) {
    log_warn("Failed to load model from %s", model_path);
  }

  //sprite3d = rl_sprite3d_create(sprite3d_path);
  if (sprite3d == 0) {
    log_warn("Failed to create sprite3d from %s", sprite3d_path);
  }

  (void)rl_camera3d_set_active(camera);

  while (!WindowShouldClose()) {
    const float dt = GetFrameTime();
    const int screen_w = GetScreenWidth();
    const int screen_h = GetScreenHeight();
    const char *message = "raylib loop + librl handles";
    vec2_t message_size = {0};
    int text_x = 0;
    int text_y = 0;

    rl_music_update_all();
    // Script-generated frame commands are rebuilt from scratch every tick.
    lua_frame_reset(&g_app.lua_frame);
    if (lua_module.api != NULL && lua_module.api->update != NULL) {
      (void)lua_module.api->update(lua_module.state, dt);
    }
    lua_frame_execute_audio(&g_app.lua_frame);
    if (IsMouseButtonPressed(MOUSE_LEFT_BUTTON)) {
      if (sfx != 0) {
        (void)rl_sound_play(sfx);
      }
      Vector2 mouse = GetMousePosition();
      last_pick = rl_pick_model(camera, model, mouse.x, mouse.y, 0.0f, 0.0f,
                                0.0f, 1.0f);
      has_pick = true;
      if (last_pick.hit) {
        log_info("Picked gumshoe: distance=%.3f point=(%.2f, %.2f, %.2f)",
                 last_pick.distance, last_pick.point.x, last_pick.point.y,
                 last_pick.point.z);
      } else {
        log_info("Pick miss on gumshoe");
      }
    }

    BeginDrawing();
    // Drain scripted commands in the same passes the host uses: clear, 3D,
    // then 2D/UI.
    ClearBackground(RAYWHITE);
    lua_frame_execute_clear(&g_app.lua_frame);

    rl_begin_mode_3d();
    lua_frame_execute_3d(&g_app.lua_frame);
    if (sprite3d != 0) {
      rl_sprite3d_draw(sprite3d, 0.0f, 0.0f, 0.0f, 1.0f, RL_COLOR_WHITE);
    }
    rl_end_mode_3d();

    lua_frame_execute_2d(&g_app.lua_frame);
    message_size = rl_measure_text_ex(komika, message, font_size, 1.0f);
    text_x = (int)((screen_w - message_size.x) * 0.5f);
    text_y = (int)((screen_h - message_size.y) * 0.5f);

    rl_draw_text_ex(komika, message, text_x + 2, text_y + 2, font_size, 1.0f,
                    text_shadow);
    rl_draw_text_ex(komika, message, text_x, text_y, font_size, 1.0f,
                    RL_COLOR_BLUE);
    rl_draw_text_ex(komika_small, TextFormat("assetHost: %s", asset_host), 10,
                    10, small_font_size, 1.0, RL_COLOR_DARKGRAY);
    rl_draw_text_ex(komika_small, "Set RL_ASSET_HOST to override", 10, 30,
                    small_font_size, 1.0, RL_COLOR_GRAY);
    rl_draw_text_ex(komika_small,
                    TextFormat("lua ready: %s ok:%d err:%d",
                               lua_ready ? "yes" : "no", lua_ok_count,
                               lua_error_count),
                    10, 96, small_font_size, 1.0, RL_COLOR_DARKBLUE);
    if (has_pick) {
      if (last_pick.hit) {
        rl_draw_text_ex(komika_small,
                        TextFormat("Pick hit: d=%.2f @ (%.2f, %.2f, %.2f)",
                                   last_pick.distance, last_pick.point.x,
                                   last_pick.point.y, last_pick.point.z),
                        10, 52, small_font_size, 1.0, RL_COLOR_DARKGREEN);
      } else {
        rl_draw_text_ex(komika_small, "Pick miss", 10, 52, small_font_size, 1.0,
                        RL_COLOR_MAROON);
      }
      rl_draw_fps_ex(komika_small, 10, 74, (int)small_font_size,
                     RL_COLOR_BLACK);
    } else {
      rl_draw_fps_ex(komika_small, 10, 52, (int)small_font_size,
                     RL_COLOR_BLACK);
    }

    EndDrawing();
  }

  rl_camera3d_destroy(camera);
  if (sprite3d != 0) {
    rl_sprite3d_destroy(sprite3d);
  }
  if (model != 0) {
    rl_model_destroy(model);
  }
  rl_font_destroy(komika);
  rl_font_destroy(komika_small);
  rl_color_destroy(text_shadow);
  if (sfx != 0) {
    rl_sound_destroy(sfx);
  }
  if (lua_module.api != NULL) {
    rl_module_deinit_instance(lua_module.api, lua_module.state);
  }
  (void)rl_event_off("lua.ready", on_lua_ready, &lua_ready);
  (void)rl_event_off("lua.ok", on_lua_ok, &lua_ok_count);
  (void)rl_event_off("lua.error", on_lua_error, &lua_error_count);
  rl_deinit();
  CloseWindow();
  return 0;
}
