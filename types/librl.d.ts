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
  pressed_key: number;
  pressed_char: number;
  num_pressed_keys: number;
  pressed_keys: Int32Array;
  num_pressed_chars: number;
  pressed_chars: Int32Array;
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
  /**
   * Window dimensions and flags passed to `rl_init()`.
   * If omitted, librl uses its internal defaults.
   */
  windowWidth?: number;
  windowHeight?: number;
  windowTitle?: string;
  windowFlags?: number;
  loaderCacheDir?: string;
  idealWidth?: number;
  idealHeight?: number;
  env?: RLInitEnv;
}

export type RLEventCallback = (payload: number) => void;
export type RLTaskGroupTaskCallback<T = unknown> = (path: string, ctx: T) => void;
export type RLTaskGroupCallback<T = unknown> = (group: RLTaskGroup<T>, ctx: T) => void;

export interface RLTaskGroup<T = unknown> {
  failedCount: number;
  completedCount: number;
  addTask(task: number, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTask(path: string, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTasks(paths: string[], onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  remainingTasks(): number;
  isDone(): boolean;
  hasFailures(): boolean;
  tick(): boolean;
  process(): number;
  failedPaths(): string[];
}

export interface RLApi {
  _waitForIdbfsReady(timeoutMs?: number): Promise<boolean>;
  isIdbfsReady(): boolean;
  waitForIdbfsReady(timeoutMs?: number): Promise<boolean>;

  init(opts?: RLInitOptions): Promise<number>;
  update(): void;
  getTime(): number;
  deinit(): void;
  uncacheFile(filename: string): number;
  clearCache(): number;
  restoreFS(): number;
  importAsset(filename: string): number;
  importAssets(filenames: string[]): number;
  pollTask(task: number): boolean;
  finishTask(task: number): number;
  freeTask(task: number): void;
  loaderTick(): void;
  createTaskGroup<T = unknown>(
    onComplete?: RLTaskGroupCallback<T> | null,
    onError?: RLTaskGroupCallback<T> | null,
    ctx?: T
  ): RLTaskGroup<T>;
  isLocalFile(filename: string): boolean;
  waitForTask(task: number, pollMs?: number): Promise<number>;
  restore(): Promise<number>;
  importAssetAsync(filename: string): Promise<number>;
  importAssetsAsync(filenames: string[]): Promise<number>;
  emitEvent(eventName: string, payload?: number): number;
  onEvent(eventName: string, callback: RLEventCallback): number;
  onceEvent(eventName: string, callback: RLEventCallback): number;
  offEvent(eventName: string, callback: RLEventCallback): number;
  clearEventListeners(eventName: string): number;
  getEventListenerCount(eventName: string): number;

  setWindowSize(width: number, height: number): void;
  setWindowPosition(x: number, y: number): void;

  beginDrawing(): void;
  endDrawing(): void;
  beginMode3D(): void;
  endMode3D(): void;
  start(init: (() => void) | null | undefined, tick: () => void, shutdown?: (() => void) | null): number;
  tick(): number;
  stop(): void;
  run(init: (() => void) | null | undefined, tick: () => void, shutdown?: (() => void) | null): void;

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
  drawTextureEx(texture: RLHandle, x: number, y: number, scale: number, rotation: number, tint: RLHandle): void;
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
  createFontFromLocal(path: string, fontSize: number): RLHandle;
  destroyFont(font: RLHandle): void;
  rl_font_get_default(): RLHandle;

  setTargetFPS(fps: number): void;

  createModel(path: string): Promise<RLHandle>;
  createModelFromLocal(path: string): RLHandle;
  modelSetTransform(
    model: RLHandle,
    positionX: number, positionY: number, positionZ: number,
    rotationX: number, rotationY: number, rotationZ: number,
    scaleX: number, scaleY: number, scaleZ: number
  ): boolean;
  drawModel(model: RLHandle, tint: RLHandle): void;
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
  createMusicFromLocal(path: string): RLHandle;
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
  createSprite3DFromLocal(path: string): RLHandle;
  createSprite3DFromTexture(texture: RLHandle): RLHandle;
  sprite3DSetTransform(sprite: RLHandle, positionX: number, positionY: number, positionZ: number, size: number): boolean;
  drawSprite3D(sprite: RLHandle, tint: RLHandle): void;
  destroySprite3D(sprite: RLHandle): void;

  COLOR_DEFAULT: number;
  COLOR_LIGHTGRAY: number;
  COLOR_GRAY: number;
  COLOR_DARKGRAY: number;
  COLOR_YELLOW: number;
  COLOR_GOLD: number;
  COLOR_ORANGE: number;
  COLOR_PINK: number;
  COLOR_RED: number;
  COLOR_MAROON: number;
  COLOR_GREEN: number;
  COLOR_LIME: number;
  COLOR_DARKGREEN: number;
  COLOR_SKYBLUE: number;
  COLOR_BLUE: number;
  COLOR_DARKBLUE: number;
  COLOR_PURPLE: number;
  COLOR_VIOLET: number;
  COLOR_DARKPURPLE: number;
  COLOR_BEIGE: number;
  COLOR_BROWN: number;
  COLOR_DARKBROWN: number;
  COLOR_WHITE: number;
  COLOR_BLACK: number;
  COLOR_BLANK: number;
  COLOR_MAGENTA: number;
  COLOR_RAYWHITE: number;
  CAMERA_PERSPECTIVE: number;
  CAMERA_ORTHOGRAPHIC: number;
  FLAG_MSAA_4X_HINT: number;
  BUTTON_UP: number;
  BUTTON_PRESSED: number;
  BUTTON_DOWN: number;
  BUTTON_RELEASED: number;
}

export const rl: RLApi;
