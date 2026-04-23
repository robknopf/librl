#include "rl.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_frame_command.h"
#include "rl_input.h"
#include "rl_loader.h"
#include "rl_logger.h"
#include "rl_protocol.h"
#include "rl_text.h"
#include "rl_window.h"
#include "rl_ws_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef PLATFORM_WEB
static const char *ASSET_HOST = "./";
#else
static const char *ASSET_HOST = "https://localhost:4444";
#endif

typedef struct remote_context_t {
  rl_ws_client_t *ws_client;
  rl_ws_frame_data_t current_frame;
  bool has_frame;
  int frames_received;
  int frames_rendered;
  rl_handle_t overlay_font;
  int overlay_font_size;
} remote_context_t;

static remote_context_t g_remote_context = {0};

// char *debug_font_path = "assets/fonts/Komika/KOMIKAH_.ttf";
char *debug_font_path = "assets/fonts/JetBrainsMono/JetBrainsMono-Regular.ttf";
char *overlay_font_path = "assets/fonts/JetBrainsMono/JetBrainsMono-Bold.ttf";

#define REMOTE_DEFAULT_HOST "localhost"
#define REMOTE_DEFAULT_PORT "9001"
#define REMOTE_DEFAULT_PROTOCOL "wss"
#define REMOTE_DEFAULT_WS_PATH "/ws"

static const char *get_remote_ws_url(void) {
  static char ws_url[256] = {0};
  const char *protocol = getenv("RL_REMOTE_WS_PROTOCOL");
  const char *host = getenv("RL_REMOTE_WS_HOST");
  const char *port = getenv("RL_REMOTE_WS_PORT");

  if (protocol == NULL || protocol[0] == '\0') {
    protocol = REMOTE_DEFAULT_PROTOCOL;
  }
  if (host == NULL || host[0] == '\0') {
    host = REMOTE_DEFAULT_HOST;
  }
  if (port == NULL || port[0] == '\0') {
    port = REMOTE_DEFAULT_PORT;
  }

  snprintf(ws_url, sizeof(ws_url), "%s://%s:%s%s", protocol, host, port,
           REMOTE_DEFAULT_WS_PATH);

  return ws_url;
}

static void on_debug_font_ready(const char *path, void *user_data) {
  (void)user_data;
  rl_debug_enable_fps(10, 10, 24, path);
}

static void on_overlay_font_ready(const char *path, void *user_data) {
  remote_context_t *ctx = (remote_context_t *)user_data;
  ctx->overlay_font = rl_font_create(path, ctx->overlay_font_size);
}

static void on_init(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;
  const char *ws_url = get_remote_ws_url();
  rl_loader_queue_task_result_t loader_rc = RL_LOADER_QUEUE_TASK_OK;

  if (context == NULL) {
    return;
  }

  rl_set_target_fps(60);

  // In init:
  loader_rc =
      rl_loader_queue_task(rl_loader_import_asset_async(debug_font_path),
                         debug_font_path, on_debug_font_ready, NULL, NULL);
  if (loader_rc != RL_LOADER_QUEUE_TASK_OK) {
    log_error("[Remote] Failed to queue debug font load (%d)", loader_rc);
  }

  log_info("[Remote] Initializing...");

  log_info("[Remote] Connecting to %s", ws_url);

  context->ws_client = rl_ws_client_create(ws_url);
  if (context->ws_client == NULL) {
    log_error("[Remote] Failed to create websocket client");
    rl_stop();
    return;
  }

  context->has_frame = false;
  context->frames_received = 0;
  context->frames_rendered = 0;

  context->overlay_font = 0;
  context->overlay_font_size = 24;
  loader_rc = rl_loader_queue_task(
      rl_loader_import_asset_async(overlay_font_path), overlay_font_path,
      on_overlay_font_ready, NULL, context);
  if (loader_rc != RL_LOADER_QUEUE_TASK_OK) {
    log_error("[Remote] Failed to queue overlay font load (%d)", loader_rc);
  }
}

static void on_shutdown(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;

  if (context == NULL) {
    return;
  }

  log_info("[Remote] Shutting down...");
  log_debug("[Remote] Frames received: %d, rendered: %d",
            context->frames_received, context->frames_rendered);

  if (context->ws_client != NULL) {
    rl_ws_client_destroy(context->ws_client);
    context->ws_client = NULL;
  }

  if (context->overlay_font != 0) {
    rl_font_destroy(context->overlay_font);
    context->overlay_font = 0;
  }

  rl_deinit();
}

static void draw_status_overlay(remote_context_t *context,
                                const char *message) {
  vec2_t screen = rl_window_get_screen_size();
  int title_font_size = 36;
  int body_font_size = 24;
  int title_width = rl_text_measure("Remote Client", title_font_size);
  int body_width = rl_text_measure(message, body_font_size);
  int center_x = (int)(screen.x * 0.5f);
  int center_y = (int)(screen.y * 0.5f);

  rl_text_draw("Remote Client", center_x - (title_width / 2), center_y - 48,
               title_font_size, RL_COLOR_DARKGRAY);
  rl_text_draw(message, center_x - (body_width / 2), center_y + 8,
               body_font_size, RL_COLOR_GRAY);

  if (context->overlay_font != 0 && context->ws_client != NULL) {
    char stats_buf[128];
    rl_ws_bandwidth_stats_t bw =
        rl_ws_client_get_bandwidth_stats(context->ws_client);
    vec2_t text_size;

    snprintf(stats_buf, sizeof(stats_buf), "in: %.1f kb/s  out: %.1f kb/s",
             bw.bytes_in_per_sec / 1024.0f, bw.bytes_out_per_sec / 1024.0f);
    text_size = rl_text_measure_ex(context->overlay_font, stats_buf,
                                   context->overlay_font_size, 1.0f);
    rl_text_draw_ex(context->overlay_font, stats_buf,
                    (int)(screen.x - text_size.x - 10), 10,
                    context->overlay_font_size, 1.0f, RL_COLOR_DARKGRAY);
  }
}

