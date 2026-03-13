#ifndef RL_PROTOCOL_H
#define RL_PROTOCOL_H

#include "rl_ws_client.h"
#include "rl_resource_protocol.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RL_PROTOCOL_MAX_REQUESTS 32

typedef struct rl_protocol_requests_t {
  rl_resource_request_t items[RL_PROTOCOL_MAX_REQUESTS];
  int count;
} rl_protocol_requests_t;

// Parse a raw message buffer, writing frame data and resource requests
// into caller-provided buffers. out_frame/out_has_frame and out_requests
// may be NULL if caller doesn't need that part.
// Returns 0 on success, -1 on parse error
int rl_protocol_parse_message(const char *raw, int len,
                               rl_ws_frame_data_t *out_frame,
                               bool *out_has_frame,
                               rl_protocol_requests_t *out_requests);

// Serialize resource responses into a string buffer for sending
// Returns length written (excluding null terminator), or -1 on error
int rl_protocol_serialize_responses(const rl_resource_response_t *responses, int count,
                                     char *out_buf, int buf_size);

#ifdef __cplusplus
}
#endif

#endif // RL_PROTOCOL_H
