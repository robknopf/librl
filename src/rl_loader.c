#include "rl_loader.h"
#include "rl_logger.h"

#include <raylib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <ctype.h>
#include <errno.h>
#include <time.h>
#include <dirent.h>
#include <sys/stat.h>

#include "fileio/fileio.h"
#include "fileio/fileio_common.h"
#include "fetch_url/fetch_url.h"
#include "lru_cache/lru_cache.h"
#include "path/path.h"
#include "json/json.h"
#include "rl_scratch.h"
#include "internal/exports.h"

#define RL_LOADER_DEFAULT_MOUNT_POINT "cache"
#ifndef RL_LOADER_DEFAULT_ASSET_HOST
#define RL_LOADER_DEFAULT_ASSET_HOST "https://localhost:4444"
#endif
#define RL_LOADER_CACHE_MAX_BYTES (32u * 1024u * 1024u)
#define RL_LOADER_CACHE_MAX_ENTRIES 256u
#define RL_LOADER_CACHE_MAX_ENTRY_BYTES (8u * 1024u * 1024u)
#define RL_LOADER_MAX_ASSET_HOST_LENGTH 256u
#define RL_LOADER_FETCH_TIMEOUT_MS 5000
#define RL_LOADER_RESTORE_TIMEOUT_MS 5000

static bool rl_loader_initialized = false;
static lru_cache_t *rl_loader_memory_cache = NULL;
static char rl_loader_asset_host[RL_LOADER_MAX_ASSET_HOST_LENGTH] = RL_LOADER_DEFAULT_ASSET_HOST;
static fileio_sync_op_t *rl_loader_restore_barrier = NULL;
static bool rl_loader_restore_ready = false;
static bool rl_loader_restore_failed = false;
static clock_t rl_loader_restore_started_at = 0;

static void rl_loader_init_asset_host_from_env(void)
{
    const char *env_asset_host = getenv("RL_ASSET_HOST");

    if (env_asset_host == NULL || env_asset_host[0] == '\0') {
        return;
    }

    rl_loader_set_asset_host(env_asset_host);
}

typedef enum
{
    RL_LOADER_TASK_KIND_NONE = 0,
    RL_LOADER_TASK_KIND_RESTORE_FS = 1,
    RL_LOADER_TASK_KIND_IMPORT_ASSET = 2,
    RL_LOADER_TASK_KIND_IMPORT_ASSETS = 3
} rl_loader_task_kind_t;

typedef enum
{
    RL_LOADER_PREPARE_STATE_INIT = 0,
    RL_LOADER_PREPARE_STATE_FETCHING_ROOT = 1,
    RL_LOADER_PREPARE_STATE_PARSING_ROOT = 2,
    RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY = 3,
    RL_LOADER_PREPARE_STATE_DONE = 4
} rl_loader_prepare_state_t;

struct rl_loader_task
{
    rl_loader_task_kind_t kind;
    int status;
    bool done;
    bool should_cache_in_memory;
    rl_loader_prepare_state_t prepare_state;
    char fetch_host[RL_LOADER_MAX_ASSET_HOST_LENGTH];
    char resolved_path[FILEIO_MAX_PATH_LENGTH * 2];
    char root_dir[FILEIO_MAX_PATH_LENGTH * 2];
    char pending_fetch_path[FILEIO_MAX_PATH_LENGTH * 2];
    char **dependency_paths;
    size_t dependency_count;
    size_t dependency_index;
    char **batch_paths;
    size_t batch_count;
    size_t batch_index;
    rl_loader_task_t *child_task;
    fileio_sync_op_t *fileio_op;
    fetch_url_op_t *fetch_op;
};

static void rl_loader_task_complete(rl_loader_task_t *task, int status);
static int rl_loader_cache_local_file_if_needed(const char *resolved_path);
static void rl_loader_get_parent_dir(const char *resolved_path, char *buffer, size_t buffer_size);
static int rl_loader_start_fetch(rl_loader_task_t *task, const char *path);

static bool rl_loader_is_http_url(const char *path)
{
    if (!path) {
        return false;
    }
    return (strncmp(path, "http://", 7) == 0) || (strncmp(path, "https://", 8) == 0);
}

static bool rl_loader_split_url(const char *url, char *host, size_t host_size, char *path, size_t path_size)
{
    const char *scheme = strstr(url, "://");
    const char *path_start = NULL;
    const char *query_start = NULL;
    size_t host_len = 0;
    size_t path_len = 0;

    if (!scheme) {
        return false;
    }

    path_start = strchr(scheme + 3, '/');
    if (!path_start) {
        return false;
    }

    host_len = (size_t)(path_start - url);
    if (host_len + 1 > host_size) {
        return false;
    }
    memcpy(host, url, host_len);
    host[host_len] = '\0';

    path_start++;
    query_start = strpbrk(path_start, "?#");
    if (query_start) {
        path_len = (size_t)(query_start - path_start);
    } else {
        path_len = strlen(path_start);
    }

    if (path_len == 0 || path_len + 1 > path_size) {
        return false;
    }
    memcpy(path, path_start, path_len);
    path[path_len] = '\0';

    return true;
}

