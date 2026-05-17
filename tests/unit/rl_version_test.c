#include "rl_version_test.h"

#include "rl_version.h"
#include "test_common.h"

#include <string.h>

int test_rl_version_run(void)
{
    TEST_ASSERT(rl_version_major() == RL_VERSION_MAJOR);
    TEST_ASSERT(rl_version_minor() == RL_VERSION_MINOR);
    TEST_ASSERT(rl_version_patch() == RL_VERSION_PATCH);
    TEST_ASSERT(rl_version_number() == RL_VERSION_NUMBER);
    TEST_ASSERT(strcmp(rl_version_string(), RL_VERSION_STRING) == 0);
    TEST_ASSERT(strcmp(rl_version_label(), RL_VERSION_LABEL) == 0);

    return 0;
}
