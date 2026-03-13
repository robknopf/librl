#include "rl_ws_client.h"
#include "rl_protocol.h"
#include "rl_resource_handler.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#include <emscripten/websocket.h>
#endif

#define MAX_MESSAGE_SIZE (1024 * 64)

struct rl_ws_client_t {
#if defined(PLATFORM_WEB)
  EMSCRIPTEN_WEBSOCKET_T socket;
#endif
  char url[256];
  bool connected;
  bool has_pending_frame;
  rl_ws_frame_data_t pending_frame;
  char message_buffer[MAX_MESSAGE_SIZE];
  rl_resource_response_t pending_responses[RL_WS_MAX_PENDING_RESPONSES];
  int pending_response_count;
  double last_reconnect_attempt;
  double reconnect_delay;
  rl_resource_handler_t resource_handler;
  // Bandwidth tracking
  size_t bytes_in_accum;
  size_t bytes_out_accum;
  double stats_timer;
  rl_ws_bandwidth_stats_t bandwidth_stats;
};

#if defined(PLATFORM_WEB)
static EM_BOOL on_ws_open(int event_type, const EmscriptenWebSocketOpenEvent *event, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)event_type;
  (void)event;
  
  printf("[WS] Connected to %s\n", client->url);
  client->connected = true;
  return EM_TRUE;
}

static EM_BOOL on_ws_error(int event_type, const EmscriptenWebSocketErrorEvent *event, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)event_type;
  (void)event;
  
  printf("[WS] Error on %s. Will attempt to reconnect...\n", client->url);
  client->connected = false;
  return EM_TRUE;
}

static EM_BOOL on_ws_close(int event_type, const EmscriptenWebSocketCloseEvent *event, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  (void)event_type;
  
  printf("[WS] Closed: code=%d, reason=%s. Will attempt to reconnect...\n", event->code, event->reason);
  client->connected = false;
  client->reconnect_delay = 1.0;
  return EM_TRUE;
}

static EM_BOOL on_ws_message(int event_type, const EmscriptenWebSocketMessageEvent *event, void *user_data) {
  rl_ws_client_t *client = (rl_ws_client_t *)user_data;
  static rl_protocol_requests_t requests;
  bool has_frame = false;
  (void)event_type;
  
  if (!event->isText || event->numBytes >= MAX_MESSAGE_SIZE) {
    return EM_TRUE;
  }
  
  client->bytes_in_accum += event->numBytes;
  
  memcpy(client->message_buffer, event->data, event->numBytes);
  client->message_buffer[event->numBytes] = '\0';
  
  if (rl_protocol_parse_message(client->message_buffer, event->numBytes,
                                 &client->pending_frame, &has_frame,
                                 &requests) != 0) {
    printf("[WS] Failed to parse message\n");
    return EM_TRUE;
  }
  
  if (has_frame) {
    client->has_pending_frame = true;
  }
  
  if (requests.count > 0) {
    int response_count = rl_resource_handler_process_requests(
      &client->resource_handler,
      requests.items,
      requests.count,
      client->pending_responses,
      RL_WS_MAX_PENDING_RESPONSES
    );
    
    if (response_count >= 0 && response_count <= RL_WS_MAX_PENDING_RESPONSES) {
      client->pending_response_count = response_count;
      
      if (response_count > 0) {
        printf("[WS] Processed %d resource requests\n", response_count);
      }
    }
  }
  
  return EM_TRUE;
}
#endif


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
  client->connected = false;
  client->has_pending_frame = false;
  client->pending_response_count = 0;
  client->last_reconnect_attempt = 0.0;
  client->reconnect_delay = 1.0;
  rl_resource_handler_init(&client->resource_handler);
  
#if defined(PLATFORM_WEB)
  EmscriptenWebSocketCreateAttributes attrs;
  emscripten_websocket_init_create_attributes(&attrs);
  attrs.url = client->url;
  
  client->socket = emscripten_websocket_new(&attrs);
  if (client->socket <= 0) {
    printf("[WS] Failed to create websocket\n");
    free(client);
    return NULL;
  }
  
  emscripten_websocket_set_onopen_callback(client->socket, client, on_ws_open);
  emscripten_websocket_set_onerror_callback(client->socket, client, on_ws_error);
  emscripten_websocket_set_onclose_callback(client->socket, client, on_ws_close);
  emscripten_websocket_set_onmessage_callback(client->socket, client, on_ws_message);
  
  printf("[WS] Connecting to %s...\n", client->url);
