#ifndef RL_FRAME_COMMANDS_H
#define RL_FRAME_COMMANDS_H

#ifdef __cplusplus
extern "C" {
#endif

#include "rl_module.h"

#define RL_FRAME_COMMAND_CAPACITY 128

typedef struct rl_frame_command_buffer_t {
  rl_module_frame_command_t commands[RL_FRAME_COMMAND_CAPACITY];
  int count;
} rl_frame_command_buffer_t;

void rl_frame_commands_reset(rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_append(void *user_data,
                              const rl_module_frame_command_t *command);
void rl_frame_commands_execute_clear(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_audio(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_state(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_3d(
    const rl_frame_command_buffer_t *frame_commands);
void rl_frame_commands_execute_2d(
    const rl_frame_command_buffer_t *frame_commands);

#ifdef __cplusplus
}
#endif

#endif // RL_FRAME_COMMANDS_H