static const char *rl_loader_strip_leading_slash(const char *path)
{
    if (path && path[0] == '/') {
        return path + 1;
    }
    return path;
}

static const char *rl_loader_get_extension(const char *path)
{
    const char *dot = NULL;
    const char *slash = NULL;
    if (!path) {
        return NULL;
    }

    dot = strrchr(path, '.');
    if (!dot) {
        return NULL;
    }

    slash = strrchr(path, '/');
    if (slash && dot < slash) {
        return NULL;
    }

    return dot;
}

static bool rl_loader_ext_eq(const char *ext, const char *target)
{
    size_t i = 0;
    if (!ext || !target) {
        return false;
    }

    while (ext[i] != '\0' && target[i] != '\0')
    {
        if ((char)tolower((unsigned char)ext[i]) != (char)tolower((unsigned char)target[i])) {
            return false;
        }
        i++;
    }

    return ext[i] == '\0' && target[i] == '\0';
}

static bool rl_loader_should_memory_cache_path(const char *resolved_path)
{
    const char *ext = rl_loader_get_extension(resolved_path);
    if (!ext) {
        return false;
    }

    // Keep cache selective so RAM usage is predictable.
    return rl_loader_ext_eq(ext, ".glb") ||
           rl_loader_ext_eq(ext, ".gltf") ||
           rl_loader_ext_eq(ext, ".ttf") ||
           rl_loader_ext_eq(ext, ".otf") ||
           rl_loader_ext_eq(ext, ".png");
}

static bool rl_loader_is_dependency_bearing_asset_path(const char *path)
{
    const char *ext = rl_loader_get_extension(path);

    return ext != NULL && rl_loader_ext_eq(ext, ".gltf");
}

static bool rl_loader_restore_barrier_poll(void)
{
    int restore_rc = 0;
    clock_t now = 0;
    double elapsed_ms = 0.0;

    if (rl_loader_restore_ready) {
        return true;
    }

    if (rl_loader_restore_barrier == NULL) {
        rl_loader_restore_ready = true;
        return true;
    }

    now = clock();
    if (rl_loader_restore_started_at != 0 && now != (clock_t)-1) {
        elapsed_ms = ((double)(now - rl_loader_restore_started_at) * 1000.0) / (double)CLOCKS_PER_SEC;
        if (elapsed_ms >= (double)RL_LOADER_RESTORE_TIMEOUT_MS) {
            fileio_sync_op_free(rl_loader_restore_barrier);
            rl_loader_restore_barrier = NULL;
            rl_loader_restore_ready = true;
            rl_loader_restore_failed = true;
            log_warn("rl_loader: cache restore timed out after %d ms; falling back to network fetch",
                     RL_LOADER_RESTORE_TIMEOUT_MS);
            return true;
        }
    }

    if (!fileio_sync_poll(rl_loader_restore_barrier)) {
        return false;
    }

    restore_rc = fileio_sync_finish(rl_loader_restore_barrier);
    fileio_sync_op_free(rl_loader_restore_barrier);
    rl_loader_restore_barrier = NULL;
    rl_loader_restore_ready = true;
    rl_loader_restore_failed = (restore_rc != 0);
    if (rl_loader_restore_failed) {
        log_warn("rl_loader: cache restore failed; falling back to network fetch");
    }

    return true;
}

static int rl_loader_prepare_single_asset(rl_loader_task_t *task)
{
    if (!task) {
        return -1;
    }

    task->should_cache_in_memory = rl_loader_should_memory_cache_path(task->resolved_path);

    if (fileio_exists(task->resolved_path)) {
        rl_loader_task_complete(task, rl_loader_cache_local_file_if_needed(task->resolved_path));
        return 0;
    }

    if (rl_loader_start_fetch(task, task->resolved_path) != 0) {
        return -1;
    }
    task->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_ROOT;
    return 0;
}

static int rl_loader_prepare_import_asset(rl_loader_task_t *task)
{
    if (!task) {
        return -1;
    }

    task->should_cache_in_memory = rl_loader_should_memory_cache_path(task->resolved_path);

    if (!rl_loader_is_dependency_bearing_asset_path(task->resolved_path)) {
        return rl_loader_prepare_single_asset(task);
    }

    rl_loader_get_parent_dir(task->resolved_path, task->root_dir, sizeof(task->root_dir));

    if (fileio_exists(task->resolved_path)) {
        task->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
        return 0;
    }

    if (rl_loader_start_fetch(task, task->resolved_path) != 0) {
        return -1;
    }
    task->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_ROOT;
    return 0;
}

static void rl_loader_task_complete(rl_loader_task_t *task, int status)
{
    if (!task) {
        return;
    }

    task->status = status;
    task->done = true;
    task->prepare_state = RL_LOADER_PREPARE_STATE_DONE;
}

static void rl_loader_cache_memory_copy_if_needed(const char *resolved_path,
                                                  const unsigned char *data,
                                                  size_t size)
{
    if (!resolved_path || !data || size == 0) {
        return;
    }

    if (rl_loader_memory_cache == NULL) {
        return;
    }

    if (!rl_loader_should_memory_cache_path(resolved_path)) {
        return;
    }

    if (size > RL_LOADER_CACHE_MAX_ENTRY_BYTES) {
        return;
    }

    lru_cache_put_copy(rl_loader_memory_cache, resolved_path, data, size);
}

