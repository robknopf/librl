/**
 * Haxe bindings for librl (Raylib wrapper).
 *
 * `rl.RL` is the public façade used by authored Haxe code.
 * It stays free of `cpp.*`, `@:native`, and `untyped __cpp__`.
 *
 * `RL.hx` delegates through `rl.native.RLNative`, which resolves by target:
 * - `RLNative.cpp.hx` for hxcpp hosts
 * - `RLNative.hx` as the current non-cpp fallback bridge
 */
package rl;

import haxe.io.Bytes;
import rl.RLHandle;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLVec2;
import rl.RLTypes.RLPickResult;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLKeyboardState;
import rl.RLTaskGroup;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTaskGroup.RLTaskGroupTaskCallback;

class RL {
  public static var INIT_OK(get, never): Int;
  static inline function get_INIT_OK(): Int return rl.native.RLNative.INIT_OK;

  public static var INIT_ERR_UNKNOWN(get, never): Int;
  static inline function get_INIT_ERR_UNKNOWN(): Int return rl.native.RLNative.INIT_ERR_UNKNOWN;

  public static var INIT_ERR_ALREADY_INITIALIZED(get, never): Int;
  static inline function get_INIT_ERR_ALREADY_INITIALIZED(): Int return rl.native.RLNative.INIT_ERR_ALREADY_INITIALIZED;

  public static var INIT_ERR_LOADER(get, never): Int;
  static inline function get_INIT_ERR_LOADER(): Int return rl.native.RLNative.INIT_ERR_LOADER;

  public static var INIT_ERR_ASSET_HOST(get, never): Int;
  static inline function get_INIT_ERR_ASSET_HOST(): Int return rl.native.RLNative.INIT_ERR_ASSET_HOST;

  public static var INIT_ERR_WINDOW(get, never): Int;
  static inline function get_INIT_ERR_WINDOW(): Int return rl.native.RLNative.INIT_ERR_WINDOW;

  public static var TICK_RUNNING(get, never): Int;
  static inline function get_TICK_RUNNING(): Int return rl.native.RLNative.TICK_RUNNING;

  public static var TICK_WAITING(get, never): Int;
  static inline function get_TICK_WAITING(): Int return rl.native.RLNative.TICK_WAITING;

  public static var TICK_FAILED(get, never): Int;
  static inline function get_TICK_FAILED(): Int return rl.native.RLNative.TICK_FAILED;

  public static var FLAG_WINDOW_RESIZABLE(get, never): Int;
  static inline function get_FLAG_WINDOW_RESIZABLE(): Int return rl.native.RLNative.FLAG_WINDOW_RESIZABLE;

  public static var FLAG_MSAA_4X_HINT(get, never): Int;
  static inline function get_FLAG_MSAA_4X_HINT(): Int return rl.native.RLNative.FLAG_MSAA_4X_HINT;

  public static var FLAG_VSYNC_HINT(get, never): Int;
  static inline function get_FLAG_VSYNC_HINT(): Int return rl.native.RLNative.FLAG_VSYNC_HINT;

  public static var CAMERA_PERSPECTIVE(get, never): Int;
  static inline function get_CAMERA_PERSPECTIVE(): Int return rl.native.RLNative.CAMERA_PERSPECTIVE;

  public static var CAMERA_ORTHOGRAPHIC(get, never): Int;
  static inline function get_CAMERA_ORTHOGRAPHIC(): Int return rl.native.RLNative.CAMERA_ORTHOGRAPHIC;

  public static var LOADER_QUEUE_TASK_OK(get, never): Int;
  static inline function get_LOADER_QUEUE_TASK_OK(): Int return rl.native.RLNative.LOADER_QUEUE_TASK_OK;

  public static var LOADER_QUEUE_TASK_ERR_INVALID(get, never): Int;
  static inline function get_LOADER_QUEUE_TASK_ERR_INVALID(): Int return rl.native.RLNative.LOADER_QUEUE_TASK_ERR_INVALID;

