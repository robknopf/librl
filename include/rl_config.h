#ifndef RL_CONFIG_H
#define RL_CONFIG_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * High-level init configuration for librl.
 *
 * - 0 for window_width, window_height, NULL for strings / loader_cache_dir: internal defaults.
 *   window_flags is not rewritten; 0 means no Raylib window flags.
 * - The window is opened during rl_init() (after core loader setup).
 */
typedef struct rl_init_config {
  int window_width;
  int window_height;
  const char *window_title;
  unsigned int window_flags;
  const char *asset_host;
  const char *loader_cache_dir;
} rl_init_config_t;

size_t rl_init_config_sizeof(void);

#ifdef __cplusplus
}
#endif

#endif // RL_CONFIG_H