static int rl_loader_cache_local_file_if_needed(const char *resolved_path)
{
    fileio_read_result_t result = {0};

    if (!resolved_path || resolved_path[0] == '\0') {
        return -1;
    }

    if (!rl_loader_should_memory_cache_path(resolved_path) || rl_loader_memory_cache == NULL) {
        return fileio_exists(resolved_path) ? 0 : -1;
    }

    result = fileio_read(resolved_path);
    if (result.error != 0 || result.data == NULL || result.size == 0) {
        if (result.data) {
            free(result.data);
        }
        return -1;
    }

    rl_loader_cache_memory_copy_if_needed(resolved_path, result.data, result.size);
    free(result.data);
    return 0;
}

static void rl_loader_get_parent_dir(const char *resolved_path, char *buffer, size_t buffer_size)
{
    const char *slash = NULL;
    size_t dir_len = 0;

    if (!buffer || buffer_size == 0) {
        return;
    }

    buffer[0] = '\0';
    if (!resolved_path || resolved_path[0] == '\0') {
        return;
    }

    slash = strrchr(resolved_path, '/');
    if (!slash) {
        return;
    }

    dir_len = (size_t)(slash - resolved_path);
    if (dir_len >= buffer_size) {
        dir_len = buffer_size - 1;
    }

    memcpy(buffer, resolved_path, dir_len);
    buffer[dir_len] = '\0';
}

static int rl_loader_resolve_prepare_target(const char *filename,
                                            char *host,
                                            size_t host_size,
                                            char *resolved_path,
                                            size_t resolved_path_size)
{
    const char *relative_path = NULL;

    if (!filename || !host || !resolved_path || host_size == 0 || resolved_path_size == 0) {
        return -1;
    }

    if (rl_loader_is_http_url(filename)) {
        return rl_loader_split_url(filename, host, host_size, resolved_path, resolved_path_size) ? 0 : -1;
    }

    relative_path = rl_loader_strip_leading_slash(filename);
    if (!relative_path || relative_path[0] == '\0') {
        return -1;
    }

    if (snprintf(host, host_size, "%s", rl_loader_asset_host) >= (int)host_size) {
        return -1;
    }
    if (snprintf(resolved_path, resolved_path_size, "%s", relative_path) >= (int)resolved_path_size) {
        return -1;
    }

    return 0;
}

static int rl_loader_append_dependency_path(rl_loader_task_t *task, const char *dependency_path)
{
    char **next_paths = NULL;
    char *copy = NULL;

    if (!task || !dependency_path || dependency_path[0] == '\0') {
        return -1;
    }

    copy = (char *)malloc(strlen(dependency_path) + 1);
    if (!copy) {
        return -1;
    }
    strcpy(copy, dependency_path);

    next_paths = (char **)realloc(task->dependency_paths, sizeof(char *) * (task->dependency_count + 1));
    if (!next_paths) {
        free(copy);
        return -1;
    }

    task->dependency_paths = next_paths;
    task->dependency_paths[task->dependency_count++] = copy;
    return 0;
}

static bool rl_loader_should_skip_dependency_uri(const char *uri)
{
    if (!uri || uri[0] == '\0') {
        return true;
    }

    return strncmp(uri, "data:", 5) == 0;
}

static int rl_loader_dependency_uri_to_local_path(const char *root_dir,
                                                  const char *uri,
                                                  char *resolved_path,
                                                  size_t resolved_path_size)
{
    char joined_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};

    if (!uri || !resolved_path || resolved_path_size == 0) {
        return -1;
    }

    if (rl_loader_should_skip_dependency_uri(uri)) {
        return 1;
    }

    if (rl_loader_is_http_url(uri)) {
        char host[RL_LOADER_MAX_ASSET_HOST_LENGTH] = {0};
        return rl_loader_split_url(uri, host, sizeof(host), resolved_path, resolved_path_size) ? 0 : -1;
    }

    if (root_dir && root_dir[0] != '\0') {
        path_join(root_dir, uri, joined_path, sizeof(joined_path));
    } else {
        snprintf(joined_path, sizeof(joined_path), "%s", uri);
    }
    path_normalize(joined_path, resolved_path, resolved_path_size);
    return resolved_path[0] != '\0' ? 0 : -1;
}

