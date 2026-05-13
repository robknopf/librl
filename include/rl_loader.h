#ifndef RL_LOADER_H
#define RL_LOADER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*rl_loader_callback_fn)(const char *path, void *user_data);

typedef enum rl_loader_queue_task_result_t {
  RL_LOADER_QUEUE_TASK_OK = 0,
  RL_LOADER_QUEUE_TASK_ERR_INVALID = -1,
  RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL = -2,
} rl_loader_queue_task_result_t;

int rl_loader_init(const char *mount_point);
int rl_loader_init_async(const char *mount_point);
void rl_loader_deinit(void);
bool rl_loader_is_initialized(void);
int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);
const char *rl_loader_get_cache_dir(void);
float rl_loader_ping_asset_host(const char *asset_host);
bool rl_loader_is_ready(void);
rl_handle_t rl_loader_restore_fs_async(void);
rl_handle_t rl_loader_create_import_task(const char *filename);
rl_handle_t rl_loader_import_assets_async(const char *const *filenames, size_t filename_count);
rl_handle_t rl_loader_import_assets_from_scratch_async(size_t filename_count);

/**
 * Synchronously import a single asset into the loader cache.
 *
 * Resolves filename against the configured asset host, fetches the bytes via
 * fetch_url_with_path_sync, and writes them into the fileio cache so subsequent
 * rl_loader_read_local / rl_loader_is_asset_cached calls succeed. If the file
 * is already cached locally, this is a no-op (returns 0).
 *
 * On Emscripten, the underlying fetch is implemented with EM_ASYNC_JS and
 * requires the final link target to use `-sJSPI=1`. Any exported function that
 * can call this API must also be listed in `-sJSPI_EXPORTS=[...]` so the wasm
 * stack can suspend across the JS fetch.
 *
 * Does not currently follow .gltf dependencies. Use rl_loader_create_import_task
 * + poll loop if you need that.
 *
 * Returns 0 on success, non-zero on failure (HTTP status when the fetch
 * returned a status, otherwise a negative error).
 */
int rl_loader_import_asset(const char *filename);
bool rl_loader_poll_task(rl_handle_t task);
int rl_loader_finish_task(rl_handle_t task);
const char *rl_loader_get_task_path(rl_handle_t task);
void rl_loader_free_task(rl_handle_t task);
bool rl_loader_is_asset_cached(const char *filename);

typedef struct rl_loader_read_result_t {
  unsigned char *data;
  size_t size;
  int error;
} rl_loader_read_result_t;

rl_loader_read_result_t rl_loader_read_local(const char *filename);
void rl_loader_read_result_free(rl_loader_read_result_t *result);

void rl_loader_normalize_path(const char *path, char *buffer, size_t buffer_size);
int rl_loader_uncache_asset(const char *filename);
int rl_loader_clear_cache(void);

rl_loader_queue_task_result_t rl_loader_add_task(rl_handle_t task,
                                                 rl_loader_callback_fn on_success,
                                                 rl_loader_callback_fn on_failure,
                                                 void *user_data);
void rl_loader_tick(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
