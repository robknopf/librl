#ifndef RL_INTERNAL_LOADER_H
#define RL_INTERNAL_LOADER_H

int rl_loader_init(const char *mount_point);
bool rl_loader_is_ready(void);
void rl_loader_deinit(void);

#endif // RL_INTERNAL_LOADER_H