  public static var LOADER_QUEUE_TASK_ERR_QUEUE_FULL(get, never): Int;
  static inline function get_LOADER_QUEUE_TASK_ERR_QUEUE_FULL(): Int return rl.native.RLNative.LOADER_QUEUE_TASK_ERR_QUEUE_FULL;

  public static var LOGGER_LEVEL_TRACE(get, never): Int;
  static inline function get_LOGGER_LEVEL_TRACE(): Int return rl.native.RLNative.LOGGER_LEVEL_TRACE;

  public static var LOGGER_LEVEL_DEBUG(get, never): Int;
  static inline function get_LOGGER_LEVEL_DEBUG(): Int return rl.native.RLNative.LOGGER_LEVEL_DEBUG;

  public static var LOGGER_LEVEL_INFO(get, never): Int;
  static inline function get_LOGGER_LEVEL_INFO(): Int return rl.native.RLNative.LOGGER_LEVEL_INFO;

  public static var LOGGER_LEVEL_WARN(get, never): Int;
  static inline function get_LOGGER_LEVEL_WARN(): Int return rl.native.RLNative.LOGGER_LEVEL_WARN;

  public static var LOGGER_LEVEL_ERROR(get, never): Int;
  static inline function get_LOGGER_LEVEL_ERROR(): Int return rl.native.RLNative.LOGGER_LEVEL_ERROR;

  public static var LOGGER_LEVEL_FATAL(get, never): Int;
  static inline function get_LOGGER_LEVEL_FATAL(): Int return rl.native.RLNative.LOGGER_LEVEL_FATAL;

  public static var COLOR_DEFAULT(get, never): RLHandle;
  static inline function get_COLOR_DEFAULT(): RLHandle return rl.native.RLNative.COLOR_DEFAULT;

  public static var COLOR_LIGHTGRAY(get, never): RLHandle;
  static inline function get_COLOR_LIGHTGRAY(): RLHandle return rl.native.RLNative.COLOR_LIGHTGRAY;

  public static var COLOR_GRAY(get, never): RLHandle;
  static inline function get_COLOR_GRAY(): RLHandle return rl.native.RLNative.COLOR_GRAY;

  public static var COLOR_YELLOW(get, never): RLHandle;
  static inline function get_COLOR_YELLOW(): RLHandle return rl.native.RLNative.COLOR_YELLOW;

  public static var COLOR_GOLD(get, never): RLHandle;
  static inline function get_COLOR_GOLD(): RLHandle return rl.native.RLNative.COLOR_GOLD;

  public static var COLOR_ORANGE(get, never): RLHandle;
  static inline function get_COLOR_ORANGE(): RLHandle return rl.native.RLNative.COLOR_ORANGE;

  public static var COLOR_PINK(get, never): RLHandle;
  static inline function get_COLOR_PINK(): RLHandle return rl.native.RLNative.COLOR_PINK;

  public static var COLOR_RED(get, never): RLHandle;
  static inline function get_COLOR_RED(): RLHandle return rl.native.RLNative.COLOR_RED;

  public static var COLOR_MAROON(get, never): RLHandle;
  static inline function get_COLOR_MAROON(): RLHandle return rl.native.RLNative.COLOR_MAROON;

  public static var COLOR_GREEN(get, never): RLHandle;
  static inline function get_COLOR_GREEN(): RLHandle return rl.native.RLNative.COLOR_GREEN;

  public static var COLOR_LIME(get, never): RLHandle;
  static inline function get_COLOR_LIME(): RLHandle return rl.native.RLNative.COLOR_LIME;

  public static var COLOR_DARKGREEN(get, never): RLHandle;
  static inline function get_COLOR_DARKGREEN(): RLHandle return rl.native.RLNative.COLOR_DARKGREEN;

  public static var COLOR_SKYBLUE(get, never): RLHandle;
  static inline function get_COLOR_SKYBLUE(): RLHandle return rl.native.RLNative.COLOR_SKYBLUE;

  public static var COLOR_BLUE(get, never): RLHandle;
  static inline function get_COLOR_BLUE(): RLHandle return rl.native.RLNative.COLOR_BLUE;

  public static var COLOR_DARKBLUE(get, never): RLHandle;
  static inline function get_COLOR_DARKBLUE(): RLHandle return rl.native.RLNative.COLOR_DARKBLUE;

