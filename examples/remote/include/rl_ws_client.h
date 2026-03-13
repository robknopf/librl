#ifndef RL_WS_CLIENT_H
#define RL_WS_CLIENT_H

#include "rl_frame_commands.h"
#include "rl_resource_protocol.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RL_WS_MAX_PENDING_RESPONSES 64

typedef struct rl_ws_bandwidth_stats_t {
  float bytes_in_per_sec;
  float bytes_out_per_sec;
} rl_ws_bandwidth_stats_t;

typedef struct rl_ws_frame_data_t {
  rl_frame_command_buffer_t commands;
  int frame_number;
  float delta_time;
} rl_ws_frame_data_t;

typedef struct rl_ws_client_t rl_ws_client_t;

rl_ws_client_t *rl_ws_client_create(const char *url);
void rl_ws_client_destroy(rl_ws_client_t *client);
void rl_ws_client_tick(rl_ws_client_t *client);
void rl_ws_client_poll(rl_ws_client_t *client);
bool rl_ws_client_is_connected(const rl_ws_client_t *client);
bool rl_ws_client_has_frame(const rl_ws_client_t *client);
bool rl_ws_client_get_frame(rl_ws_client_t *client, rl_ws_frame_data_t *out_frame);

// Resource response handling
int rl_ws_client_get_pending_responses(rl_ws_client_t *client, 
                                       rl_resource_response_t *responses,
                                       int max_responses);
// Poll async resource loads, returns count of newly completed responses
int rl_ws_client_poll_resource_loads(rl_ws_client_t *client,
                                      rl_resource_response_t *responses,
                                      int max_responses);
void rl_ws_client_send_responses(rl_ws_client_t *client,
                                 const rl_resource_response_t *responses,
                                 int count);

void rl_ws_client_send_input(rl_ws_client_t *client, const char *input_json);
rl_ws_bandwidth_stats_t rl_ws_client_get_bandwidth_stats(const rl_ws_client_t *client);

#ifdef __cplusplus
}
#endif

#endif // RL_WS_CLIENT_H
