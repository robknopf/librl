#ifndef RL_HANDLE_H
#define RL_HANDLE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

/** Resource kind encoded in the high 6 bits of {@link rl_handle_t}. */
typedef enum rl_handle_kind_t {
    RL_KIND_NONE = 0,
    RL_KIND_COLOR = 1,
    RL_KIND_CAMERA3D = 2,
    RL_KIND_FONT = 3,
    RL_KIND_TEXTURE = 4,
    RL_KIND_SPRITE2D = 5,
    RL_KIND_SPRITE3D = 6,
    RL_KIND_MODEL = 7,
    RL_KIND_MODEL_ASSET = 8,
    RL_KIND_SOUND = 9,
    RL_KIND_MUSIC = 10,
    RL_KIND_TEXT2D = 11,
    RL_KIND_ASSET_TASK = 12,
} rl_handle_kind_t;

/** Returns {@link RL_KIND_NONE} for handle {@code 0}; otherwise the kind field. */
rl_handle_kind_t rl_handle_get_kind(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_HANDLE_H
