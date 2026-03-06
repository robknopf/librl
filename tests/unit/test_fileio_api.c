#include "test_fileio_api.h"

#include "fileio/fileio.h"
#include "fileio/fileio_common.h"
#include "test_common.h"

#include <string.h>
#include <stdlib.h>
#include <unistd.h>

static void cleanup_mount(const char *mount_point)
{
    (void)remove("librl_fileio_api_mount/dir/file.bin");
    (void)rmdir("librl_fileio_api_mount/dir");
    (void)rmdir("librl_fileio_api_mount");
    (void)mount_point;
}

int test_fileio_api_run(void)
{
    const char *mount_input = "/librl_fileio_api_mount";
    const char *expected_mount = "librl_fileio_api_mount";
    const char *rel_file = "dir/file.bin";
    const unsigned char payload[] = { 10, 20, 30, 40 };
    fileio_read_result_t rr = {0};

    fileio_deinit();
    cleanup_mount(expected_mount);

    TEST_ASSERT(fileio_init(mount_input) == 0);
    TEST_ASSERT(fileio_mount_point_initialized);
    TEST_ASSERT(strcmp(fileio_mount_point, expected_mount) == 0);

    TEST_ASSERT(fileio_mkdir("dir") == 0);
    TEST_ASSERT(fileio_write(rel_file, (void *)payload, sizeof(payload)) == 0);
    TEST_ASSERT(fileio_exists(rel_file));

    rr = fileio_read(rel_file);
    TEST_ASSERT(rr.error == 0);
    TEST_ASSERT(rr.size == sizeof(payload));
    TEST_ASSERT(rr.data != NULL);
    TEST_ASSERT(memcmp(rr.data, payload, sizeof(payload)) == 0);
    free(rr.data);

    fileio_deinit();
    TEST_ASSERT(!fileio_mount_point_initialized);

    TEST_ASSERT(fileio_exists(rel_file) == false);
    TEST_ASSERT(fileio_write(rel_file, (void *)payload, sizeof(payload)) == -1);

    cleanup_mount(expected_mount);
    return 0;
}
