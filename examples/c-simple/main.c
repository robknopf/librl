// C simple example aligned with the Haxe/Nim simple runtime scenes.
#include "rl.h"
#include "rl_color.h"
#include "rl_fileio.h"
#include "rl_logger.h"
#include "rl_music.h"
#include "rl_render.h"
#include "rl_window.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#ifdef PLATFORM_WEB
static const char *ASSET_HOST = "./";
#else
static const char *ASSET_HOST = "https://localhost:4444";
#endif

static const char *DEBUG_FONT_PATH =
    "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
static const char *KOMIKA_FONT_PATH = "assets/fonts/Komika/KOMIKAH_.ttf";
static const char *MODEL_PATH = "assets/models/gumshoe/gumshoe.glb";
static const char *SPRITE_PATH = "assets/sprites/logo/wg-logo-bw-alpha.png";
static const char *BGM_PATH = "assets/music/ethernight_club.mp3";
static const char *INITIAL_MESSAGE = "Hello from C Simple Main !";

enum {
  SCREEN_WIDTH = 1024,
  SCREEN_HEIGHT = 1280,
  SCREEN_FLAGS = RL_WINDOW_FLAG_MSAA_4X_HINT,
  DEBUG_FONT_SIZE = 18,
  KOMIKA_FONT_SIZE = 24,
  OVERLAY_TEXT_CAPACITY = 256,
};

typedef enum result_code_t {
  RESULT_OK = 0,
  RESULT_ERROR = -1,
  RESULT_QUIT = 1,
} result_code_t;

typedef struct app_context_t {
  float elapsed;
  float countdown_timer;
  float total_time;
  float sprite_y_offset;
  int reload_count;
  rl_handle_t debug_font;
  rl_handle_t komika_font;
  rl_handle_t sprite;
  rl_handle_t camera;
  rl_handle_t bgm;
  rl_handle_t grey_alpha_color;
  rl_handle_t gumshoe;
  rl_handle_t background_color;
  char message[OVERLAY_TEXT_CAPACITY];
  char platform_text[OVERLAY_TEXT_CAPACITY];
} app_context_t;

static app_context_t g_app_context = {0};

static void set_message(app_context_t *ctx, const char *text) {
  if (ctx == NULL) {
    return;
  }
  (void)snprintf(ctx->message, sizeof(ctx->message), "%s",
                 text != NULL ? text : "");
}

static void set_platform_text(app_context_t *ctx) {
  const char *platform = rl_get_platform();
  if (ctx == NULL) {
    return;
  }
  (void)snprintf(ctx->platform_text, sizeof(ctx->platform_text), "Platform: %s",
                 platform != NULL ? platform : "<unknown>");
}

static void on_import_bgm_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx == NULL) {
    return;
  }
  if (ctx->bgm != 0) {
    rl_music_destroy(ctx->bgm);
  }
  ctx->bgm = rl_music_create(path);
  (void)rl_music_set_loop(ctx->bgm, true);
  (void)rl_music_play(ctx->bgm);
}

static void on_import_model_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx == NULL) {
    return;
  }
  ctx->gumshoe = rl_model_create(path);
  (void)rl_model_set_animation(ctx->gumshoe, 1);
  (void)rl_model_set_animation_speed(ctx->gumshoe, 1.0f);
  (void)rl_model_set_animation_loop(ctx->gumshoe, true);
  (void)rl_model_set_transform(ctx->gumshoe, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                               0.0f, 1.0f, 1.0f, 1.0f);
}

static void on_import_sprite_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx == NULL) {
    return;
  }
  ctx->sprite = rl_sprite3d_create(path);
  (void)rl_sprite3d_set_transform(ctx->sprite, 0.0f, 0.0f, ctx->sprite_y_offset,
                                  1.0f);
}

static void on_import_debug_font_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx == NULL) {
    return;
  }
  ctx->debug_font = rl_font_create(path, DEBUG_FONT_SIZE);
}

