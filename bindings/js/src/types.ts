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

export type RLSprite3dFacing = 0 | 1 | 2 | 3;

export interface RLPickStats {
  broadphaseTests: number;
  broadphaseRejects: number;
  narrowphaseTests: number;
  narrowphaseHits: number;
}

export interface RLInitEnv {
  canvas?: HTMLCanvasElement | null;
  print?: (...args: unknown[]) => void;
  printErr?: (...args: unknown[]) => void;
  locateFile?: (path: string, prefix: string) => string;
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
  canvasId?: string;
  modulePath?: string;
  wasmPath?: string;
  env?: RLInitEnv;
  [key: string]: unknown;
}

export type RLEventCallback = (payload: number) => void;
export type RLAssetTaskCallback = (path: string, ctx: unknown) => void;
export type RLTaskGroupTaskCallback<T = unknown> = (path: string, ctx: T) => void;
export type RLTaskGroupCallback<T = unknown> = (group: RLTaskGroup<T>, ctx: T) => void;

export interface RLTaskGroup<T = unknown> {
  failedCount: number;
  completedCount: number;
  addTask(task: RLHandle, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTask(path: string, onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  addImportTasks(paths: string[], onSuccess?: RLTaskGroupTaskCallback<T> | null, onError?: RLTaskGroupTaskCallback<T> | null): void;
  remainingTasks(): number;
  isDone(): boolean;
  hasFailures(): boolean;
  tick(): boolean;
  process(): number;
  failedPaths(): string[];
}

export interface RLFs {
  remove(filename: string): number;
  clear(): number;
  init(rootDir?: string): Promise<number>;
  initAsync(rootDir?: string): RLHandle;
  deinitAsync(): RLHandle;
  deinit(): Promise<void>;
  isInitialized(): boolean;
  isReady(): boolean;
  flush(): number;
  getRootDir(): string;
  normalizePath(path: string): string;
  restoreAsync(): RLHandle;
  read(filename: string): Uint8Array | null;
  write(path: string, data: ArrayBufferView | string): number;
  mkdir(path: string): number;
  rmdir(path: string): number;
  exists(filename: string): boolean;
}

export interface RLAsset {
  ADD_TASK_OK: number;
  ADD_TASK_ERR_INVALID: number;
  ADD_TASK_ERR_QUEUE_FULL: number;
  pingHost(assetHost?: string): number;
  setHost(assetHost: string): number;
  getHost(): string;
  ensure(localPath: string, src?: string | null): Promise<number>;
  ensureAsync(localPath: string, src?: string | null): RLHandle;
  ensureGroupAsync(filenames: string[]): RLHandle;
  pollTask(task: RLHandle): boolean;
  finishTask(task: RLHandle): number;
  getTaskPath(task: RLHandle): string;
  freeTask(task: RLHandle): void;
  addTask(task: RLHandle, onSuccess?: RLAssetTaskCallback | null, onFailure?: RLAssetTaskCallback | null, ctx?: unknown): number;
  tick(): void;
}

export interface RLEvent {
  emit(eventName: string, payload?: number): number;
  on(eventName: string, callback: RLEventCallback): number;
  once(eventName: string, callback: RLEventCallback): number;
  off(eventName: string, callback: RLEventCallback): number;
  clearListeners(eventName: string): number;
  getListenerCount(eventName: string): number;
}

export interface RLWindow {
  setSize(width: number, height: number): void;
  isCloseRequested(): boolean;
  getMonitorCount(): number;
  setTitle(title: string): void;
  getCurrentMonitor(): number;
  setMonitor(monitor: number): void;
  getMonitorWidth(monitor?: number): number;
  getMonitorHeight(monitor?: number): number;
  setPosition(x: number, y: number): void;
  getScreenSize(): RLVector2;
  getPosition(): RLVector2;
  getMonitorPosition(monitor?: number): RLVector2;
}

export interface RLRender {
  begin(): void;
  end(): void;
  beginMode2D(camera: RLHandle): void;
  endMode2D(): void;
  beginMode3D(): void;
  endMode3D(): void;
  clearBackground(color: RLHandle): void;
  enableLighting(): void;
  disableLighting(): void;
  isLightingEnabled(): boolean;
  setLightDirection(x: number, y: number, z: number): void;
  setLightAmbient(ambient: number): void;
}

export interface RLCamera3d {
  create(
    positionX: number, positionY: number, positionZ: number,
    targetX: number, targetY: number, targetZ: number,
    upX: number, upY: number, upZ: number,
    fovy: number, projection: number,
  ): RLHandle;
  getDefault(): RLHandle;
  set(
    camera: RLHandle,
    positionX: number, positionY: number, positionZ: number,
    targetX: number, targetY: number, targetZ: number,
    upX: number, upY: number, upZ: number,
    fovy: number, projection: number,
  ): boolean;
  setActive(camera: RLHandle): boolean;
  getActive(): RLHandle;
  destroy(camera: RLHandle): void;
}

export interface RLShape {
  drawCube(positionX: number, positionY: number, positionZ: number, width: number, height: number, length: number, color: RLHandle): void;
  drawRectangle(x: number, y: number, width: number, height: number, color: RLHandle): void;
}

export interface RLDebug {
  enableFps(x: number, y: number, fontSize: number, font?: RLHandle): void;
  disable(): void;
}

export interface RLText {
  drawFps(x: number, y: number): void;
  drawFpsEx(font: RLHandle, x: number, y: number, fontSize: number, color: RLHandle): void;
  draw(text: string, x: number, y: number, fontSize: number, color: RLHandle): void;
  drawEx(font: RLHandle, text: string, x: number, y: number, fontSize: number, spacing: number, color: RLHandle): void;
  measure(text: string, fontSize: number): number;
  measureEx(font: RLHandle, text: string, fontSize: number, spacing?: number): RLVector2;
}

export interface RLTexture {
  getDefault(): RLHandle;
  create(path: string): RLHandle;
  destroy(texture: RLHandle): void;
  drawEx(texture: RLHandle, x: number, y: number, scale: number, rotation: number, tint: RLHandle): void;
  drawGround(texture: RLHandle, x: number, y: number, z: number, width: number, length: number, tint: RLHandle): void;
}

export interface RLInput {
  pollEvents(): void;
  getMouseWheel(): number;
  getMouseButton(button: number): number;
  getMouseState(): RLMouseState;
  getKeyboardState(): RLKeyboardState;
  getGamepads(): RLGamepadState[];
  getGamepad(id: number): RLGamepadState | null;
  getTouchpoints(): RLTouchpoint[];
  getTouchpoint(id: number): RLTouchpoint | null;
  getMousePosition(): RLVector2;
}

export type RLColorPreset =
  | "DEFAULT" | "LIGHTGRAY" | "GRAY" | "DARKGRAY"
  | "YELLOW" | "GOLD" | "ORANGE" | "PINK"
  | "RED" | "MAROON" | "GREEN" | "LIME"
  | "DARKGREEN" | "SKYBLUE" | "BLUE" | "DARKBLUE"
  | "PURPLE" | "VIOLET" | "DARKPURPLE"
  | "BEIGE" | "BROWN" | "DARKBROWN"
  | "WHITE" | "BLACK" | "BLANK" | "MAGENTA" | "RAYWHITE";

export type RLColorPresets = { [K in RLColorPreset]: RLHandle };

export interface RLColor extends RLColorPresets {
  create(r: number, g: number, b: number, a: number): RLHandle;
  destroy(color: RLHandle): void;
}

export interface RLFont {
  create(path: string, size: number): RLHandle;
  destroy(font: RLHandle): void;
  getDefault(): RLHandle;
}

export interface RLModel {
  getDefaultAsset(): RLHandle;
  loadAsset(path: string): RLHandle;
  destroyAsset(modelAsset: RLHandle): void;
  create(modelAsset: RLHandle): RLHandle;
  createFromFile(path: string): RLHandle;
  setAsset(model: RLHandle, modelAsset: RLHandle): void;
  setTransform(
    model: RLHandle,
    positionX: number, positionY: number, positionZ: number,
    rotationX: number, rotationY: number, rotationZ: number,
    scaleX: number, scaleY: number, scaleZ: number,
  ): void;
  setVisible(model: RLHandle, visible: boolean): boolean;
  setPickable(model: RLHandle, pickable: boolean): boolean;
  isVisible(model: RLHandle): boolean;
  isPickable(model: RLHandle): boolean;
  draw(model: RLHandle): void;
  isValid(model: RLHandle): boolean;
  isValidStrict(model: RLHandle): boolean;
  getAnimationCount(model: RLHandle): number;
  getAnimationFrameCount(model: RLHandle, animationIndex: number): number;
  updateAnimation(model: RLHandle, animationIndex: number, frameIndex: number): void;
  setAnimation(model: RLHandle, animationIndex: number): void;
  setAnimationSpeed(model: RLHandle, speed: number): void;
  setAnimationLoop(model: RLHandle, loop: boolean): void;
  setTint(model: RLHandle, color: RLHandle): void;
  animate(model: RLHandle, deltaTime: number): void;
  destroy(model: RLHandle): void;
}

export interface RLPickResult {
  hit: boolean;
  distance: number;
  point: { x: number; y: number; z: number };
  normal: { x: number; y: number; z: number };
}

export interface RLScenePickResult extends RLPickResult {
  handle: RLHandle;
}

export interface RLScene {
  create(): RLHandle;
  destroy(scene: RLHandle): void;
  add(scene: RLHandle, drawable: RLHandle, layer?: number): boolean;
  setLayer(scene: RLHandle, drawable: RLHandle, layer: number): boolean;
  remove(scene: RLHandle, drawable: RLHandle): boolean;
  clear(scene: RLHandle): void;
  setActiveCamera(scene: RLHandle, camera: RLHandle): void;
  draw(scene: RLHandle): void;
  pick(scene: RLHandle, camera: RLHandle, mouseX: number, mouseY: number): RLScenePickResult;
}

export interface RLPick {
  model(camera: RLHandle, model: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  sprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: number, mouseY: number): RLPickResult;
  resetStats(): void;
}

export interface RLMusic {
  create(path: string): RLHandle;
  destroy(music: RLHandle): void;
  play(music: RLHandle): void;
  stop(music: RLHandle): void;
  pause(music: RLHandle): void;
  setLoop(music: RLHandle, loop: boolean): void;
  setVolume(music: RLHandle, volume: number): void;
  isPlaying(music: RLHandle): boolean;
  update(music: RLHandle): void;
  updateAll(): void;
}

export interface RLSound {
  create(path: string): RLHandle;
  destroy(sound: RLHandle): void;
  play(sound: RLHandle): void;
  stop(sound: RLHandle): void;
  pause(sound: RLHandle): void;
  resume(sound: RLHandle): void;
  setVolume(sound: RLHandle, volume: number): void;
  setPitch(sound: RLHandle, pitch: number): void;
  setPan(sound: RLHandle, pan: number): void;
  isPlaying(sound: RLHandle): boolean;
}

export interface RLSprite3d {
  create(texture: RLHandle): RLHandle;
  createFromFile(path: string): RLHandle;
  setTexture(sprite: RLHandle, texture: RLHandle): boolean;
  setTransform(sprite: RLHandle, positionX: number, positionY: number, positionZ: number, size: number): boolean;
  setFacing(sprite: RLHandle, facing: RLSprite3dFacing): boolean;
  setVisible(sprite: RLHandle, visible: boolean): boolean;
  setPickable(sprite: RLHandle, pickable: boolean): boolean;
  isVisible(sprite: RLHandle): boolean;
  isPickable(sprite: RLHandle): boolean;
  getDefaultTexture(): RLHandle;
  getTransform(sprite: RLHandle): RLSprite3dTransform | null;
  setTint(sprite: RLHandle, color?: RLHandle): boolean;
  draw(sprite: RLHandle): void;
  destroy(sprite: RLHandle): void;
}

export interface RLSprite2d {
  create(texture: RLHandle): RLHandle;
  createFromFile(path: string): RLHandle;
  getDefaultTexture(): RLHandle;
  setTexture(sprite: RLHandle, texture: RLHandle): boolean;
  setTransform(sprite: RLHandle, x: number, y: number, rotation: number, scale: number): boolean;
  setVisible(sprite: RLHandle, visible: boolean): boolean;
  setPickable(sprite: RLHandle, pickable: boolean): boolean;
  isVisible(sprite: RLHandle): boolean;
  isPickable(sprite: RLHandle): boolean;
  setTint(sprite: RLHandle, color?: RLHandle): boolean;
  draw(sprite: RLHandle): void;
  destroy(sprite: RLHandle): void;
}

export interface RLText2d {
  create(font: RLHandle, size: number): RLHandle;
  setFont(handle: RLHandle, font: RLHandle): void;
  setSize(handle: RLHandle, size: number): void;
  setContent(handle: RLHandle, content: string): void;
  setPosition(handle: RLHandle, x: number, y: number): void;
  setColor(handle: RLHandle, color: RLHandle): void;
  setVisible(handle: RLHandle, visible: boolean): boolean;
  setPickable(handle: RLHandle, pickable: boolean): boolean;
  isVisible(handle: RLHandle): boolean;
  isPickable(handle: RLHandle): boolean;
  draw(handle: RLHandle): void;
  destroy(handle: RLHandle): void;
}

export interface RLLogger {
  message(level: number, message: string): void;
  messageSource(level: number, sourceFile: string, sourceLine: number, message: string): void;
  setLevel(level: number): void;
}

export interface RLHelpers {
  waitForFsReady(timeoutMs?: number): Promise<boolean>;
  taskIsValid(task: RLHandle): boolean;
  waitForTask(task: RLHandle, pollMs?: number): Promise<number>;
  waitForFsRestoreAsync(): Promise<number>;
  waitForAssetEnsureAsync(localPath: string, src?: string | null): Promise<number>;
  waitForAssetEnsureGroupAsync(filenames: string[]): Promise<number>;
  createTaskGroup<T = unknown>(
    onComplete?: RLTaskGroupCallback<T> | null,
    onError?: RLTaskGroupCallback<T> | null,
    ctx?: T,
  ): RLTaskGroup<T>;
  getScreenWidth(): number;
  getScreenHeight(): number;
  getPickStats(): RLPickStats;
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
  handleKind(handle: RLHandle): number;
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
  HANDLE_KIND_NONE: number;
  HANDLE_KIND_COLOR: number;
  HANDLE_KIND_CAMERA3D: number;
  HANDLE_KIND_FONT: number;
  HANDLE_KIND_TEXTURE: number;
  HANDLE_KIND_SPRITE2D: number;
  HANDLE_KIND_SPRITE3D: number;
  HANDLE_KIND_MODEL: number;
  HANDLE_KIND_MODEL_ASSET: number;
  HANDLE_KIND_SOUND: number;
  HANDLE_KIND_MUSIC: number;
  HANDLE_KIND_TEXT2D: number;
  HANDLE_KIND_SCENE: number;
  HANDLE_KIND_ASSET_TASK: number;
  fs: RLFs;
  asset: RLAsset;
  event: RLEvent;
  window: RLWindow;
  render: RLRender;
  camera3d: RLCamera3d;
  shape: RLShape;
  debug: RLDebug;
  text: RLText;
  texture: RLTexture;
  input: RLInput;
  color: RLColor;
  font: RLFont;
  model: RLModel;
  pick: RLPick;
  scene: RLScene;
  music: RLMusic;
  sound: RLSound;
  sprite3d: RLSprite3d;
  sprite2d: RLSprite2d;
  text2d: RLText2d;
  logger: RLLogger;
  helpers: RLHelpers;
}

/** Runtime default export of `dist/rl.js` (declarations only). */
export declare const rl: RLApi;
export default rl;
