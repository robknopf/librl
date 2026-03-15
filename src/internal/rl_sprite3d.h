#ifndef RL_INTERNAL_SPRITE3D_H
#define RL_INTERNAL_SPRITE3D_H

#include <stdbool.h>
#include <raylib.h>

#include "rl_types.h"

void rl_sprite3d_init(void);
void rl_sprite3d_deinit(void);
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

#endif // RL_INTERNAL_SPRITE3D_H
