#include "test_lru_cache.h"
#include "fileio_test.h"
#include "test_fileio_common.h"
#include "test_fileio_api.h"
#include "test_path.h"
#include "test_rl_handle_pool.h"
#include "test_rl_loader.h"

#include <stdio.h>

int main(void)
{
    int passed = 0;
    int failed = 0;
    int rc = 0;

    rc = test_lru_cache_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = fileio_test_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = test_fileio_common_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = test_fileio_api_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = test_path_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = test_rl_handle_pool_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    rc = test_rl_loader_run();
    if (rc == 0) {
        passed++;
    } else {
        failed++;
    }

    printf("unit_tests: %d passed, %d failed\n", passed, failed);
    return failed == 0 ? 0 : 1;
}
