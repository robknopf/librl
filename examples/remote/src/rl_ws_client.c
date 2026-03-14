#include "rl_ws_client.h"
#include "rl_protocol.h"
#include "rl_resource_handler.h"
#include "websocket/websocket.h"
#include "rl_logger.h"
#include "rl_frame.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_MESSAGE_SIZE (1024 * 64)

struct rl_ws_client_t {
  websocket_t *ws;
  char url[256];
  bool has_pending_frame;
  rl_ws_frame_data_t pending_frame;
  char message_buffer[MAX_MESSAGE_SIZE];
  rl_resource_response_t pending_responses[RL_WS_MAX_PENDING_RESPONSES];
  int pending_response_count;
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
  static rl_protocol_requests_t requests;
  rl_protocol_message_type_t message_type = RL_PROTOCOL_MESSAGE_UNKNOWN;
  bool has_frame = false;

  if (!is_text || len >= MAX_MESSAGE_SIZE) {
    return;
  }

  client->bytes_in_accum += (size_t)len;

  memcpy(client->message_buffer, data, (size_t)len);
  client->message_buffer[len] = '\0';

  if (rl_protocol_parse_message(client->message_buffer, len,
                                &message_type,
                                &client->pending_frame, &has_frame,
                                &requests) != 0) {
    log_error("[WS] Failed to parse message");
    return;
  }

  if (message_type == RL_PROTOCOL_MESSAGE_FRAME && has_frame) {
    client->has_pending_frame = true;
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
  client->has_pending_frame = false;
  client->pending_response_count = 0;
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
  
  memcpy(out_frame, &client->pending_frame, sizeof(rl_ws_frame_data_t));
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

void rl_ws_client_send_input(rl_ws_client_t *client, const char *input_json) {
  if (client == NULL || input_json == NULL) {
    return;
  }
  websocket_send_text(client->ws, input_json);
}

void rl_ws_client_tick(rl_ws_client_t *client) {
  double now = 0.0;
  
  if (client == NULL) {
    return;
  }
  
  now = rl_frame_get_time();
  
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