static int rl_loader_collect_gltf_dependency_uris(rl_loader_task_t *task,
                                                  const unsigned char *json_bytes,
                                                  size_t json_size)
{
    json_value_t *root = NULL;
    const json_value_t *buffers = NULL;
    const json_value_t *images = NULL;
    const json_value_t *entry = NULL;
    int index = 0;

    if (!task || !json_bytes || json_size == 0) {
        return -1;
    }

    root = json_parse_with_length((const char *)json_bytes, json_size);
    if (!root) {
        return -1;
    }

    buffers = json_object_get(root, "buffers");
    if (json_is_array(buffers)) {
        for (index = 0; index < json_array_size(buffers); ++index) {
            const json_value_t *uri = NULL;
            char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};
            int rc = 0;

            entry = json_array_get(buffers, index);
            uri = json_object_get(entry, "uri");
            if (!json_is_string(uri) || json_get_string(uri) == NULL) {
                continue;
            }

            rc = rl_loader_dependency_uri_to_local_path(task->root_dir,
                                                        json_get_string(uri),
                                                        resolved_path,
                                                        sizeof(resolved_path));
            if (rc == 1) {
                continue;
            }
            if (rc != 0 || rl_loader_append_dependency_path(task, resolved_path) != 0) {
                json_delete(root);
                return -1;
            }
        }
    }

    images = json_object_get(root, "images");
    if (json_is_array(images)) {
        for (index = 0; index < json_array_size(images); ++index) {
            const json_value_t *uri = NULL;
            char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};
            int rc = 0;

            entry = json_array_get(images, index);
            uri = json_object_get(entry, "uri");
            if (!json_is_string(uri) || json_get_string(uri) == NULL) {
                continue;
            }

            rc = rl_loader_dependency_uri_to_local_path(task->root_dir,
                                                        json_get_string(uri),
                                                        resolved_path,
                                                        sizeof(resolved_path));
            if (rc == 1) {
                continue;
            }
            if (rc != 0 || rl_loader_append_dependency_path(task, resolved_path) != 0) {
                json_delete(root);
                return -1;
            }
        }
    }

    json_delete(root);
    return 0;
}

static int rl_loader_start_fetch(rl_loader_task_t *task, const char *path)
{
    char full_url[512];

    if (!task || !path || path[0] == '\0') {
        return -1;
    }

    if (task->fetch_op != NULL) {
        fetch_url_op_free(task->fetch_op);
        task->fetch_op = NULL;
    }

    if (path[0] == '/') {
        return -1;
    }
    snprintf(full_url, sizeof(full_url), "%s/%s", task->fetch_host, path);
    if (fetch_url_head(full_url, RL_LOADER_FETCH_TIMEOUT_MS) != 0) {
        return -1;
    }

    snprintf(task->pending_fetch_path, sizeof(task->pending_fetch_path), "%s", path);
    task->fetch_op = fetch_url_with_path_async(task->fetch_host, path, RL_LOADER_FETCH_TIMEOUT_MS);
    return task->fetch_op != NULL ? 0 : -1;
}

static int rl_loader_handle_fetch_completion(rl_loader_task_t *task, fetch_url_result_t *fetch_result)
{
    if (!task || !fetch_result) {
        return -1;
    }

    if (fetch_result->code != 200 || fetch_result->data == NULL || fetch_result->size == 0) {
        free(fetch_result->data);
        fetch_result->data = NULL;
        return -1;
    }

    if (fileio_write(task->pending_fetch_path, fetch_result->data, fetch_result->size) != 0) {
        free(fetch_result->data);
        fetch_result->data = NULL;
        return -1;
    }

    rl_loader_cache_memory_copy_if_needed(task->pending_fetch_path,
                                          (const unsigned char *)fetch_result->data,
                                          fetch_result->size);
    return 0;
}

static rl_loader_task_t *rl_loader_import_auto(const char *filename)
{
    return rl_loader_import_asset_async(filename);
}

static int rl_loader_clear_cache_dir(const char *abs_dir, const char *rel_dir)
{
    struct stat st;
    DIR *dir = NULL;
    struct dirent *entry = NULL;

    if (stat(abs_dir, &st) != 0)
    {
        if (errno == ENOENT)
        {
            return 0;
        }
        return -1;
    }

    if (!S_ISDIR(st.st_mode))
    {
        if (!rel_dir || rel_dir[0] == '\0')
        {
            return -1;
        }
        return fileio_rmfile(rel_dir);
    }

    dir = opendir(abs_dir);
    if (!dir)
    {
        return -1;
    }

    while ((entry = readdir(dir)) != NULL)
    {
        char abs_child[FILEIO_MAX_PATH_LENGTH * 2];
        char rel_child[FILEIO_MAX_PATH_LENGTH * 2];
        int child_rc = 0;

        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
        {
            continue;
        }

        snprintf(abs_child, sizeof(abs_child), "%s/%s", abs_dir, entry->d_name);
        abs_child[sizeof(abs_child) - 1] = '\0';

        if (rel_dir && rel_dir[0] != '\0')
        {
            snprintf(rel_child, sizeof(rel_child), "%s/%s", rel_dir, entry->d_name);
        }
        else
        {
            snprintf(rel_child, sizeof(rel_child), "%s", entry->d_name);
        }
        rel_child[sizeof(rel_child) - 1] = '\0';

        child_rc = rl_loader_clear_cache_dir(abs_child, rel_child);
        if (child_rc != 0)
        {
            closedir(dir);
            return child_rc;
        }
    }

    closedir(dir);

    if (rel_dir && rel_dir[0] != '\0')
    {
        if (fileio_rmdir(rel_dir) != 0)
        {
            return -1;
        }
    }

    return 0;
}