  public static var COLOR_PURPLE(get, never): RLHandle;
  static inline function get_COLOR_PURPLE(): RLHandle return rl.native.RLNative.COLOR_PURPLE;

  public static var COLOR_VIOLET(get, never): RLHandle;
  static inline function get_COLOR_VIOLET(): RLHandle return rl.native.RLNative.COLOR_VIOLET;

  public static var COLOR_DARKPURPLE(get, never): RLHandle;
  static inline function get_COLOR_DARKPURPLE(): RLHandle return rl.native.RLNative.COLOR_DARKPURPLE;

  public static var COLOR_BEIGE(get, never): RLHandle;
  static inline function get_COLOR_BEIGE(): RLHandle return rl.native.RLNative.COLOR_BEIGE;

  public static var COLOR_BROWN(get, never): RLHandle;
  static inline function get_COLOR_BROWN(): RLHandle return rl.native.RLNative.COLOR_BROWN;

  public static var COLOR_DARKBROWN(get, never): RLHandle;
  static inline function get_COLOR_DARKBROWN(): RLHandle return rl.native.RLNative.COLOR_DARKBROWN;

  public static var COLOR_DARKGRAY(get, never): RLHandle;
  static inline function get_COLOR_DARKGRAY(): RLHandle return rl.native.RLNative.COLOR_DARKGRAY;

  public static var COLOR_WHITE(get, never): RLHandle;
  static inline function get_COLOR_WHITE(): RLHandle return rl.native.RLNative.COLOR_WHITE;

  public static var COLOR_BLANK(get, never): RLHandle;
  static inline function get_COLOR_BLANK(): RLHandle return rl.native.RLNative.COLOR_BLANK;

  public static var COLOR_MAGENTA(get, never): RLHandle;
  static inline function get_COLOR_MAGENTA(): RLHandle return rl.native.RLNative.COLOR_MAGENTA;

  public static var COLOR_RAYWHITE(get, never): RLHandle;
  static inline function get_COLOR_RAYWHITE(): RLHandle return rl.native.RLNative.COLOR_RAYWHITE;

  public static var COLOR_BLACK(get, never): RLHandle;
  static inline function get_COLOR_BLACK(): RLHandle return rl.native.RLNative.COLOR_BLACK;

  public static function init(?config: RLInitConfig): Int {

    return rl.native.RLNative.init(config);

  }

  public static function initAsync(?config: RLInitConfig): Int {

    return rl.native.RLNative.initAsync(config);

  }

  public static function initValues(
    width: Int, height: Int, title: String,
    flags: Int = 0, assetHost: String = "", loaderCacheDir: String = ""
  ): Int {

    return rl.native.RLNative.initValues(width, height, title, flags, assetHost, loaderCacheDir);

  }

  public static function deinit(): Void {

    rl.native.RLNative.deinit();

  }

  public static function isInitialized(): Bool {

    return rl.native.RLNative.isInitialized();

  }

  public static function getPlatform(): String {

    return rl.native.RLNative.getPlatform();

  }

  public static function update(): Void {

    rl.native.RLNative.update();

  }

  public static function updateToScratch(): Void {

    rl.native.RLNative.updateToScratch();

  }

  public static function tick(): Int {

    return rl.native.RLNative.tick();

  }

  public static function getDeltaTime(): Float {

    return rl.native.RLNative.getDeltaTime();

  }

  public static function getTime(): Float {

    return rl.native.RLNative.getTime();

  }

  public static function setTargetFps(fps: Int): Void {

    rl.native.RLNative.setTargetFps(fps);

  }

  public static function colorCreate(r: Int, g: Int, b: Int, a: Int): RLHandle {

    return rl.native.RLNative.colorCreate(r, g, b, a);

  }

  public static function colorDestroy(color: RLHandle): Void {

    rl.native.RLNative.colorDestroy(color);

  }

  public static function fontCreate(filename: String, fontSize: Int): RLHandle {

    return rl.native.RLNative.fontCreate(filename, fontSize);

  }

