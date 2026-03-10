#ifndef RL_LUA_MODULE_H
#define RL_LUA_MODULE_H

#include "rl_module.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Lua module exposes only the generic module ABI to callers.
 * VM internals remain private to the module implementation.
 */
const rl_module_api_t *rl_lua_module_get_api(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LUA_MODULE_H