static unsigned char *rl_loader_load_file_data_cb(const char *file_name, int *data_size)
{
    fileio_read_result_t result = {0};
    const char *resolved_path = NULL;
    char parsed_asset_host[256] = {0};
    char parsed_path[512] = {0};
    bool should_cache_in_memory = false;
    size_t cached_size = 0;
    unsigned char *cached_data = NULL;

    if (data_size) {
        *data_size = 0;
    }

    if (!file_name) {
        return NULL;
    }

    // Step 1: Resolve host/path. Explicit URL overrides default asset host.
    if (rl_loader_is_http_url(file_name)) {
        if (!rl_loader_split_url(file_name, parsed_asset_host, sizeof(parsed_asset_host), parsed_path, sizeof(parsed_path))) {
            return NULL;
        }
        resolved_path = parsed_path;
    } else {
        resolved_path = rl_loader_strip_leading_slash(file_name);
    }

    should_cache_in_memory = rl_loader_should_memory_cache_path(resolved_path);

    // Step 2: Cache-first read from in-memory LRU for selected asset types.
    if (should_cache_in_memory && rl_loader_memory_cache != NULL) {
        if (lru_cache_get_copy(rl_loader_memory_cache, resolved_path, &cached_data, &cached_size)) {
            if (cached_size > (size_t)INT_MAX) {
                free(cached_data);
                return NULL;
            }
            if (data_size) {
                *data_size = (int)cached_size;
            }
            return cached_data;
        }
    }

    // Step 3: Cache-first read from local mounted storage.
    result = fileio_read(resolved_path);

    // Step 4: If load failed, signal raylib failure for this path.
    if (result.error != 0 || !result.data || result.size == 0) {
        if (result.data) {
            free(result.data);
        }
        return NULL;
    }

    if (should_cache_in_memory && rl_loader_memory_cache != NULL && result.size <= RL_LOADER_CACHE_MAX_ENTRY_BYTES) {
        lru_cache_put_copy(rl_loader_memory_cache, resolved_path, result.data, result.size);
    }

    if (data_size) {
        if (result.size > (size_t)INT_MAX) {
            free(result.data);
            return NULL;
        }
        *data_size = (int)result.size;
    }

    return result.data;
}

int rl_loader_set_asset_host(const char *asset_host)
{
    const char *next_asset_host = asset_host;
    size_t asset_host_len = 0;

    if (!next_asset_host || next_asset_host[0] == '\0') {
        next_asset_host = RL_LOADER_DEFAULT_ASSET_HOST;
    }

    asset_host_len = strlen(next_asset_host);
    if (asset_host_len + 1 > sizeof(rl_loader_asset_host)) {
        return -1;
    }

    memcpy(rl_loader_asset_host, next_asset_host, asset_host_len + 1);
    return 0;
}

const char *rl_loader_get_asset_host(void)
{
    return rl_loader_asset_host;
}

rl_loader_task_t *rl_loader_restore_fs_async(void)
{
    rl_loader_task_t *task = NULL;

    if (!rl_loader_initialized) {
        return NULL;
    }

    task = (rl_loader_task_t *)calloc(1, sizeof(rl_loader_task_t));
    if (!task) {
        return NULL;
    }

    task->kind = RL_LOADER_TASK_KIND_RESTORE_FS;
    task->fileio_op = fileio_restore_async();
    if (!task->fileio_op) {
        free(task);
        return NULL;
    }

    return task;
}

static rl_loader_task_t *rl_loader_import_single_asset(const char *filename)
{
    rl_loader_task_t *task = NULL;

    if (!rl_loader_initialized || !filename || filename[0] == '\0') {
        return NULL;
    }

    task = (rl_loader_task_t *)calloc(1, sizeof(rl_loader_task_t));
    if (!task) {
        return NULL;
    }

    task->kind = RL_LOADER_TASK_KIND_IMPORT_ASSET;
    task->prepare_state = RL_LOADER_PREPARE_STATE_INIT;

    if (rl_loader_resolve_prepare_target(filename,
                                         task->fetch_host,
                                         sizeof(task->fetch_host),
                                         task->resolved_path,
                                         sizeof(task->resolved_path)) != 0) {
        free(task);
        return NULL;
    }
    return task;
}

rl_loader_task_t *rl_loader_import_asset_async(const char *filename)
{
    rl_loader_task_t *task = NULL;
    const char *ext = NULL;

    if (!rl_loader_initialized || !filename || filename[0] == '\0') {
        return NULL;
    }

    ext = rl_loader_get_extension(filename);
    if (ext == NULL || !rl_loader_ext_eq(ext, ".gltf")) {
        return rl_loader_import_single_asset(filename);
    }

    task = (rl_loader_task_t *)calloc(1, sizeof(rl_loader_task_t));
    if (!task) {
        return NULL;
    }

    task->kind = RL_LOADER_TASK_KIND_IMPORT_ASSET;
    task->prepare_state = RL_LOADER_PREPARE_STATE_INIT;

    if (rl_loader_resolve_prepare_target(filename,
                                         task->fetch_host,
                                         sizeof(task->fetch_host),
                                         task->resolved_path,
                                         sizeof(task->resolved_path)) != 0) {
        free(task);
        return NULL;
    }

    return task;
}

