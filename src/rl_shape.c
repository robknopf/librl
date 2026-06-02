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

RL_KEEP
void rl_shape_draw_circle_3d(float center_x, float center_y, float center_z,
                              float radius,
                              float rotation_axis_x, float rotation_axis_y, float rotation_axis_z,
                              float rotation_angle,
                              rl_handle_t color)
{
    Color c = rl_color_get(color);
    DrawCircle3D(
        (Vector3){center_x, center_y, center_z},
        radius,
        (Vector3){rotation_axis_x, rotation_axis_y, rotation_axis_z},
        rotation_angle,
        c
    );
}
