#ifndef RL_RESOURCE_REGISTRY_H
#define RL_RESOURCE_REGISTRY_H

#include "rl_types.h"
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RL_RESOURCE_REGISTRY_MAX_RESOURCES 256
#define RL_RESOURCE_REGISTRY_MAX_NAME_LEN 64

typedef struct rl_resource_registry_t rl_resource_registry_t;

rl_resource_registry_t *rl_resource_registry_create(void);
void rl_resource_registry_destroy(rl_resource_registry_t *registry);

int rl_resource_registry_register(rl_resource_registry_t *registry, 
                                   const char *name, 
                                   rl_handle_t handle);

rl_handle_t rl_resource_registry_get(const rl_resource_registry_t *registry, 
                                      const char *name);

bool rl_resource_registry_has(const rl_resource_registry_t *registry, 
                               const char *name);

void rl_resource_registry_unregister(rl_resource_registry_t *registry, 
                                      const char *name);

void rl_resource_registry_clear(rl_resource_registry_t *registry);

#ifdef __cplusplus
}
#endif

#endif // RL_RESOURCE_REGISTRY_H
