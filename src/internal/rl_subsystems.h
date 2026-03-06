#ifndef RL_SUBSYSTEMS_H
#define RL_SUBSYSTEMS_H

// Internal lifecycle hooks wired by rl_init/rl_deinit.
// Keep these out of public headers to avoid exposing internal ordering details.
void rl_color_init(void);
void rl_color_deinit(void);

void rl_font_init(void);
void rl_font_deinit(void);

void rl_model_init(void);
void rl_model_deinit(void);

void rl_camera3d_init(void);
void rl_camera3d_deinit(void);

void rl_sprite3d_init(void);
void rl_sprite3d_deinit(void);

void rl_texture_init(void);
void rl_texture_deinit(void);

#endif // RL_SUBSYSTEMS_H
