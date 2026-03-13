#ifndef RL_RESOURCE_PROTOCOL_H
#define RL_RESOURCE_PROTOCOL_H

#include "rl_types.h"
#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RL_RESOURCE_REQUEST_MAX_FILENAME 256

typedef enum rl_resource_request_type_t {
  RL_RESOURCE_REQUEST_CREATE_COLOR = 0,
  RL_RESOURCE_REQUEST_CREATE_FONT = 1,
  RL_RESOURCE_REQUEST_CREATE_TEXTURE = 2,
  RL_RESOURCE_REQUEST_CREATE_MODEL = 3,
  RL_RESOURCE_REQUEST_CREATE_SOUND = 4,
  RL_RESOURCE_REQUEST_CREATE_MUSIC = 5,
  RL_RESOURCE_REQUEST_CREATE_CAMERA3D = 6,
  RL_RESOURCE_REQUEST_CREATE_SPRITE3D = 7,
  RL_RESOURCE_REQUEST_DESTROY = 99,
} rl_resource_request_type_t;

typedef struct rl_resource_request_create_color_t {
  int r, g, b, a;
} rl_resource_request_create_color_t;

typedef struct rl_resource_request_create_font_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
  float fontSize;
} rl_resource_request_create_font_t;

typedef struct rl_resource_request_create_texture_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
} rl_resource_request_create_texture_t;

typedef struct rl_resource_request_create_model_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
} rl_resource_request_create_model_t;

typedef struct rl_resource_request_create_sound_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
} rl_resource_request_create_sound_t;

typedef struct rl_resource_request_create_music_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
} rl_resource_request_create_music_t;

typedef struct rl_resource_request_create_camera3d_t {
  float posX, posY, posZ;
  float targetX, targetY, targetZ;
  float upX, upY, upZ;
  float fovy;
  int projection;
} rl_resource_request_create_camera3d_t;

typedef struct rl_resource_request_create_sprite3d_t {
  char filename[RL_RESOURCE_REQUEST_MAX_FILENAME];
} rl_resource_request_create_sprite3d_t;

typedef struct rl_resource_request_destroy_t {
  rl_handle_t handle;
} rl_resource_request_destroy_t;

typedef struct rl_resource_request_t {
  uint32_t rid;
  rl_resource_request_type_t type;
  union {
    rl_resource_request_create_color_t create_color;
    rl_resource_request_create_font_t create_font;
    rl_resource_request_create_texture_t create_texture;
    rl_resource_request_create_model_t create_model;
    rl_resource_request_create_sound_t create_sound;
    rl_resource_request_create_music_t create_music;
    rl_resource_request_create_camera3d_t create_camera3d;
    rl_resource_request_create_sprite3d_t create_sprite3d;
    rl_resource_request_destroy_t destroy;
  } data;
} rl_resource_request_t;

typedef struct rl_resource_response_t {
  uint32_t rid;
  rl_handle_t handle;
  bool success;
} rl_resource_response_t;

#ifdef __cplusplus
}
#endif

#endif // RL_RESOURCE_PROTOCOL_H
