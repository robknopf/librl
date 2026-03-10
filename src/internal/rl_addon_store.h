#ifndef RL_ADDON_STORE_H
#define RL_ADDON_STORE_H

#include "rl_addon.h"

typedef struct rl_addon_entry_t {
    const char *name;
    const rl_addon_api_t *(*get_api_fn)(void);
} rl_addon_entry_t;

#if defined(__GNUC__) || defined(__clang__)
#define RL_ADDON_WEAK __attribute__((weak))
#else
#define RL_ADDON_WEAK
#endif

extern const rl_addon_api_t *rl_lua_addon_get_api(void) RL_ADDON_WEAK;

static const rl_addon_entry_t rl_addon_store[] = {
    { "lua", rl_lua_addon_get_api },
};

static const size_t rl_addon_store_count = sizeof(rl_addon_store) / sizeof(rl_addon_store[0]);

#endif // RL_ADDON_STORE_H