  public static function fontDestroy(font: RLHandle): Void {

    rl.native.RLNative.fontDestroy(font);

  }

  public static function textDraw(text: String, x: Int, y: Int, fontSize: Int, color: RLHandle): Void {

    rl.native.RLNative.textDraw(text, x, y, fontSize, color);

  }

  public static function textMeasure(text: String, fontSize: Int): Int {

    return rl.native.RLNative.textMeasure(text, fontSize);

  }

  public static function textDrawFps(x: Int, y: Int): Void {

    rl.native.RLNative.textDrawFps(x, y);

  }

  public static function textDrawEx(font: RLHandle, text: String, x: Int, y: Int, fontSize: Float, spacing: Float, color: RLHandle): Void {

    rl.native.RLNative.textDrawEx(font, text, x, y, fontSize, spacing, color);

  }

  public static function textMeasureEx(font: RLHandle, text: String, fontSize: Float, spacing: Float): RLVec2 {

    return rl.native.RLNative.textMeasureEx(font, text, fontSize, spacing);

  }

  public static function textDrawFpsEx(font: RLHandle, x: Int, y: Int, fontSize: Float, color: RLHandle): Void {

    rl.native.RLNative.textDrawFpsEx(font, x, y, fontSize, color);

  }

  public static function setAssetHost(assetHost: String): Int {

    return rl.native.RLNative.setAssetHost(assetHost);

  }

  public static function getAssetHost(): String {

    return rl.native.RLNative.getAssetHost();

  }

  public static function musicCreate(filename: String): RLHandle {

    return rl.native.RLNative.musicCreate(filename);

  }

  public static function musicDestroy(music: RLHandle): Void {

    rl.native.RLNative.musicDestroy(music);

  }

  public static function musicPlay(music: RLHandle): Bool {

    return rl.native.RLNative.musicPlay(music);

  }

  public static function musicPause(music: RLHandle): Bool {

    return rl.native.RLNative.musicPause(music);

  }

  public static function musicStop(music: RLHandle): Bool {

    return rl.native.RLNative.musicStop(music);

  }

  public static function musicSetLoop(music: RLHandle, shouldLoop: Bool): Bool {

    return rl.native.RLNative.musicSetLoop(music, shouldLoop);

  }

  public static function musicSetVolume(music: RLHandle, volume: Float): Bool {

    return rl.native.RLNative.musicSetVolume(music, volume);

  }

  public static function musicIsPlaying(music: RLHandle): Bool {

    return rl.native.RLNative.musicIsPlaying(music);

  }

  public static function musicUpdate(music: RLHandle): Bool {

    return rl.native.RLNative.musicUpdate(music);

  }

  public static function musicUpdateAll(): Void {

    rl.native.RLNative.musicUpdateAll();

  }

  public static function soundCreate(filename: String): RLHandle {

    return rl.native.RLNative.soundCreate(filename);

  }

  public static function soundDestroy(sound: RLHandle): Void {

    rl.native.RLNative.soundDestroy(sound);

  }

  public static function soundPlay(sound: RLHandle): Bool {

    return rl.native.RLNative.soundPlay(sound);

  }

  public static function soundPause(sound: RLHandle): Bool {

    return rl.native.RLNative.soundPause(sound);

  }

  public static function soundResume(sound: RLHandle): Bool {

    return rl.native.RLNative.soundResume(sound);

  }

  public static function soundStop(sound: RLHandle): Bool {

    return rl.native.RLNative.soundStop(sound);

  }

  public static function soundSetVolume(sound: RLHandle, volume: Float): Bool {

    return rl.native.RLNative.soundSetVolume(sound, volume);

  }

  public static function soundSetPitch(sound: RLHandle, pitch: Float): Bool {

    return rl.native.RLNative.soundSetPitch(sound, pitch);

  }

  public static function soundSetPan(sound: RLHandle, pan: Float): Bool {

    return rl.native.RLNative.soundSetPan(sound, pan);

  }

  public static function soundIsPlaying(sound: RLHandle): Bool {

    return rl.native.RLNative.soundIsPlaying(sound);

  }

