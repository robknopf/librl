#ifndef RL_DEBUG_H
#define RL_DEBUG_H

#ifdef __cplusplus
extern "C" {
#endif

void rl_debug_enable_fps(int x, int y, int font_size, const char *font_path);
void rl_debug_disable(void);

#ifdef __cplusplus
}
#endif

#endif // RL_DEBUG_H
