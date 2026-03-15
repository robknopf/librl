#ifndef RL_SPRITE3D_H
#define RL_SPRITE3D_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

rl_handle_t rl_sprite3d_create(const char *filename);
rl_handle_t rl_sprite3d_create_from_texture(rl_handle_t texture);
bool rl_sprite3d_set_transform(rl_handle_t handle,
                               float position_x, float position_y,
                               float position_z, float size);
void rl_sprite3d_draw(rl_handle_t handle, rl_handle_t tint);
void rl_sprite3d_destroy(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_SPRITE3D_H