  public static function enableLighting(): Void {

    rl.native.RLNative.enableLighting();

  }

  public static function disableLighting(): Void {

    rl.native.RLNative.disableLighting();

  }

  public static function isLightingEnabled(): Int {

    return rl.native.RLNative.isLightingEnabled();

  }

  public static function setLightDirection(x: Float, y: Float, z: Float): Void {

    rl.native.RLNative.setLightDirection(x, y, z);

  }

  public static function setLightAmbient(ambient: Float): Void {

    rl.native.RLNative.setLightAmbient(ambient);

  }

  public static function renderBegin(): Void {

    rl.native.RLNative.renderBegin();

  }

  public static function renderEnd(): Void {

    rl.native.RLNative.renderEnd();

  }

  public static function renderClearBackground(color: RLHandle): Void {

    rl.native.RLNative.renderClearBackground(color);

  }

  public static function renderBeginMode2D(camera: RLHandle): Void {

    rl.native.RLNative.renderBeginMode2D(camera);

  }

  public static function renderEndMode2D(): Void {

    rl.native.RLNative.renderEndMode2D();

  }

  public static function renderBeginMode3D(): Void {

    rl.native.RLNative.renderBeginMode3D();

  }

  public static function renderEndMode3D(): Void {

    rl.native.RLNative.renderEndMode3D();

  }

  public static function windowCloseRequested(): Bool {

    return rl.native.RLNative.windowCloseRequested();

  }

  public static function windowGetScreenSize(): RLVec2 {

    return rl.native.RLNative.windowGetScreenSize();

  }

  public static function windowGetMonitorCount(): Int {

    return rl.native.RLNative.windowGetMonitorCount();

  }

  public static function windowSetTitle(title: String): Void {

    rl.native.RLNative.windowSetTitle(title);

  }

  public static function windowSetSize(width: Int, height: Int): Void {

    rl.native.RLNative.windowSetSize(width, height);

  }

  public static function windowGetCurrentMonitor(): Int {

    return rl.native.RLNative.windowGetCurrentMonitor();

  }

  public static function windowSetMonitor(monitor: Int): Void {

    rl.native.RLNative.windowSetMonitor(monitor);

  }

  public static function windowGetMonitorWidth(monitor: Int): Int {

    return rl.native.RLNative.windowGetMonitorWidth(monitor);

  }

  public static function windowGetMonitorHeight(monitor: Int): Int {

    return rl.native.RLNative.windowGetMonitorHeight(monitor);

  }

  public static function windowGetMonitorPosition(monitor: Int): RLVec2 {

    return rl.native.RLNative.windowGetMonitorPosition(monitor);

  }

  public static function windowGetPosition(): RLVec2 {

    return rl.native.RLNative.windowGetPosition();

  }

  public static function windowSetPosition(x: Int, y: Int): Void {

    rl.native.RLNative.windowSetPosition(x, y);

  }

