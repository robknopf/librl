#include "test_fileio_common.h"

#include "fileio/fileio.h"
#include "fileio/fileio_common.h"
#include "test_common.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef EMSCRIPTEN
#define TEST_FILEIO_MOUNT "unit_fileio_mount"
#else
#define TEST_FILEIO_MOUNT "/tmp/librl_unit_fileio_mount"
#endif

static void remove_test_file(const char *relative_path)
{
    char full_path[FILEIO_MAX_PATH_LENGTH * 2];
    (void)snprintf(full_path, sizeof(full_path), "%s/%s", TEST_FILEIO_MOUNT, relative_path);
    (void)remove(full_path);
}

static void cleanup_test_mount(void)
{
    (void)remove(TEST_FILEIO_MOUNT "/nested/path/data.bin");
    (void)rmdir(TEST_FILEIO_MOUNT "/nested/path");
    (void)rmdir(TEST_FILEIO_MOUNT "/nested");
    (void)rmdir(TEST_FILEIO_MOUNT);
}

int test_fileio_common_run(void)
{
    const unsigned char payload[] = {0, 1, 2, 3, 255};
    const char *data_path = "nested/path/data.bin";
    const char *missing_path = "nested/path/missing.bin";
    fileio_read_result_t read_result = {0};

    char too_long_mount[FILEIO_MAX_PATH_LENGTH];
    memset(too_long_mount, 'a', sizeof(too_long_mount) - 1);
    too_long_mount[sizeof(too_long_mount) - 1] = '\0';

    fileio_deinit_common();

    TEST_ASSERT(fileio_init_common(NULL) == -1);
    TEST_ASSERT(fileio_init_common("/") == -1);
    TEST_ASSERT(fileio_init_common(too_long_mount) == -1);

    TEST_ASSERT(fileio_read_common(data_path).error == -1);
    TEST_ASSERT(fileio_write_common(data_path, (void *)payload, sizeof(payload)) == -1);
    TEST_ASSERT(fileio_mkdir_common("a/b") == -1);
    TEST_ASSERT(fileio_exists_common(data_path) == false);

    cleanup_test_mount();
    TEST_ASSERT(fileio_init_common(TEST_FILEIO_MOUNT) == 0);
    TEST_ASSERT(fileio_mount_point_initialized);
    TEST_ASSERT(strcmp(fileio_mount_point, TEST_FILEIO_MOUNT) == 0);

    TEST_ASSERT(fileio_init_common(TEST_FILEIO_MOUNT) == -1);

    remove_test_file(data_path);
    remove_test_file(missing_path);

    TEST_ASSERT(fileio_mkdir_common("nested/path") == 0);
    TEST_ASSERT(fileio_write_common(data_path, (void *)payload, sizeof(payload)) == 0);
    TEST_ASSERT(fileio_exists_common(data_path));

    read_result = fileio_read_common(data_path);
    TEST_ASSERT(read_result.error == 0);
    TEST_ASSERT(read_result.size == sizeof(payload));
    TEST_ASSERT(read_result.data != NULL);
    TEST_ASSERT(memcmp(read_result.data, payload, sizeof(payload)) == 0);
    TEST_ASSERT(read_result.data[sizeof(payload)] == 0);
    free(read_result.data);

    read_result = fileio_read_common(missing_path);
    TEST_ASSERT(read_result.error == -1);
    TEST_ASSERT(read_result.data == NULL);

    read_result = fileio_read_url_common("https://example.com", "asset.bin", 10);
    TEST_ASSERT(read_result.error == 503);
    TEST_ASSERT(read_result.data == NULL);
    TEST_ASSERT(read_result.size == 0);

    fileio_deinit_common();
    TEST_ASSERT(!fileio_mount_point_initialized);
    TEST_ASSERT(fileio_mount_point[0] == '\0');
    cleanup_test_mount();

    return 0;
}
