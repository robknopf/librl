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
  position: RLVector3;
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
  fileioBaseDir?: string;
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
  waitForFileioReady(timeoutMs?: number): Promise<boolean>;
  taskIsValid(task: number): boolean;
  waitForTask(task: number, pollMs?: number): Promise<number>;
  waitForFileioRestoreAsync(): Promise<number>;
  waitForFileioEnsureAsync(localPath: string, src?: string | null): Promise<number>;
  waitForFileioEnsureGroupAsync(filenames: string[]): Promise<number>;
  createTaskGroup<T = unknown>(onComplete?: RLTaskGroupCallback<T> | null, onError?: RLTaskGroupCallback<T> | null, ctx?: T): RLTaskGroup<T>;
  getScreenWidth(): number;
  getScreenHeight(): number;
  getPickStats(): RLPickStats;
}

export interface RLApi {
  helpers: RLHelpers;
  TICK_RUNNING: number;
  TICK_WAITING: number;
  TICK_FAILED: number;
  boot(opts?: RLInitOptions): Promise<number>;
  init(opts?: RLInitOptions): Promise<number>;
  initAsync(opts?: RLInitOptions): number;
  refreshScratch(...args: unknown[]): unknown;
  getTime(...args: unknown[]): unknown;
  deinit(): Promise<void>;
  isInitialized(): boolean;
  getPlatform(): string;
  getVersionMajor(): number;
  getVersionMinor(): number;
  getVersionPatch(): number;
  versionLabel(...args: unknown[]): unknown;
  getVersionNumber(): number;
  getVersionString(): string;
  fileioRemove(...args: unknown[]): unknown;
  fileioClear(...args: unknown[]): unknown;
  fileioInit(baseDir?: string): Promise<number>;
  fileioInitAsync(baseDir?: string): number;
  fileioDeinitAsync(): number;
  fileioDeinit(): Promise<number>;
  fileioIsInitialized(): boolean;
  fileioIsReady(): boolean;
  fileioFlush(...args: unknown[]): unknown;
  fileioGetBaseDir(): string;
  fileioPingAssetHost(...args: unknown[]): unknown;
  fileioSetAssetHost(assetHost: string): number;
  fileioGetAssetHost(): string;
  fileioNormalizePath(path: string): string;
  fileioRestoreAsync(): number;
  fileioEnsure(localPath: string, src?: string | null): Promise<number>;
  fileioEnsureAsync(localPath: string, src?: string | null): number;
  fileioEnsureGroupAsync(filenames: string[]): number;
  fileioPollTask(task: number): boolean;
  fileioFinishTask(...args: unknown[]): unknown;
  fileioGetTaskPath(task: number): string;
  fileioRead(filename: string): Uint8Array | null;
  fileioWrite(path: string, data: ArrayBufferView): number;
  fileioMkdir(...args: unknown[]): unknown;
  fileioRmdir(...args: unknown[]): unknown;
  fileioFreeTask(...args: unknown[]): unknown;
  fileioAddTask(...args: unknown[]): unknown;
  fileioTick(...args: unknown[]): unknown;
  fileioExists(filename: string): boolean;
  emitEvent(eventName: string, payload?: number): number;
  onEvent(eventName: string, callback: RLEventCallback): number;
  onceEvent(eventName: string, callback: RLEventCallback): number;
  offEvent(eventName: string, callback: RLEventCallback): number;
  clearEventListeners(...args: unknown[]): unknown;
  getEventListenerCount(...args: unknown[]): unknown;
  setWindowSize(...args: unknown[]): unknown;
  isWindowCloseRequested(): boolean;
  getMonitorCount(...args: unknown[]): unknown;
  setWindowTitle(...args: unknown[]): unknown;
  getCurrentMonitor(...args: unknown[]): unknown;
  setWindowMonitor(...args: unknown[]): unknown;
  getMonitorWidth(...args: unknown[]): unknown;
  getMonitorHeight(...args: unknown[]): unknown;
  setWindowPosition(...args: unknown[]): unknown;
  beginDrawing(...args: unknown[]): unknown;
  endDrawing(...args: unknown[]): unknown;
  beginMode2D(...args: unknown[]): unknown;
  endMode2D(...args: unknown[]): unknown;
  beginMode3d(...args: unknown[]): unknown;
  endMode3d(...args: unknown[]): unknown;
  tick(): number;
  getDeltaTime(...args: unknown[]): unknown;
  createCamera3d(...args: unknown[]): unknown;
  getDefaultCamera3d(): RLHandle;
  setCamera3d(...args: unknown[]): unknown;
  setActiveCamera3d(...args: unknown[]): unknown;
  getActiveCamera3d(): RLHandle;
  destroyCamera3d(...args: unknown[]): unknown;
  enableLighting(...args: unknown[]): unknown;
  disableLighting(...args: unknown[]): unknown;
  isLightingEnabled(): boolean;
  setLightDirection(...args: unknown[]): unknown;
  setLightAmbient(...args: unknown[]): unknown;
  clearBackground(...args: unknown[]): unknown;
  drawCube(...args: unknown[]): unknown;
  drawRectangle(...args: unknown[]): unknown;
  debugEnableFps(...args: unknown[]): unknown;
  debugDisable(...args: unknown[]): unknown;
  drawFPS(...args: unknown[]): unknown;
  drawFPSEx(...args: unknown[]): unknown;
  drawText(...args: unknown[]): unknown;
  drawTextEx(...args: unknown[]): unknown;
  drawTextureEx(...args: unknown[]): unknown;
  drawTextureGround(...args: unknown[]): unknown;
  measureText(...args: unknown[]): unknown;
  pollInputEvents(...args: unknown[]): unknown;
  getMouseWheel(...args: unknown[]): unknown;
  getMouseButton(...args: unknown[]): unknown;
  getMouseState(): RLMouseState;
  getKeyboardState(): RLKeyboardState;
  getGamepads(): RLGamepadState[];
  getGamepad(id: number): RLGamepadState | null;
  getTouchpoints(): RLTouchpoint[];
  getTouchpoint(id: number): RLTouchpoint | null;
  getScreenSize(): RLVector2;
  getWindowPosition(): RLVector2;
  getMonitorPosition(monitor?: number): RLVector2;
  getMousePosition(): RLVector2;
  measureTextEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;
  INIT_OK: number;
  INIT_ERR_UNKNOWN: number;
  INIT_ERR_ALREADY_INITIALIZED: number;
  INIT_ERR_LOADER: number;
  INIT_ERR_ASSET_HOST: number;
  INIT_ERR_WINDOW: number;
  FILEIO_ADD_TASK_OK: number;
  FILEIO_ADD_TASK_ERR_INVALID: number;
  FILEIO_ADD_TASK_ERR_QUEUE_FULL: number;
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
  createColor(...args: unknown[]): unknown;
  destroyColor(...args: unknown[]): unknown;
  createFont(...args: unknown[]): unknown;
  destroyFont(...args: unknown[]): unknown;
  getDefaultFont(): RLHandle;
  setTargetFPS(...args: unknown[]): unknown;
  getDefaultModelAsset(...args: unknown[]): unknown;
  loadModelAsset(...args: unknown[]): unknown;
  destroyModelAsset(...args: unknown[]): unknown;
  createModel(...args: unknown[]): unknown;
  createModelFromFile(...args: unknown[]): unknown;
  setModelAsset(...args: unknown[]): unknown;
  setModelTransform(...args: unknown[]): unknown;
  drawModel(...args: unknown[]): unknown;
  isModelValid(model: RLHandle): boolean;
  isModelValidStrict(model: RLHandle): boolean;
  getModelAnimationCount(...args: unknown[]): unknown;
  getModelAnimationFrameCount(...args: unknown[]): unknown;
  updateModelAnimation(...args: unknown[]): unknown;
  setModelAnimation(...args: unknown[]): unknown;
  setModelAnimationSpeed(...args: unknown[]): unknown;
  setModelAnimationLoop(...args: unknown[]): unknown;
  setModelTint(...args: unknown[]): unknown;
  animateModel(...args: unknown[]): unknown;
  destroyModel(...args: unknown[]): unknown;
  pickModel(camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  pickSprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  resetPickStats(...args: unknown[]): unknown;
  createMusic(...args: unknown[]): unknown;
  destroyMusic(...args: unknown[]): unknown;
  playMusic(...args: unknown[]): unknown;
  pauseMusic(...args: unknown[]): unknown;
  stopMusic(...args: unknown[]): unknown;
  setMusicLoop(...args: unknown[]): unknown;
  setMusicVolume(...args: unknown[]): unknown;
  isMusicPlaying(music: RLHandle): boolean;
  updateMusic(...args: unknown[]): unknown;
  updateAllMusic(...args: unknown[]): unknown;
  createSound(...args: unknown[]): unknown;
  destroySound(...args: unknown[]): unknown;
  playSound(...args: unknown[]): unknown;
  pauseSound(...args: unknown[]): unknown;
  resumeSound(...args: unknown[]): unknown;
  stopSound(...args: unknown[]): unknown;
  setSoundVolume(...args: unknown[]): unknown;
  setSoundPitch(...args: unknown[]): unknown;
  setSoundPan(...args: unknown[]): unknown;
  isSoundPlaying(sound: RLHandle): boolean;
  getDefaultTexture(): RLHandle;
  createTexture(...args: unknown[]): unknown;
  destroyTexture(...args: unknown[]): unknown;
  createSprite3d(...args: unknown[]): unknown;
  createSprite3dFromFile(...args: unknown[]): unknown;
  setSprite3dTexture(...args: unknown[]): unknown;
  setSprite3dTransform(...args: unknown[]): unknown;
  getSprite3dTransform(sprite: RLHandle): RLSprite3dTransform;
  setSprite3dTint(...args: unknown[]): unknown;
  drawSprite3d(...args: unknown[]): unknown;
  destroySprite3d(...args: unknown[]): unknown;
  createSprite2d(...args: unknown[]): unknown;
  createSprite2dFromFile(...args: unknown[]): unknown;
  setSprite2dTexture(...args: unknown[]): unknown;
  setSprite2dTransform(...args: unknown[]): unknown;
  setSprite2dTint(...args: unknown[]): unknown;
  drawSprite2d(...args: unknown[]): unknown;
  destroySprite2d(...args: unknown[]): unknown;
  createText2d(font: RLHandle, size: number): RLHandle;
  setText2dFont(handle: RLHandle, font: RLHandle): void;
  setText2dSize(handle: RLHandle, size: number): void;
  setText2dContent(handle: RLHandle, content: string): void;
  setText2dPosition(handle: RLHandle, x: number, y: number): void;
  setText2dColor(handle: RLHandle, color: RLHandle): void;
  drawText2d(handle: RLHandle): void;
  destroyText2d(handle: RLHandle): void;
  loggerMessage(...args: unknown[]): unknown;
  loggerMessageSource(...args: unknown[]): unknown;
  loggerSetLevel(...args: unknown[]): unknown;
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
}

export const rl: RLApi;