  public static function camera3dCreate(
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): RLHandle {

    return rl.native.RLNative.camera3dCreate(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

  }

  public static function camera3dSet(
    camera: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): Bool {

    return rl.native.RLNative.camera3dSet(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

  }

  public static function camera3dSetActive(camera: RLHandle): Bool {

    return rl.native.RLNative.camera3dSetActive(camera);

  }

  public static function camera3dDestroy(camera: RLHandle): Void {

    rl.native.RLNative.camera3dDestroy(camera);

  }

  public static function modelCreate(filename: String): RLHandle {

    return rl.native.RLNative.modelCreate(filename);

  }

  public static function modelSetTransform(
    model: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    rotationX: Float, rotationY: Float, rotationZ: Float,
    scaleX: Float, scaleY: Float, scaleZ: Float
  ): Bool {

    return rl.native.RLNative.modelSetTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);

  }

  public static function modelDraw(model: RLHandle, tint: RLHandle): Void {

    rl.native.RLNative.modelDraw(model, tint);

  }

  public static function modelSetAnimation(model: RLHandle, animationIndex: Int): Bool {

    return rl.native.RLNative.modelSetAnimation(model, animationIndex);

  }

  public static function modelSetAnimationSpeed(model: RLHandle, speed: Float): Bool {

    return rl.native.RLNative.modelSetAnimationSpeed(model, speed);

  }

  public static function modelSetAnimationLoop(model: RLHandle, shouldLoop: Bool): Bool {

    return rl.native.RLNative.modelSetAnimationLoop(model, shouldLoop);

  }

  public static function modelAnimate(model: RLHandle, deltaSeconds: Float): Bool {

    return rl.native.RLNative.modelAnimate(model, deltaSeconds);

  }

  public static function modelDestroy(model: RLHandle): Void {

    rl.native.RLNative.modelDestroy(model);

  }

  public static function sprite3dCreate(filename: String): RLHandle {

    return rl.native.RLNative.sprite3dCreate(filename);

  }

  public static function sprite3dSetTransform(sprite: RLHandle, positionX: Float, positionY: Float, positionZ: Float, size: Float): Bool {

    return rl.native.RLNative.sprite3dSetTransform(sprite, positionX, positionY, positionZ, size);

  }

  public static function sprite3dDraw(sprite: RLHandle, tint: RLHandle): Void {

    rl.native.RLNative.sprite3dDraw(sprite, tint);

  }

  public static function sprite3dDestroy(sprite: RLHandle): Void {

    rl.native.RLNative.sprite3dDestroy(sprite);

  }

  public static function sprite2dCreate(filename: String): RLHandle {

    return rl.native.RLNative.sprite2dCreate(filename);

  }

  public static function sprite2dCreateFromTexture(texture: RLHandle): RLHandle {

    return rl.native.RLNative.sprite2dCreateFromTexture(texture);

  }

  public static function sprite2dSetTransform(sprite: RLHandle, x: Float, y: Float, scale: Float, rotation: Float): Bool {

    return rl.native.RLNative.sprite2dSetTransform(sprite, x, y, scale, rotation);

  }

  public static function sprite2dDraw(sprite: RLHandle, tint: RLHandle): Void {

    rl.native.RLNative.sprite2dDraw(sprite, tint);

  }

  public static function sprite2dDestroy(sprite: RLHandle): Void {

    rl.native.RLNative.sprite2dDestroy(sprite);

  }

  public static function textureCreate(filename: String): RLHandle {

    return rl.native.RLNative.textureCreate(filename);

  }

  public static function textureDestroy(texture: RLHandle): Void {

    rl.native.RLNative.textureDestroy(texture);

  }

  public static function textureDrawEx(texture: RLHandle, x: Float, y: Float, scale: Float, rotation: Float, tint: RLHandle): Void {

    rl.native.RLNative.textureDrawEx(texture, x, y, scale, rotation, tint);

  }

  public static function textureDrawGround(texture: RLHandle, positionX: Float, positionY: Float, positionZ: Float, width: Float, length: Float, tint: RLHandle): Void {

    rl.native.RLNative.textureDrawGround(texture, positionX, positionY, positionZ, width, length, tint);

  }

  public static function inputPollEvents(): Void {

    rl.native.RLNative.inputPollEvents();

  }

  public static function inputGetMousePosition(): RLVec2 {

    return rl.native.RLNative.inputGetMousePosition();

  }

  public static function inputGetMouseWheel(): Int {

    return rl.native.RLNative.inputGetMouseWheel();

  }

  public static function inputGetMouseButton(button: Int): Int {

    return rl.native.RLNative.inputGetMouseButton(button);

  }

  public static function inputGetMouseState(): RLMouseState {

    return rl.native.RLNative.inputGetMouseState();

  }

  public static function inputGetKeyboardState(): RLKeyboardState {

    return rl.native.RLNative.inputGetKeyboardState();

  }

  public static function pickModel(camera: RLHandle, model: RLHandle, mouseX: Float, mouseY: Float): RLPickResult {

    return rl.native.RLNative.pickModel(camera, model, mouseX, mouseY);

  }

  public static function pickSprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: Float, mouseY: Float): RLPickResult {

    return rl.native.RLNative.pickSprite3d(camera, sprite3d, mouseX, mouseY);

  }

  public static function pickResetStats(): Void {

    rl.native.RLNative.pickResetStats();

  }

