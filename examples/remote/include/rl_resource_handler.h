#ifndef RL_RESOURCE_HANDLER_H
#define RL_RESOURCE_HANDLER_H

#include "rl_resource_protocol.h"
#include "rl_loader.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RL_RESOURCE_HANDLER_MAX_PENDING 32

typedef struct rl_pending_resource_load_t {
  bool in_use;
  uint32_t rid;
  rl_resource_request_type_t type;
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
  float size;
  rl_loader_task_t *loader_task;
} rl_pending_resource_load_t;

typedef struct rl_resource_handler_t {
  rl_pending_resource_load_t pending[RL_RESOURCE_HANDLER_MAX_PENDING];
} rl_resource_handler_t;

// Initialize the resource handler
void rl_resource_handler_init(rl_resource_handler_t *handler);

// Process resource requests (as C structs, protocol-agnostic)
// Sync resources (colors, camera3d) generate immediate responses
// Async resources (fonts, textures, models, etc.) start loader tasks
// Returns count of immediate responses
int rl_resource_handler_process_requests(rl_resource_handler_t *handler,
                                         const rl_resource_request_t *requests,
                                         int request_count,
                                         rl_resource_response_t *responses,
                                         int max_responses);

// Poll pending async loads, returns count of newly completed responses
int rl_resource_handler_poll(rl_resource_handler_t *handler,
                              rl_resource_response_t *responses,
                              int max_responses);

// Clean up all pending loads
void rl_resource_handler_cleanup(rl_resource_handler_t *handler);

#ifdef __cplusplus
}
#endif

#endif // RL_RESOURCE_HANDLER_H