RL_KEEP
rl_loader_task_t *rl_loader_import_assets_from_scratch_async(size_t filename_count)
{
    const char *filenames[RL_SCRATCH_MAX_STRING_TABLE_ENTRIES];
    rl_scratch_t *scratch = NULL;
    size_t i = 0;

    if (filename_count == 0 || filename_count > RL_SCRATCH_MAX_STRING_TABLE_ENTRIES) {
        return NULL;
    }

    scratch = (rl_scratch_t *)(uintptr_t)rl_scratch_get();
    if (scratch == NULL) {
        return NULL;
    }

    for (i = 0; i < filename_count; i++) {
        uint32_t offset = scratch->string_offsets[i];
        if (offset >= RL_SCRATCH_MAX_STRING_TABLE_BYTES) {
            return NULL;
        }
        filenames[i] = &scratch->string_bytes[offset];
    }

    return rl_loader_import_assets_async(filenames, filename_count);
}

rl_loader_task_t *rl_loader_import_assets_async(const char *const *filenames, size_t filename_count)
{
    rl_loader_task_t *task = NULL;
    size_t i = 0;

    if (!rl_loader_initialized || filenames == NULL || filename_count == 0) {
        return NULL;
    }

    task = (rl_loader_task_t *)calloc(1, sizeof(rl_loader_task_t));
    if (!task) {
        return NULL;
    }

    task->kind = RL_LOADER_TASK_KIND_IMPORT_ASSETS;
    task->batch_paths = (char **)calloc(filename_count, sizeof(char *));
    if (!task->batch_paths) {
        free(task);
        return NULL;
    }

    for (i = 0; i < filename_count; i++) {
        if (filenames[i] == NULL || filenames[i][0] == '\0') {
            rl_loader_free_task(task);
            return NULL;
        }

        task->batch_paths[i] = (char *)malloc(strlen(filenames[i]) + 1);
        if (!task->batch_paths[i]) {
            rl_loader_free_task(task);
            return NULL;
        }
        strcpy(task->batch_paths[i], filenames[i]);
    }

    task->batch_count = filename_count;
    return task;
}

bool rl_loader_poll_task(rl_loader_task_t *task)
{
    fetch_url_result_t fetch_result = {0};
    fileio_read_result_t root_result = {0};
    int finish_rc = 0;

    if (!task) {
        return false;
    }

    if (task->done) {
        return true;
    }

    switch (task->kind) {
        case RL_LOADER_TASK_KIND_RESTORE_FS:
            if (task->fileio_op == NULL) {
                rl_loader_task_complete(task, -1);
                return true;
            }
            if (!fileio_sync_poll(task->fileio_op)) {
                return false;
            }
            rl_loader_task_complete(task, fileio_sync_finish(task->fileio_op));
            return true;
        case RL_LOADER_TASK_KIND_IMPORT_ASSET:
            if (task->prepare_state == RL_LOADER_PREPARE_STATE_INIT) {
                if (!rl_loader_restore_barrier_poll()) {
                    return false;
                }
                if (rl_loader_prepare_import_asset(task) != 0) {
                    rl_loader_task_complete(task, -1);
                    return true;
                }
                if (task->done) {
                    return true;
                }
            }
            if (task->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_ROOT ||
                task->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY) {
                if (task->fetch_op == NULL) {
                    rl_loader_task_complete(task, -1);
                    return true;
                }
                if (!fetch_url_poll(task->fetch_op)) {
                    return false;
                }
                finish_rc = fetch_url_finish(task->fetch_op, &fetch_result);
                if (finish_rc != 0) {
                    rl_loader_task_complete(task, -1);
                    return true;
                }
                if (rl_loader_handle_fetch_completion(task, &fetch_result) != 0) {
                    free(fetch_result.data);
                    rl_loader_task_complete(task, -1);
                    return true;
                }
                free(fetch_result.data);
                if (task->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_ROOT) {
                    task->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
                } else {
                    task->dependency_index++;
                    task->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
                }
            }

            if (task->prepare_state == RL_LOADER_PREPARE_STATE_PARSING_ROOT) {
                if (!rl_loader_is_dependency_bearing_asset_path(task->resolved_path)) {
                    rl_loader_task_complete(task, 0);
                    return true;
                }

                if (task->dependency_count == 0 && task->dependency_index == 0) {
                    root_result = fileio_read(task->resolved_path);
                    if (root_result.error != 0 || root_result.data == NULL || root_result.size == 0) {
                        free(root_result.data);
                        rl_loader_task_complete(task, -1);
                        return true;
                    }
                    if (rl_loader_collect_gltf_dependency_uris(task, root_result.data, root_result.size) != 0) {
                        free(root_result.data);
                        rl_loader_task_complete(task, -1);
                        return true;
                    }
                    free(root_result.data);
                }

                while (task->dependency_index < task->dependency_count &&
                       fileio_exists(task->dependency_paths[task->dependency_index])) {
                    rl_loader_cache_local_file_if_needed(task->dependency_paths[task->dependency_index]);
                    task->dependency_index++;
                }

                if (task->dependency_index >= task->dependency_count) {
                    rl_loader_task_complete(task, 0);
                    return true;
                }

                if (rl_loader_start_fetch(task, task->dependency_paths[task->dependency_index]) != 0) {
                    rl_loader_task_complete(task, -1);
                    return true;
                }
                task->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY;
                return false;
            }

            if (task->prepare_state != RL_LOADER_PREPARE_STATE_FETCHING_ROOT || task->fetch_op == NULL) {
                rl_loader_task_complete(task, -1);
                return true;
            }
            if (!fetch_url_poll(task->fetch_op)) {
                return false;
            }
            finish_rc = fetch_url_finish(task->fetch_op, &fetch_result);
            if (finish_rc != 0) {
                rl_loader_task_complete(task, -1);
                return true;
            }
            if (rl_loader_handle_fetch_completion(task, &fetch_result) != 0) {
                free(fetch_result.data);
                rl_loader_task_complete(task, -1);
                return true;
            }
            free(fetch_result.data);
            rl_loader_task_complete(task, 0);
            return true;
        case RL_LOADER_TASK_KIND_IMPORT_ASSETS:
            while (task->batch_index < task->batch_count) {
                if (task->child_task == NULL) {
                    task->child_task = rl_loader_import_auto(task->batch_paths[task->batch_index]);
                    if (task->child_task == NULL) {
                        rl_loader_task_complete(task, -1);
                        return true;
                    }
                }

                if (!rl_loader_poll_task(task->child_task)) {
                    return false;
                }

                finish_rc = rl_loader_finish_task(task->child_task);
                if (finish_rc != 0) {
                    rl_loader_task_complete(task, finish_rc);
                    return true;
                }

                rl_loader_free_task(task->child_task);
                task->child_task = NULL;
                task->batch_index++;
            }

            rl_loader_task_complete(task, 0);
            return true;
        default:
            rl_loader_task_complete(task, -1);
            return true;
    }
}

