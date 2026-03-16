#ifndef RL_RESOURCE_HANDLER_H
#define RL_RESOURCE_HANDLER_H

#include "rl_resource_protocol.h"
#include "rl_protocol.h"
#include "rl_frame_command.h"
#include "rl_loader.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RL_RESOURCE_HANDLER_MAX_PENDING 32
#define RL_RESOURCE_HANDLER_MAX_TRACKED 256

typedef struct rl_pending_resource_load_t {
  bool in_use;
  uint32_t rid;
  rl_handle_t world_handle;
  rl_resource_request_type_t type;
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
  float size;
  rl_loader_task_t *loader_task;
} rl_pending_resource_load_t;

typedef struct rl_resource_handler_t {
  rl_pending_resource_load_t pending[RL_RESOURCE_HANDLER_MAX_PENDING];
  struct {
    bool in_use;
    rl_resource_request_type_t type;
    rl_handle_t world_handle;
    rl_handle_t local_handle;
  } tracked[RL_RESOURCE_HANDLER_MAX_TRACKED];
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

// Destroy all tracked remote-created resources and clear pending async loads.
void rl_resource_handler_reset(rl_resource_handler_t *handler);

// Clean up all pending loads
void rl_resource_handler_cleanup(rl_resource_handler_t *handler);

rl_handle_t rl_resource_handler_get_local_handle(const rl_resource_handler_t *handler,
                                                 rl_handle_t world_handle);

void rl_resource_handler_resolve_frame_commands(
    const rl_resource_handler_t *handler,
    rl_frame_command_buffer_t *frame_commands);

void rl_resource_handler_resolve_pick_requests(
    const rl_resource_handler_t *handler,
    rl_protocol_pick_requests_t *pick_requests);

#ifdef __cplusplus
}
#endif

#endif // RL_RESOURCE_HANDLER_H
