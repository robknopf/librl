#ifndef RL_FRAME_RUNNER_H
#define RL_FRAME_RUNNER_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*rl_frame_runner_init_fn)(void *user_data);
typedef void (*rl_frame_runner_tick_fn)(void *user_data);
typedef void (*rl_frame_runner_shutdown_fn)(void *user_data);

void rl_frame_runner_run(rl_frame_runner_init_fn init_fn,
                         rl_frame_runner_tick_fn tick_fn,
                         rl_frame_runner_shutdown_fn shutdown_fn,
                         void *user_data);
void rl_frame_runner_request_stop(void);
void rl_frame_runner_set_target_fps(int fps);

#ifdef __cplusplus
}
#endif

#endif // RL_FRAME_RUNNER_H
