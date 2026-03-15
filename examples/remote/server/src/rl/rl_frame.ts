import type { FrameSnapshot } from "../types";
import { CommandType } from "../types";
import type { rl_frame_command_buffer_t } from "./rl_frame_commands";
import { rl_frame_commands_append } from "./rl_frame_commands";

interface rl_frame_state_t {
  frame_snapshot: FrameSnapshot | null;
  time_seconds: number;
}

const rl_frame_state: rl_frame_state_t = {
  frame_snapshot: null,
  time_seconds: 0.0,
};

export function begin_frame_snapshot(
  frame_snapshot: FrameSnapshot,
  frame_command_buffer: rl_frame_command_buffer_t,
  time_seconds: number,
): void {
  frame_snapshot.commands = frame_command_buffer.commands;
  rl_frame_state.frame_snapshot = frame_snapshot;
  rl_frame_state.time_seconds = time_seconds;
}

export function end_frame_snapshot(): void {
  rl_frame_state.frame_snapshot = null;
}

export function rl_frame_begin(): void {}

export function rl_frame_end(): void {}

export function rl_frame_clear_background(color: number): void {
  const frame_snapshot = rl_frame_state.frame_snapshot;
  if (frame_snapshot == null) {
    return;
  }

  rl_frame_commands_append(
    {
      commands: frame_snapshot.commands,
      count: frame_snapshot.commands.length,
    },
    {
      type: CommandType.CLEAR,
      color,
    },
  );
}

export function rl_frame_get_delta_time(): number {
  return rl_frame_state.frame_snapshot?.deltaTime ?? 0.0;
}

export function rl_frame_begin_mode_2d(_camera: number): void {}

export function rl_frame_end_mode_2d(): void {}

export function rl_frame_get_time(): number {
  return rl_frame_state.time_seconds;
}