static void on_import_komika_font_ready(const char *path, void *user_data) {
  app_context_t *ctx = (app_context_t *)user_data;
  if (ctx == NULL) {
    return;
  }
  ctx->komika_font = rl_font_create(path, KOMIKA_FONT_SIZE);
}

static void on_import_failed(const char *path, void *user_data) {
  (void)user_data;
  rl_logger_message_source(RL_LOGGER_LEVEL_ERROR, "example", 0,
                           "Failed to import asset: %s",
                           path != NULL ? path : "(null)");
}

static int import_asset_async(const char *path, rl_fileio_callback_fn on_success,
                              void *user_data) {
  rl_handle_t task = rl_fileio_ensure_async(path, NULL);
  if (task == 0) {
    on_import_failed(path, user_data);
    return -1;
  }
  if (rl_fileio_add_task(task, on_success, on_import_failed, user_data) != RL_FILEIO_ADD_TASK_OK) {
    rl_fileio_free(task);
    on_import_failed(path, user_data);
    return -1;
  }
  return 0;
}

static int queue_assets(app_context_t *ctx) {
  if (ctx == NULL) {
    return -1;
  }

  if (import_asset_async(BGM_PATH, on_import_bgm_ready, ctx) != 0) {
    return -1;
  }
  if (import_asset_async(MODEL_PATH, on_import_model_ready, ctx) != 0) {
    return -1;
  }
  if (import_asset_async(SPRITE_PATH, on_import_sprite_ready, ctx) != 0) {
    return -1;
  }
  if (import_asset_async(DEBUG_FONT_PATH, on_import_debug_font_ready, ctx) !=
      0) {
    return -1;
  }
  if (import_asset_async(KOMIKA_FONT_PATH, on_import_komika_font_ready, ctx) !=
      0) {
    return -1;
  }

  return 0;
}

static void animate_frame(app_context_t *ctx, float delta_time_sec) {
  float sprite_x = 0.0f;
  float sprite_y = 0.0f;
  float sprite_z = 0.0f;
  const float bob_speed = 1.0f;
  const float bob_height = 1.5f;

  if (ctx == NULL) {
    return;
  }

  if (ctx->gumshoe != 0) {
    (void)rl_model_animate(ctx->gumshoe, delta_time_sec);
  }

  if (ctx->sprite != 0) {
    float y = sinf(ctx->elapsed * bob_speed) * bob_height;
    sprite_y = y + ctx->sprite_y_offset;
    (void)rl_sprite3d_set_transform(ctx->sprite, sprite_x, sprite_y, sprite_z,
                                    1.0f);
  }
}

int rt_boot(void) {
  memset(&g_app_context, 0, sizeof(g_app_context));
  set_message(&g_app_context, INITIAL_MESSAGE);
  set_platform_text(&g_app_context);
  return RESULT_OK;
}

int rt_init(void *user_data) {
  app_context_t *ctx = &g_app_context;
  rl_init_config_t init_cfg;

  (void)user_data;

  ctx->elapsed = 0.0f;
  ctx->countdown_timer = 30.0f;
  ctx->total_time = 0.0f;
  ctx->sprite_y_offset = 3.0f;
  ctx->reload_count = 0;
  set_message(ctx, INITIAL_MESSAGE);
  set_platform_text(ctx);

  memset(&init_cfg, 0, sizeof(init_cfg));
  init_cfg.window_width = SCREEN_WIDTH;
  init_cfg.window_height = SCREEN_HEIGHT;
  init_cfg.window_title = "c-simple (C runtime)";
  init_cfg.window_flags = SCREEN_FLAGS;
  init_cfg.asset_host = ASSET_HOST;
  if (rl_init(&init_cfg) != 0) {
    return RESULT_ERROR;
  }

  rl_logger_set_level(RL_LOGGER_LEVEL_WARN);
  rl_set_target_fps(60);
  (void)rl_fileio_clear();

  rl_enable_lighting();
  rl_set_light_direction(-0.6f, -1.0f, -0.5f);
  rl_set_light_ambient(0.25f);

  ctx->camera =
      rl_camera3d_create(12.0f, 12.0f, 12.0f, 0.0f, 1.0f, 0.0f, 0.0f, 1.0f,
                         0.0f, 45.0f, 0);
  (void)rl_camera3d_set_active(ctx->camera);
  ctx->grey_alpha_color = rl_color_create(0, 0, 0, 128);
  ctx->background_color = rl_color_create(245, 245, 245, 255);

  if (queue_assets(ctx) != 0) {
    return RESULT_ERROR;
  }

  rl_render_begin();
  rl_render_clear_background(ctx->background_color);
  rl_render_end();

  return RESULT_OK;
}

