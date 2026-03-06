#ifndef RL_LOADER_H
#define RL_LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

int rl_loader_set_asset_host(const char *asset_host);
const char *rl_loader_get_asset_host(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
