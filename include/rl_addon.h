#ifndef RL_ADDON_H
#define RL_ADDON_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum rl_addon_log_level_t {
    RL_ADDON_LOG_TRACE = 0,
    RL_ADDON_LOG_DEBUG = 1,
    RL_ADDON_LOG_INFO = 2,
    RL_ADDON_LOG_WARN = 3,
    RL_ADDON_LOG_ERROR = 4
} rl_addon_log_level_t;

typedef void (*rl_addon_log_fn)(void *user_data, int level, const char *message);
typedef void *(*rl_addon_alloc_fn)(size_t size, void *user_data);
typedef void (*rl_addon_free_fn)(void *ptr, void *user_data);

typedef struct rl_addon_host_api_t {
    void *user_data;
    rl_addon_log_fn log;
    rl_addon_alloc_fn alloc;
    rl_addon_free_fn free;
} rl_addon_host_api_t;

typedef int (*rl_addon_init_fn)(const rl_addon_host_api_t *host, void **addon_state);
typedef void (*rl_addon_deinit_fn)(void *addon_state);
typedef int (*rl_addon_update_fn)(void *addon_state, float dt_seconds);

typedef struct rl_addon_api_t {
    const char *name;
    int abi_version;
    rl_addon_init_fn init;
    rl_addon_deinit_fn deinit;
    rl_addon_update_fn update;
} rl_addon_api_t;

#define RL_ADDON_ABI_VERSION 1

void rl_addon_log(const rl_addon_host_api_t *host, int level, const char *message);
void *rl_addon_alloc(const rl_addon_host_api_t *host, size_t size);
void rl_addon_free(const rl_addon_host_api_t *host, void *ptr);
int rl_addon_api_validate(const rl_addon_api_t *api, char *error, size_t error_size);
int rl_addon_init_instance(const rl_addon_api_t *api, const rl_addon_host_api_t *host, void **addon_state,
                           char *error, size_t error_size);
void rl_addon_deinit_instance(const rl_addon_api_t *api, void *addon_state);
const rl_addon_api_t *rl_addon_get_api(const char *name);
int rl_addon_init(const char *name, const rl_addon_host_api_t *host, const rl_addon_api_t **out_api,
                  void **addon_state, char *error, size_t error_size);

#define RL_ADDON_DEFINE(GETTER_FN, ADDON_NAME, INIT_FN, DEINIT_FN, UPDATE_FN) \
    const rl_addon_api_t *GETTER_FN(void)                                      \
    {                                                                           \
        static const rl_addon_api_t api = {                                    \
            (ADDON_NAME),                                                       \
            RL_ADDON_ABI_VERSION,                                               \
            (INIT_FN),                                                          \
            (DEINIT_FN),                                                        \
            (UPDATE_FN)                                                         \
        };                                                                      \
        return &api;                                                            \
    }

#ifdef __cplusplus
}
#endif

#endif // RL_ADDON_H
