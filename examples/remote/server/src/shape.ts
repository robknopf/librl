import { rl_shape_draw_circle_3d, rl_shape_draw_cube, rl_shape_draw_rectangle } from "./rl/rl_shape";

export class Shape {
  static drawRectangle(x: number, y: number, width: number, height: number, color: number): void {
    rl_shape_draw_rectangle(x, y, width, height, color);
  }

  static drawCircle3d(
    centerX: number,
    centerY: number,
    centerZ: number,
    radius: number,
    rotationAxisX: number,
    rotationAxisY: number,
    rotationAxisZ: number,
    rotationAngle: number,
    color: number,
  ): void {
    rl_shape_draw_circle_3d(centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color);
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
