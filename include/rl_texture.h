#ifndef RL_TEXTURE_H
#define RL_TEXTURE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

rl_handle_t rl_texture_create(const char *filename);
void rl_texture_destroy(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_TEXTURE_H
