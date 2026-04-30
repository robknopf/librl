#include "example_task_group.h"

#include <stdio.h>
#include <string.h>

static void example_task_group_clear_entry(example_task_group_entry_t *entry) {
  if (entry == NULL) {
    return;
  }

  if (entry->task != NULL) {
    rl_loader_free_task(entry->task);
  }

  memset(entry, 0, sizeof(*entry));
}

void example_task_group_init(example_task_group_t *group, void *user_data,
                             example_task_group_completion_fn on_complete) {
  if (group == NULL) {
    return;
  }

  memset(group, 0, sizeof(*group));
  group->user_data = user_data;
  group->on_complete = on_complete;
}

void example_task_group_reset(example_task_group_t *group) {
  size_t i = 0;

  if (group == NULL) {
    return;
  }

  for (i = 0; i < EXAMPLE_TASK_GROUP_CAPACITY; i++) {
    example_task_group_clear_entry(&group->entries[i]);
  }
}

int example_task_group_add_import_task(example_task_group_t *group, int id,
                                       const char *path,
                                       const void *user_data,
                                       size_t user_data_size) {
  size_t i = 0;

  if (group == NULL || path == NULL || path[0] == '\0') {
    return EXAMPLE_TASK_GROUP_ERR_INVALID_ARGS;
  }

  if (user_data_size > EXAMPLE_TASK_GROUP_USER_DATA_CAPACITY) {
    return EXAMPLE_TASK_GROUP_ERR_USER_DATA_TOO_LARGE;
  }

  for (i = 0; i < EXAMPLE_TASK_GROUP_CAPACITY; i++) {
    example_task_group_entry_t *entry = &group->entries[i];
    if (entry->in_use) {
      continue;
    }

    memset(entry, 0, sizeof(*entry));
    entry->task = rl_loader_create_import_task(path);
    if (entry->task == NULL) {
      memset(entry, 0, sizeof(*entry));
      return EXAMPLE_TASK_GROUP_ERR_TASK_CREATE_FAILED;
    }

    entry->in_use = true;
    entry->id = id;
    entry->user_data_size = user_data_size;
    (void)snprintf(entry->path, sizeof(entry->path), "%s", path);
    if (user_data != NULL && user_data_size > 0) {
      memcpy(entry->user_data, user_data, user_data_size);
    }
    return EXAMPLE_TASK_GROUP_OK;
  }

  return EXAMPLE_TASK_GROUP_ERR_GROUP_FULL;
}

void example_task_group_poll(example_task_group_t *group) {
  size_t i = 0;

  if (group == NULL) {
    return;
  }

  for (i = 0; i < EXAMPLE_TASK_GROUP_CAPACITY; i++) {
    example_task_group_entry_t *entry = &group->entries[i];
    int rc = 0;

    if (!entry->in_use || entry->task == NULL) {
      continue;
    }

    if (!rl_loader_poll_task(entry->task)) {
      continue;
    }

    rc = rl_loader_finish_task(entry->task);
    rl_loader_free_task(entry->task);
    entry->task = NULL;

    if (group->on_complete != NULL) {
      group->on_complete(entry, rc, group->user_data);
    }

    memset(entry, 0, sizeof(*entry));
  }
}
