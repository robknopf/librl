#ifndef RL_INTERNAL_MODEL_H
#define RL_INTERNAL_MODEL_H

#include <stdbool.h>
#include <raylib.h>

#include "rl_types.h"

void rl_model_init(void);
void rl_model_deinit(void);
bool rl_model_get_transform(rl_handle_t handle, float *position_x, float *position_y, float *position_z, float *scale_x, float *scale_y, float *scale_z, float *rotation_x, float *rotation_y, float *rotation_z);
bool rl_model_get_ray_collision(rl_handle_t handle, Ray ray, Matrix transform, RayCollision *collision);
bool rl_model_get_ray_collision_ex(rl_handle_t handle,
                                   Ray ray,
                                   Matrix transform,
                                   RayCollision *collision,
                                   Matrix *resolved_model_transform,
                                   bool *broadphase_tested,
                                   bool *broadphase_rejected,
                                   bool *narrowphase_ran);

#endif // RL_INTERNAL_MODEL_H
