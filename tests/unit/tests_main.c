#include "rl_handle_pool_test.h"
#include "rl_loader_test.h"

#include <stdio.h>

int main(void)
{
    int passed = 0;
    int failed = 0;
    int rc = 0;

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
