#include "rl_fileio_test.h"

#include "rl_fileio.h"
#include "fetch_url_stub.h"
#include "raylib_loader_stub.h"
#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static void cleanup_fileio_mount(void)
{
    (void)remove("cache_fileio_test/assets/model.glb");
    (void)remove("cache_fileio_test/assets/scene.gltf");
    (void)remove("cache_fileio_test/assets/mesh.bin");
    (void)remove("cache_fileio_test/assets/tex.png");
    (void)remove("cache_fileio_test/assets/readme.txt");
    (void)remove("cache_fileio_test/assets/scene2.gltf");
    (void)remove("cache_fileio_test/assets/mesh2.bin");
    (void)remove("cache_fileio_test/assets/tex2.png");
    (void)remove("cache_fileio_test/assets/readme2.txt");
    (void)rmdir("cache_fileio_test/assets");
    (void)rmdir("cache_fileio_test");
}

static void remove_local_file(const char *relative_path)
{
    char full_path[512];
    (void)snprintf(full_path, sizeof(full_path), "cache_fileio_test/%s", relative_path);
    (void)remove(full_path);
}

int test_rl_fileio_run(void)
{
    int data_size = 0;
    int poll_count = 0;
    unsigned char *data = 0;
    rl_handle_t task = 0;
    const char glb_payload[] = "glb-from-remote";
    const char txt_payload[] = "txt-from-remote";
    const char gltf_payload[] =
        "{"
        "\"asset\":{\"version\":\"2.0\"},"
        "\"buffers\":[{\"uri\":\"mesh.bin\",\"byteLength\":4}],"
        "\"images\":[{\"uri\":\"tex.png\"}]"
        "}";
    const unsigned char mesh_payload[] = { 0xde, 0xad, 0xbe, 0xef };
    const unsigned char tex_payload[] = { 0x89, 0x50, 0x4e, 0x47 };
    const char batch_txt_payload[] = "txt-from-batch";
    const char batch_gltf_payload[] =
        "{"
        "\"asset\":{\"version\":\"2.0\"},"
        "\"buffers\":[{\"uri\":\"mesh2.bin\",\"byteLength\":2}],"
        "\"images\":[{\"uri\":\"tex2.png\"}]"
        "}";
    const unsigned char batch_mesh_payload[] = { 0xaa, 0xbb };
    const unsigned char batch_tex_payload[] = { 0x01, 0x02, 0x03 };
    const char custom_host[] = "https://assets.example.test:8443";

    cleanup_fileio_mount();
    fetch_url_stub_reset();
    TEST_ASSERT(rl_fileio_set_asset_host(custom_host) == 0);
    TEST_ASSERT(strcmp(rl_fileio_get_asset_host(), custom_host) == 0);

    TEST_ASSERT(rl_fileio_init_async("cache_fileio_test") == 0);
    poll_count = 0;
    while (!rl_fileio_is_ready() && poll_count < 8) {
        rl_fileio_tick();
        poll_count++;
    }
    TEST_ASSERT(rl_fileio_is_ready() == true);
    TEST_ASSERT(test_raylib_callback_is_set());

    task = rl_fileio_restore_async();
    TEST_ASSERT(task != 0);
    TEST_ASSERT(rl_fileio_poll_task(task) == true);
    TEST_ASSERT(rl_fileio_finish_task(task) == 0);
    rl_fileio_free_task(task);
    task = 0;

    data = test_raylib_invoke_load_file_data_callback("assets/model.glb", &data_size);
    TEST_ASSERT(data == 0);

    fetch_url_stub_set_response(200, glb_payload, sizeof(glb_payload) - 1);
    task = rl_fileio_ensure_async("assets/model.glb", "https://example.com/assets/model.glb?x=1#frag");
    TEST_ASSERT(task != 0);
    TEST_ASSERT(rl_fileio_poll_task(task) == true);
    TEST_ASSERT(rl_fileio_finish_task(task) == 0);
    rl_fileio_free_task(task);
    task = 0;
    TEST_ASSERT(fetch_url_stub_get_call_count() == 1);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_host(), "https://example.com") == 0);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_path(), "assets/model.glb") == 0);
    TEST_ASSERT(rl_fileio_exists("assets/model.glb") == true);

    data = test_raylib_invoke_load_file_data_callback("https://example.com/assets/model.glb?x=1#frag", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)(sizeof(glb_payload) - 1));
    TEST_ASSERT(memcmp(data, glb_payload, sizeof(glb_payload) - 1) == 0);
    free(data);

    // Remove the disk copy; .glb should still load from in-memory cache.
    remove_local_file("assets/model.glb");
    data = test_raylib_invoke_load_file_data_callback("assets/model.glb", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)(sizeof(glb_payload) - 1));
    free(data);

    fetch_url_stub_set_response(200, txt_payload, sizeof(txt_payload) - 1);
    task = rl_fileio_ensure_async("assets/readme.txt", NULL);
    TEST_ASSERT(task != 0);
    TEST_ASSERT(rl_fileio_poll_task(task) == true);
    TEST_ASSERT(rl_fileio_finish_task(task) == 0);
    rl_fileio_free_task(task);
    task = 0;
    TEST_ASSERT(fetch_url_stub_get_call_count() == 2);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_host(), custom_host) == 0);
    TEST_ASSERT(strcmp(fetch_url_stub_get_last_path(), "assets/readme.txt") == 0);

    // Non-memory-cached extension loads from local cache after ensure.
    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)(sizeof(txt_payload) - 1));
    free(data);

    remove_local_file("assets/readme.txt");
    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data == 0);

    fetch_url_stub_enqueue_response(200, gltf_payload, sizeof(gltf_payload) - 1);
    fetch_url_stub_enqueue_response(200, (const char *)mesh_payload, sizeof(mesh_payload));
    fetch_url_stub_enqueue_response(200, (const char *)tex_payload, sizeof(tex_payload));
    task = rl_fileio_ensure_async("assets/scene.gltf", NULL);
    TEST_ASSERT(task != 0);
    TEST_ASSERT(rl_fileio_poll_task(task) == false);
    TEST_ASSERT(rl_fileio_poll_task(task) == false);
    TEST_ASSERT(rl_fileio_poll_task(task) == true);
    TEST_ASSERT(rl_fileio_finish_task(task) == 0);
    rl_fileio_free_task(task);
    task = 0;
    TEST_ASSERT(fetch_url_stub_get_call_count() == 5);
    TEST_ASSERT(rl_fileio_exists("assets/scene.gltf") == true);
    TEST_ASSERT(rl_fileio_exists("assets/mesh.bin") == true);
    TEST_ASSERT(rl_fileio_exists("assets/tex.png") == true);

    data = test_raylib_invoke_load_file_data_callback("assets/scene.gltf", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)(sizeof(gltf_payload) - 1));
    free(data);

    data = test_raylib_invoke_load_file_data_callback("assets/mesh.bin", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)sizeof(mesh_payload));
    TEST_ASSERT(memcmp(data, mesh_payload, sizeof(mesh_payload)) == 0);
    free(data);

    data = test_raylib_invoke_load_file_data_callback("assets/tex.png", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)sizeof(tex_payload));
    TEST_ASSERT(memcmp(data, tex_payload, sizeof(tex_payload)) == 0);
    free(data);

    {
        const char *batch_paths[] = {
            "assets/readme2.txt",
            "assets/scene2.gltf"
        };

        fetch_url_stub_enqueue_response(200, batch_txt_payload, sizeof(batch_txt_payload) - 1);
        fetch_url_stub_enqueue_response(200, batch_gltf_payload, sizeof(batch_gltf_payload) - 1);
        fetch_url_stub_enqueue_response(200, (const char *)batch_mesh_payload, sizeof(batch_mesh_payload));
        fetch_url_stub_enqueue_response(200, (const char *)batch_tex_payload, sizeof(batch_tex_payload));
        task = rl_fileio_ensure_group_async(batch_paths, 2);
        TEST_ASSERT(task != 0);
        poll_count = 0;
        while (!rl_fileio_poll_task(task) && poll_count < 8) {
            poll_count++;
        }
        TEST_ASSERT(poll_count > 0);
        TEST_ASSERT(poll_count < 8);
        TEST_ASSERT(rl_fileio_finish_task(task) == 0);
        rl_fileio_free_task(task);
        task = 0;
    }

    TEST_ASSERT(rl_fileio_exists("assets/readme2.txt") == true);
    TEST_ASSERT(rl_fileio_exists("assets/scene2.gltf") == true);
    TEST_ASSERT(rl_fileio_exists("assets/mesh2.bin") == true);
    TEST_ASSERT(rl_fileio_exists("assets/tex2.png") == true);

    data = test_raylib_invoke_load_file_data_callback("assets/readme2.txt", &data_size);
    TEST_ASSERT(data != 0);
    TEST_ASSERT(data_size == (int)(sizeof(batch_txt_payload) - 1));
    TEST_ASSERT(memcmp(data, batch_txt_payload, sizeof(batch_txt_payload) - 1) == 0);
    free(data);

    rl_fileio_deinit();
    TEST_ASSERT(rl_fileio_set_asset_host(NULL) == 0);
    TEST_ASSERT(!test_raylib_callback_is_set());

    // Re-init should succeed; the missing local .txt file stays absent.
    TEST_ASSERT(rl_fileio_init("cache_fileio_test") == 0);
    TEST_ASSERT(test_raylib_callback_is_set());

    task = rl_fileio_restore_async();
    TEST_ASSERT(task != 0);
    TEST_ASSERT(rl_fileio_poll_task(task) == true);
    TEST_ASSERT(rl_fileio_finish_task(task) == 0);
    rl_fileio_free_task(task);
    task = 0;

    data = test_raylib_invoke_load_file_data_callback("assets/readme.txt", &data_size);
    TEST_ASSERT(data == 0);

    rl_fileio_deinit();
    TEST_ASSERT(!test_raylib_callback_is_set());
    cleanup_fileio_mount();

    return 0;
}
