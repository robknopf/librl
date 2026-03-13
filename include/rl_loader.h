#ifndef RL_LOADER_H
#define RL_LOADER_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct rl_loader_op rl_loader_op_t;

int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);
rl_loader_op_t *rl_loader_begin_restore(void);
rl_loader_op_t *rl_loader_begin_prepare_file(const char *filename);
rl_loader_op_t *rl_loader_begin_prepare_model(const char *filename);
rl_loader_op_t *rl_loader_begin_prepare_paths(const char *const *filenames, size_t filename_count);
rl_loader_op_t *rl_loader_begin_prepare_paths_from_scratch(size_t filename_count);
bool rl_loader_poll_op(rl_loader_op_t *op);
int rl_loader_finish_op(rl_loader_op_t *op);
void rl_loader_free_op(rl_loader_op_t *op);
bool rl_loader_is_local(const char *filename);
int rl_loader_uncache_file(const char *filename);
int rl_loader_clear_cache(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
