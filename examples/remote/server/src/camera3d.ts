import {
  rl_camera3d_create,
  rl_camera3d_destroy,
  rl_camera3d_get_active,
  rl_camera3d_set,
  rl_camera3d_set_active,
} from "./rl/rl_camera3d";

export class Camera3D {
  handle: number | null = null;
  private _positionX: number;
  private _positionY: number;
  private _positionZ: number;
  private _targetX: number;
  private _targetY: number;
  private _targetZ: number;
  private _upX: number;
  private _upY: number;
  private _upZ: number;
  private _fovy: number;
  private _projection: number;
  private dirty = true;

  constructor(
    positionX: number,
    positionY: number,
    positionZ: number,
    targetX: number,
    targetY: number,
    targetZ: number,
    upX: number,
    upY: number,
    upZ: number,
    fovy: number,
    projection: number,
  ) {
    this._positionX = positionX;
    this._positionY = positionY;
    this._positionZ = positionZ;
    this._targetX = targetX;
    this._targetY = targetY;
    this._targetZ = targetZ;
    this._upX = upX;
    this._upY = upY;
    this._upZ = upZ;
    this._fovy = fovy;
    this._projection = projection;
  }

  static async create(
    positionX: number,
    positionY: number,
    positionZ: number,
    targetX: number,
    targetY: number,
    targetZ: number,
    upX: number,
    upY: number,
    upZ: number,
    fovy: number,
    projection: number,
  ): Promise<Camera3D> {
    const camera = new Camera3D(
      positionX,
      positionY,
      positionZ,
      targetX,
      targetY,
      targetZ,
      upX,
      upY,
      upZ,
      fovy,
      projection,
    );
    camera.handle = await rl_camera3d_create(
      positionX, positionY, positionZ,
      targetX, targetY, targetZ,
      upX, upY, upZ,
      fovy, projection,
    );
    return camera;
  }

  set(
    positionX: number,
    positionY: number,
    positionZ: number,
    targetX: number,
    targetY: number,
    targetZ: number,
    upX: number,
    upY: number,
    upZ: number,
    fovy: number,
    projection: number,
  ): boolean {
    this.positionX = positionX;
    this.positionY = positionY;
    this.positionZ = positionZ;
    this.targetX = targetX;
    this.targetY = targetY;
    this.targetZ = targetZ;
    this.upX = upX;
    this.upY = upY;
    this.upZ = upZ;
    this.fovy = fovy;
    this.projection = projection;
    this.dirty = true;
    return true;
  }

  sync(): boolean {
    if (this.handle == null) {
      return false;
    }

    if (!this.dirty) {
      return false;
    }

    const ok = rl_camera3d_set(
      this.handle,
      this._positionX, this._positionY, this._positionZ,
      this._targetX, this._targetY, this._targetZ,
      this._upX, this._upY, this._upZ,
      this._fovy, this._projection,
    );

    if (ok) {
      this.dirty = false;
    }

    return ok;
  }

  setActive(): boolean {
    return this.handle != null ? rl_camera3d_set_active(this.handle) : false;
  }

  isActive(): boolean {
    return this.handle != null && rl_camera3d_get_active() === this.handle;
  }

  async destroy(): Promise<void> {
    if (this.handle == null) {
      return;
    }
    await rl_camera3d_destroy(this.handle);
    this.handle = 0;
  }

  get positionX(): number { return this._positionX; }
  set positionX(value: number) { this._positionX = value; this.dirty = true; }

  get positionY(): number { return this._positionY; }
  set positionY(value: number) { this._positionY = value; this.dirty = true; }

  get positionZ(): number { return this._positionZ; }
  set positionZ(value: number) { this._positionZ = value; this.dirty = true; }

  get targetX(): number { return this._targetX; }
  set targetX(value: number) { this._targetX = value; this.dirty = true; }

  get targetY(): number { return this._targetY; }
  set targetY(value: number) { this._targetY = value; this.dirty = true; }

  get targetZ(): number { return this._targetZ; }
  set targetZ(value: number) { this._targetZ = value; this.dirty = true; }

  get upX(): number { return this._upX; }
  set upX(value: number) { this._upX = value; this.dirty = true; }

  get upY(): number { return this._upY; }
  set upY(value: number) { this._upY = value; this.dirty = true; }

  get upZ(): number { return this._upZ; }
  set upZ(value: number) { this._upZ = value; this.dirty = true; }

  get fovy(): number { return this._fovy; }
  set fovy(value: number) { this._fovy = value; this.dirty = true; }

  get projection(): number { return this._projection; }
  set projection(value: number) { this._projection = value; this.dirty = true; }
}
