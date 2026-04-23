#ifndef RL_LOADER_H
#define RL_LOADER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct rl_loader_task rl_loader_task_t;
typedef void (*rl_loader_callback_fn)(const char *path, void *user_data);

typedef enum rl_loader_queue_task_result_t {
  RL_LOADER_QUEUE_TASK_OK = 0,
  RL_LOADER_QUEUE_TASK_ERR_INVALID = -1,
  RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL = -2,
} rl_loader_queue_task_result_t;

int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);
rl_loader_task_t *rl_loader_restore_fs_async(void);
rl_loader_task_t *rl_loader_import_asset_async(const char *filename);
rl_loader_task_t *rl_loader_import_assets_async(const char *const *filenames, size_t filename_count);
rl_loader_task_t *rl_loader_import_assets_from_scratch_async(size_t filename_count);
bool rl_loader_poll_task(rl_loader_task_t *task);
int rl_loader_finish_task(rl_loader_task_t *task);
const char *rl_loader_get_task_path(rl_loader_task_t *task);
void rl_loader_free_task(rl_loader_task_t *task);
bool rl_loader_is_local(const char *filename);

typedef struct rl_loader_read_result_t {
  unsigned char *data;
  size_t size;
  int error;
} rl_loader_read_result_t;

rl_loader_read_result_t rl_loader_read_local(const char *filename);
void rl_loader_read_result_free(rl_loader_read_result_t *result);

void rl_loader_normalize_path(const char *path, char *buffer, size_t buffer_size);
int rl_loader_uncache_file(const char *filename);
int rl_loader_clear_cache(void);

rl_loader_queue_task_result_t rl_loader_queue_task(rl_loader_task_t *task,
                                                   const char *path,
                                                   rl_loader_callback_fn on_success,
                                                   rl_loader_callback_fn on_failure,
                                                   void *user_data);
void rl_loader_tick(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
