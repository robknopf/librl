#ifndef RL_LOADER_H
#define RL_LOADER_H

#ifdef __cplusplus
extern "C" {
#endif

int rl_loader_init(const char *mount_point);
void rl_loader_deinit(void);

#ifdef __cplusplus
}
#endif

#endif // RL_LOADER_H
