#include "internal/rl_shape.h"
#include "rl_shape.h"

#include "raylib.h"
#include "raymath.h"

#include <math.h>
#include <stdio.h>

static int assert_true(int condition, const char *expr, int line)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s:%d: %s\n", __FILE__, line, expr);
        return 0;
    }
    return 1;
}

static int assert_approx(float actual, float expected, float epsilon, const char *label, int line)
{
    if (fabsf(actual - expected) > epsilon) {
        fprintf(stderr, "FAIL: %s:%d: %s expected %.3f got %.3f\n",
                __FILE__, line, label, expected, actual);
        return 0;
    }
    return 1;
}

#define ASSERT_TRUE(expr) do { if (!assert_true((expr), #expr, __LINE__)) return 1; } while (0)
#define ASSERT_APPROX(actual, expected, epsilon, label) \
    do { if (!assert_approx((actual), (expected), (epsilon), (label), __LINE__)) return 1; } while (0)

int main(void)
{
    rl_handle_t shape = 0;
    Ray ray = {0};
    RayCollision hit = {0};

    printf("=== rl_shape transformed pick regression ===\n");

    rl_shape_init();

    shape = rl_shape_create();
    ASSERT_TRUE(shape != 0);
    ASSERT_TRUE(rl_shape_set_cube(shape, 0.0f, 0.0f, 0.0f, 1.0f, 1.0f, 1.0f));
    ASSERT_TRUE(rl_shape_set_transform(shape, 20.0f, 1.0f, 20.0f, 0.0f, 0.0f, 0.0f, 0.6f, 0.6f, 0.6f));
    ASSERT_TRUE(rl_shape_set_pickable(shape, true));

    ray.position = (Vector3){20.0f, 1.0f, 18.0f};
    ray.direction = Vector3Normalize((Vector3){0.0f, 0.0f, 1.0f});
    hit = rl_shape_get_ray_collision(shape, ray);

    ASSERT_TRUE(hit.hit);
    ASSERT_APPROX(hit.point.x, 0.0f, 0.001f, "hit.point.x");
    ASSERT_APPROX(hit.point.y, 0.0f, 0.001f, "hit.point.y");
    ASSERT_APPROX(hit.point.z, -0.5f, 0.001f, "hit.point.z");
    ASSERT_APPROX(hit.distance, 1.7f, 0.001f, "hit.distance");

    rl_shape_destroy(shape);
    rl_shape_deinit();

    printf("OK: rl_shape transformed pick regression\n");
    return 0;
}
