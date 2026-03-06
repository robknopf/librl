#ifndef RL_TEXTURE_STORE_H
#define RL_TEXTURE_STORE_H

#include <stdbool.h>
#include <raylib.h>

#include "rl.h"

// Internal shared-texture store helpers.
// Public callers should use rl_texture_create/rl_texture_destroy instead.
Texture2D *rl_texture_get_ptr(rl_handle_t handle);
bool rl_texture_retain(rl_handle_t handle);
void rl_texture_release(rl_handle_t handle);

#endif // RL_TEXTURE_STORE_H
