/* GENERATED — DO NOT EDIT
 * librl TypeScript declarations
 * from: bindings/js/rl.js (via tools/gen_librl_dts.py)
 */

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

export interface RLGamepadState {
  id: number;
  axis: Float32Array;
  buttons: Int32Array;
}

export interface RLTouchpoint {
  id: number;
  x: number;
  y: number;
}

export interface RLPickResult {
  hit: boolean;
  distance: number;
  point: RLVector3;
  normal: RLVector3;
}

export interface RLSprite3dTransform {
  positionX: number;
  positionY: number;
  positionZ: number;
  size: number;
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
  fsRootDir?: string;
  windowWidth?: number;
  windowHeight?: number;
  windowTitle?: string;
  windowFlags?: number;
  loaderCacheDir?: string;
  idealWidth?: number;
  idealHeight?: number;
  env?: RLInitEnv;
  [key: string]: unknown;
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

export interface RLHelpers {
  waitForFsReady(timeoutMs?: number): Promise<boolean>;
  taskIsValid(task: number): boolean;
  waitForTask(task: number, pollMs?: number): Promise<number>;
  waitForFsRestoreAsync(): Promise<number>;
  waitForAssetEnsureAsync(localPath: string, src?: string | null): Promise<number>;
  waitForAssetEnsureGroupAsync(filenames: string[]): Promise<number>;
  createTaskGroup<T = unknown>(onComplete?: RLTaskGroupCallback<T> | null, onError?: RLTaskGroupCallback<T> | null, ctx?: T): RLTaskGroup<T>;
  getScreenWidth(): number;
  getScreenHeight(): number;
  getPickStats(): RLPickStats;
}

export interface RLFs {
  remove(...args: unknown[]): unknown;
  clear(...args: unknown[]): unknown;
  init(rootDir?: string): Promise<number>;
  initAsync(rootDir?: string): number;
  deinitAsync(...args: unknown[]): unknown;
  deinit(): Promise<void>;
  isInitialized(): boolean;
  isReady(): boolean;
  flush(...args: unknown[]): unknown;
  getRootDir(): string;
  normalizePath(path: string): string;
  restoreAsync(): number;
  read(filename: string): Uint8Array | null;
  write(path: string, data: ArrayBufferView): number;
  mkdir(...args: unknown[]): unknown;
  rmdir(...args: unknown[]): unknown;
  exists(filename: string): boolean;
}
export interface RLAsset {
  ADD_TASK_OK: number;
  ADD_TASK_ERR_INVALID: number;
  ADD_TASK_ERR_QUEUE_FULL: number;
  pingHost(...args: unknown[]): unknown;
  setHost(assetHost: string): number;
  getHost(): string;
  ensure(localPath: string, src?: string | null): Promise<number>;
  ensureAsync(localPath: string, src?: string | null): number;
  ensureGroupAsync(filenames: string[]): number;
  pollTask(task: number): boolean;
  finishTask(...args: unknown[]): unknown;
  getTaskPath(task: number): string;
  freeTask(...args: unknown[]): unknown;
  addTask(...args: unknown[]): unknown;
  tick(...args: unknown[]): unknown;
}
export interface RLModel {
  getDefaultAsset(...args: unknown[]): unknown;
  loadAsset(...args: unknown[]): unknown;
  destroyAsset(...args: unknown[]): unknown;
  create(...args: unknown[]): unknown;
  createFromFile(...args: unknown[]): unknown;
  setAsset(...args: unknown[]): unknown;
  setTransform(...args: unknown[]): unknown;
  draw(...args: unknown[]): unknown;
  isValid(model: RLHandle): boolean;
  isValidStrict(model: RLHandle): boolean;
  getAnimationCount(...args: unknown[]): unknown;
  getAnimationFrameCount(...args: unknown[]): unknown;
  updateAnimation(...args: unknown[]): unknown;
  setAnimation(...args: unknown[]): unknown;
  setAnimationSpeed(...args: unknown[]): unknown;
  setAnimationLoop(...args: unknown[]): unknown;
  setTint(...args: unknown[]): unknown;
  animate(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
}
export interface RLSprite3d {
  create(...args: unknown[]): unknown;
  createFromFile(...args: unknown[]): unknown;
  setTexture(...args: unknown[]): unknown;
  setTransform(...args: unknown[]): unknown;
  getDefaultTexture(...args: unknown[]): unknown;
  getTransform(sprite: RLHandle): RLSprite3dTransform | null;
  setTint(...args: unknown[]): unknown;
  draw(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
}
export interface RLSprite2d {
  create(...args: unknown[]): unknown;
  createFromFile(...args: unknown[]): unknown;
  getDefaultTexture(...args: unknown[]): unknown;
  setTexture(...args: unknown[]): unknown;
  setTransform(...args: unknown[]): unknown;
  setTint(...args: unknown[]): unknown;
  draw(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
}
export interface RLText2d {
  create(font: RLHandle, size: number): RLHandle;
  setFont(handle: RLHandle, font: RLHandle): void;
  setSize(handle: RLHandle, size: number): void;
  setContent(handle: RLHandle, content: string): void;
  setPosition(handle: RLHandle, x: number, y: number): void;
  setColor(handle: RLHandle, color: RLHandle): void;
  draw(handle: RLHandle): void;
  destroy(handle: RLHandle): void;
}
export interface RLTexture {
  getDefault(): RLHandle;
  create(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
  drawEx(...args: unknown[]): unknown;
  drawGround(...args: unknown[]): unknown;
}
export interface RLFont {
  create(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
  getDefault(): RLHandle;
}
export interface RLCamera3d {
  create(...args: unknown[]): unknown;
  getDefault(): RLHandle;
  set(...args: unknown[]): unknown;
  setActive(...args: unknown[]): unknown;
  getActive(): RLHandle;
  destroy(...args: unknown[]): unknown;
}
export interface RLWindow {
  setSize(...args: unknown[]): unknown;
  isCloseRequested(): boolean;
  getMonitorCount(...args: unknown[]): unknown;
  setTitle(...args: unknown[]): unknown;
  getCurrentMonitor(...args: unknown[]): unknown;
  setMonitor(...args: unknown[]): unknown;
  getMonitorWidth(...args: unknown[]): unknown;
  getMonitorHeight(...args: unknown[]): unknown;
  setPosition(...args: unknown[]): unknown;
  getScreenSize(): RLVector2;
  getPosition(): RLVector2;
  getMonitorPosition(monitor?: number): RLVector2;
}
export interface RLInput {
  pollEvents(...args: unknown[]): unknown;
  getMouseWheel(...args: unknown[]): unknown;
  getMouseButton(...args: unknown[]): unknown;
  getMouseState(): RLMouseState;
  getKeyboardState(): RLKeyboardState;
  getGamepads(): RLGamepadState[];
  getGamepad(id: number): RLGamepadState | null;
  getTouchpoints(): RLTouchpoint[];
  getTouchpoint(id: number): RLTouchpoint | null;
  getMousePosition(): RLVector2;
}
export interface RLRender {
  begin(...args: unknown[]): unknown;
  end(...args: unknown[]): unknown;
  beginMode2D(...args: unknown[]): unknown;
  endMode2D(...args: unknown[]): unknown;
  beginMode3D(...args: unknown[]): unknown;
  endMode3D(...args: unknown[]): unknown;
  clearBackground(...args: unknown[]): unknown;
  enableLighting(...args: unknown[]): unknown;
  disableLighting(...args: unknown[]): unknown;
  isLightingEnabled(): boolean;
  setLightDirection(...args: unknown[]): unknown;
  setLightAmbient(...args: unknown[]): unknown;
}
export interface RLText {
  drawFps(...args: unknown[]): unknown;
  drawFpsEx(...args: unknown[]): unknown;
  draw(...args: unknown[]): unknown;
  drawEx(...args: unknown[]): unknown;
  measure(...args: unknown[]): unknown;
  measureEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;
}
export interface RLShape {
  drawCube(...args: unknown[]): unknown;
  drawRectangle(...args: unknown[]): unknown;
}
export interface RLDebug {
  enableFps(...args: unknown[]): unknown;
  disable(...args: unknown[]): unknown;
}
export interface RLLogger {
  message(...args: unknown[]): unknown;
  messageSource(...args: unknown[]): unknown;
  setLevel(...args: unknown[]): unknown;
}
export interface RLPick {
  model(camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  sprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  resetStats(...args: unknown[]): unknown;
}
export interface RLEvent {
  emit(eventName: string, payload?: number): number;
  on(eventName: string, callback: RLEventCallback): number;
  once(eventName: string, callback: RLEventCallback): number;
  off(eventName: string, callback: RLEventCallback): number;
  clearListeners(...args: unknown[]): unknown;
  getListenerCount(...args: unknown[]): unknown;
}
export interface RLColor {
  create(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
}
export interface RLMusic {
  create(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
  play(...args: unknown[]): unknown;
  pause(...args: unknown[]): unknown;
  stop(...args: unknown[]): unknown;
  setLoop(...args: unknown[]): unknown;
  setVolume(...args: unknown[]): unknown;
  isPlaying(music: RLHandle): boolean;
  update(...args: unknown[]): unknown;
  updateAll(...args: unknown[]): unknown;
}
export interface RLSound {
  create(...args: unknown[]): unknown;
  destroy(...args: unknown[]): unknown;
  play(...args: unknown[]): unknown;
  pause(...args: unknown[]): unknown;
  resume(...args: unknown[]): unknown;
  stop(...args: unknown[]): unknown;
  setVolume(...args: unknown[]): unknown;
  setPitch(...args: unknown[]): unknown;
  setPan(...args: unknown[]): unknown;
  isPlaying(sound: RLHandle): boolean;
}

export interface RLApi {
  TICK_RUNNING: number;
  TICK_WAITING: number;
  TICK_FAILED: number;
  boot(opts?: RLInitOptions): Promise<number>;
  init(opts?: RLInitOptions): Promise<number>;
  initAsync(opts?: RLInitOptions): number;
  refreshScratch(): void;
  getTime(): number;
  deinit(): Promise<void>;
  isInitialized(): boolean;
  getPlatform(): string;
  getVersionMajor(): number;
  getVersionMinor(): number;
  getVersionPatch(): number;
  versionLabel(): string;
  getVersionNumber(): number;
  getVersionString(): string;
  tick(): number;
  getDeltaTime(): number;
  setTargetFPS(fps: number): void;
  INIT_OK: number;
  INIT_ERR_UNKNOWN: number;
  INIT_ERR_ALREADY_INITIALIZED: number;
  INIT_ERR_LOADER: number;
  INIT_ERR_ASSET_HOST: number;
  INIT_ERR_WINDOW: number;
  BOOT_OK: number;
  BOOT_ERR_UNKNOWN: number;
  BOOT_ERR_LOADER: number;
  BOOT_ERR_VERSION_MISMATCH: number;
  CAMERA_PERSPECTIVE: number;
  CAMERA_ORTHOGRAPHIC: number;
  FLAG_FULLSCREEN_MODE: number;
  FLAG_WINDOW_RESIZABLE: number;
  FLAG_WINDOW_UNDECORATED: number;
  FLAG_WINDOW_TRANSPARENT: number;
  FLAG_MSAA_4X_HINT: number;
  FLAG_VSYNC_HINT: number;
  FLAG_WINDOW_HIDDEN: number;
  FLAG_WINDOW_ALWAYS_RUN: number;
  FLAG_WINDOW_MINIMIZED: number;
  FLAG_WINDOW_MAXIMIZED: number;
  FLAG_WINDOW_UNFOCUSED: number;
  FLAG_WINDOW_TOPMOST: number;
  FLAG_WINDOW_HIGHDPI: number;
  FLAG_INTERLACED_HINT: number;
  LOGGER_LEVEL_TRACE: number;
  LOGGER_LEVEL_DEBUG: number;
  LOGGER_LEVEL_INFO: number;
  LOGGER_LEVEL_WARN: number;
  LOGGER_LEVEL_ERROR: number;
  LOGGER_LEVEL_FATAL: number;
  BUTTON_UP: number;
  BUTTON_PRESSED: number;
  BUTTON_DOWN: number;
  BUTTON_RELEASED: number;
  helpers: RLHelpers;
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
  fs: RLFs;
  asset: RLAsset;
  model: RLModel;
  sprite3d: RLSprite3d;
  sprite2d: RLSprite2d;
  text2d: RLText2d;
  texture: RLTexture;
  font: RLFont;
  camera3d: RLCamera3d;
  window: RLWindow;
  input: RLInput;
  render: RLRender;
  text: RLText;
  shape: RLShape;
  debug: RLDebug;
  logger: RLLogger;
  pick: RLPick;
  event: RLEvent;
  color: RLColor;
  music: RLMusic;
  sound: RLSound;
}

export const rl: RLApi;
