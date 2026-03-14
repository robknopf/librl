#ifndef RL_PROTOCOL_H
#define RL_PROTOCOL_H

#include "rl_ws_client.h"
#include "rl_resource_protocol.h"
#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RL_PROTOCOL_MAX_REQUESTS 32
#define RL_PROTOCOL_MAX_PICK_REQUESTS 16
#define RL_PROTOCOL_MAX_PICK_RESPONSES 16
#define RL_PROTOCOL_MAX_MUSIC_COMMANDS 16

typedef struct rl_protocol_requests_t {
  rl_resource_request_t items[RL_PROTOCOL_MAX_REQUESTS];
  int count;
} rl_protocol_requests_t;

typedef enum rl_pick_request_type_t {
  RL_PICK_REQUEST_MODEL = 0,
  RL_PICK_REQUEST_SPRITE3D = 1,
} rl_pick_request_type_t;

typedef struct rl_pick_request_model_t {
  rl_handle_t camera;
  rl_handle_t handle;
  float mouse_x;
  float mouse_y;
  float x;
  float y;
  float z;
  float scale;
  float rotation_x;
  float rotation_y;
  float rotation_z;
} rl_pick_request_model_t;

typedef struct rl_pick_request_sprite3d_t {
  rl_handle_t camera;
  rl_handle_t handle;
  float mouse_x;
  float mouse_y;
  float x;
  float y;
  float z;
  float size;
} rl_pick_request_sprite3d_t;

typedef struct rl_pick_request_t {
  uint32_t rid;
  rl_pick_request_type_t type;
  union {
    rl_pick_request_model_t model;
    rl_pick_request_sprite3d_t sprite3d;
  } data;
} rl_pick_request_t;

typedef struct rl_protocol_pick_requests_t {
  rl_pick_request_t items[RL_PROTOCOL_MAX_PICK_REQUESTS];
  int count;
} rl_protocol_pick_requests_t;

typedef struct rl_pick_response_t {
  uint32_t rid;
  bool hit;
  float distance;
  vec3_t point;
  vec3_t normal;
} rl_pick_response_t;

typedef enum rl_music_command_type_t {
  RL_MUSIC_COMMAND_PLAY = 0,
  RL_MUSIC_COMMAND_PAUSE = 1,
  RL_MUSIC_COMMAND_STOP = 2,
  RL_MUSIC_COMMAND_SET_LOOP = 3,
  RL_MUSIC_COMMAND_SET_VOLUME = 4,
} rl_music_command_type_t;

typedef struct rl_music_command_t {
  rl_music_command_type_t type;
  rl_handle_t handle;
  bool loop;
  float volume;
} rl_music_command_t;

typedef struct rl_protocol_music_commands_t {
  rl_music_command_t items[RL_PROTOCOL_MAX_MUSIC_COMMANDS];
  int count;
} rl_protocol_music_commands_t;

typedef enum rl_protocol_message_type_t {
  RL_PROTOCOL_MESSAGE_UNKNOWN = 0,
  RL_PROTOCOL_MESSAGE_FRAME,
  RL_PROTOCOL_MESSAGE_RESOURCE_REQUESTS,
  RL_PROTOCOL_MESSAGE_PICK_REQUESTS,
  RL_PROTOCOL_MESSAGE_MUSIC_COMMANDS,
  RL_PROTOCOL_MESSAGE_RESET,
} rl_protocol_message_type_t;

// Parse a raw server message buffer, writing frame data or resource requests
// into caller-provided buffers depending on the packet type. out_frame/out_has_frame
// and out_requests may be NULL if caller doesn't need that part.
// Returns 0 on success, -1 on parse error
int rl_protocol_parse_message(const char *raw, int len,
                               rl_protocol_message_type_t *out_type,
                               rl_ws_frame_data_t *out_frame,
                               bool *out_has_frame,
                               rl_protocol_requests_t *out_requests,
                               rl_protocol_pick_requests_t *out_pick_requests,
                               rl_protocol_music_commands_t *out_music_commands);

// Serialize resource response packets into a string buffer for sending
// Returns length written (excluding null terminator), or -1 on error
int rl_protocol_serialize_responses(const rl_resource_response_t *responses, int count,
                                     char *out_buf, int buf_size);

int rl_protocol_serialize_pick_responses(const rl_pick_response_t *responses,
                                         int count,
                                         char *out_buf,
                                         int buf_size);

// Serialize compact client input state for remote gameplay/picking.
// Returns length written (excluding null terminator), or -1 on error.
int rl_protocol_serialize_input_state(const rl_mouse_state_t *mouse,
                                      const rl_keyboard_state_t *keyboard,
                                      int screen_width,
                                      int screen_height,
                                      char *out_buf,
                                      int buf_size);

#ifdef __cplusplus
}
#endif

#endif // RL_PROTOCOL_H