  public static function pickGetBroadphaseTests(): Int {

    return rl.native.RLNative.pickGetBroadphaseTests();

  }

  public static function pickGetBroadphaseRejects(): Int {

    return rl.native.RLNative.pickGetBroadphaseRejects();

  }

  public static function pickGetNarrowphaseTests(): Int {

    return rl.native.RLNative.pickGetNarrowphaseTests();

  }

  public static function pickGetNarrowphaseHits(): Int {

    return rl.native.RLNative.pickGetNarrowphaseHits();

  }

  public static function loaderInit(?mountPoint: String): Int {

    return rl.native.RLNative.loaderInit(mountPoint);

  }

  public static function loaderInitAsync(?mountPoint: String): Int {

    return rl.native.RLNative.loaderInitAsync(mountPoint);

  }

  public static function loaderDeinit(): Void {

    rl.native.RLNative.loaderDeinit();

  }

  public static function loaderIsInitialized(): Bool {

    return rl.native.RLNative.loaderIsInitialized();

  }

  public static function loaderRestoreFsAsync(): RLHandle {

    return rl.native.RLNative.loaderRestoreFsAsync();

  }

  public static function loaderImportAssetAsync(filename: String): RLHandle {

    return rl.native.RLNative.loaderImportAssetAsync(filename);

  }

  public static function loaderImportAsset(filename: String): Int {

    return rl.native.RLNative.loaderImportAsset(filename);

  }

  public static function loaderImportAssetsAsync(filenames: Array<String>): RLHandle {

    return rl.native.RLNative.loaderImportAssetsAsync(filenames);

  }

  public static function loaderPollTask(task: RLHandle): Bool {

    return rl.native.RLNative.loaderPollTask(task);

  }

  public static function loaderFinishTask(task: RLHandle): Int {

    return rl.native.RLNative.loaderFinishTask(task);

  }

  public static function loaderGetTaskPath(task: RLHandle): String {

    return rl.native.RLNative.loaderGetTaskPath(task);

  }

  public static function loaderReadLocal(filename: String): Bytes {

    return rl.native.RLNative.loaderReadLocal(filename);

  }

  public static function loaderFreeTask(task: RLHandle): Void {

    rl.native.RLNative.loaderFreeTask(task);

  }

  public static function loaderIsAssetCached(filename: String): Bool {

    return rl.native.RLNative.loaderIsAssetCached(filename);

  }

  public static function loaderPingAssetHost(?assetHost: String): Float {

    return rl.native.RLNative.loaderPingAssetHost(assetHost);

  }

  public static function loaderGetCacheDir(): String {

    return rl.native.RLNative.loaderGetCacheDir();

  }

  public static function loaderCreateTaskGroup<T>(?onComplete: RLTaskGroupCallback<T>, ?onError: RLTaskGroupCallback<T>, ?ctx: T): RLTaskGroup {

    return rl.native.RLNative.loaderCreateTaskGroup(onComplete, onError, ctx);

  }

  public static function loaderTaskInvalid(): RLHandle {

    return rl.native.RLNative.loaderTaskInvalid();

  }

  public static function loaderTaskIsValid(task: RLHandle): Bool {

    return rl.native.RLNative.loaderTaskIsValid(task);

  }

  public static function loaderAddTask<T>(task: RLHandle, onSuccess: String->T->Void, onFailure: String->T->Void, ctx: T): Int {

    return rl.native.RLNative.loaderAddTask(task, onSuccess, onFailure, ctx);

  }

  public static function loaderTick(): Void {

    rl.native.RLNative.loaderTick();

  }

  public static function loaderClearCache(): Int {

    return rl.native.RLNative.loaderClearCache();

  }

  public static function loaderUncacheAsset(filename: String): Int {

    return rl.native.RLNative.loaderUncacheAsset(filename);

  }

  public static function loggerMessage(level: Int, message: String): Void {

    rl.native.RLNative.loggerMessage(level, message);

  }

  public static function loggerSetLevel(level: Int): Void {

    rl.native.RLNative.loggerSetLevel(level);

  }
}
