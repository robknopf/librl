import {
  rl_sprite3d_create,
  rl_sprite3d_create_from_texture,
  rl_sprite3d_destroy,
  rl_sprite3d_draw,
  rl_sprite3d_set_transform,
} from "./rl/rl_sprite3d";

export class Sprite3D {
  handle: number | null = null;
  private _x = 0.0;
  private _y = 0.0;
  private _z = 0.0;
  private _size = 1.0;
  private transformDirty = true;

  constructor(public readonly path: string | null) {}

  static async load(path: string): Promise<Sprite3D> {
    const sprite = new Sprite3D(path);
    sprite.handle = await rl_sprite3d_create(path);
    return sprite;
  }

  static async fromTexture(texture: number): Promise<Sprite3D> {
    const sprite = new Sprite3D(null);
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
    await rl_sprite3d_destroy(this.handle);
    this.handle = 0;
  }

  get x(): number { return this._x; }
  set x(value: number) { this._x = value; this.transformDirty = true; }

  get y(): number { return this._y; }
  set y(value: number) { this._y = value; this.transformDirty = true; }

  get z(): number { return this._z; }
  set z(value: number) { this._z = value; this.transformDirty = true; }

  get size(): number { return this._size; }
  set size(value: number) { this._size = value; this.transformDirty = true; }
}
