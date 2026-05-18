#ifndef RL_FRAME_COMMAND_H
#define RL_FRAME_COMMAND_H

#include <stdbool.h>
#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

#define RL_FRAME_COMMAND_CAPACITY 128
#define RL_FRAME_TEXT_MAX 256

typedef enum rl_render_command_type_t {
  RL_RENDER_CMD_CLEAR = 0,
  RL_RENDER_CMD_DRAW_TEXT = 1,
  RL_RENDER_CMD_DRAW_SPRITE3D = 2,
  RL_RENDER_CMD_PLAY_SOUND = 3,
  RL_RENDER_CMD_DRAW_MODEL = 4,
  RL_RENDER_CMD_DRAW_TEXTURE = 5,
  RL_RENDER_CMD_DRAW_CUBE = 6,
  RL_RENDER_CMD_DRAW_GROUND_TEXTURE = 7,
  RL_RENDER_CMD_SET_CAMERA3D = 8,
  RL_RENDER_CMD_SET_MODEL_TRANSFORM = 9,
  RL_RENDER_CMD_SET_SPRITE3D_TRANSFORM = 10,
  RL_RENDER_CMD_PLAY_MUSIC = 11,
  RL_RENDER_CMD_PAUSE_MUSIC = 12,
  RL_RENDER_CMD_STOP_MUSIC = 13,
  RL_RENDER_CMD_SET_MUSIC_LOOP = 14,
  RL_RENDER_CMD_SET_MUSIC_VOLUME = 15,
  RL_RENDER_CMD_SET_ACTIVE_CAMERA3D = 16,
  RL_RENDER_CMD_SET_SPRITE2D_TRANSFORM = 17,
  RL_RENDER_CMD_DRAW_SPRITE2D = 18
} rl_render_command_type_t;

typedef struct rl_frame_clear_t {
  rl_handle_t color;
} rl_frame_clear_t;

typedef struct rl_frame_draw_text_t {
  rl_handle_t font;
  rl_handle_t color;
  float x;
  float y;
  float font_size;
  float spacing;
  char text[RL_FRAME_TEXT_MAX];
} rl_frame_draw_text_t;

typedef struct rl_frame_draw_sprite3d_t {
  rl_handle_t sprite;
  rl_handle_t tint;
} rl_frame_draw_sprite3d_t;

typedef struct rl_frame_play_sound_t {
  rl_handle_t sound;
  float volume;
  float pitch;
  float pan;
} rl_frame_play_sound_t;

typedef struct rl_frame_play_music_t {
  rl_handle_t music;
} rl_frame_play_music_t;

typedef struct rl_frame_pause_music_t {
  rl_handle_t music;
} rl_frame_pause_music_t;

typedef struct rl_frame_stop_music_t {
  rl_handle_t music;
} rl_frame_stop_music_t;

typedef struct rl_frame_set_music_loop_t {
  rl_handle_t music;
  bool loop;
} rl_frame_set_music_loop_t;

typedef struct rl_frame_set_music_volume_t {
  rl_handle_t music;
  float volume;
} rl_frame_set_music_volume_t;

typedef struct rl_frame_draw_model_t {
  rl_handle_t model;
  rl_handle_t tint;
  int animation_index;
  int animation_frame;
} rl_frame_draw_model_t;

typedef struct rl_frame_draw_texture_t {
  rl_handle_t texture;
  rl_handle_t tint;
  float x;
  float y;
  float scale;
  float rotation;
} rl_frame_draw_texture_t;

typedef struct rl_frame_draw_cube_t {
  rl_handle_t color;
  float x;
  float y;
  float z;
  float width;
  float height;
  float length;
} rl_frame_draw_cube_t;

typedef struct rl_frame_draw_ground_texture_t {
  rl_handle_t texture;
  rl_handle_t tint;
  float x;
  float y;
  float z;
  float width;
  float length;
} rl_frame_draw_ground_texture_t;

typedef struct rl_frame_draw_sprite2d_t {
  rl_handle_t sprite;
  rl_handle_t tint;
} rl_frame_draw_sprite2d_t;

typedef struct rl_frame_set_sprite2d_transform_t {
  rl_handle_t sprite;
  float x;
  float y;
  float scale;
  float rotation;
} rl_frame_set_sprite2d_transform_t;

typedef struct rl_frame_set_active_camera3d_t {
  rl_handle_t camera;
} rl_frame_set_active_camera3d_t;

typedef struct rl_frame_set_camera3d_t {
  rl_handle_t camera;
  float position_x;
  float position_y;
  float position_z;
  float target_x;
  float target_y;
  float target_z;
  float up_x;
  float up_y;
  float up_z;
  float fovy;
  int projection;
} rl_frame_set_camera3d_t;

typedef struct rl_frame_set_model_transform_t {
  rl_handle_t model;
  float position_x;
  float position_y;
  float position_z;
  float rotation_x;
  float rotation_y;
  float rotation_z;
  float scale_x;
  float scale_y;
  float scale_z;
} rl_frame_set_model_transform_t;

typedef struct rl_frame_set_sprite3d_transform_t {
  rl_handle_t sprite;
  float position_x;
  float position_y;
  float position_z;
  float size;
} rl_frame_set_sprite3d_transform_t;

typedef struct rl_render_command_t {
  int type;
  union {
    rl_frame_clear_t clear;
    rl_frame_draw_text_t draw_text;
    rl_frame_draw_sprite3d_t draw_sprite3d;
    rl_frame_play_sound_t play_sound;
    rl_frame_play_music_t play_music;
    rl_frame_pause_music_t pause_music;
    rl_frame_stop_music_t stop_music;
    rl_frame_set_music_loop_t set_music_loop;
    rl_frame_set_music_volume_t set_music_volume;
    rl_frame_draw_model_t draw_model;
    rl_frame_draw_texture_t draw_texture;
    rl_frame_draw_cube_t draw_cube;
    rl_frame_draw_ground_texture_t draw_ground_texture;
    rl_frame_set_camera3d_t set_camera3d;
    rl_frame_set_model_transform_t set_model_transform;
    rl_frame_set_sprite3d_transform_t set_sprite3d_transform;
    rl_frame_set_active_camera3d_t set_active_camera3d;
    rl_frame_draw_sprite2d_t draw_sprite2d;
    rl_frame_set_sprite2d_transform_t set_sprite2d_transform;
  } data;
} rl_render_command_t;

typedef struct rl_frame_command_buffer_t {
  rl_render_command_t commands[RL_FRAME_COMMAND_CAPACITY];
  int count;
} rl_frame_command_buffer_t;

void rl_frame_commands_reset(rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_append(void *user_data,
                              const rl_render_command_t *command);
void rl_frame_commands_execute_clear(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_audio(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_state(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_3d(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_2d(
    const rl_frame_command_buffer_t *frame_commands);

#ifdef __cplusplus
}
#endif

#endif // RL_FRAME_COMMAND_H
