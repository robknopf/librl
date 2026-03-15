import { rl_texture_create, rl_texture_destroy, rl_texture_draw_ex, rl_texture_draw_ground } from "./rl/rl_texture";

export class Texture {
  handle: number | null = null;

  constructor(public readonly path: string) {}

  static async load(path: string): Promise<Texture> {
    const texture = new Texture(path);
    texture.handle = await rl_texture_create(path);
    return texture;
  }

  drawEx(x: number, y: number, scale: number, rotation: number, tint: number): void {
    if (this.handle == null) {
      return;
    }

    rl_texture_draw_ex(this.handle, x, y, scale, rotation, tint);
  }

  drawGround(positionX: number, positionY: number, positionZ: number, width: number, length: number, tint: number): void {
    if (this.handle == null) {
      return;
    }

    rl_texture_draw_ground(this.handle, positionX, positionY, positionZ, width, length, tint);
  }

  async destroy(): Promise<void> {
    if (this.handle == null) {
      return;
    }
    await rl_texture_destroy(this.handle);
    this.handle = 0;
  }
}
