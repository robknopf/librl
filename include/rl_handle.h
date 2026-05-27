#ifndef RL_HANDLE_H
#define RL_HANDLE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

/** Resource type encoded in the high 6 bits of {@link rl_handle_t}. */
typedef enum rl_handle_type_t {
    RL_TYPE_NONE = 0,
    RL_TYPE_COLOR = 1,
    RL_TYPE_CAMERA3D = 2,
    RL_TYPE_FONT = 3,
    RL_TYPE_TEXTURE = 4,
    RL_TYPE_SPRITE2D = 5,
    RL_TYPE_SPRITE3D = 6,
    RL_TYPE_MODEL = 7,
    RL_TYPE_MODEL_ASSET = 8,
    RL_TYPE_SOUND = 9,
    RL_TYPE_MUSIC = 10,
    RL_TYPE_TEXT2D = 11,
    RL_TYPE_ASSET_TASK = 12,
} rl_handle_type_t;

/** Returns {@link RL_TYPE_NONE} for handle {@code 0}; otherwise the type field. */
rl_handle_type_t rl_handle_get_type(rl_handle_t handle);

#ifdef __cplusplus
}
#endif

#endif // RL_HANDLE_H
