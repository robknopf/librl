// C version of the Nim example: simple handle-based demo with async asset load.
#include "rl.h"
#include "rl_color.h"
#include "rl_loader.h"
#include "rl_logger.h"
#include "rl_music.h"
#include "rl_render.h"
#include "rl_window.h"

#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#ifdef PLATFORM_WEB
static const char *ASSET_HOST = "./";
#else
static const char *ASSET_HOST = "https://localhost:4444";
#endif
static const char *MODEL_PATH = "assets/models/gumshoe/gumshoe.glb";
static const char *SPRITE_PATH = "assets/sprites/logo/wg-logo-bw-alpha.png";
static const char *FONT_PATH =
    "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
static const char *BGM_PATH = "assets/music/ethernight_club.mp3";
static const char *MESSAGE = "Hello World!";

typedef struct app_context_t {
  rl_handle_t komika;
  rl_handle_t komika_small;
  rl_handle_t gumshoe;
  rl_handle_t sprite;
  rl_handle_t camera;
  rl_handle_t grey_alpha_color;
  rl_handle_t bgm;
  float countdown_timer;
  float total_time;
  double last_time;
} app_context_t;

static void rl_loader_import_asset_failed_cb_default(const char *path,
                                                     void *user_data) {
  (void)user_data;
  rl_logger_message_source(RL_LOGGER_LEVEL_WARN, "unknown", 0,
                           "Failed to load asset: %s",
                           path != NULL ? path : "(null)");
}

static int finish_import_tasks(rl_loader_task_t **tasks, size_t task_count) {
  size_t remaining = 0;
  size_t i = 0;
  int failures = 0;

  for (i = 0; i < task_count; i++) {
    if (tasks[i] != NULL) {
      remaining++;
    }
  }

  while (remaining > 0) {
    rl_loader_tick();
    for (i = 0; i < task_count; i++) {
      int rc = 0;
      const char *path = NULL;
      if (tasks[i] == NULL || !rl_loader_poll_task(tasks[i])) {
        continue;
      }
      path = rl_loader_get_task_path(tasks[i]);
      rc = rl_loader_finish_task(tasks[i]);
      rl_loader_free_task(tasks[i]);
      tasks[i] = NULL;
      remaining--;
      if (rc != 0) {
        failures++;
        rl_loader_import_asset_failed_cb_default(path, NULL);
      }
    }
  }

  return failures == 0 ? 0 : -1;
}

static void on_bgm_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx->bgm != 0) {
    rl_music_stop(ctx->bgm);
  }
  ctx->bgm = rl_music_create(path);
  rl_music_set_loop(ctx->bgm, true);
  rl_music_set_volume(ctx->bgm, 0.1);
  rl_music_play(ctx->bgm);
}

static void play_bgm(const char *path, void *user_data) {
  rl_loader_task_t *bgm_asset_task = rl_loader_import_asset_async(path);
  rl_loader_queue_task(bgm_asset_task, path, on_bgm_ready, NULL, user_data);
}

static void on_init(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  rl_set_target_fps(60);

  // camera
  ctx->camera =
      rl_camera3d_create(12.0f, 12.0f, 12.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
                         0.0f, 45.0f, 0 /* CAMERA_PERSPECTIVE */);
  rl_camera3d_set_active(ctx->camera);

  // lighting
  // TODO:  create rl_lights.c?  Add light instances?
  rl_enable_lighting();
  rl_set_light_direction(-0.6f, -1.0f, -0.5f);
  rl_set_light_ambient(0.25f);

  // draw a blank screen while loading
  rl_render_begin();
  rl_render_clear_background(RL_COLOR_BLACK);
  rl_render_end();

  // start fetching the bgm, asyncronously
  play_bgm(BGM_PATH, ctx);

  // fetch the assets we'll need
  rl_loader_task_t *asset_import_tasks[] = {
      rl_loader_import_asset_async(FONT_PATH),
      rl_loader_import_asset_async(MODEL_PATH),
      rl_loader_import_asset_async(SPRITE_PATH)};
      
  const size_t asset_import_tasks_count =
      sizeof(asset_import_tasks) / sizeof(asset_import_tasks[0]);

  // wait until they all have been fetched/loaded
  if (finish_import_tasks(asset_import_tasks, asset_import_tasks_count) != 0) {
    rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "example", 0,
                             "Failed to import required startup assets");
    rl_stop();
    return;
  }

  ctx->grey_alpha_color = rl_color_create(0, 0, 0, 128);
  ctx->komika = rl_font_create(FONT_PATH, 24.0f);
  ctx->komika_small = rl_font_create(FONT_PATH, 16.0f);
  ctx->gumshoe = rl_model_create(MODEL_PATH);
  ctx->sprite = rl_sprite3d_create(SPRITE_PATH);
  rl_model_set_animation(ctx->gumshoe, 1);
  rl_model_set_animation_speed(ctx->gumshoe, 1.0f);
  rl_model_set_animation_loop(ctx->gumshoe, true);
  ctx->last_time = rl_get_time();
  ctx->countdown_timer = 5.0f;
}

