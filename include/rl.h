#ifndef RL_H
#define RL_H

#include <stdbool.h>
#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

void rl_init();
void rl_deinit();
int rl_set_asset_host(const char *asset_host);
const char *rl_get_asset_host(void);
void rl_init_window(int width, int height, const char *title);
void rl_set_window_title(const char *title);
void rl_set_window_size(int width, int height);
vec2_t rl_get_screen_size(void);
int rl_get_monitor_count();
int rl_get_current_monitor();
void rl_set_window_monitor(int monitor);
vec2_t rl_get_monitor_position(int monitor);
vec2_t rl_get_window_position(void);
vec2_t rl_get_mouse_position(void);
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
rl_handle_t rl_music_create(const char *filename);
void rl_music_destroy(rl_handle_t handle);
bool rl_music_play(rl_handle_t handle);
bool rl_music_pause(rl_handle_t handle);
bool rl_music_stop(rl_handle_t handle);
bool rl_music_set_loop(rl_handle_t handle, bool loop);
bool rl_music_set_volume(rl_handle_t handle, float volume);
bool rl_music_is_playing(rl_handle_t handle);
bool rl_music_update(rl_handle_t handle);
void rl_music_update_all(void);
rl_handle_t rl_sound_create(const char *filename);
void rl_sound_destroy(rl_handle_t handle);
bool rl_sound_play(rl_handle_t handle);
bool rl_sound_pause(rl_handle_t handle);
bool rl_sound_resume(rl_handle_t handle);
bool rl_sound_stop(rl_handle_t handle);
bool rl_sound_set_volume(rl_handle_t handle, float volume);
bool rl_sound_set_pitch(rl_handle_t handle, float pitch);
bool rl_sound_set_pan(rl_handle_t handle, float pan);
bool rl_sound_is_playing(rl_handle_t handle);
void rl_enable_lighting();
void rl_disable_lighting();
int rl_is_lighting_enabled();
void rl_set_light_direction(float x, float y, float z);
void rl_set_light_ambient(float ambient);
void rl_draw_cube(float position_x, float position_y, float position_z,
                  float width, float height, float length, rl_handle_t color);
void rl_draw_rectangle(int x, int y, int width, int height, rl_handle_t color);
void rl_update(void);
double rl_get_time();
int rl_measure_text(const char *text, int fontSize) ;
vec2_t rl_measure_text_ex(rl_handle_t font, const char *text, float fontSize, float spacing);



#ifdef __cplusplus
}
#endif

#endif // RL_H
