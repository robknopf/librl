import { rl_shape_draw_cube, rl_shape_draw_rectangle } from "./rl/rl_shape";

export class Shape {
  static drawRectangle(x: number, y: number, width: number, height: number, color: number): void {
    rl_shape_draw_rectangle(x, y, width, height, color);
  }

  static drawCube(
    positionX: number,
    positionY: number,
    positionZ: number,
    width: number,
    height: number,
    length: number,
    color: number,
  ): void {
    rl_shape_draw_cube(positionX, positionY, positionZ, width, height, length, color);
  }
}
