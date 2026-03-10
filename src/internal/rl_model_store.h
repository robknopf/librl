#ifndef RL_MODEL_STORE_H
#define RL_MODEL_STORE_H

#include <stdbool.h>
#include <raylib.h>
#include "rl_types.h"

// Internal-only collision helper used by picking.
bool rl_model_get_ray_collision(rl_handle_t handle, Ray ray, Matrix transform, RayCollision *collision);
bool rl_model_get_ray_collision_ex(rl_handle_t handle,
                                   Ray ray,
                                   Matrix transform,
                                   RayCollision *collision,
                                   bool *broadphase_tested,
                                   bool *broadphase_rejected,
                                   bool *narrowphase_ran);

#endif // RL_MODEL_STORE_H
