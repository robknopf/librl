#ifndef RL_PICK_H
#define RL_PICK_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

typedef struct
{
    bool hit;
    float distance;
    vec3_t point;
    vec3_t normal;
} rl_pick_result_t;

rl_pick_result_t rl_pick_model(rl_handle_t camera,
                               rl_handle_t model,
                               float mouse_x,
                               float mouse_y,
                               float position_x,
                               float position_y,
                               float position_z,
                               float scale);

bool rl_pick_model_to_scratch(rl_handle_t camera,
                              rl_handle_t model,
                              float mouse_x,
                              float mouse_y,
                              float position_x,
                              float position_y,
                              float position_z,
                              float scale);

rl_pick_result_t rl_pick_sprite3d(rl_handle_t camera,
                                  rl_handle_t sprite3d,
                                  float mouse_x,
                                  float mouse_y,
                                  float position_x,
                                  float position_y,
                                  float position_z,
                                  float size);

bool rl_pick_sprite3d_to_scratch(rl_handle_t camera,
                                 rl_handle_t sprite3d,
                                 float mouse_x,
                                 float mouse_y,
                                 float position_x,
                                 float position_y,
                                 float position_z,
                                 float size);

#ifdef __cplusplus
}
#endif

#endif // RL_PICK_H
