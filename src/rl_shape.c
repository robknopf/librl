#include "internal/exports.h"
#include "internal/rl_color.h"
#include "raylib.h"

RL_KEEP
void rl_shape_draw_rectangle(int x, int y, int width, int height,
                             rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawRectangle(x, y, width, height, c);
}

RL_KEEP
void rl_shape_draw_cube(float position_x, float position_y, float position_z,
                        float width, float height, float length,
                        rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawCube((Vector3){position_x, position_y, position_z}, width, height, length, c);
}
