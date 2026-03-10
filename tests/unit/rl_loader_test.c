#include "rl_loader_test.h"

#include "rl_loader.h"
#include "internal/rl_subsystems.h"
#include "fetch_url_stub.h"
#include "raylib_loader_stub.h"
#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static void cleanup_loader_mount(void)
{
    (void)remove("cache_loader_test/assets/model.glb");
    (void)remove("cache_loader_test/assets/readme.txt");
    (void)rmdir("cache_loader_test/assets");
    (void)rmdir("cache_loader_test");
}

static void remove_cached_file(const char *relative_path)
{
    char full_path[512];
    (void)snprintf(full_path, sizeof(full_path), "cache_loader_test/%s", relative_path);
    (void)remove(full_path);
}

int test_rl_loader_run(void)
{
    int data_size = 0;
    unsigned char *data = NULL;
    const char glb_payload[] = "glb-from-remote";
    const char txt_payload[] = "txt-from-remote";
    const char custom_host[] = "https://assets.example.test:8443";

    cleanup_loader_mount();
    fetch_url_stub_reset();
    TEST_ASSERT(rl_loader_set_asset_host(custom_host) == 0);
    TEST_ASSERT(strcmp(rl_loader_get_asset_host(), custom_host) == 0);

    TEST_ASSERT(rl_loader_init("cache_loader_test") == 0);
    TEST_ASSERT(test_raylib_callback_is_set());

    fetch_url_stub_set_response(200, glb_payload, sizeof(glb_payload) - 1);

    data = test_raylib_invoke_load_file_data_callback("https://example.com/assets/model.glb?x=1#frag", &data_size);
    TEST_ASSERT(data != NULL);
    TEST_ASSERT(data_size == (int)(sizeof(glb_payload) - 1));
    TEST_ASSERT(memcmp(data, glb_payload, sizeof(glb_payload) - 1) == 0);
    free(data);

    TEST_ASSERT(fetch_url_stub_get_call_count() == 1);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_host(), "https://example.com") == 0);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_path(), "assets/model.glb") == 0);

    // Remove the disk copy; .glb should still load from in-memory cache.
    remove_cached_file("assets/model.glb");
    data = test_raylib_invoke_load_file_data_callback("assets/model.glb", &data_size);
    TEST_ASSERT(data != NULL);
    TEST_ASSERT(data_size == (int)(sizeof(glb_payload) - 1));
    free(data);
    TEST_ASSERT(fetch_url_stub_get_call_count() == 1);

    // Non-memory-cached extension should hit remote again if disk file is removed.
    fetch_url_stub_set_response(200, txt_payload, sizeof(txt_payload) - 1);
    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data != NULL);
    free(data);
    TEST_ASSERT(fetch_url_stub_get_call_count() == 2);

    remove_cached_file("assets/readme.txt");
    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data != NULL);
    free(data);
    TEST_ASSERT(fetch_url_stub_get_call_count() == 3);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_host(), custom_host) == 0);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_path(), "assets/readme.txt") == 0);

    rl_loader_deinit();
    TEST_ASSERT(rl_loader_set_asset_host(NULL) == 0);
    TEST_ASSERT(!test_raylib_callback_is_set());

    // Re-init should use local cache for the persisted .txt file.
    TEST_ASSERT(rl_loader_init("cache_loader_test") == 0);
    TEST_ASSERT(test_raylib_callback_is_set());

    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data != NULL);
    TEST_ASSERT(data_size == (int)(sizeof(txt_payload) - 1));
    free(data);
    TEST_ASSERT(fetch_url_stub_get_call_count() == 3);

    rl_loader_deinit();
    TEST_ASSERT(!test_raylib_callback_is_set());
    cleanup_loader_mount();

    return 0;
}
