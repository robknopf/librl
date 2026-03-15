#include "rl_frame_runner.h"
#include "rl_loader.h"
#include "internal/exports.h"
#include "internal/rl_loader.h"
#include "raylib.h"
#include <string.h>

#if defined(PLATFORM_WEB)
#include <emscripten/emscripten.h>
#endif

typedef struct rl_frame_loop_state_t {
    rl_frame_runner_init_fn init_fn;
    rl_frame_runner_tick_fn tick_fn;
    rl_frame_runner_shutdown_fn shutdown_fn;
    void *user_data;
    int running;
    int init_complete;
} rl_frame_loop_state_t;

static rl_frame_loop_state_t rl_frame_loop_state = {0};

static void rl_frame_finish_run(void) {
    rl_frame_runner_shutdown_fn shutdown_fn = rl_frame_loop_state.shutdown_fn;
    void *user_data = rl_frame_loop_state.user_data;

    rl_frame_loop_state.running = 0;
    rl_frame_loop_state.init_fn = NULL;
    rl_frame_loop_state.tick_fn = NULL;
    rl_frame_loop_state.shutdown_fn = NULL;
    rl_frame_loop_state.user_data = NULL;

    if (shutdown_fn != NULL) {
        shutdown_fn(user_data);
    }
}

#if defined(PLATFORM_WEB)
static void rl_frame_web_step(void) {
    if (!rl_frame_loop_state.running) {
        emscripten_cancel_main_loop();
        rl_frame_finish_run();
        return;
    }

    rl_loader_tick();

    if (!rl_frame_loop_state.init_complete) {
        if (!rl_loader_is_ready()) {
            return;
        }

        if (rl_frame_loop_state.init_fn != NULL) {
            rl_frame_loop_state.init_fn(rl_frame_loop_state.user_data);
        }
        rl_frame_loop_state.init_complete = 1;

        if (!rl_frame_loop_state.running) {
            emscripten_cancel_main_loop();
            rl_frame_finish_run();
            return;
        }
    }

    if (rl_frame_loop_state.tick_fn != NULL) {
        rl_frame_loop_state.tick_fn(rl_frame_loop_state.user_data);
    }

    if (!rl_frame_loop_state.running) {
        emscripten_cancel_main_loop();
        rl_frame_finish_run();
    }
}
#endif

RL_KEEP
void rl_frame_runner_run(rl_frame_runner_init_fn init_fn,
                         rl_frame_runner_tick_fn tick_fn,
                         rl_frame_runner_shutdown_fn shutdown_fn,
                         void *user_data) {
    if (tick_fn == NULL) {
        return;
    }

    rl_frame_loop_state.init_fn = init_fn;
    rl_frame_loop_state.tick_fn = tick_fn;
    rl_frame_loop_state.shutdown_fn = shutdown_fn;
    rl_frame_loop_state.user_data = user_data;
    rl_frame_loop_state.running = 1;
    rl_frame_loop_state.init_complete = 0;

#if defined(PLATFORM_WEB)
    emscripten_set_main_loop(rl_frame_web_step, 0, 1);
#else
    while (rl_frame_loop_state.running && !WindowShouldClose()) {
        rl_loader_tick();

        if (!rl_frame_loop_state.init_complete) {
            if (!rl_loader_is_ready()) {
                continue;
            }

            if (rl_frame_loop_state.init_fn != NULL) {
                rl_frame_loop_state.init_fn(rl_frame_loop_state.user_data);
            }
            rl_frame_loop_state.init_complete = 1;

            if (!rl_frame_loop_state.running) {
                break;
            }
        }

        rl_frame_loop_state.tick_fn(rl_frame_loop_state.user_data);
    }
    rl_frame_finish_run();
#endif
}

RL_KEEP
void rl_frame_runner_request_stop() {
    rl_frame_loop_state.running = 0;
}

RL_KEEP
void rl_frame_runner_set_target_fps(int fps) {
    SetTargetFPS(fps);
}
