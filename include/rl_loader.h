#ifndef RL_LOADER_H
#define RL_LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);
int rl_loader_cache_file(const char *filename);
int rl_loader_uncache_file(const char *filename);
int rl_loader_clear_cache(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
