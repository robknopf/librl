import type { Command } from "./types";
import { CommandType } from "./types";
import type { PickRequest } from "./protocol";
import { PickRequestType } from "./protocol";
import { ResourceManager } from "./resource_manager";

export class Model {
  handle: number | null = null;
  x = 0.0;
  y = 0.0;
  z = 0.0;
  scale = 1.0;
  rotationX = 0.0;
  rotationY = 0.0;
  rotationZ = 0.0;
  animationIndex = -1;
  animationFrame = 0;

  constructor(public readonly path: string) {}

  static async load(path: string, resourceManager: ResourceManager): Promise<Model> {
    const model = new Model(path);

    model.handle = await resourceManager.createModel(path);
    return model;
  }

  draw(commands: Command[], tint: number): void {
    if (this.handle == null || this.handle === 0) {
      return;
    }

    commands.push({
      type: CommandType.DRAW_MODEL,
      model: this.handle,
      tint,
      x: this.x,
      y: this.y,
      z: this.z,
      scale: this.scale,
      rotationX: this.rotationX,
      rotationY: this.rotationY,
      rotationZ: this.rotationZ,
      animationIndex: this.animationIndex,
      animationFrame: this.animationFrame,
    });
  }

  createPickRequest(rid: number, camera: number, mouseX: number, mouseY: number): PickRequest | null {
    if (this.handle == null || this.handle === 0 || camera === 0) {
      return null;
    }

    return {
      rid,
      type: PickRequestType.MODEL,
      camera,
      handle: this.handle,
      mouseX,
      mouseY,
      x: this.x,
      y: this.y,
      z: this.z,
      scale: this.scale,
      rotationX: this.rotationX,
      rotationY: this.rotationY,
      rotationZ: this.rotationZ,
    };
  }

  async destroy(resourceManager: ResourceManager): Promise<void> {
    if (this.handle == null || this.handle === 0) {
      return;
    }

    await resourceManager.destroyResource(this.handle);
    this.handle = 0;
  }
}
