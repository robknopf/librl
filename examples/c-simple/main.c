// C version of the Nim example: simple handle-based demo with async asset load.
#include "rl.h"
#include "rl_window.h"

#include <stdbool.h>
#include <stdio.h>

static const char *ASSET_HOST = "https://localhost:4444";
static const char *MODEL_PATH = "assets/models/gumshoe/gumshoe.glb";
static const char *SPRITE_PATH = "assets/sprites/logo/wg-logo-bw-alpha.png";
static const char *FONT_PATH = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
static const char *MESSAGE = "Hello World!";

typedef struct app_context_t {
  rl_handle_t komika;
  rl_handle_t komika_small;
  rl_handle_t gumshoe;
  rl_handle_t sprite;
  rl_handle_t camera;
  rl_handle_t grey_alpha_color;
  float countdown_timer;
  float total_time;
  double last_time;
  int assets_ready;
} app_context_t;

static void on_asset_ready(const char *path, void *user_data) {
  (void)path;
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx) {
    ctx->assets_ready++;
  }
}

static void on_asset_failed(const char *path, void *user_data) {
  (void)user_data;
  rl_logger_message_source(RL_LOGGER_LEVEL_WARN, "example", 0,
                           "Failed to load asset: %s",
                           path != NULL ? path : "(null)");
}

static void queue_asset(const char *path, app_context_t *ctx) {
  rl_loader_task_t *task = rl_loader_import_asset_async(path);
  int rc = rl_loader_add_task(task, path,
                              (rl_loader_callback_fn)on_asset_ready,
                              (rl_loader_callback_fn)on_asset_failed,
                              ctx);
  if (rc != RL_LOADER_ADD_TASK_OK) {
    rl_logger_message_source(RL_LOGGER_LEVEL_WARN, "example", 0,
                             "Failed to queue asset: %s (rc=%d)",
                             path != NULL ? path : "(null)", rc);
  }
}

static void on_init(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  rl_window_open(1024, 1280, "Hello, World! (C simple)",
                 RL_WINDOW_FLAG_MSAA_4X_HINT);
  rl_set_target_fps(60);

  queue_asset(FONT_PATH, ctx);
  queue_asset(MODEL_PATH, ctx);
  queue_asset(SPRITE_PATH, ctx);
}

static void on_tick(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  if (ctx->assets_ready < 3) {
    return;
  }

  if (ctx->komika == 0) {
    ctx->grey_alpha_color = rl_color_create(0, 0, 0, 128);
    rl_enable_lighting();
    rl_set_light_direction(-0.6f, -1.0f, -0.5f);
    rl_set_light_ambient(0.25f);

    ctx->komika = rl_font_create(FONT_PATH, 24.0f);
    ctx->komika_small = rl_font_create(FONT_PATH, 16.0f);
    ctx->gumshoe = rl_model_create(MODEL_PATH);
    ctx->sprite = rl_sprite3d_create(SPRITE_PATH);
    ctx->camera = rl_camera3d_create(
        12.0f, 12.0f, 12.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        45.0f, 0 /* CAMERA_PERSPECTIVE */);
    rl_camera3d_set_active(ctx->camera);
    rl_model_set_animation(ctx->gumshoe, 1);
    rl_model_set_animation_speed(ctx->gumshoe, 1.0f);
    rl_model_set_animation_loop(ctx->gumshoe, true);
    ctx->last_time = rl_get_time();
    ctx->countdown_timer = 5.0f;
  }

  double current_time = rl_get_time();
  float delta_time = (float)(current_time - ctx->last_time);
  ctx->total_time += delta_time;
  ctx->last_time = current_time;
  ctx->countdown_timer -= delta_time;
  if (ctx->countdown_timer <= 0.0f) {
    rl_request_stop();
    return;
  }

  rl_render_begin();
  rl_render_clear_background(RL_COLOR_RAYWHITE);
  rl_render_begin_mode_3d();
  rl_model_animate(ctx->gumshoe, delta_time);
  rl_model_set_transform(ctx->gumshoe,
                         0.0f, 0.0f, 0.0f,
                         0.0f, 0.0f, 0.0f,
                         1.0f, 1.0f, 1.0f);
  rl_model_draw(ctx->gumshoe, RL_COLOR_RAYWHITE);
  rl_sprite3d_set_transform(ctx->sprite, 0.0f, 0.0f, 0.0f, 1.0f);
  rl_sprite3d_draw(ctx->sprite, RL_COLOR_RAYWHITE);
  rl_render_end_mode_3d();

  vec2_t screen = rl_window_get_screen_size();
  int w = (int)screen.x;
  int h = (int)screen.y;
  vec2_t text_size = rl_text_measure_ex(ctx->komika, MESSAGE, 24.0f, 0.0f);
  int text_x = (int)((w - text_size.x) / 2.0f);
  int text_y = (int)((h - text_size.y) / 2.0f);
  rl_text_draw_ex(ctx->komika, MESSAGE, text_x, text_y, 24.0f, 1.0f, RL_COLOR_BLUE);

  char remaining[64];
  char elapsed[64];
  rl_mouse_state_t mouse = rl_input_get_mouse_state();
  char mouse_text[128];

  (void)snprintf(remaining, sizeof(remaining), "Remaining: %.2f",
                 ctx->countdown_timer);
  (void)snprintf(elapsed, sizeof(elapsed), "Elapsed: %.2f",
                 ctx->total_time);
  (void)snprintf(mouse_text, sizeof(mouse_text),
                 "Mouse: (%d, %d) w:%d b:[%d, %d, %d]",
                 mouse.x, mouse.y, mouse.wheel,
                 mouse.left, mouse.right, mouse.middle);

  rl_text_draw_ex(ctx->komika_small, remaining, 10, 36, 16.0f, 1.0f, RL_COLOR_BLACK);
  rl_text_draw_ex(ctx->komika_small, elapsed, 10, 56, 16.0f, 1.0f, RL_COLOR_BLACK);
  rl_text_draw_ex(ctx->komika_small, mouse_text, 10, 76, 16.0f, 1.0f, RL_COLOR_BLACK);
  rl_text_draw_fps_ex(ctx->komika_small, 10, 10, 16, ctx->grey_alpha_color);

  rl_render_end();
}

static void on_shutdown(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  rl_disable_lighting();
  if (ctx->sprite != 0) rl_sprite3d_destroy(ctx->sprite);
  if (ctx->gumshoe != 0) rl_model_destroy(ctx->gumshoe);
  if (ctx->komika != 0) rl_font_destroy(ctx->komika);
  if (ctx->komika_small != 0) rl_font_destroy(ctx->komika_small);
  if (ctx->grey_alpha_color != 0) rl_color_destroy(ctx->grey_alpha_color);
  if (ctx->camera != 0) rl_camera3d_destroy(ctx->camera);
  rl_deinit();
  rl_window_close();
}

int main(void) {
  app_context_t ctx = {0};

  rl_init();
  rl_set_asset_host(ASSET_HOST);
  rl_run(on_init, on_tick, on_shutdown, &ctx);

  return 0;
}
