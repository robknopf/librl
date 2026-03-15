import { CommandType } from "../types";
import { get_frame_command_buffer } from "../frame_command_buffer";
import { rl_frame_commands_append } from "./rl_frame_commands";
import { RL_FONT_DEFAULT } from "./rl_font";

export function rl_text_draw_fps(_x: number, _y: number): void {}

export function rl_text_draw_fps_ex(font: number, x: number, y: number, font_size: number, color: number): void {
  rl_text_draw_ex(font, "FPS", x, y, font_size, 1.0, color);
}

export function rl_text_draw(text: string, x: number, y: number, font_size: number, color: number): void {
  rl_text_draw_ex(RL_FONT_DEFAULT, text, x, y, font_size, 1.0, color);
}

export function rl_text_draw_ex(
  font: number,
  text: string,
  x: number,
  y: number,
  font_size: number,
  spacing: number,
  color: number,
): void {
  const frame_command_buffer = get_frame_command_buffer();
  if (frame_command_buffer == null) {
    return;
  }

  rl_frame_commands_append(frame_command_buffer, {
    type: CommandType.DRAW_TEXT,
    font,
    color,
    x,
    y,
    fontSize: font_size,
    spacing,
    text,
  });
}

export function rl_text_measure(text: string, font_size: number): number {
  return Math.round(text.length * font_size * 0.5);
}

export function rl_text_measure_ex(_font: number, text: string, font_size: number, spacing: number): { x: number; y: number } {
  return {
    x: text.length * (font_size * 0.5 + spacing),
    y: font_size,
  };
}
