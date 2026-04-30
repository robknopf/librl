#ifndef EXAMPLES_C_LUA_EXAMPLE_TASK_GROUP_H
#define EXAMPLES_C_LUA_EXAMPLE_TASK_GROUP_H

#include "rl_loader.h"

#include <stdbool.h>
#include <stddef.h>

#define EXAMPLE_TASK_GROUP_CAPACITY 64
#define EXAMPLE_TASK_GROUP_PATH_CAPACITY 256
#define EXAMPLE_TASK_GROUP_USER_DATA_CAPACITY 64

typedef struct example_task_group_entry_t {
  bool in_use;
  int id;
  rl_loader_task_t *task;
  char path[EXAMPLE_TASK_GROUP_PATH_CAPACITY];
  size_t user_data_size;
  unsigned char user_data[EXAMPLE_TASK_GROUP_USER_DATA_CAPACITY];
} example_task_group_entry_t;

typedef void (*example_task_group_completion_fn)(
    example_task_group_entry_t *entry, int rc, void *group_user_data);

typedef struct example_task_group_t {
  example_task_group_entry_t entries[EXAMPLE_TASK_GROUP_CAPACITY];
  void *user_data;
  example_task_group_completion_fn on_complete;
} example_task_group_t;

typedef enum example_task_group_result_t {
  EXAMPLE_TASK_GROUP_OK = 0,
  EXAMPLE_TASK_GROUP_ERR_INVALID_ARGS = -1,
  EXAMPLE_TASK_GROUP_ERR_GROUP_FULL = -2,
  EXAMPLE_TASK_GROUP_ERR_USER_DATA_TOO_LARGE = -3,
  EXAMPLE_TASK_GROUP_ERR_TASK_CREATE_FAILED = -4
} example_task_group_result_t;

void example_task_group_init(example_task_group_t *group, void *user_data,
                             example_task_group_completion_fn on_complete);
void example_task_group_reset(example_task_group_t *group);
int example_task_group_add_import_task(example_task_group_t *group, int id,
                                       const char *path,
                                       const void *user_data,
                                       size_t user_data_size);
void example_task_group_poll(example_task_group_t *group);

static inline int example_task_group_entry_id(
    const example_task_group_entry_t *entry) {
  return entry != NULL ? entry->id : 0;
}

static inline const char *example_task_group_entry_path(
    const example_task_group_entry_t *entry) {
  return entry != NULL ? entry->path : NULL;
}

static inline const void *example_task_group_entry_user_data(
    const example_task_group_entry_t *entry) {
  return entry != NULL ? entry->user_data : NULL;
}

#endif