int rl_loader_finish_task(rl_loader_task_t *task)
{
    if (!task) {
        return -1;
    }

    if (!rl_loader_poll_task(task)) {
        return 1;
    }

    return task->status;
}

void rl_loader_free_task(rl_loader_task_t *task)
{
    if (!task) {
        return;
    }

    if (task->fetch_op != NULL) {
        fetch_url_op_free(task->fetch_op);
    }
    if (task->child_task != NULL) {
        rl_loader_free_task(task->child_task);
    }
    if (task->fileio_op != NULL) {
        fileio_sync_op_free(task->fileio_op);
    }
    if (task->dependency_paths != NULL) {
        size_t i = 0;
        for (i = 0; i < task->dependency_count; i++) {
            free(task->dependency_paths[i]);
        }
        free(task->dependency_paths);
    }
    if (task->batch_paths != NULL) {
        size_t i = 0;
        for (i = 0; i < task->batch_count; i++) {
            free(task->batch_paths[i]);
        }
        free(task->batch_paths);
    }
    free(task);
}

bool rl_loader_is_local(const char *filename)
{
    char host[RL_LOADER_MAX_ASSET_HOST_LENGTH] = {0};
    char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};

    if (!rl_loader_initialized) {
        return false;
    }

    if (rl_loader_resolve_prepare_target(filename,
                                         host,
                                         sizeof(host),
                                         resolved_path,
                                         sizeof(resolved_path)) != 0) {
        return false;
    }

    return fileio_exists(resolved_path);
}

rl_loader_read_result_t rl_loader_read_local(const char *filename)
{
    rl_loader_read_result_t out = {0};
    char host[RL_LOADER_MAX_ASSET_HOST_LENGTH] = {0};
    char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};
    fileio_read_result_t result = {0};
    bool should_cache_in_memory = false;
    size_t cached_size = 0;
    unsigned char *cached_data = NULL;

    if (!rl_loader_initialized || filename == NULL || filename[0] == '\0') {
        out.error = -1;
        return out;
    }

    if (rl_loader_resolve_prepare_target(filename,
                                         host,
                                         sizeof(host),
                                         resolved_path,
                                         sizeof(resolved_path)) != 0) {
        out.error = -1;
        return out;
    }

    should_cache_in_memory = rl_loader_should_memory_cache_path(resolved_path);
    if (should_cache_in_memory && rl_loader_memory_cache != NULL) {
        if (lru_cache_get_copy(rl_loader_memory_cache, resolved_path, &cached_data, &cached_size)) {
            out.data = cached_data;
            out.size = cached_size;
            out.error = 0;
            return out;
        }
    }

    result = fileio_read(resolved_path);
    out.data = (unsigned char *)result.data;
    out.size = result.size;
    out.error = result.error;
    return out;
}

void rl_loader_read_result_free(rl_loader_read_result_t *result)
{
    if (result == NULL) {
        return;
    }
    free(result->data);
    result->data = NULL;
    result->size = 0;
}

void rl_loader_normalize_path(const char *path, char *buffer, size_t buffer_size)
{
    if (path == NULL || buffer == NULL || buffer_size == 0) {
        return;
    }
    path_normalize(path, buffer, buffer_size);
}

