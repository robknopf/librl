#include "rl_text2d_test.h"

#include "rl_text2d.h"
#include "internal/rl_text2d.h"
#include "test_common.h"

#include <stdio.h>

int test_rl_text2d_run(void)
{
    printf("=== rl_text2d tests ===\n");

    rl_text2d_init();

    /* create returns a valid handle */
    rl_handle_t h = rl_text2d_create(0, 16.0f);
    TEST_ASSERT(h != 0);

    /* setters do not crash on a valid handle */
    rl_text2d_set_content(h, "Hello, text2d!");
    rl_text2d_set_position(h, 10.0f, 20.0f);
    rl_text2d_set_color(h, 0);
    rl_text2d_set_size(h, 24.0f);
    rl_text2d_set_font(h, 0);

    /* destroy works */
    rl_text2d_destroy(h);

    /* stale handle operations are graceful (log error, no crash) */
    rl_text2d_set_content(h, "stale");
    rl_text2d_destroy(h);

    /* handle pool recycles after destroy */
    rl_handle_t h2 = rl_text2d_create(0, 12.0f);
    TEST_ASSERT(h2 != 0);
    rl_text2d_destroy(h2);

    rl_text2d_deinit();

    printf("OK: rl_text2d lifecycle\n");
    return 0;
}