int rt_tick(float host_dt) {
  app_context_t *ctx = &g_app_context;
  rl_tick_result_t tick_rc = rl_tick();
  rl_mouse_state_t mouse;
  char mouse_text[OVERLAY_TEXT_CAPACITY];
  char remaining_text[OVERLAY_TEXT_CAPACITY];
  char elapsed_text[OVERLAY_TEXT_CAPACITY];
  char reload_text[OVERLAY_TEXT_CAPACITY];

  if (tick_rc == RL_TICK_FAILED) {
    return RESULT_ERROR;
  }
  if (tick_rc == RL_TICK_WAITING) {
    return RESULT_OK;
  }
  if (rl_window_close_requested()) {
    return RESULT_QUIT;
  }

  ctx->elapsed += host_dt;
  ctx->countdown_timer -= host_dt;
  ctx->total_time += host_dt;

  animate_frame(ctx, host_dt);
  rl_music_update_all();

  mouse = rl_input_get_mouse_state();
  (void)snprintf(mouse_text, sizeof(mouse_text),
                 "Mouse: (%d, %d) w:%d b:[%d, %d, %d]", mouse.x, mouse.y,
                 mouse.wheel, mouse.left, mouse.right, mouse.middle);
  (void)snprintf(remaining_text, sizeof(remaining_text), "Remaining: %.2f",
                 ctx->countdown_timer);
  (void)snprintf(elapsed_text, sizeof(elapsed_text), "Elapsed: %.2f",
                 ctx->total_time);
  (void)snprintf(reload_text, sizeof(reload_text), "Reloads: %d",
                 ctx->reload_count);

  set_message(ctx, "Nothing picked!");
  if (ctx->gumshoe != 0) {
    rl_pick_result_t pick =
        rl_pick_model(ctx->camera, ctx->gumshoe, (float)mouse.x, (float)mouse.y);
    if (pick.hit) {
      (void)snprintf(ctx->message, sizeof(ctx->message),
                     "Model pick: Mouse position (mouse.x:%d, mouse.y:%d) pick "
                     "result y: %f",
                     mouse.x, mouse.y, pick.point.y);
    }
  }
  if (ctx->sprite != 0) {
    rl_pick_result_t pick = rl_pick_sprite3d(ctx->camera, ctx->sprite,
                                             (float)mouse.x, (float)mouse.y);
    if (pick.hit) {
      (void)snprintf(ctx->message, sizeof(ctx->message),
                     "Sprite pick: Mouse position (mouse.x:%d, mouse.y:%d) "
                     "pick result y: %f",
                     mouse.x, mouse.y, pick.point.y);
    }
  }

  rl_render_begin();
  rl_render_clear_background(ctx->background_color);

  rl_render_begin_mode_3d();
  if (ctx->gumshoe != 0) {
    rl_model_draw(ctx->gumshoe, RL_COLOR_RAYWHITE);
  }
  if (ctx->sprite != 0) {
    rl_sprite3d_draw(ctx->sprite, RL_COLOR_RAYWHITE);
  }
  rl_render_end_mode_3d();

  {
    vec2_t screen = rl_window_get_screen_size();
    if (ctx->komika_font != 0) {
      vec2_t text_size = rl_text_measure_ex(ctx->komika_font, ctx->message,
                                            (float)KOMIKA_FONT_SIZE, 1.0f);
      int text_x = (int)((screen.x - text_size.x) / 2.0f);
      int text_y = (int)((screen.y - text_size.y) / 2.0f);
      rl_text_draw_ex(ctx->komika_font, ctx->message, text_x, text_y,
                      (float)KOMIKA_FONT_SIZE, 1.0f, RL_COLOR_BLUE);
    } else {
      int text_width = rl_text_measure(ctx->message, KOMIKA_FONT_SIZE);
      int text_x = (int)((screen.x - (float)text_width) / 2.0f);
      int text_y = (int)((screen.y - (float)KOMIKA_FONT_SIZE) / 2.0f);
      rl_text_draw(ctx->message, text_x, text_y, KOMIKA_FONT_SIZE,
                   RL_COLOR_BLUE);
    }
  }

  if (ctx->debug_font != 0) {
    rl_text_draw_ex(ctx->debug_font, remaining_text, 10, 36,
                    (float)DEBUG_FONT_SIZE, 1.0f, RL_COLOR_BLACK);
    rl_text_draw_ex(ctx->debug_font, elapsed_text, 10, 56,
                    (float)DEBUG_FONT_SIZE, 1.0f, RL_COLOR_BLACK);
    rl_text_draw_ex(ctx->debug_font, mouse_text, 10, 76,
                    (float)DEBUG_FONT_SIZE, 1.0f, RL_COLOR_BLACK);
    rl_text_draw_ex(ctx->debug_font, reload_text, 10, 96,
                    (float)DEBUG_FONT_SIZE, 1.0f, RL_COLOR_BLACK);
    rl_text_draw_ex(ctx->debug_font, ctx->platform_text, 10, 116,
                    (float)DEBUG_FONT_SIZE, 1.0f, RL_COLOR_BLACK);
    rl_text_draw_fps_ex(ctx->debug_font, 10, 10, (float)DEBUG_FONT_SIZE,
                        ctx->grey_alpha_color);
  } else {
    rl_text_draw(remaining_text, 10, 36, DEBUG_FONT_SIZE, RL_COLOR_BLACK);
    rl_text_draw(elapsed_text, 10, 56, DEBUG_FONT_SIZE, RL_COLOR_BLACK);
    rl_text_draw(mouse_text, 10, 76, DEBUG_FONT_SIZE, RL_COLOR_BLACK);
    rl_text_draw(reload_text, 10, 96, DEBUG_FONT_SIZE, RL_COLOR_BLACK);
    rl_text_draw(ctx->platform_text, 10, 116, DEBUG_FONT_SIZE,
                 RL_COLOR_BLACK);
    rl_text_draw_fps(10, 10);
  }

  rl_render_end();
  return RESULT_OK;
}

void rt_shutdown(void) {
  app_context_t *ctx = &g_app_context;
  rl_deinit();
  memset(ctx, 0, sizeof(*ctx));
}

#ifdef PLATFORM_WEB
int main(void) {
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
  int rc = RESULT_OK;
  double last_time = 0.0;

  if (rt_boot() != RESULT_OK) {
    return RESULT_ERROR;
  }
  if (rt_init(NULL) != RESULT_OK) {
    rt_shutdown();
    return RESULT_ERROR;
  }

  last_time = now_seconds();
  for (;;) {
    double current_time = now_seconds();
    float dt_seconds = (float)(current_time - last_time);
    last_time = current_time;

    rc = rt_tick(dt_seconds);
    if (rc != RESULT_OK) {
      rt_shutdown();
      return rc;
    }
    usleep(1000);
  }
}
#endif
