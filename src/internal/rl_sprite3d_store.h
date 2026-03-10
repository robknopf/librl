#ifndef RL_SPRITE3D_STORE_H
#define RL_SPRITE3D_STORE_H

#include <stdbool.h>
#include <raylib.h>
#include "rl_types.h"

// Internal-only collision helper used by picking.
bool rl_sprite3d_get_ray_collision(rl_handle_t handle,
                                   Camera3D camera,
                                   Ray ray,
                                   float position_x,
                                   float position_y,
                                   float position_z,
                                   float size,
                                   RayCollision *collision);
bool rl_sprite3d_get_ray_collision_ex(rl_handle_t handle,
                                      Camera3D camera,
                                      Ray ray,
                                      float position_x,
                                      float position_y,
                                      float position_z,
                                      float size,
                                      RayCollision *collision,
                                      bool *broadphase_tested,
                                      bool *broadphase_rejected,
                                      bool *narrowphase_ran);

#endif // RL_SPRITE3D_STORE_H
