#include "rl_ws_client.h"
#include "rl_protocol.h"
#include "rl_resource_handler.h"
#include "websocket/websocket.h"
#include "rl_logger.h"
#include "rl_render.h"
#include "rl_music.h"
#include "rl_pick.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_MESSAGE_SIZE (1024 * 64)

struct rl_ws_client_t {
  websocket_t *ws;
  char url[256];
  bool is_building_frame;
  bool has_pending_frame;
  rl_ws_frame_data_t building_frame;
  rl_ws_frame_data_t ready_frame;
  char message_buffer[MAX_MESSAGE_SIZE];
  rl_resource_response_t pending_responses[RL_WS_MAX_PENDING_RESPONSES];
  int pending_response_count;
  rl_pick_response_t pending_pick_responses[RL_PROTOCOL_MAX_PICK_RESPONSES];
  int pending_pick_response_count;
  double last_reconnect_attempt;
  double reconnect_delay;
  rl_resource_handler_t resource_handler;
  size_t bytes_in_accum;
  size_t bytes_out_accum;
  double stats_timer;
  rl_ws_bandwidth_stats_t bandwidth_stats;
};

static void process_ws_open(rl_ws_client_t *client) {
  log_info("[WS] Connected to %s", client->url);
}

static void process_ws_error(rl_ws_client_t *client) {
  log_error("[WS] Error on %s. Will attempt to reconnect...", client->url);
  client->reconnect_delay = 1.0;
}

static void process_ws_close(rl_ws_client_t *client, int code, const char *reason) {
  log_info("[WS] Closed: code=%d, reason=%s. Will attempt to reconnect...", code, reason);
  client->reconnect_delay = 1.0;
}

