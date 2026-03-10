export type RLHandle = number;

export interface RLVector2 {
  x: number;
  y: number;
}

export interface RLVector3 {
  x: number;
  y: number;
  z: number;
}

export interface RLVector4 {
  x: number;
  y: number;
  z: number;
  w: number;
}

export interface RLMouseState {
  x: number;
  y: number;
  wheel: number;
  left: number;
  right: number;
  middle: number;
  buttons: Int32Array;
}

export interface RLKeyboardState {
  max_num_keys: number;
  keys: Int32Array;
  last_key: number;
  last_char: number;
}

export interface RLPickResult {
  hit: boolean;
  distance: number;
  point: RLVector3;
  normal: RLVector3;
}

export interface RLPickStats {
  broadphaseTests: number;
  broadphaseRejects: number;
  narrowphaseTests: number;
  narrowphaseHits: number;
}

export interface RLInitEnv {
  canvas?: HTMLCanvasElement | null;
  print?: (...args: unknown[]) => void;
  [key: string]: unknown;
}

export interface RLInitOptions {
  assetHost?: string;
  idealWidth?: number;
  idealHeight?: number;
  env?: RLInitEnv;
}

export interface RLApi {
  _waitForIdbfsReady(timeoutMs?: number): Promise<boolean>;
  isIdbfsReady(): boolean;
  waitForIdbfsReady(timeoutMs?: number): Promise<boolean>;

  init(opts?: RLInitOptions): Promise<void>;
  update(): void;
  getTime(): number;
  deinit(): void;

  initWindow(width: number, height: number, title: string, flags?: number): void;
  closeWindow(): void;
  setWindowSize(width: number, height: number): void;
  setWindowPosition(x: number, y: number): void;

  beginDrawing(): void;
  endDrawing(): void;
  beginMode3D(): void;
  endMode3D(): void;

  createCamera3D(
    positionX: number, positionY: number, positionZ: number,
    targetX: number, targetY: number, targetZ: number,
    upX: number, upY: number, upZ: number,
    fovy: number, projection: number
  ): RLHandle;
  getDefaultCamera3D(): RLHandle;
  setCamera3D(
    camera: RLHandle,
    positionX: number, positionY: number, positionZ: number,
    targetX: number, targetY: number, targetZ: number,
    upX: number, upY: number, upZ: number,
    fovy: number, projection: number
  ): boolean;
  setActiveCamera3D(camera: RLHandle): boolean;
  getActiveCamera3D(): RLHandle;
  destroyCamera3D(camera: RLHandle): void;

  enableLighting(): void;
  disableLighting(): void;
  isLightingEnabled(): boolean;
  setLightDirection(x: number, y: number, z: number): void;
  setLightAmbient(ambient: number): void;

  clearBackground(color: RLHandle): void;
  drawCube(positionX: number, positionY: number, positionZ: number, width: number, height: number, length: number, color: RLHandle): void;
  drawFPS(x: number, y: number): void;
  drawFPSEx(font: RLHandle, x: number, y: number, fontSize: number, color: RLHandle): void;
  drawText(text: string, x: number, y: number, fontSize: number, color: RLHandle): void;
  drawTextEx(font: RLHandle, text: string, x: number, y: number, fontSize: number, spacing: number, tint: RLHandle): void;
  measureText(text: string, fontSize: number): number;
  measureTextEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;

  getMouseState(): RLMouseState;
  getKeyboardState(): RLKeyboardState;
  getScreenSize(): RLVector2;
  getScreenWidth(): number;
  getScreenHeight(): number;
  getWindowPosition(): RLVector2;
  getMonitorPosition(monitor?: number): RLVector2;
  getMousePosition(): RLVector2;

  createColor(r: number, g: number, b: number, a: number): RLHandle;
  destroyColor(color: RLHandle): void;
  createFont(path: string, fontSize: number): Promise<RLHandle>;
  destroyFont(font: RLHandle): void;
  rl_font_get_default(): RLHandle;

