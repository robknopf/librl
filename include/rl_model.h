#ifndef RL_MODEL_H
#define RL_MODEL_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

rl_handle_t rl_model_create(const char *filename) ;
void rl_model_draw(rl_handle_t handle,
                   float position_x, float position_y, float position_z,
                   float scale,
                   float rotation_x, float rotation_y, float rotation_z,
                   rl_handle_t tint);
bool rl_model_is_valid(rl_handle_t handle);
bool rl_model_is_valid_strict(rl_handle_t handle);
int rl_model_animation_count(rl_handle_t handle);
int rl_model_animation_frame_count(rl_handle_t handle, int animation_index);
void rl_model_animation_update(rl_handle_t handle, int animation_index, int frame);
bool rl_model_set_animation(rl_handle_t handle, int animation_index);
bool rl_model_set_animation_speed(rl_handle_t handle, float speed);
bool rl_model_set_animation_loop(rl_handle_t handle, bool should_loop);
bool rl_model_animate(rl_handle_t handle, float delta_seconds);
void rl_model_destroy(rl_handle_t handle) ;


#ifdef __cplusplus
}
#endif

#endif // RL_MODEL_H
