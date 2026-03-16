import type { ResourceManager } from "./resource_manager";
import {
  rl_sprite3d_create,
  rl_sprite3d_create_from_texture,
  rl_sprite3d_destroy,
  rl_sprite3d_draw,
  set_resource_manager as set_sprite3d_resource_manager,
  rl_sprite3d_set_transform,
} from "./rl/rl_sprite3d";

export class Sprite3D {
  handle: number | null = null;
  private _x = 0.0;
  private _y = 0.0;
  private _z = 0.0;
  private _size = 1.0;
  private transformDirty = true;

  constructor(
    public readonly path: string | null,
    private readonly resourceManager: ResourceManager,
  ) {}

  static async load(resourceManager: ResourceManager, path: string): Promise<Sprite3D> {
    const sprite = new Sprite3D(path, resourceManager);
    set_sprite3d_resource_manager(resourceManager);
    sprite.handle = await rl_sprite3d_create(path);
    return sprite;
  }

  static async fromTexture(resourceManager: ResourceManager, texture: number): Promise<Sprite3D> {
    const sprite = new Sprite3D(null, resourceManager);
    set_sprite3d_resource_manager(resourceManager);
    sprite.handle = await rl_sprite3d_create_from_texture(texture);
    return sprite;
  }

  draw(tint: number): void {
    if (this.handle == null) {
      return;
    }
    this.sync();

    rl_sprite3d_draw(this.handle, tint);
  }

  set(x: number, y: number, z: number, size: number): void {
    if (this._x === x && this._y === y && this._z === z && this._size === size) {
      return;
    }

    this._x = x;
    this._y = y;
    this._z = z;
    this._size = size;
    this.transformDirty = true;
  }

  sync(): boolean {
    if (this.handle == null || !this.transformDirty) {
      return false;
    }

    const ok = rl_sprite3d_set_transform(this.handle, this._x, this._y, this._z, this._size);
    if (ok) {
      this.transformDirty = false;
    }

    return ok;
  }

  async destroy(): Promise<void> {
    if (this.handle == null) {
      return;
    }
    set_sprite3d_resource_manager(this.resourceManager);
    await rl_sprite3d_destroy(this.handle);
    this.handle = 0;
  }

  get x(): number { return this._x; }
  set x(value: number) {
    if (this._x === value) {
      return;
    }
    this._x = value;
    this.transformDirty = true;
  }

  get y(): number { return this._y; }
  set y(value: number) {
    if (this._y === value) {
      return;
    }
    this._y = value;
    this.transformDirty = true;
  }

  get z(): number { return this._z; }
  set z(value: number) {
    if (this._z === value) {
      return;
    }
    this._z = value;
    this.transformDirty = true;
  }

  get size(): number { return this._size; }
  set size(value: number) {
    if (this._size === value) {
      return;
    }
    this._size = value;
    this.transformDirty = true;
  }
}
