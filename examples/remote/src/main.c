#include "rl.h"
#include "rl_window.h"
#include "rl_frame_runner.h"
#include "rl_frame_commands.h"
#include "rl_ws_client.h"
#include "rl_resource_registry.h"
#include "rl_color.h"
#include "rl_font.h"
#include "rl_loader.h"
#include "rl_text.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct remote_context_t {
  rl_ws_client_t *ws_client;
  rl_ws_frame_data_t current_frame;
  rl_resource_registry_t *resource_registry;
  bool has_frame;
  int frames_received;
  int frames_rendered;
  rl_handle_t overlay_font;
  rl_handle_t overlay_color;
} remote_context_t;

static remote_context_t g_remote_context = {0};

char* debug_font_path = "assets/fonts/Komika/KOMIKAH_.ttf";

static void on_debug_font_ready(const char *path, void *user_data) {
    (void)user_data;
    rl_debug_enable_fps(10, 10, 16, path);
}

static void on_overlay_font_ready(const char *path, void *user_data) {
    remote_context_t *ctx = (remote_context_t *)user_data;
    ctx->overlay_font = rl_font_create(path, 18.0f);
}

static void on_init(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;
  const char *ws_url = "ws://localhost:9001/ws";
  
  if (context == NULL) {
    return;
  }
  
  rl_window_init(1024, 1280, "librl Remote Client", RL_WINDOW_FLAG_MSAA_4X_HINT);
  rl_frame_runner_set_target_fps(60);

// In init:
rl_loader_add_task(
    rl_loader_import_asset_async(debug_font_path),
    debug_font_path,
    on_debug_font_ready, NULL, NULL);

  printf("[Remote] Initializing...\n");
  
  context->resource_registry = rl_resource_registry_create();
  if (context->resource_registry == NULL) {
    printf("[Remote] Failed to create resource registry\n");
    rl_frame_runner_request_stop();
    return;
  }
  
  printf("[Remote] Connecting to %s\n", ws_url);
  
  context->ws_client = rl_ws_client_create(ws_url);
  if (context->ws_client == NULL) {
    printf("[Remote] Failed to create websocket client\n");
    rl_resource_registry_destroy(context->resource_registry);
    rl_frame_runner_request_stop();
    return;
  }
  
  context->has_frame = false;
  context->frames_received = 0;
  context->frames_rendered = 0;
  
  context->overlay_font = 0;
  rl_loader_add_task(
      rl_loader_import_asset_async(debug_font_path),
      debug_font_path,
      on_overlay_font_ready, NULL, context);
  context->overlay_color = rl_color_create(80, 80, 80, 255);
}

static void on_shutdown(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;
  
  if (context == NULL) {
    return;
  }
  
  printf("[Remote] Shutting down...\n");
  printf("[Remote] Frames received: %d, rendered: %d\n", 
         context->frames_received, context->frames_rendered);
  
  if (context->ws_client != NULL) {
    rl_ws_client_destroy(context->ws_client);
    context->ws_client = NULL;
  }
  
  if (context->resource_registry != NULL) {
    rl_resource_registry_destroy(context->resource_registry);
    context->resource_registry = NULL;
  }
  
  rl_window_close();
}

static void on_tick(void *user_data) {
  remote_context_t *context = (remote_context_t *)user_data;
  static rl_resource_response_t responses[RL_WS_MAX_PENDING_RESPONSES];
  int response_count = 0;
  
  if (context == NULL) {
    return;
  }
  
  if (context->ws_client == NULL) {
    return;
  }
  
  rl_ws_client_tick(context->ws_client);
  
  rl_ws_client_poll(context->ws_client);
  
  response_count = rl_ws_client_get_pending_responses(context->ws_client, responses, RL_WS_MAX_PENDING_RESPONSES);
  if (response_count > 0) {
    rl_ws_client_send_responses(context->ws_client, responses, response_count);
  }
  
  // Poll async resource loads (fonts, textures, models, etc.)
  response_count = rl_ws_client_poll_resource_loads(context->ws_client, responses, RL_WS_MAX_PENDING_RESPONSES);
  if (response_count > 0) {
    rl_ws_client_send_responses(context->ws_client, responses, response_count);
  }
  
  if (!rl_ws_client_is_connected(context->ws_client)) {
    return;
  }
  
  if (rl_ws_client_has_frame(context->ws_client)) {
    if (rl_ws_client_get_frame(context->ws_client, &context->current_frame)) {
      context->has_frame = true;
      context->frames_received++;
    }
  }
  
  if (!context->has_frame || context->current_frame.commands.count == 0) {
    return;
  }
  rl_frame_begin();
  rl_frame_commands_execute_clear(&context->current_frame.commands);
  
  rl_begin_mode_3d();
  rl_frame_commands_execute_3d(&context->current_frame.commands);
  rl_end_mode_3d();
  
  rl_frame_commands_execute_2d(&context->current_frame.commands);
  
  // Draw local overlay (bandwidth stats)
  if (context->overlay_font != 0) {
    char stats_buf[128];
    rl_ws_bandwidth_stats_t bw = rl_ws_client_get_bandwidth_stats(context->ws_client);
    vec2_t screen = rl_window_get_screen_size();
    
    snprintf(stats_buf, sizeof(stats_buf), "in: %.1f kb/s  out: %.1f kb/s",
             bw.bytes_in_per_sec / 1024.0f, bw.bytes_out_per_sec / 1024.0f);
    vec2_t text_size = rl_text_measure_ex(context->overlay_font, stats_buf, 16.0f, 1.0f);
    rl_text_draw_ex(context->overlay_font, stats_buf, (int)(screen.x - text_size.x - 10), 10, 16.0f, 1.0f, context->overlay_color);
  }
  
  rl_frame_end();
  context->frames_rendered++;
}

int main(void) {
  rl_init();
  rl_frame_runner_run(on_init, on_tick, on_shutdown, &g_remote_context);
  return 0;
}