static void process_ws_message(rl_ws_client_t *client, const char *data, int len, bool is_text) {
  rl_ws_frame_data_t parsed_frame = {0};
  static rl_protocol_requests_t requests;
  static rl_protocol_pick_requests_t pick_requests;
  rl_protocol_message_type_t message_type = RL_PROTOCOL_MESSAGE_UNKNOWN;
  bool has_frame = false;
  int i = 0;

  if (!is_text || len >= MAX_MESSAGE_SIZE) {
    return;
  }

  client->bytes_in_accum += (size_t)len;

  memcpy(client->message_buffer, data, (size_t)len);
  client->message_buffer[len] = '\0';

  if (rl_protocol_parse_message(client->message_buffer, len,
                                &message_type,
                                &parsed_frame, &has_frame,
                                &requests,
                                &pick_requests) != 0) {
    log_error("[WS] Failed to parse message");
    return;
  }

  if (message_type == RL_PROTOCOL_MESSAGE_FRAME_BEGIN && has_frame) {
    memset(&client->building_frame, 0, sizeof(client->building_frame));
    client->building_frame.frame_number = parsed_frame.frame_number;
    client->building_frame.delta_time = parsed_frame.delta_time;
    client->is_building_frame = true;
  }

  if (message_type == RL_PROTOCOL_MESSAGE_FRAME_CHUNK && has_frame) {
    int remaining_capacity = 0;
    int copy_count = 0;

    if (!client->is_building_frame) {
      log_warn("[WS] Received frame chunk without frame begin");
      return;
    }

    rl_resource_handler_resolve_frame_commands(&client->resource_handler,
                                               &parsed_frame.commands);

    remaining_capacity =
        RL_FRAME_COMMAND_CAPACITY - client->building_frame.commands.count;
    copy_count = parsed_frame.commands.count;
    if (copy_count > remaining_capacity) {
      copy_count = remaining_capacity;
      log_warn("[WS] Truncated frame chunk to fit command capacity");
    }

    if (copy_count > 0) {
      memcpy(&client->building_frame.commands.commands[client->building_frame.commands.count],
             parsed_frame.commands.commands,
             (size_t)copy_count * sizeof(rl_render_command_t));
      client->building_frame.commands.count += copy_count;
    }
  }

  if (message_type == RL_PROTOCOL_MESSAGE_FRAME_END) {
    if (!client->is_building_frame) {
      log_warn("[WS] Received frame end without frame begin");
      return;
    }
    memcpy(&client->ready_frame, &client->building_frame, sizeof(client->ready_frame));
    client->has_pending_frame = true;
    client->is_building_frame = false;
  }

  if (message_type == RL_PROTOCOL_MESSAGE_RESOURCE_REQUESTS && requests.count > 0) {
    int response_count = rl_resource_handler_process_requests(
        &client->resource_handler,
        requests.items,
        requests.count,
        client->pending_responses + client->pending_response_count,
        RL_WS_MAX_PENDING_RESPONSES - client->pending_response_count);

    if (response_count >= 0 &&
        client->pending_response_count + response_count <= RL_WS_MAX_PENDING_RESPONSES) {
      client->pending_response_count += response_count;

      if (response_count > 0) {
        log_debug("[WS] Processed %d resource requests", response_count);
      }
    }
  }

  if (message_type == RL_PROTOCOL_MESSAGE_PICK_REQUESTS && pick_requests.count > 0) {
    rl_resource_handler_resolve_pick_requests(&client->resource_handler, &pick_requests);
    int base_count = client->pending_pick_response_count;

    for (i = 0; i < pick_requests.count &&
                client->pending_pick_response_count < RL_PROTOCOL_MAX_PICK_RESPONSES; i++) {
      const rl_pick_request_t *request = &pick_requests.items[i];
      rl_pick_response_t *response =
          &client->pending_pick_responses[client->pending_pick_response_count];

      memset(response, 0, sizeof(*response));
      response->rid = request->rid;

      switch (request->type) {
        case RL_PICK_REQUEST_MODEL: {
          rl_pick_result_t pick = rl_pick_model(request->data.model.camera,
                                                request->data.model.handle,
                                                request->data.model.mouse_x,
                                                request->data.model.mouse_y,
                                                request->data.model.x,
                                                request->data.model.y,
                                                request->data.model.z,
                                                request->data.model.scale,
                                                request->data.model.rotation_x,
                                                request->data.model.rotation_y,
                                                request->data.model.rotation_z);
          response->hit = pick.hit;
          response->distance = pick.distance;
          response->point = pick.point;
          response->normal = pick.normal;
          client->pending_pick_response_count++;
          break;
        }

        case RL_PICK_REQUEST_SPRITE3D: {
          rl_pick_result_t pick = rl_pick_sprite3d(request->data.sprite3d.camera,
                                                   request->data.sprite3d.handle,
                                                   request->data.sprite3d.mouse_x,
                                                   request->data.sprite3d.mouse_y,
                                                   request->data.sprite3d.x,
                                                   request->data.sprite3d.y,
                                                   request->data.sprite3d.z,
                                                   request->data.sprite3d.size);
          response->hit = pick.hit;
          response->distance = pick.distance;
          response->point = pick.point;
          response->normal = pick.normal;
          client->pending_pick_response_count++;
          break;
        }

        default:
          break;
      }
    }

    if (client->pending_pick_response_count > base_count) {
      log_debug("[WS] Processed %d pick requests",
                client->pending_pick_response_count - base_count);
    }
  }

  if (message_type == RL_PROTOCOL_MESSAGE_RESET) {
    log_info("[WS] Resetting remote client state");
    client->is_building_frame = false;
    client->has_pending_frame = false;
    memset(&client->building_frame, 0, sizeof(client->building_frame));
    memset(&client->ready_frame, 0, sizeof(client->ready_frame));
    client->pending_response_count = 0;
    client->pending_pick_response_count = 0;
    rl_resource_handler_reset(&client->resource_handler);
  }
}

static void on_ws_open(websocket_t *ws, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)ws;
  process_ws_open(client);
}

static void on_ws_error(websocket_t *ws, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)ws;
  process_ws_error(client);
}

static void on_ws_close(websocket_t *ws, int code, const char *reason, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)ws;
  process_ws_close(client, code, reason);
}

static void on_ws_message(websocket_t *ws, const char *data, int len, bool is_text, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)ws;
  process_ws_message(client, data, len, is_text);
}

