#include "rl_resource_registry.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct rl_resource_entry_t {
  char name[RL_RESOURCE_REGISTRY_MAX_NAME_LEN];
  rl_handle_t handle;
  bool in_use;
} rl_resource_entry_t;

struct rl_resource_registry_t {
  rl_resource_entry_t entries[RL_RESOURCE_REGISTRY_MAX_RESOURCES];
};

rl_resource_registry_t *rl_resource_registry_create(void) {
  rl_resource_registry_t *registry = (rl_resource_registry_t *)calloc(1, sizeof(rl_resource_registry_t));
  return registry;
}

void rl_resource_registry_destroy(rl_resource_registry_t *registry) {
  if (registry != NULL) {
    free(registry);
  }
}

int rl_resource_registry_register(rl_resource_registry_t *registry, 
                                   const char *name, 
                                   rl_handle_t handle) {
  int i = 0;
  
  if (registry == NULL || name == NULL || name[0] == '\0') {
    return -1;
  }
  
  for (i = 0; i < RL_RESOURCE_REGISTRY_MAX_RESOURCES; i++) {
    if (registry->entries[i].in_use && 
        strcmp(registry->entries[i].name, name) == 0) {
      registry->entries[i].handle = handle;
      return 0;
    }
  }
  
  for (i = 0; i < RL_RESOURCE_REGISTRY_MAX_RESOURCES; i++) {
    if (!registry->entries[i].in_use) {
      snprintf(registry->entries[i].name, RL_RESOURCE_REGISTRY_MAX_NAME_LEN, "%s", name);
      registry->entries[i].handle = handle;
      registry->entries[i].in_use = true;
      return 0;
    }
  }
  
  return -1;
}

rl_handle_t rl_resource_registry_get(const rl_resource_registry_t *registry, 
                                      const char *name) {
  int i = 0;
  
  if (registry == NULL || name == NULL) {
    return 0;
  }
  
  for (i = 0; i < RL_RESOURCE_REGISTRY_MAX_RESOURCES; i++) {
    if (registry->entries[i].in_use && 
        strcmp(registry->entries[i].name, name) == 0) {
      return registry->entries[i].handle;
    }
  }
  
  return 0;
}

bool rl_resource_registry_has(const rl_resource_registry_t *registry, 
                               const char *name) {
  return rl_resource_registry_get(registry, name) != 0;
}

void rl_resource_registry_unregister(rl_resource_registry_t *registry, 
                                      const char *name) {
  int i = 0;
  
  if (registry == NULL || name == NULL) {
    return;
  }
  
  for (i = 0; i < RL_RESOURCE_REGISTRY_MAX_RESOURCES; i++) {
    if (registry->entries[i].in_use && 
        strcmp(registry->entries[i].name, name) == 0) {
      memset(&registry->entries[i], 0, sizeof(rl_resource_entry_t));
      return;
    }
  }
}

void rl_resource_registry_clear(rl_resource_registry_t *registry) {
  if (registry == NULL) {
    return;
  }
  
  memset(registry->entries, 0, sizeof(registry->entries));
}
