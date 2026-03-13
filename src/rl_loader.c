#include "rl_loader.h"

#include <raylib.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdbool.h>
#include <limits.h>
#include <ctype.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>

#include "fileio/fileio.h"
#include "fileio/fileio_common.h"
#include "fetch_url/fetch_url.h"
#include "lru_cache/lru_cache.h"
#include "path/path.h"
#include "vendor/cjson/cJSON.h"

#define RL_LOADER_DEFAULT_MOUNT_POINT "cache"
#ifndef RL_LOADER_DEFAULT_ASSET_HOST
#define RL_LOADER_DEFAULT_ASSET_HOST "https://localhost:4444"
#endif
#define RL_LOADER_CACHE_MAX_BYTES (32u * 1024u * 1024u)
#define RL_LOADER_CACHE_MAX_ENTRIES 256u
#define RL_LOADER_CACHE_MAX_ENTRY_BYTES (8u * 1024u * 1024u)
#define RL_LOADER_MAX_ASSET_HOST_LENGTH 256u
#define RL_LOADER_FETCH_TIMEOUT_MS 5000

static bool rl_loader_initialized = false;
static lru_cache_t *rl_loader_memory_cache = NULL;
static char rl_loader_asset_host[RL_LOADER_MAX_ASSET_HOST_LENGTH] = RL_LOADER_DEFAULT_ASSET_HOST;

typedef enum
{
    RL_LOADER_OP_KIND_NONE = 0,
    RL_LOADER_OP_KIND_RESTORE = 1,
    RL_LOADER_OP_KIND_PREPARE_FILE = 2,
    RL_LOADER_OP_KIND_PREPARE_MODEL = 3,
    RL_LOADER_OP_KIND_PREPARE_BATCH = 4
} rl_loader_op_kind_t;

typedef enum
{
    RL_LOADER_PREPARE_STATE_INIT = 0,
    RL_LOADER_PREPARE_STATE_FETCHING_ROOT = 1,
    RL_LOADER_PREPARE_STATE_PARSING_ROOT = 2,
    RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY = 3,
    RL_LOADER_PREPARE_STATE_DONE = 4
} rl_loader_prepare_state_t;

struct rl_loader_op
{
    rl_loader_op_kind_t kind;
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
    rl_loader_op_t *child_op;
    fileio_sync_op_t *fileio_op;
    fetch_url_op_t *fetch_op;
};

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

static bool rl_loader_is_model_path(const char *path)
{
    const char *ext = rl_loader_get_extension(path);

    return ext != NULL &&
           (rl_loader_ext_eq(ext, ".gltf") || rl_loader_ext_eq(ext, ".glb"));
}

