#ifndef RL_FONT_H
#define RL_FONT_H

#ifdef __cplusplus
extern "C" {
#endif

//#include <raylib.h>
#include "rl.h"

extern const rl_handle_t RL_FONT_DEFAULT;


rl_handle_t rl_font_get_next_handle() ;
rl_handle_t rl_font_create(const char *filename, float fontSize) ;
void rl_font_destroy(rl_handle_t handle) ;
rl_handle_t rl_font_get_default() ;

//void rl_font_set(rl_handle_t handle, Font font) ;
//Font rl_font_get(rl_handle_t handle) ;

void rl_font_init() ;
void rl_font_deinit();


#ifdef __cplusplus
}
#endif

#endif // RL_FONT_H