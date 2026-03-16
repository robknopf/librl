import type { ResourceManager } from "./resource_manager";
import {
  rl_texture_create,
  rl_texture_destroy,
  rl_texture_draw_ex,
  rl_texture_draw_ground,
  set_resource_manager as set_texture_resource_manager,
} from "./rl/rl_texture";

export class Texture {
  handle: number | null = null;

  constructor(
    public readonly path: string,
    private readonly resourceManager: ResourceManager,
  ) {}

  static async load(resourceManager: ResourceManager, path: string): Promise<Texture> {
    const texture = new Texture(path, resourceManager);
    set_texture_resource_manager(resourceManager);
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
    set_texture_resource_manager(this.resourceManager);
    await rl_texture_destroy(this.handle);
    this.handle = 0;
  }
}
