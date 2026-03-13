#ifndef RL_LOADER_H
#define RL_LOADER_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct rl_loader_task rl_loader_task_t;

int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);
rl_loader_task_t *rl_loader_restore_fs_async(void);
rl_loader_task_t *rl_loader_import_asset_async(const char *filename);
rl_loader_task_t *rl_loader_import_assets_async(const char *const *filenames, size_t filename_count);
rl_loader_task_t *rl_loader_import_assets_from_scratch_async(size_t filename_count);
bool rl_loader_poll_task(rl_loader_task_t *task);
int rl_loader_finish_task(rl_loader_task_t *task);
void rl_loader_free_task(rl_loader_task_t *task);
bool rl_loader_is_local(const char *filename);
int rl_loader_uncache_file(const char *filename);
int rl_loader_clear_cache(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
