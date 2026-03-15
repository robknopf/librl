import type { PickRequest } from "./protocol";
import { PickRequestType } from "./protocol";
import {
  rl_model_animation_update,
  rl_model_create,
  rl_model_destroy,
  rl_model_draw,
  rl_model_is_valid,
  rl_model_set_transform,
} from "./rl/rl_model";
import {
  rl_loader_add_task,
  rl_loader_add_task_result_t,
  rl_loader_import_asset_async,
} from "./rl/rl_loader";

export class Model {
  handle: number | null = null;
  private _x = 0.0;
  private _y = 0.0;
  private _z = 0.0;
  private _scale = 1.0;
  private _rotationX = 0.0;
  private _rotationY = 0.0;
  private _rotationZ = 0.0;
  private _animationIndex = -1;
  private _animationFrame = 0;
  private transformDirty = true;

  constructor(public readonly path: string) {}

  load(on_ready?: ((model: Model) => void) | null, on_failure?: ((path: string) => void) | null): void {
    const task = rl_loader_import_asset_async(this.path);
    const rc = rl_loader_add_task(
      task,
      this.path,
      () => {
        void rl_model_create(this.path)
          .then((handle) => {
            this.handle = handle;
            on_ready?.(this);
          })
          .catch(() => {
            on_failure?.(this.path);
          });
      },
      (failedPath) => {
        on_failure?.(failedPath);
      },
      undefined,
    );

    if (rc !== rl_loader_add_task_result_t.RL_LOADER_ADD_TASK_OK) {
      on_failure?.(this.path);
    }
  }

  draw(tint: number): void {
    if (this.handle == null || !rl_model_is_valid(this.handle)) {
      return;
    }

    this.sync();
    rl_model_animation_update(this.handle, this.animationIndex, this.animationFrame);
    rl_model_draw(
      this.handle,
      tint,
    );
  }

  set(
    x: number,
    y: number,
    z: number,
    rotationX: number,
    rotationY: number,
    rotationZ: number,
    scale: number,
  ): void {
    this._x = x;
    this._y = y;
    this._z = z;
    this._rotationX = rotationX;
    this._rotationY = rotationY;
    this._rotationZ = rotationZ;
    this._scale = scale;
    this.transformDirty = true;
  }

  sync(): boolean {
    if (this.handle == null || !rl_model_is_valid(this.handle) || !this.transformDirty) {
      return false;
    }

    const ok = rl_model_set_transform(
      this.handle,
      this._x,
      this._y,
      this._z,
      this._rotationX,
      this._rotationY,
      this._rotationZ,
      this._scale,
      this._scale,
      this._scale,
    );

    if (ok) {
      this.transformDirty = false;
    }

    return ok;
  }

  createPickRequest(rid: number, camera: number, mouseX: number, mouseY: number): PickRequest | null {
    if (this.handle == null || !rl_model_is_valid(this.handle) || camera === 0) {
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

  async destroy(): Promise<void> {
    if (this.handle == null || !rl_model_is_valid(this.handle)) {
      return;
    }

    await rl_model_destroy(this.handle);
    this.handle = 0;
  }

  get x(): number { return this._x; }
  set x(value: number) { this._x = value; this.transformDirty = true; }

  get y(): number { return this._y; }
  set y(value: number) { this._y = value; this.transformDirty = true; }

  get z(): number { return this._z; }
  set z(value: number) { this._z = value; this.transformDirty = true; }

  get scale(): number { return this._scale; }
  set scale(value: number) { this._scale = value; this.transformDirty = true; }

  get rotationX(): number { return this._rotationX; }
  set rotationX(value: number) { this._rotationX = value; this.transformDirty = true; }

  get rotationY(): number { return this._rotationY; }
  set rotationY(value: number) { this._rotationY = value; this.transformDirty = true; }

  get rotationZ(): number { return this._rotationZ; }
  set rotationZ(value: number) { this._rotationZ = value; this.transformDirty = true; }

  get animationIndex(): number { return this._animationIndex; }
  set animationIndex(value: number) { this._animationIndex = value; }

  get animationFrame(): number { return this._animationFrame; }
  set animationFrame(value: number) { this._animationFrame = value; }
}