int rl_loader_uncache_file(const char *filename)
{
    const char *resolved_path = rl_loader_strip_leading_slash(filename);
    int rc = 0;

    if (!resolved_path || resolved_path[0] == '\0') {
        return -1;
    }

    rc = fileio_rmfile(resolved_path);
    if (rc == 0 && rl_loader_memory_cache != NULL) {
        // Prevent stale reads from in-memory cache after on-disk removal.
        lru_cache_clear(rl_loader_memory_cache);
    }

    return rc;
}

int rl_loader_clear_cache(void)
{
    if (!fileio_mount_point_initialized || fileio_mount_point[0] == '\0') {
        return -1;
    }

    if (rl_loader_clear_cache_dir(fileio_mount_point, "") != 0) {
        return -1;
    }

    if (rl_loader_memory_cache != NULL) {
        lru_cache_clear(rl_loader_memory_cache);
    }

    return 0;
}

bool rl_loader_is_ready(void)
{
    return rl_loader_restore_barrier_poll();
}

#define RL_LOADER_MAX_MANAGED_TASKS 16
#define RL_LOADER_MAX_TASK_PATH 256

typedef struct rl_loader_managed_task_t {
    rl_loader_task_t *task;
    char path[RL_LOADER_MAX_TASK_PATH];
    rl_loader_callback_fn on_success;
    rl_loader_callback_fn on_failure;
    void *user_data;
    bool in_use;
} rl_loader_managed_task_t;

static rl_loader_managed_task_t rl_loader_managed_tasks[RL_LOADER_MAX_MANAGED_TASKS] = {{0}};

rl_loader_add_task_result_t rl_loader_add_task(rl_loader_task_t *task,
                                               const char *path,
                                               rl_loader_callback_fn on_success,
                                               rl_loader_callback_fn on_failure,
                                               void *user_data)
{
    int i = 0;
    rl_loader_managed_task_t *slot = NULL;

    if (task == NULL) {
        if (on_failure != NULL) {
            on_failure(path, user_data);
        }
        return RL_LOADER_ADD_TASK_ERR_INVALID;
    }

    for (i = 0; i < RL_LOADER_MAX_MANAGED_TASKS; i++) {
        if (!rl_loader_managed_tasks[i].in_use) {
            slot = &rl_loader_managed_tasks[i];
            break;
        }
    }

    if (slot == NULL) {
        if (on_failure != NULL) {
            on_failure(path, user_data);
        }
        rl_loader_free_task(task);
        return RL_LOADER_ADD_TASK_ERR_QUEUE_FULL;
    }

    slot->task = task;
    slot->path[0] = '\0';
    if (path != NULL) {
        snprintf(slot->path, sizeof(slot->path), "%s", path);
    }
    slot->on_success = on_success;
    slot->on_failure = on_failure;
    slot->user_data = user_data;
    slot->in_use = true;
    return RL_LOADER_ADD_TASK_OK;
}

void rl_loader_tick(void)
{
    int i = 0;

    rl_loader_restore_barrier_poll();

    for (i = 0; i < RL_LOADER_MAX_MANAGED_TASKS; i++) {
        rl_loader_managed_task_t *slot = &rl_loader_managed_tasks[i];
        int rc = 0;

        if (!slot->in_use) {
            continue;
        }

        if (!rl_loader_poll_task(slot->task)) {
            continue;
        }

        rc = rl_loader_finish_task(slot->task);

        if (rc == 0 && slot->on_success != NULL) {
            slot->on_success(slot->path, slot->user_data);
        } else if (rc != 0 && slot->on_failure != NULL) {
            slot->on_failure(slot->path, slot->user_data);
        }

        rl_loader_free_task(slot->task);
        slot->task = NULL;
        slot->in_use = false;
    }
}

int rl_loader_init(const char *mount_point)
{
    const char *resolved_mount = mount_point;

    if (rl_loader_initialized) {
        return 0;
    }

    if (!resolved_mount || resolved_mount[0] == '\0') {
        resolved_mount = RL_LOADER_DEFAULT_MOUNT_POINT;
    }

    if (fileio_init(resolved_mount) != 0) {
        return -1;
    }

    rl_loader_init_asset_host_from_env();

    rl_loader_restore_barrier = fileio_restore_async();
    rl_loader_restore_ready = (rl_loader_restore_barrier == NULL);
    rl_loader_restore_failed = false;
    rl_loader_restore_started_at = clock();

    // One shared byte cache for loader callbacks across all modules.
    rl_loader_memory_cache = lru_cache_create(RL_LOADER_CACHE_MAX_BYTES, RL_LOADER_CACHE_MAX_ENTRIES);

    SetLoadFileDataCallback(rl_loader_load_file_data_cb);

    rl_loader_initialized = true;
    return 0;
}

void rl_loader_deinit(void)
{
    if (!rl_loader_initialized) {
        return;
    }

    SetLoadFileDataCallback(NULL);
    lru_cache_destroy(rl_loader_memory_cache);
    rl_loader_memory_cache = NULL;
    if (rl_loader_restore_barrier != NULL) {
        fileio_sync_op_free(rl_loader_restore_barrier);
        rl_loader_restore_barrier = NULL;
    }
    rl_loader_restore_ready = false;
    rl_loader_restore_failed = false;
    rl_loader_restore_started_at = 0;
    fileio_deinit();
    rl_loader_initialized = false;
}