static void rl_loader_op_complete(rl_loader_op_t *op, int status)
{
    if (!op) {
        return;
    }

    op->status = status;
    op->done = true;
    op->prepare_state = RL_LOADER_PREPARE_STATE_DONE;
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

static int rl_loader_append_dependency_path(rl_loader_op_t *op, const char *dependency_path)
{
    char **next_paths = NULL;
    char *copy = NULL;

    if (!op || !dependency_path || dependency_path[0] == '\0') {
        return -1;
    }

    copy = (char *)malloc(strlen(dependency_path) + 1);
    if (!copy) {
        return -1;
    }
    strcpy(copy, dependency_path);

    next_paths = (char **)realloc(op->dependency_paths, sizeof(char *) * (op->dependency_count + 1));
    if (!next_paths) {
        free(copy);
        return -1;
    }

    op->dependency_paths = next_paths;
    op->dependency_paths[op->dependency_count++] = copy;
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

static int rl_loader_collect_gltf_dependency_uris(rl_loader_op_t *op,
                                                  const unsigned char *json_bytes,
                                                  size_t json_size)
{
    cJSON *root = NULL;
    cJSON *buffers = NULL;
    cJSON *images = NULL;
    cJSON *entry = NULL;

    if (!op || !json_bytes || json_size == 0) {
        return -1;
    }

    root = cJSON_ParseWithLength((const char *)json_bytes, json_size);
    if (!root) {
        return -1;
    }

    buffers = cJSON_GetObjectItemCaseSensitive(root, "buffers");
    if (cJSON_IsArray(buffers)) {
        cJSON_ArrayForEach(entry, buffers)
        {
            cJSON *uri = cJSON_GetObjectItemCaseSensitive(entry, "uri");
            char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};
            int rc = 0;

            if (!cJSON_IsString(uri) || uri->valuestring == NULL) {
                continue;
            }

            rc = rl_loader_dependency_uri_to_local_path(op->root_dir,
                                                        uri->valuestring,
                                                        resolved_path,
                                                        sizeof(resolved_path));
            if (rc == 1) {
                continue;
            }
            if (rc != 0 || rl_loader_append_dependency_path(op, resolved_path) != 0) {
                cJSON_Delete(root);
                return -1;
            }
        }
    }

    images = cJSON_GetObjectItemCaseSensitive(root, "images");
    if (cJSON_IsArray(images)) {
        cJSON_ArrayForEach(entry, images)
        {
            cJSON *uri = cJSON_GetObjectItemCaseSensitive(entry, "uri");
            char resolved_path[FILEIO_MAX_PATH_LENGTH * 2] = {0};
            int rc = 0;

            if (!cJSON_IsString(uri) || uri->valuestring == NULL) {
                continue;
            }

            rc = rl_loader_dependency_uri_to_local_path(op->root_dir,
                                                        uri->valuestring,
                                                        resolved_path,
                                                        sizeof(resolved_path));
            if (rc == 1) {
                continue;
            }
            if (rc != 0 || rl_loader_append_dependency_path(op, resolved_path) != 0) {
                cJSON_Delete(root);
                return -1;
            }
        }
    }

    cJSON_Delete(root);
    return 0;
}

static int rl_loader_start_fetch(rl_loader_op_t *op, const char *path)
{
    if (!op || !path || path[0] == '\0') {
        return -1;
    }

    if (op->fetch_op != NULL) {
        fetch_url_op_free(op->fetch_op);
        op->fetch_op = NULL;
    }

    snprintf(op->pending_fetch_path, sizeof(op->pending_fetch_path), "%s", path);
    op->fetch_op = fetch_url_with_path_begin(op->fetch_host, path, RL_LOADER_FETCH_TIMEOUT_MS);
    return op->fetch_op != NULL ? 0 : -1;
}

static int rl_loader_handle_fetch_completion(rl_loader_op_t *op, fetch_url_result_t *fetch_result)
{
    if (!op || !fetch_result) {
        return -1;
    }

    if (fetch_result->code != 200 || fetch_result->data == NULL || fetch_result->size == 0) {
        free(fetch_result->data);
        fetch_result->data = NULL;
        return -1;
    }

    if (fileio_write(op->pending_fetch_path, fetch_result->data, fetch_result->size) != 0) {
        free(fetch_result->data);
        fetch_result->data = NULL;
        return -1;
    }

    rl_loader_cache_memory_copy_if_needed(op->pending_fetch_path,
                                          (const unsigned char *)fetch_result->data,
                                          fetch_result->size);
    return 0;
}

static rl_loader_op_t *rl_loader_begin_prepare_auto(const char *filename)
{
    if (rl_loader_is_model_path(filename)) {
        return rl_loader_begin_prepare_model(filename);
    }

    return rl_loader_begin_prepare_file(filename);
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

rl_loader_op_t *rl_loader_begin_restore(void)
{
    rl_loader_op_t *op = NULL;

    if (!rl_loader_initialized) {
        return NULL;
    }

    op = (rl_loader_op_t *)calloc(1, sizeof(rl_loader_op_t));
    if (!op) {
        return NULL;
    }

    op->kind = RL_LOADER_OP_KIND_RESTORE;
    op->fileio_op = fileio_restore_begin();
    if (!op->fileio_op) {
        free(op);
        return NULL;
    }

    return op;
}

rl_loader_op_t *rl_loader_begin_prepare_file(const char *filename)
{
    rl_loader_op_t *op = NULL;

    if (!rl_loader_initialized || !filename || filename[0] == '\0') {
        return NULL;
    }

    op = (rl_loader_op_t *)calloc(1, sizeof(rl_loader_op_t));
    if (!op) {
        return NULL;
    }

    op->kind = RL_LOADER_OP_KIND_PREPARE_FILE;
    op->prepare_state = RL_LOADER_PREPARE_STATE_INIT;

    if (rl_loader_resolve_prepare_target(filename,
                                         op->fetch_host,
                                         sizeof(op->fetch_host),
                                         op->resolved_path,
                                         sizeof(op->resolved_path)) != 0) {
        free(op);
        return NULL;
    }

    op->should_cache_in_memory = rl_loader_should_memory_cache_path(op->resolved_path);

    if (fileio_exists(op->resolved_path)) {
        rl_loader_op_complete(op, rl_loader_cache_local_file_if_needed(op->resolved_path));
        return op;
    }

    if (rl_loader_start_fetch(op, op->resolved_path) != 0) {
        free(op);
        return NULL;
    }
    op->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_ROOT;
    return op;
}

rl_loader_op_t *rl_loader_begin_prepare_model(const char *filename)
{
    rl_loader_op_t *op = NULL;
    const char *ext = NULL;

    if (!rl_loader_initialized || !filename || filename[0] == '\0') {
        return NULL;
    }

    ext = rl_loader_get_extension(filename);
    if (ext == NULL || !rl_loader_ext_eq(ext, ".gltf")) {
        return rl_loader_begin_prepare_file(filename);
    }

    op = (rl_loader_op_t *)calloc(1, sizeof(rl_loader_op_t));
    if (!op) {
        return NULL;
    }

    op->kind = RL_LOADER_OP_KIND_PREPARE_MODEL;
    op->prepare_state = RL_LOADER_PREPARE_STATE_INIT;

    if (rl_loader_resolve_prepare_target(filename,
                                         op->fetch_host,
                                         sizeof(op->fetch_host),
                                         op->resolved_path,
                                         sizeof(op->resolved_path)) != 0) {
        free(op);
        return NULL;
    }

    rl_loader_get_parent_dir(op->resolved_path, op->root_dir, sizeof(op->root_dir));

    if (fileio_exists(op->resolved_path)) {
        op->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
        return op;
    }

    if (rl_loader_start_fetch(op, op->resolved_path) != 0) {
        free(op);
        return NULL;
    }
    op->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_ROOT;
    return op;
}

rl_loader_op_t *rl_loader_begin_prepare_paths(const char *const *filenames, size_t filename_count)
{
    rl_loader_op_t *op = NULL;
    size_t i = 0;

    if (!rl_loader_initialized || filenames == NULL || filename_count == 0) {
        return NULL;
    }

    op = (rl_loader_op_t *)calloc(1, sizeof(rl_loader_op_t));
    if (!op) {
        return NULL;
    }

    op->kind = RL_LOADER_OP_KIND_PREPARE_BATCH;
    op->batch_paths = (char **)calloc(filename_count, sizeof(char *));
    if (!op->batch_paths) {
        free(op);
        return NULL;
    }

    for (i = 0; i < filename_count; i++) {
        if (filenames[i] == NULL || filenames[i][0] == '\0') {
            rl_loader_free_op(op);
            return NULL;
        }

        op->batch_paths[i] = (char *)malloc(strlen(filenames[i]) + 1);
        if (!op->batch_paths[i]) {
            rl_loader_free_op(op);
            return NULL;
        }
        strcpy(op->batch_paths[i], filenames[i]);
    }

    op->batch_count = filename_count;
    return op;
}

bool rl_loader_poll_op(rl_loader_op_t *op)
{
    fetch_url_result_t fetch_result = {0};
    fileio_read_result_t root_result = {0};
    int finish_rc = 0;

    if (!op) {
        return false;
    }

    if (op->done) {
        return true;
    }

    switch (op->kind) {
        case RL_LOADER_OP_KIND_RESTORE:
            if (op->fileio_op == NULL) {
                rl_loader_op_complete(op, -1);
                return true;
            }
            if (!fileio_sync_poll(op->fileio_op)) {
                return false;
            }
            rl_loader_op_complete(op, fileio_sync_finish(op->fileio_op));
            return true;
        case RL_LOADER_OP_KIND_PREPARE_FILE:
            if (op->prepare_state != RL_LOADER_PREPARE_STATE_FETCHING_ROOT || op->fetch_op == NULL) {
                rl_loader_op_complete(op, -1);
                return true;
            }
            if (!fetch_url_poll(op->fetch_op)) {
                return false;
            }
            finish_rc = fetch_url_finish(op->fetch_op, &fetch_result);
            if (finish_rc != 0) {
                rl_loader_op_complete(op, -1);
                return true;
            }
            if (rl_loader_handle_fetch_completion(op, &fetch_result) != 0) {
                free(fetch_result.data);
                rl_loader_op_complete(op, -1);
                return true;
            }
            free(fetch_result.data);
            rl_loader_op_complete(op, 0);
            return true;
        case RL_LOADER_OP_KIND_PREPARE_MODEL:
            if (op->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_ROOT ||
                op->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY) {
                if (op->fetch_op == NULL) {
                    rl_loader_op_complete(op, -1);
                    return true;
                }
                if (!fetch_url_poll(op->fetch_op)) {
                    return false;
                }
                finish_rc = fetch_url_finish(op->fetch_op, &fetch_result);
                if (finish_rc != 0) {
                    rl_loader_op_complete(op, -1);
                    return true;
                }
                if (rl_loader_handle_fetch_completion(op, &fetch_result) != 0) {
                    free(fetch_result.data);
                    rl_loader_op_complete(op, -1);
                    return true;
                }
                free(fetch_result.data);
                if (op->prepare_state == RL_LOADER_PREPARE_STATE_FETCHING_ROOT) {
                    op->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
                } else {
                    op->dependency_index++;
                    op->prepare_state = RL_LOADER_PREPARE_STATE_PARSING_ROOT;
                }
            }

            if (op->prepare_state == RL_LOADER_PREPARE_STATE_PARSING_ROOT) {
                if (op->dependency_count == 0 && op->dependency_index == 0) {
                    root_result = fileio_read(op->resolved_path);
                    if (root_result.error != 0 || root_result.data == NULL || root_result.size == 0) {
                        free(root_result.data);
                        rl_loader_op_complete(op, -1);
                        return true;
                    }
                    if (rl_loader_collect_gltf_dependency_uris(op, root_result.data, root_result.size) != 0) {
                        free(root_result.data);
                        rl_loader_op_complete(op, -1);
                        return true;
                    }
                    free(root_result.data);
                }

                while (op->dependency_index < op->dependency_count &&
                       fileio_exists(op->dependency_paths[op->dependency_index])) {
                    rl_loader_cache_local_file_if_needed(op->dependency_paths[op->dependency_index]);
                    op->dependency_index++;
                }

                if (op->dependency_index >= op->dependency_count) {
                    rl_loader_op_complete(op, 0);
                    return true;
                }

                if (rl_loader_start_fetch(op, op->dependency_paths[op->dependency_index]) != 0) {
                    rl_loader_op_complete(op, -1);
                    return true;
                }
                op->prepare_state = RL_LOADER_PREPARE_STATE_FETCHING_DEPENDENCY;
                return false;
            }

            rl_loader_op_complete(op, -1);
            return true;
        case RL_LOADER_OP_KIND_PREPARE_BATCH:
            while (op->batch_index < op->batch_count) {
                if (op->child_op == NULL) {
                    op->child_op = rl_loader_begin_prepare_auto(op->batch_paths[op->batch_index]);
                    if (op->child_op == NULL) {
                        rl_loader_op_complete(op, -1);
                        return true;
                    }
                }

                if (!rl_loader_poll_op(op->child_op)) {
                    return false;
                }

                finish_rc = rl_loader_finish_op(op->child_op);
                if (finish_rc != 0) {
                    rl_loader_op_complete(op, finish_rc);
                    return true;
                }

                rl_loader_free_op(op->child_op);
                op->child_op = NULL;
                op->batch_index++;
            }

            rl_loader_op_complete(op, 0);
            return true;
        default:
            rl_loader_op_complete(op, -1);
            return true;
    }
}

int rl_loader_finish_op(rl_loader_op_t *op)
{
    if (!op) {
        return -1;
    }

    if (!rl_loader_poll_op(op)) {
        return 1;
    }

    return op->status;
}

void rl_loader_free_op(rl_loader_op_t *op)
{
    if (!op) {
        return;
    }

    if (op->fetch_op != NULL) {
        fetch_url_op_free(op->fetch_op);
    }
    if (op->child_op != NULL) {
        rl_loader_free_op(op->child_op);
    }
    if (op->fileio_op != NULL) {
        fileio_sync_op_free(op->fileio_op);
    }
    if (op->dependency_paths != NULL) {
        size_t i = 0;
        for (i = 0; i < op->dependency_count; i++) {
            free(op->dependency_paths[i]);
        }
        free(op->dependency_paths);
    }
    if (op->batch_paths != NULL) {
        size_t i = 0;
        for (i = 0; i < op->batch_count; i++) {
            free(op->batch_paths[i]);
        }
        free(op->batch_paths);
    }
    free(op);
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
    fileio_deinit();
    rl_loader_initialized = false;
}
