#ifndef RL_INTERNAL_MODEL_H
#define RL_INTERNAL_MODEL_H

#include <stdbool.h>
#include <raylib.h>

#include "rl_types.h"

void rl_model_init(void);
void rl_model_deinit(void);
bool rl_model_get_ray_collision(rl_handle_t handle, Ray ray, Matrix transform, RayCollision *collision);
bool rl_model_get_ray_collision_ex(rl_handle_t handle,
                                   Ray ray,
                                   Matrix transform,
                                   RayCollision *collision,
                                   bool *broadphase_tested,
                                   bool *broadphase_rejected,
                                   bool *narrowphase_ran);

#endif // RL_INTERNAL_MODEL_H
