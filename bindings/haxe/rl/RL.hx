/**
 * Haxe bindings for librl (Raylib wrapper).
 *
 * This file is cppia/Lua-safe: no cpp.*, @:native, or untyped __cpp__.
 * All hxcpp-specific implementation lives in RLNative.hx (RLImpl abstract),
 * which is compiled into the host binary with -D scriptable.
 *
 * Scripts import rl.RL normally. Under hxcpp the abstract RLImpl in
 * RLNative.hx is unified with this class via typedef. Under cppia the
 * signatures are resolved from export_classes.info at script compile time.
 */
package rl;

import rl.RLHandle;
import rl.RLTypes;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLVec2;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLKeyboardState;
import rl.RLTaskGroup;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTaskGroup.RLTaskGroupTaskCallback;

#if cpp
typedef RLLoaderTaskPtr = rl.native.RLLoaderNative.RLLoaderTaskPtrImpl;
typedef RL = rl.native.RLNative.RLImpl;
#else
abstract RLLoaderTaskPtr(Int) from Int to Int {
  public static inline function invalid(): RLLoaderTaskPtr {
    return cast 0;
  }
  public inline function isValid(): Bool {
    return this != 0;
  }
}

@:keep
@:native("rl.native._RLNative.RLImpl_Impl_")
extern class RL {
  // --- Init result codes ---
  public static var INIT_OK: Int;
  public static var INIT_ERR_UNKNOWN: Int;
  public static var INIT_ERR_ALREADY_INITIALIZED: Int;
  public static var INIT_ERR_LOADER: Int;
  public static var INIT_ERR_ASSET_HOST: Int;
  public static var INIT_ERR_WINDOW: Int;

  // --- Tick result codes ---
  public static var TICK_RUNNING: Int;
  public static var TICK_WAITING: Int;
  public static var TICK_FAILED: Int;

  // --- Window flags ---
  public static var FLAG_WINDOW_RESIZABLE: Int;
  public static var FLAG_MSAA_4X_HINT: Int;
  public static var FLAG_VSYNC_HINT: Int;

  // --- Camera projections ---
  public static var CAMERA_PERSPECTIVE: Int;
  public static var CAMERA_ORTHOGRAPHIC: Int;

  // --- Loader queue_task result codes ---
  public static var LOADER_QUEUE_TASK_OK: Int;
  public static var LOADER_QUEUE_TASK_ERR_INVALID: Int;
  public static var LOADER_QUEUE_TASK_ERR_QUEUE_FULL: Int;

  // --- Logger levels ---
  public static var LOGGER_LEVEL_TRACE: Int;
  public static var LOGGER_LEVEL_DEBUG: Int;
  public static var LOGGER_LEVEL_INFO: Int;
  public static var LOGGER_LEVEL_WARN: Int;
  public static var LOGGER_LEVEL_ERROR: Int;
  public static var LOGGER_LEVEL_FATAL: Int;

  // --- Colors ---
  public static var COLOR_DEFAULT: RLHandle;
  public static var COLOR_LIGHTGRAY: RLHandle;
  public static var COLOR_GRAY: RLHandle;
  public static var COLOR_DARKGRAY: RLHandle;
  public static var COLOR_YELLOW: RLHandle;
  public static var COLOR_GOLD: RLHandle;
  public static var COLOR_ORANGE: RLHandle;
  public static var COLOR_PINK: RLHandle;
  public static var COLOR_RED: RLHandle;
  public static var COLOR_MAROON: RLHandle;
  public static var COLOR_GREEN: RLHandle;
  public static var COLOR_LIME: RLHandle;
  public static var COLOR_DARKGREEN: RLHandle;
  public static var COLOR_SKYBLUE: RLHandle;
  public static var COLOR_BLUE: RLHandle;
  public static var COLOR_DARKBLUE: RLHandle;
  public static var COLOR_PURPLE: RLHandle;
  public static var COLOR_VIOLET: RLHandle;
  public static var COLOR_DARKPURPLE: RLHandle;
  public static var COLOR_BEIGE: RLHandle;
  public static var COLOR_BROWN: RLHandle;
  public static var COLOR_DARKBROWN: RLHandle;
  public static var COLOR_WHITE: RLHandle;
  public static var COLOR_BLACK: RLHandle;
  public static var COLOR_BLANK: RLHandle;
  public static var COLOR_MAGENTA: RLHandle;
  public static var COLOR_RAYWHITE: RLHandle;

  // --- Core lifecycle ---
  public static function init(?config: RLInitConfig): Int;
  public static function initAsync(?config: RLInitConfig): Int;
  public static function initValues(width: Int, height: Int, title: String, flags: Int = 0, assetHost: String = "", loaderCacheDir: String = ""): Int;
  public static function deinit(): Void;
  public static function isInitialized(): Bool;
  public static function getPlatform(): String;
  public static function update(): Void;
  public static function updateToScratch(): Void;
  public static function tick(): Int;

  // --- Time ---
  public static function getDeltaTime(): Float;
  public static function getTime(): Float;
  public static function setTargetFps(fps: Int): Void;

  // --- Colors ---
  public static function colorCreate(r: Int, g: Int, b: Int, a: Int): RLHandle;
  public static function colorDestroy(color: RLHandle): Void;

  // --- Fonts / Text ---
  public static function fontCreate(filename: String, fontSize: Int): RLHandle;
  public static function fontDestroy(font: RLHandle): Void;
  public static function textDraw(text: String, x: Int, y: Int, fontSize: Int, color: RLHandle): Void;
  public static function textMeasure(text: String, fontSize: Int): Int;
  public static function textDrawFps(x: Int, y: Int): Void;
  public static function textDrawEx(font: RLHandle, text: String, x: Int, y: Int, fontSize: Float, spacing: Float, color: RLHandle): Void;
  public static function textMeasureEx(font: RLHandle, text: String, fontSize: Float, spacing: Float): RLVec2;
  public static function textDrawFpsEx(font: RLHandle, x: Int, y: Int, fontSize: Float, color: RLHandle): Void;

  // --- Asset host ---
  public static function setAssetHost(assetHost: String): Int;
  public static function getAssetHost(): String;

  // --- Music ---
  public static function musicCreate(filename: String): RLHandle;
  public static function musicDestroy(music: RLHandle): Void;
  public static function musicPlay(music: RLHandle): Bool;
  public static function musicPause(music: RLHandle): Bool;
  public static function musicStop(music: RLHandle): Bool;
  public static function musicSetLoop(music: RLHandle, shouldLoop: Bool): Bool;
  public static function musicSetVolume(music: RLHandle, volume: Float): Bool;
  public static function musicIsPlaying(music: RLHandle): Bool;
  public static function musicUpdate(music: RLHandle): Bool;
  public static function musicUpdateAll(): Void;

  // --- Sound ---
  public static function soundCreate(filename: String): RLHandle;
  public static function soundDestroy(sound: RLHandle): Void;
  public static function soundPlay(sound: RLHandle): Bool;
  public static function soundPause(sound: RLHandle): Bool;
  public static function soundResume(sound: RLHandle): Bool;
  public static function soundStop(sound: RLHandle): Bool;
  public static function soundSetVolume(sound: RLHandle, volume: Float): Bool;
  public static function soundSetPitch(sound: RLHandle, pitch: Float): Bool;
  public static function soundSetPan(sound: RLHandle, pan: Float): Bool;
  public static function soundIsPlaying(sound: RLHandle): Bool;

  // --- Lighting ---
  public static function enableLighting(): Void;
  public static function disableLighting(): Void;
  public static function isLightingEnabled(): Int;
  public static function setLightDirection(x: Float, y: Float, z: Float): Void;
  public static function setLightAmbient(ambient: Float): Void;

  // --- Render ---
  public static function renderBegin(): Void;
  public static function renderEnd(): Void;
  public static function renderClearBackground(color: RLHandle): Void;
  public static function renderBeginMode2D(camera: RLHandle): Void;
  public static function renderEndMode2D(): Void;
  public static function renderBeginMode3D(): Void;
  public static function renderEndMode3D(): Void;

  // --- Window ---
  public static function windowSetTitle(title: String): Void;
  public static function windowSetSize(width: Int, height: Int): Void;
  public static function windowCloseRequested(): Bool;
  public static function windowGetScreenSize(): RLVec2;
  public static function windowGetMonitorCount(): Int;
  public static function windowGetCurrentMonitor(): Int;
  public static function windowSetMonitor(monitor: Int): Void;
  public static function windowGetMonitorWidth(monitor: Int): Int;
  public static function windowGetMonitorHeight(monitor: Int): Int;
  public static function windowGetMonitorPosition(monitor: Int): RLVec2;
  public static function windowGetPosition(): RLVec2;
  public static function windowSetPosition(x: Int, y: Int): Void;

  // --- 3D Camera ---
  public static function camera3dCreate(
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): RLHandle;
  public static function camera3dSet(
    camera: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): Bool;
  public static function camera3dSetActive(camera: RLHandle): Bool;
  public static function camera3dDestroy(camera: RLHandle): Void;

  // --- Models ---
  public static function modelCreate(filename: String): RLHandle;
  public static function modelSetTransform(
    model: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    rotationX: Float, rotationY: Float, rotationZ: Float,
    scaleX: Float, scaleY: Float, scaleZ: Float
  ): Bool;
  public static function modelDraw(model: RLHandle, tint: RLHandle): Void;
  public static function modelSetAnimation(model: RLHandle, animationIndex: Int): Bool;
  public static function modelSetAnimationSpeed(model: RLHandle, speed: Float): Bool;
  public static function modelSetAnimationLoop(model: RLHandle, shouldLoop: Bool): Bool;
  public static function modelAnimate(model: RLHandle, deltaSeconds: Float): Bool;
  public static function modelDestroy(model: RLHandle): Void;

  // --- Sprite3D ---
  public static function sprite3dCreate(filename: String): RLHandle;
  public static function sprite3dSetTransform(sprite: RLHandle, positionX: Float, positionY: Float, positionZ: Float, size: Float): Bool;
  public static function sprite3dDraw(sprite: RLHandle, tint: RLHandle): Void;
  public static function sprite3dDestroy(sprite: RLHandle): Void;

  // --- Sprite2D ---
  public static function sprite2dCreate(filename: String): RLHandle;
  public static function sprite2dCreateFromTexture(texture: RLHandle): RLHandle;
  public static function sprite2dSetTransform(sprite: RLHandle, x: Float, y: Float, scale: Float, rotation: Float): Bool;
  public static function sprite2dDraw(sprite: RLHandle, tint: RLHandle): Void;
  public static function sprite2dDestroy(sprite: RLHandle): Void;

  // --- Texture ---
  public static function textureCreate(filename: String): RLHandle;
  public static function textureDestroy(texture: RLHandle): Void;
  public static function textureDrawEx(texture: RLHandle, x: Float, y: Float, scale: Float, rotation: Float, tint: RLHandle): Void;
  public static function textureDrawGround(texture: RLHandle, positionX: Float, positionY: Float, positionZ: Float, width: Float, length: Float, tint: RLHandle): Void;

  // --- Input ---
  public static function inputPollEvents(): Void;
  public static function inputGetMousePosition(): RLVec2;
  public static function inputGetMouseWheel(): Int;
  public static function inputGetMouseButton(button: Int): Int;
  public static function inputGetMouseState(): RLMouseState;
  public static function inputGetKeyboardState(): RLKeyboardState;
  public static function keyboardGetKeyState(state: RLKeyboardState, key: Int): Int;
  public static function keyboardIsKeyDown(state: RLKeyboardState, key: Int): Bool;
  public static function keyboardGetPressedKey(state: RLKeyboardState, index: Int): Int;
  public static function keyboardGetPressedChar(state: RLKeyboardState, index: Int): Int;
  public static function keyboardGetPressedKeys(state: RLKeyboardState): Array<Int>;
  public static function keyboardGetPressedChars(state: RLKeyboardState): Array<Int>;

  // --- Loader ---
  public static function loaderRestoreFsAsync(): RLLoaderTaskPtr;
  public static function loaderInit(?mountPoint: String): Int;
  public static function loaderInitAsync(?mountPoint: String): Int;
  public static function loaderDeinit(): Void;
  public static function loaderImportAssetAsync(filename: String): RLLoaderTaskPtr;
  public static function loaderImportAssetSync(filename: String): Int;
  public static function loaderImportAssetsAsync(filenames: Array<String>): RLLoaderTaskPtr;
  public static function loaderPollTask(task: RLLoaderTaskPtr): Bool;
  public static function loaderFinishTask(task: RLLoaderTaskPtr): Int;
  public static function loaderCreateTaskGroup<T>(?onComplete: RLTaskGroupCallback<T>, ?onError: RLTaskGroupCallback<T>, ?ctx: T): RLTaskGroup;
  public static function loaderTaskInvalid(): RLLoaderTaskPtr;
  public static function loaderTaskIsValid(task: RLLoaderTaskPtr): Bool;
  public static function loaderGetTaskPath(task: RLLoaderTaskPtr): String;
  public static function loaderReadLocal(filename: String): haxe.io.Bytes;
  public static function loaderFreeTask(task: RLLoaderTaskPtr): Void;
  public static function loaderIsAssetCached(filename: String): Bool;
  public static function loaderPingAssetHost(?assetHost: String): Float;
  public static function loaderGetCacheDir(): String;
  public static function loaderAddTask<T>(task: RLLoaderTaskPtr, onSuccess: String->T->Void, onFailure: String->T->Void, ctx: T): Int;
  public static function loaderTick(): Void;
  public static function loaderClearCache(): Int;
  public static function loaderUncacheAsset(filename: String): Int;

  // --- Logger ---
  public static function loggerMessage(level: Int, message: String): Void;
  public static function loggerMessageSource(level: Int, sourceFile: String, sourceLine: Int, message: String): Void;
  public static function loggerSetLevel(level: Int): Void;
  public static function logTrace(message: String): Void;
  public static function logDebug(message: String): Void;
  public static function logInfo(message: String): Void;
  public static function logWarn(message: String): Void;
  public static function logError(message: String): Void;
  public static function logFatal(message: String): Void;
}
#end
