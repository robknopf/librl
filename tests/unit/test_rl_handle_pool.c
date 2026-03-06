#include "test_rl_handle_pool.h"

#include "internal/rl_handle_pool.h"
#include "test_common.h"

#include <stddef.h>

int test_rl_handle_pool_run(void)
{
    rl_handle_pool_t pool;
    uint16_t free_indices[4] = {0};
    uint16_t generations[4] = {0};
    unsigned char occupied[4] = {0};
    uint16_t resolved_index = 0;

    rl_handle_t h1 = 0;
    rl_handle_t h2 = 0;
    rl_handle_t h3 = 0;
    rl_handle_t h4 = 0;
    rl_handle_t h2_new = 0;

    rl_handle_pool_init(&pool, 4, free_indices, 4, generations, occupied);

    h1 = rl_handle_pool_alloc(&pool);
    h2 = rl_handle_pool_alloc(&pool);
    h3 = rl_handle_pool_alloc(&pool);
    h4 = rl_handle_pool_alloc(&pool);

    TEST_ASSERT(h1 != 0);
    TEST_ASSERT(h2 != 0);
    TEST_ASSERT(h3 != 0);
    TEST_ASSERT(h4 == 0);

    TEST_ASSERT(rl_handle_pool_resolve(&pool, h2, &resolved_index));
    TEST_ASSERT(resolved_index == RL_HANDLE_INDEX(h2));

    TEST_ASSERT(rl_handle_pool_free(&pool, h2));
    TEST_ASSERT(!rl_handle_pool_resolve(&pool, h2, &resolved_index));
    TEST_ASSERT(!rl_handle_pool_free(&pool, h2));

    h2_new = rl_handle_pool_alloc(&pool);
    TEST_ASSERT(h2_new != 0);
    TEST_ASSERT(RL_HANDLE_INDEX(h2_new) == RL_HANDLE_INDEX(h2));
    TEST_ASSERT(RL_HANDLE_GENERATION(h2_new) != RL_HANDLE_GENERATION(h2));

    TEST_ASSERT(rl_handle_pool_resolve(&pool, h2_new, &resolved_index));
    TEST_ASSERT(rl_handle_pool_handle_from_index(&pool, resolved_index) == h2_new);

    rl_handle_pool_reset(&pool);
    TEST_ASSERT(!rl_handle_pool_resolve(&pool, h1, &resolved_index));
    TEST_ASSERT(!rl_handle_pool_resolve(&pool, h2_new, &resolved_index));

    h1 = rl_handle_pool_alloc(&pool);
    TEST_ASSERT(h1 != 0);
    TEST_ASSERT(RL_HANDLE_INDEX(h1) == 1);
    TEST_ASSERT(RL_HANDLE_GENERATION(h1) == 1);

    return 0;
}
