import type { Command } from "../types";

export const RL_FRAME_COMMAND_CAPACITY = 128;

export interface rl_frame_command_buffer_t {
  commands: Command[];
  count: number;
}

export function rl_frame_command_buffer_create(): rl_frame_command_buffer_t {
  return {
    commands: [],
    count: 0,
  };
}

export function rl_frame_commands_reset(frame_commands: rl_frame_command_buffer_t): void {
  frame_commands.commands = [];
  frame_commands.count = 0;
}

export function rl_frame_commands_append(
  user_data: rl_frame_command_buffer_t,
  command: Command,
): void {
  if (user_data.count >= RL_FRAME_COMMAND_CAPACITY) {
    console.error("Exceeded RL_FRAME_COMMAND_CAPACITY, no additional command will be sent this frame")
    return;
  }

  user_data.commands.push(command);
  user_data.count++;
}
