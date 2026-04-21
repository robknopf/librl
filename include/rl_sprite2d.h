#ifndef RL_SPRITE2D_H
#define RL_SPRITE2D_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

rl_handle_t rl_sprite2d_create(const char *filename);
rl_handle_t rl_sprite2d_create_from_texture(rl_handle_t texture);
bool rl_sprite2d_set_transform(rl_handle_t handle,
                               float x, float y,
                               float scale, float rotation);
void rl_sprite2d_draw(rl_handle_t handle, rl_handle_t tint);
void rl_sprite2d_destroy(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_SPRITE2D_H