#else
  printf("[WS] Desktop websocket not implemented yet\n");
#endif
  
  return client;
}

void rl_ws_client_destroy(rl_ws_client_t *client) {
  if (client == NULL) {
    return;
  }
  
  rl_resource_handler_cleanup(&client->resource_handler);
  
#if defined(PLATFORM_WEB)
  if (client->socket > 0) {
    emscripten_websocket_close(client->socket, 1000, "Client closing");
    emscripten_websocket_delete(client->socket);
  }
#endif
  
  free(client);
}

bool rl_ws_client_is_connected(const rl_ws_client_t *client) {
  if (client == NULL) {
    return false;
  }
  return client->connected;
}

void rl_ws_client_poll(rl_ws_client_t *client) {
  (void)client;
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
  if (client == NULL || responses == NULL || count <= 0) {
    return;
  }
  
  if (!client->connected) {
    printf("[WS] Cannot send responses: not connected\n");
    return;
  }
  
#if defined(PLATFORM_WEB)
  char send_buf[MAX_MESSAGE_SIZE];
  int len = rl_protocol_serialize_responses(responses, count, send_buf, MAX_MESSAGE_SIZE);
  
  if (len > 0) {
    printf("[WS] Sending %d resource responses\n", count);
    EMSCRIPTEN_RESULT result = emscripten_websocket_send_utf8_text(client->socket, send_buf);
    if (result < 0) {
      printf("[WS] Failed to send responses: %d\n", result);
    } else {
      printf("[WS] Responses sent successfully\n");
    }
    client->bytes_out_accum += (size_t)len;
  }
#endif
}

void rl_ws_client_send_input(rl_ws_client_t *client, const char *input_json) {
  if (client == NULL || input_json == NULL || !client->connected) {
    return;
  }
  
#if defined(PLATFORM_WEB)
  emscripten_websocket_send_utf8_text(client->socket, input_json);
#else
  (void)input_json;
#endif
}

void rl_ws_client_tick(rl_ws_client_t *client) {
  if (client == NULL) {
    return;
  }
  
#if defined(PLATFORM_WEB)
  double now = emscripten_get_now() / 1000.0;
  
  // Update bandwidth stats every second
  if (client->stats_timer == 0.0) {
    client->stats_timer = now;
  } else if (now - client->stats_timer >= 1.0) {
    double elapsed = now - client->stats_timer;
    client->bandwidth_stats.bytes_in_per_sec = (float)(client->bytes_in_accum / elapsed);
    client->bandwidth_stats.bytes_out_per_sec = (float)(client->bytes_out_accum / elapsed);
    client->bytes_in_accum = 0;
    client->bytes_out_accum = 0;
    client->stats_timer = now;
  }
  
  if (!client->connected) {
    if (now - client->last_reconnect_attempt >= client->reconnect_delay) {
      printf("[WS] Attempting to reconnect to %s...\n", client->url);
      client->last_reconnect_attempt = now;
      
      EmscriptenWebSocketCreateAttributes attrs;
      emscripten_websocket_init_create_attributes(&attrs);
      attrs.url = client->url;
      
      EMSCRIPTEN_WEBSOCKET_T new_socket = emscripten_websocket_new(&attrs);
      if (new_socket > 0) {
        client->socket = new_socket;
        emscripten_websocket_set_onopen_callback(client->socket, client, on_ws_open);
        emscripten_websocket_set_onerror_callback(client->socket, client, on_ws_error);
        emscripten_websocket_set_onclose_callback(client->socket, client, on_ws_close);
        emscripten_websocket_set_onmessage_callback(client->socket, client, on_ws_message);
        client->reconnect_delay = 1.0;
      } else {
        client->reconnect_delay *= 2.0;
        if (client->reconnect_delay > 30.0) {
          client->reconnect_delay = 30.0;
        }
        printf("[WS] Reconnect failed. Next attempt in %.1f seconds\n", client->reconnect_delay);
      }
    }
  }
#endif
}

rl_ws_bandwidth_stats_t rl_ws_client_get_bandwidth_stats(const rl_ws_client_t *client) {
  rl_ws_bandwidth_stats_t empty = {0};
  if (client == NULL) {
    return empty;
  }
  return client->bandwidth_stats;
}
