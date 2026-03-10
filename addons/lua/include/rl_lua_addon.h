#ifndef RL_LUA_ADDON_H
#define RL_LUA_ADDON_H

#include "rl_addon.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Lua addon exposes only the generic addon ABI to callers.
 * VM internals remain private to the addon implementation.
 */
const rl_addon_api_t *rl_lua_addon_get_api(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LUA_ADDON_H