static void on_tick(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;
  static rl_resource_response_t responses[RL_WS_MAX_PENDING_RESPONSES];
  static rl_pick_response_t pick_responses[RL_PROTOCOL_MAX_PICK_RESPONSES];
  int response_count = 0;
  int pick_response_count = 0;
  bool is_connected = false;
  rl_mouse_state_t mouse_state = {0};
  rl_keyboard_state_t keyboard_state = {0};
  vec2_t screen_size = {0};

  if (context == NULL) {
    return;
  }

  if (context->ws_client == NULL) {
    return;
  }

  rl_ws_client_tick(context->ws_client);

  rl_ws_client_poll(context->ws_client);

  mouse_state = rl_input_get_mouse_state();
  keyboard_state = rl_input_get_keyboard_state();
  screen_size = rl_window_get_screen_size();
  rl_ws_client_send_input_state(context->ws_client, &mouse_state,
                                &keyboard_state, (int)screen_size.x,
                                (int)screen_size.y);

  response_count = rl_ws_client_get_pending_responses(
      context->ws_client, responses, RL_WS_MAX_PENDING_RESPONSES);
  if (response_count > 0) {
    rl_ws_client_send_responses(context->ws_client, responses, response_count);
  }

  pick_response_count = rl_ws_client_get_pending_pick_responses(
      context->ws_client, pick_responses, RL_PROTOCOL_MAX_PICK_RESPONSES);
  if (pick_response_count > 0) {
    rl_ws_client_send_pick_responses(context->ws_client, pick_responses,
                                     pick_response_count);
  }

  // Poll async resource loads (fonts, textures, models, etc.)
  response_count = rl_ws_client_poll_resource_loads(
      context->ws_client, responses, RL_WS_MAX_PENDING_RESPONSES);
  if (response_count > 0) {
    rl_ws_client_send_responses(context->ws_client, responses, response_count);
  }

  is_connected = rl_ws_client_is_connected(context->ws_client);

  if (is_connected && rl_ws_client_has_frame(context->ws_client)) {
    if (rl_ws_client_get_frame(context->ws_client, &context->current_frame)) {
      context->has_frame = true;
      context->frames_received++;
    }
  }

  rl_render_begin();

  if (!is_connected) {
    rl_render_clear_background(RL_COLOR_LIGHTGRAY);
    draw_status_overlay(context, "Waiting for remote server...");
  } else if (!context->has_frame ||
             context->current_frame.commands.count == 0) {
    rl_render_clear_background(RL_COLOR_LIGHTGRAY);
    draw_status_overlay(context, "Connected. Waiting for first frame...");
  } else {
    rl_frame_commands_execute_clear(&context->current_frame.commands);
    rl_frame_commands_execute_audio(&context->current_frame.commands);
    rl_frame_commands_execute_state(&context->current_frame.commands);

    rl_render_begin_mode_3d();
    rl_frame_commands_execute_3d(&context->current_frame.commands);
    rl_render_end_mode_3d();

    rl_frame_commands_execute_2d(&context->current_frame.commands);

    if (context->overlay_font != 0) {
      char stats_buf[128];
      rl_ws_bandwidth_stats_t bw =
          rl_ws_client_get_bandwidth_stats(context->ws_client);
      vec2_t screen = rl_window_get_screen_size();
      vec2_t text_size;

      snprintf(stats_buf, sizeof(stats_buf), "in: %.1f kb/s  out: %.1f kb/s",
               bw.bytes_in_per_sec / 1024.0f, bw.bytes_out_per_sec / 1024.0f);
      text_size = rl_text_measure_ex(context->overlay_font, stats_buf,
                                     context->overlay_font_size, 1.0f);
      rl_text_draw_ex(context->overlay_font, stats_buf,
                      (int)(screen.x - text_size.x - 10), 10,
                      context->overlay_font_size, 1.0f, RL_COLOR_DARKGRAY);
    }
  }

  rl_render_end();
  context->frames_rendered++;
}

int main(void) {
  rl_init_config_t init_cfg;
  memset(&init_cfg, 0, sizeof(init_cfg));
  init_cfg.window_width = 1024;
  init_cfg.window_height = 1280;
  init_cfg.window_title = "librl Remote Client";
  init_cfg.window_flags = RL_WINDOW_FLAG_MSAA_4X_HINT;
  init_cfg.asset_host = ASSET_HOST;
  if (rl_init(&init_cfg) != 0) {
    return 1;
  }
  rl_run(on_init, on_tick, on_shutdown, &g_remote_context);
  return 0;
}