static const websocket_callbacks_t ws_callbacks = {
  on_ws_open,
  on_ws_close,
  on_ws_error,
  on_ws_message
};


rl_ws_client_t *rl_ws_client_create(const char *url) {
  rl_ws_client_t *client = NULL;
  
  if (url == NULL) {
    return NULL;
  }
  
  client = (rl_ws_client_t *)calloc(1, sizeof(rl_ws_client_t));
  if (client == NULL) {
    return NULL;
  }
  
  snprintf(client->url, sizeof(client->url), "%s", url);
  client->is_building_frame = false;
  client->has_pending_frame = false;
  client->pending_response_count = 0;
  client->pending_pick_response_count = 0;
  client->last_reconnect_attempt = 0.0;
  client->reconnect_delay = 1.0;
  rl_resource_handler_init(&client->resource_handler);
  
  client->ws = websocket_create(url, &ws_callbacks, client);
  if (client->ws == NULL) {
    log_error("[WS] Failed to create websocket");
    free(client);
    return NULL;
  }
  
  log_info("[WS] Connecting to %s...", url);
  return client;
}

void rl_ws_client_destroy(rl_ws_client_t *client) {
  if (client == NULL) {
    return;
  }
  
  rl_resource_handler_cleanup(&client->resource_handler);
  websocket_destroy(client->ws);
  free(client);
}

bool rl_ws_client_is_connected(const rl_ws_client_t *client) {
  if (client == NULL || client->ws == NULL) {
    return false;
  }
  return websocket_is_connected(client->ws);
}

void rl_ws_client_poll(rl_ws_client_t *client) {
  if (client == NULL || client->ws == NULL) {
    return;
  }
  websocket_poll(client->ws);
}

bool rl_ws_client_has_frame(const rl_ws_client_t *client) {
  if (client == NULL) {
    return false;
  }
  return client->has_pending_frame;
}

bool rl_ws_client_get_frame(rl_ws_client_t *client, rl_ws_frame_data_t *out_frame) {
  if (client == NULL || out_frame == NULL || !client->has_pending_frame) {
    return false;
  }
  
  memcpy(out_frame, &client->ready_frame, sizeof(rl_ws_frame_data_t));
  client->has_pending_frame = false;
  return true;
}

int rl_ws_client_poll_resource_loads(rl_ws_client_t *client,
                                      rl_resource_response_t *responses,
                                      int max_responses) {
  if (client == NULL || responses == NULL || max_responses <= 0) {
    return 0;
  }
  return rl_resource_handler_poll(&client->resource_handler, responses, max_responses);
}

int rl_ws_client_get_pending_responses(rl_ws_client_t *client, 
                                       rl_resource_response_t *responses,
                                       int max_responses) {
  int count = 0;
  int i = 0;
  
  if (client == NULL || responses == NULL || max_responses <= 0) {
    return 0;
  }
  
  count = client->pending_response_count;
  if (count > max_responses) {
    count = max_responses;
  }
  
  if (count > 0 && count <= RL_WS_MAX_PENDING_RESPONSES) {
    for (i = 0; i < count; i++) {
      responses[i] = client->pending_responses[i];
    }
    client->pending_response_count = 0;
  }
  
  return count;
}

void rl_ws_client_send_responses(rl_ws_client_t *client,
                                 const rl_resource_response_t *responses,
                                 int count) {
  char send_buf[MAX_MESSAGE_SIZE];
  int len = 0;
  
  if (client == NULL || responses == NULL || count <= 0) {
    return;
  }
  
  if (!websocket_is_connected(client->ws)) {
    log_warn("[WS] Cannot send responses: not connected");
    return;
  }
  
  len = rl_protocol_serialize_responses(responses, count, send_buf, MAX_MESSAGE_SIZE);
  if (len > 0) {
    log_debug("[WS] Sending %d resource responses", count);
    if (websocket_send_text(client->ws, send_buf) != 0) {
      log_warn("[WS] Failed to send responses");
    } else {
      log_debug("[WS] Responses sent successfully");
    }
    client->bytes_out_accum += (size_t)len;
  }
}