static void on_tick(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  /*
  if (ctx->komika == 0 || ctx->komika_small == 0 || ctx->gumshoe == 0 ||
       ctx->sprite == 0 || ctx->camera == 0 || ctx->grey_alpha_color == 0) {
     return;
   }
 */

  double current_time = rl_get_time();
  float delta_time = (float)(current_time - ctx->last_time);
  ctx->total_time += delta_time;
  ctx->last_time = current_time;
  ctx->countdown_timer -= delta_time;
  if (ctx->countdown_timer <= 0.0f) {
    rl_stop();
    return;
  }

  rl_music_update_all();

  rl_render_begin();
  rl_render_clear_background(RL_COLOR_RAYWHITE);
  rl_render_begin_mode_3d();
  rl_model_animate(ctx->gumshoe, delta_time);
  rl_model_set_transform(ctx->gumshoe, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f,
                         1.0f, 1.0f);
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
  rl_text_draw_ex(ctx->komika, MESSAGE, text_x, text_y, 24.0f, 1.0f,
                  RL_COLOR_BLUE);

  char remaining[64];
  char elapsed[64];
  rl_mouse_state_t mouse = rl_input_get_mouse_state();
  char mouse_text[128];

  (void)snprintf(remaining, sizeof(remaining), "Remaining: %.2f",
                 ctx->countdown_timer);
  (void)snprintf(elapsed, sizeof(elapsed), "Elapsed: %.2f", ctx->total_time);
  (void)snprintf(mouse_text, sizeof(mouse_text),
                 "Mouse: (%d, %d) w:%d b:[%d, %d, %d]", mouse.x, mouse.y,
                 mouse.wheel, mouse.left, mouse.right, mouse.middle);

  rl_text_draw_ex(ctx->komika_small, remaining, 10, 36, 16.0f, 1.0f,
                  RL_COLOR_BLACK);
  rl_text_draw_ex(ctx->komika_small, elapsed, 10, 56, 16.0f, 1.0f,
                  RL_COLOR_BLACK);
  rl_text_draw_ex(ctx->komika_small, mouse_text, 10, 76, 16.0f, 1.0f,
                  RL_COLOR_BLACK);
  rl_text_draw_fps_ex(ctx->komika_small, 10, 10, 16, ctx->grey_alpha_color);

  rl_render_end();
}

static void on_shutdown(void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;

  if (ctx->bgm != 0)
    rl_music_destroy(ctx->bgm);
  rl_disable_lighting();
  if (ctx->sprite != 0)
    rl_sprite3d_destroy(ctx->sprite);
  if (ctx->gumshoe != 0)
    rl_model_destroy(ctx->gumshoe);
  if (ctx->komika != 0)
    rl_font_destroy(ctx->komika);
  if (ctx->komika_small != 0)
    rl_font_destroy(ctx->komika_small);
  if (ctx->grey_alpha_color != 0)
    rl_color_destroy(ctx->grey_alpha_color);
  if (ctx->camera != 0)
    rl_camera3d_destroy(ctx->camera);

  rl_deinit();
}

int main(void) {
  app_context_t ctx = {0};

  {
    rl_init_config_t init_cfg;
    memset(&init_cfg, 0, sizeof(init_cfg));
    init_cfg.window_width = 1024;
    init_cfg.window_height = 1280;
    init_cfg.window_title = "Hello, World! (C simple)";
    init_cfg.window_flags = RL_WINDOW_FLAG_MSAA_4X_HINT;
    init_cfg.asset_host = ASSET_HOST;
    if (rl_init(&init_cfg) != 0) {
      return 1;
    }
  }
  rl_run(on_init, on_tick, on_shutdown, &ctx);

  return 0;
}
