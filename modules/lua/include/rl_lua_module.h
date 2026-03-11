#ifndef RL_LUA_MODULE_H
#define RL_LUA_MODULE_H

#include "rl_module.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef struct rl_lua_script_config_t {
    int width;
    int height;
    int target_fps;
    unsigned int flags;
    char title[256];
} rl_lua_script_config_t;

/* Lua module exposes only the generic module ABI to callers.
 * VM internals remain private to the module implementation.
 */
const rl_module_api_t *rl_lua_module_get_api(void);
int rl_lua_module_get_script_config(void *module_state, rl_lua_script_config_t *out_config);
int rl_lua_module_call_init(void *module_state);

#ifdef __cplusplus
}
#endif

#endif // RL_LUA_MODULE_H
