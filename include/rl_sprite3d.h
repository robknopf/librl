#ifndef RL_SPRITE3D_H
#define RL_SPRITE3D_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include "rl_types.h"

typedef enum {
    RL_SPRITE3D_FACING_CAMERA         = 0, /* fully faces camera                             */
    RL_SPRITE3D_FACING_CAMERA_FIXED_Y = 1, /* faces camera but keeps Y axis fixed (default) */
    RL_SPRITE3D_FACING_Y_UP           = 2, /* flat in XZ plane, normal faces +Y             */
    RL_SPRITE3D_FACING_NONE           = 3, /* fixed in XY plane, normal faces +Z            */
} rl_sprite3d_facing_t;

rl_handle_t rl_sprite3d_get_default_texture(void);
rl_handle_t rl_sprite3d_create(rl_handle_t texture);
rl_handle_t rl_sprite3d_create_from_file(const char *filename);
bool rl_sprite3d_set_texture(rl_handle_t handle, rl_handle_t texture);
bool rl_sprite3d_get_transform(rl_handle_t handle,
                               float *position_x, float *position_y,
                               float *position_z, float *size);
bool rl_sprite3d_set_transform(rl_handle_t handle,
                               float position_x, float position_y,
                               float position_z, float size);
bool rl_sprite3d_set_facing(rl_handle_t handle, int facing);
bool rl_sprite3d_set_tint(rl_handle_t handle, rl_handle_t color_handle);
bool rl_sprite3d_set_visible(rl_handle_t handle, bool visible);
bool rl_sprite3d_set_pickable(rl_handle_t handle, bool pickable);
bool rl_sprite3d_is_visible(rl_handle_t handle);
bool rl_sprite3d_is_pickable(rl_handle_t handle);
void rl_sprite3d_draw(rl_handle_t handle);
void rl_sprite3d_destroy(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_SPRITE3D_H
