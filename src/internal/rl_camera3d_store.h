#ifndef RL_CAMERA3D_STORE_H
#define RL_CAMERA3D_STORE_H

#include <stdbool.h>
#include <raylib.h>
#include "rl_types.h"

// Internal-only helper for subsystems that need current camera matrices/state.
bool rl_camera3d_get_active_camera(Camera3D *camera);
bool rl_camera3d_get_camera(rl_handle_t handle, Camera3D *camera);

#endif // RL_CAMERA3D_STORE_H
