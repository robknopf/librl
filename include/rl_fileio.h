#ifndef RL_FILEIO_H
#define RL_FILEIO_H

#include <stdbool.h>
#include <stddef.h>

#include "rl_types.h"

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*rl_fileio_callback_fn)(const char *path, void *user_data);

/* Lifecycle */
int         rl_fileio_init(const char *base_dir);
int         rl_fileio_init_async(const char *base_dir);
void        rl_fileio_deinit(void);
rl_handle_t rl_fileio_deinit_async(void);
bool        rl_fileio_is_initialized(void);
bool        rl_fileio_is_ready(void);
int         rl_fileio_flush(void);
rl_handle_t rl_fileio_restore_async(void);
const char *rl_fileio_get_base_dir(void);

/* Asset host — base URL for relative paths in ensure */
int         rl_fileio_set_asset_host(const char *host);
const char *rl_fileio_get_asset_host(void);
float       rl_fileio_ping_asset_host(const char *host);

/* File operations — all paths are jailed to base_dir */
bool rl_fileio_exists(const char *path);
int  rl_fileio_read(const char *path, unsigned char **out_data, size_t *out_size);
void rl_fileio_read_free(unsigned char *data);
int  rl_fileio_write(const char *path, const unsigned char *data, size_t size);
int  rl_fileio_remove(const char *path);
int  rl_fileio_mkdir(const char *path);
int  rl_fileio_rmdir(const char *path);
int  rl_fileio_clear(void);
void rl_fileio_normalize_path(const char *path, char *buf, size_t buf_size);

/* Ensure — make a file local, fetching if absent.
 *
 * If local_path already exists on disk, returns 0 immediately (no fetch).
 * Otherwise fetches from src. If src is NULL, resolves local_path against the
 * configured asset host. Returns an error if src is NULL and no host is set.
 *
 * The synchronous variant requires JSPI_EXPORTS on wasm (uses EM_ASYNC_JS
 * internally). The async variant returns a handle to poll. */
int         rl_fileio_ensure(const char *local_path, const char *src);
rl_handle_t rl_fileio_ensure_async(const char *local_path, const char *src);
bool        rl_fileio_poll_task(rl_handle_t handle);
int         rl_fileio_finish_task(rl_handle_t handle);
const char *rl_fileio_get_task_path(rl_handle_t handle);
void        rl_fileio_free_task(rl_handle_t handle);

/* Group async — ensure a set of files in parallel */
rl_handle_t rl_fileio_ensure_group_async(const char *const *paths, size_t count);
rl_handle_t rl_fileio_ensure_group_from_scratch_async(size_t count);

/* Managed queue — fire callbacks when tasks complete, pumped each frame */
typedef enum {
    RL_FILEIO_ADD_TASK_OK             =  0,
    RL_FILEIO_ADD_TASK_ERR_INVALID    = -1,
    RL_FILEIO_ADD_TASK_ERR_QUEUE_FULL = -2,
} rl_fileio_add_task_result_t;

rl_fileio_add_task_result_t rl_fileio_add_task(rl_handle_t handle,
                                               rl_fileio_callback_fn on_success,
                                               rl_fileio_callback_fn on_failure,
                                               void *user_data);
void rl_fileio_tick(void);

#ifdef __cplusplus
}
#endif

#endif /* RL_FILEIO_H */
