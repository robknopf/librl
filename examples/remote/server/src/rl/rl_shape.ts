import { CommandType } from "../types";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";

export function rl_shape_draw_rectangle(
  _x: number,
  _y: number,
  _width: number,
  _height: number,
  _color: number,
): void {
  // The remote frame protocol does not yet expose a rectangle command.
}

export function rl_shape_draw_cube(
  position_x: number,
  position_y: number,
  position_z: number,
  width: number,
  height: number,
  length: number,
  color: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_CUBE,
    color,
    x: position_x,
    y: position_y,
    z: position_z,
    width,
    height,
    length,
  });
}
