#ifndef RL_SHAPE_H
#define RL_SHAPE_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_types.h"

void rl_shape_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color);
void rl_shape_draw_cube(float position_x, float position_y, float position_z,
                        float width, float height, float length,
                        rl_handle_t color);

#ifdef __cplusplus
}
#endif

#endif // RL_SHAPE_H
