#ifndef RL_H
#define RL_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef unsigned int rl_handle_t;

typedef struct
{
    float x;
    float y;
} vec2_t;

typedef struct
{
    float x;
    float y;
    float z;
} vec3_t;

typedef struct
{
    float x;
    float y;
    float z;
    float w;
} vec4_t;

typedef struct
{
    float m0;
    float m4;
    float m8;
    float m12;
    float m1;
    float m5;
    float m9;
    float m13;
    float m2;
    float m6;
    float m10;
    float m14;
    float m3;
    float m7;
    float m11;
    float m15;
} matrix_t;

typedef struct
{
    float x;
    float y;
    float z;
    float w;
} quat_t;

typedef struct
{
    float r;
    float g;
    float b;
    float a;
} color_t;

typedef struct
{
    float x;
    float y;
    float width;
    float height;
} rect_t;



void rl_init();
void rl_deinit();
void rl_init_window(int width, int height, const char *title);
void rl_set_window_title(const char *title);
void rl_set_window_size(int width, int height);
int rl_get_screen_width();
int rl_get_screen_height();
int rl_get_monitor_count();
int rl_get_current_monitor();
void rl_set_window_monitor(int monitor);
void rl_get_monitor_position(int monitor);
float rl_get_monitor_position_x(int monitor);
float rl_get_monitor_position_y(int monitor);
void rl_get_window_position();
float rl_get_window_position_x();
float rl_get_window_position_y();
void rl_get_mouse();
float rl_get_mouse_x();
float rl_get_mouse_y();
int rl_get_mouse_wheel();
int rl_get_mouse_button(int button);
void rl_set_window_position(int x, int y);
void rl_close_window();
void rl_begin_drawing();
void rl_end_drawing();
void rl_clear_background(rl_handle_t color);
void rl_set_target_fps(int fps);
void rl_draw_fps(int x, int y);
void rl_draw_fps_ex(rl_handle_t font, int x, int y, int fontSize, rl_handle_t color);
void rl_draw_text(const char *text, int x, int y, int fontSize, rl_handle_t color);
void rl_draw_text_ex(rl_handle_t font, const char *text, int x, int y, float fontSize, float spacing, rl_handle_t color);
void rl_begin_mode_2d(rl_handle_t camera);
void rl_end_mode_2d();
rl_handle_t rl_camera3d_create(float position_x, float position_y, float position_z,
                               float target_x, float target_y, float target_z,
                               float up_x, float up_y, float up_z,
                               float fovy, int projection);
rl_handle_t rl_camera3d_get_default(void);
bool rl_camera3d_set(rl_handle_t handle,
                     float position_x, float position_y, float position_z,
                     float target_x, float target_y, float target_z,
                     float up_x, float up_y, float up_z,
                     float fovy, int projection);
bool rl_camera3d_set_active(rl_handle_t handle);
rl_handle_t rl_camera3d_get_active();
void rl_camera3d_destroy(rl_handle_t handle);
void rl_begin_mode_3d();
void rl_end_mode_3d();
void rl_enable_lighting();
void rl_disable_lighting();
int rl_is_lighting_enabled();
void rl_set_light_direction(float x, float y, float z);
void rl_set_light_ambient(float ambient);
void rl_draw_cube(float position_x, float position_y, float position_z,
                  float width, float height, float length, rl_handle_t color);
void rl_draw_rectangle(int x, int y, int width, int height, rl_handle_t color);
void rl_update();
double rl_get_time();
int rl_measure_text(const char *text, int fontSize) ;
void rl_measure_text_ex(rl_handle_t font, const char *text, float fontSize, float spacing);



#ifdef __cplusplus
}
#endif

#endif // RL_H
