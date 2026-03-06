#ifndef RL_COLOR_STORE_H
#define RL_COLOR_STORE_H

#include <raylib.h>

#include "rl.h"

Color rl_color_get(rl_handle_t handle);
void rl_color_set(rl_handle_t handle, int r, int g, int b, int a);

#endif // RL_COLOR_STORE_H