  setTargetFPS(fps: number): void;

  createModel(path: string): Promise<RLHandle>;
  drawModel(model: RLHandle, x: number, y: number, z: number, scale: number, tint: RLHandle): void;
  isModelValid(model: RLHandle): boolean;
  isModelValidStrict(model: RLHandle): boolean;
  modelAnimationCount(model: RLHandle): number;
  modelAnimationFrameCount(model: RLHandle, animationIndex: number): number;
  modelAnimationUpdate(model: RLHandle, animationIndex: number, frame: number): void;
  modelSetAnimation(model: RLHandle, animationIndex: number): boolean;
  modelSetAnimationSpeed(model: RLHandle, speed: number): boolean;
  modelSetAnimationLoop(model: RLHandle, shouldLoop: boolean): boolean;
  modelAnimate(model: RLHandle, deltaSeconds: number): boolean;
  destroyModel(model: RLHandle): void;

  pickModel(
    camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number,
    x?: number, y?: number, z?: number, scale?: number
  ): RLPickResult;
  pickSprite3D(
    camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number,
    x?: number, y?: number, z?: number, size?: number
  ): RLPickResult;
  resetPickStats(): void;
  getPickStats(): RLPickStats;

  createMusic(path: string): Promise<RLHandle>;
  destroyMusic(music: RLHandle): void;
  playMusic(music: RLHandle): boolean;
  pauseMusic(music: RLHandle): boolean;
  stopMusic(music: RLHandle): boolean;
  setMusicLoop(music: RLHandle, shouldLoop: boolean): boolean;
  setMusicVolume(music: RLHandle, volume: number): boolean;
  isMusicPlaying(music: RLHandle): boolean;
  updateMusic(music: RLHandle): boolean;
  updateAllMusic(): void;

  createSound(path: string): Promise<RLHandle>;
  destroySound(sound: RLHandle): void;
  playSound(sound: RLHandle): boolean;
  pauseSound(sound: RLHandle): boolean;
  resumeSound(sound: RLHandle): boolean;
  stopSound(sound: RLHandle): boolean;
  setSoundVolume(sound: RLHandle, volume: number): boolean;
  setSoundPitch(sound: RLHandle, pitch: number): boolean;
  setSoundPan(sound: RLHandle, pan: number): boolean;
  isSoundPlaying(sound: RLHandle): boolean;

  createTexture(path: string): Promise<RLHandle>;
  destroyTexture(texture: RLHandle): void;

  createSprite3D(path: string): Promise<RLHandle>;
  createSprite3DFromTexture(texture: RLHandle): RLHandle;
  drawSprite3D(sprite: RLHandle, x: number, y: number, z: number, size: number, tint: RLHandle): void;
  destroySprite3D(sprite: RLHandle): void;

  DEFAULT: number;
  LIGHTGRAY: number;
  GRAY: number;
  DARKGRAY: number;
  YELLOW: number;
  GOLD: number;
  ORANGE: number;
  PINK: number;
  RED: number;
  MAROON: number;
  GREEN: number;
  LIME: number;
  DARKGREEN: number;
  SKYBLUE: number;
  BLUE: number;
  DARKBLUE: number;
  PURPLE: number;
  VIOLET: number;
  DARKPURPLE: number;
  BEIGE: number;
  BROWN: number;
  DARKBROWN: number;
  WHITE: number;
  BLACK: number;
  BLANK: number;
  MAGENTA: number;
  RAYWHITE: number;
  CAMERA_PERSPECTIVE: number;
  CAMERA_ORTHOGRAPHIC: number;
  FLAG_MSAA_4X_HINT: number;
  BUTTON_UP: number;
  BUTTON_PRESSED: number;
  BUTTON_DOWN: number;
  BUTTON_RELEASED: number;
}

export const rl: RLApi;