void rl_ws_client_send_input_state(rl_ws_client_t *client,
                                   const rl_mouse_state_t *mouse,
                                   const rl_keyboard_state_t *keyboard,
                                   int screen_width,
                                   int screen_height) {
  char send_buf[MAX_MESSAGE_SIZE];
  int len = 0;

  if (client == NULL || mouse == NULL || keyboard == NULL || client->ws == NULL) {
    return;
  }

  if (!websocket_is_connected(client->ws)) {
    return;
  }

  len = rl_protocol_serialize_input_state(mouse, keyboard, screen_width, screen_height,
                                          send_buf, MAX_MESSAGE_SIZE);
  if (len <= 0) {
    log_warn("[WS] Failed to serialize input state");
    return;
  }

  if (websocket_send_text(client->ws, send_buf) != 0) {
    log_warn("[WS] Failed to send input state");
    return;
  }

  client->bytes_out_accum += (size_t)len;
}

int rl_ws_client_get_pending_pick_responses(rl_ws_client_t *client,
                                            rl_pick_response_t *responses,
                                            int max_responses) {
  int count = 0;
  int i = 0;

  if (client == NULL || responses == NULL || max_responses <= 0) {
    return 0;
  }

  count = client->pending_pick_response_count;
  if (count > max_responses) {
    count = max_responses;
  }

  for (i = 0; i < count; i++) {
    responses[i] = client->pending_pick_responses[i];
  }
  client->pending_pick_response_count = 0;

  return count;
}

void rl_ws_client_send_pick_responses(rl_ws_client_t *client,
                                      const rl_pick_response_t *responses,
                                      int count) {
  char send_buf[MAX_MESSAGE_SIZE];
  int len = 0;

  if (client == NULL || responses == NULL || count <= 0 || client->ws == NULL) {
    return;
  }

  if (!websocket_is_connected(client->ws)) {
    return;
  }

  len = rl_protocol_serialize_pick_responses(responses, count, send_buf, MAX_MESSAGE_SIZE);
  if (len <= 0) {
    log_warn("[WS] Failed to serialize pick responses");
    return;
  }

  if (websocket_send_text(client->ws, send_buf) != 0) {
    log_warn("[WS] Failed to send pick responses");
    return;
  }

  client->bytes_out_accum += (size_t)len;
}

void rl_ws_client_tick(rl_ws_client_t *client) {
  double now = 0.0;
  
  if (client == NULL) {
    return;
  }
  
  now = rl_render_get_time();
  
  if (client->stats_timer == 0.0) {
    client->stats_timer = now;
  } else if (now - client->stats_timer >= 1.0) {
    double elapsed = now - client->stats_timer;
    client->bandwidth_stats.bytes_in_per_sec = (float)((double)client->bytes_in_accum / elapsed);
    client->bandwidth_stats.bytes_out_per_sec = (float)((double)client->bytes_out_accum / elapsed);
    client->bytes_in_accum = 0;
    client->bytes_out_accum = 0;
    client->stats_timer = now;
  }
  
  if (!websocket_is_connected(client->ws)) {
    if (now - client->last_reconnect_attempt >= client->reconnect_delay) {
      log_info("[WS] Attempting to reconnect to %s...", client->url);
      client->last_reconnect_attempt = now;
      
      websocket_destroy(client->ws);
      client->ws = websocket_create(client->url, &ws_callbacks, client);
      
      if (client->ws != NULL) {
        client->reconnect_delay = 1.0;
      } else {
        client->reconnect_delay *= 2.0;
        if (client->reconnect_delay > 30.0) {
          client->reconnect_delay = 30.0;
        }
        log_warn("[WS] Reconnect failed. Next attempt in %.1f seconds", client->reconnect_delay);
      }
    }
  }
}

rl_ws_bandwidth_stats_t rl_ws_client_get_bandwidth_stats(const rl_ws_client_t *client) {
  rl_ws_bandwidth_stats_t empty = {0};
  if (client == NULL) {
    return empty;
  }
  return client->bandwidth_stats;
}
