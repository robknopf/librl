import {
  rl_frame_command_buffer_create,
  type rl_frame_command_buffer_t,
} from "./rl/rl_frame_commands";

let current_frame_command_buffer: rl_frame_command_buffer_t | null = null;

export function create_frame_command_buffer(): rl_frame_command_buffer_t {
  return rl_frame_command_buffer_create();
}

export function destroy_frame_command_buffer(
  frame_command_buffer: rl_frame_command_buffer_t | null,
): void {
  if (current_frame_command_buffer === frame_command_buffer) {
    current_frame_command_buffer = null;
  }
}

export function set_frame_command_buffer(
  frame_command_buffer: rl_frame_command_buffer_t | null,
): void {
  current_frame_command_buffer = frame_command_buffer;
}

export function get_frame_command_buffer(): rl_frame_command_buffer_t | null {
  return current_frame_command_buffer;
}
