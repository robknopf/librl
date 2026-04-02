/**
 * Haxe extern bindings for librl (Raylib wrapper).
 * Target: hxcpp (native and emscripten).
 *
 * Build setup: add librl include path (-I path/to/librl/include) and link
 * against librl. See librl Makefile for building the library.
 */
package rl;

import haxe.ds.StringMap;

#if cpp
@:include("rl.h")
#end
private extern class RLNative {
  // --- Types (rl_handle_t = unsigned int) ---
  // RLHandle is passed as Int in Haxe; use Int for handle values

  // --- Window flags (rl_window.h) ---
  static inline var FLAG_WINDOW_RESIZABLE: Int = 0x00000004;
  static inline var FLAG_MSAA_4X_HINT: Int = 0x00000020;
  static inline var FLAG_VSYNC_HINT: Int = 0x00000040;

  // --- Camera projections (rl_camera3d.h) ---
  static inline var CAMERA_PERSPECTIVE: Int = 0;
  static inline var CAMERA_ORTHOGRAPHIC: Int = 1;

  // --- Loader add_task result codes (rl_loader.h) ---
  static inline var LOADER_ADD_TASK_OK: Int = 0;
  static inline var LOADER_ADD_TASK_ERR_INVALID: Int = -1;
  static inline var LOADER_ADD_TASK_ERR_QUEUE_FULL: Int = -2;

  // --- Logger levels (rl_logger.h) ---
  static inline var LOGGER_LEVEL_TRACE: Int = 0;
  static inline var LOGGER_LEVEL_DEBUG: Int = 1;
  static inline var LOGGER_LEVEL_INFO: Int = 2;
  static inline var LOGGER_LEVEL_WARN: Int = 3;
  static inline var LOGGER_LEVEL_ERROR: Int = 4;
  static inline var LOGGER_LEVEL_FATAL: Int = 5;

  // --- Core lifecycle ---
  @:native("rl_init")
  static function init(): Void;

  @:native("rl_deinit")
  static function deinit(): Void;

  @:native("rl_update")
  static function update(): Void;

  @:native("rl_update_to_scratch")
  static function updateToScratch(): Void;

  // --- Run loop (init_fn, tick_fn, shutdown_fn, user_data). ---
  @:native("rl_run")
  static function runNative(
    initFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    tickFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    shutdownFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    userData: cpp.RawPointer<cpp.Void>
  ): Void;

  @:native("rl_request_stop")
  static function requestStop(): Void;

  // --- Time ---
  @:native("rl_get_delta_time")
  static function getDeltaTime(): Float;

  @:native("rl_get_time")
  static function getTime(): Float;

  @:native("rl_set_target_fps")
  static function setTargetFps(fps: Int): Void;

  // --- Colors (rl_color.h) ---
  @:native("rl_color_create")
  static function colorCreate(r: Int, g: Int, b: Int, a: Int): Int;

  @:native("rl_color_destroy")
  static function colorDestroy(color: Int): Void;

  // --- Fonts (rl_font.h, rl_text.h) ---
  @:native("rl_font_create")
  static function fontCreate(filename: String, fontSize: Float): Int;

  @:native("rl_font_destroy")
  static function fontDestroy(font: Int): Void;

  @:native("rl_text_draw_ex")
  static function textDrawEx(font: Int, text: String, x: Int, y: Int, fontSize: Float, spacing: Float, color: Int): Void;

  @:native("rl_text_measure_ex")
  static function textMeasureEx(font: Int, text: String, fontSize: Float, spacing: Float): RLVec2;

  @:native("rl_text_draw_fps_ex")
  static function textDrawFpsEx(font: Int, x: Int, y: Int, fontSize: Int, color: Int): Void;

  // --- Asset host ---
  @:native("rl_set_asset_host")
  static function setAssetHost(assetHost: String): Int;

  @:native("rl_get_asset_host")
  static function getAssetHost(): String;

  // --- Loader (rl_loader.h) ---
  @:native("rl_loader_import_asset_async")
  static function loaderImportAssetAsync(filename: String): RLLoaderTaskPtr;

  @:native("rl_loader_poll_task")
  static function loaderPollTask(task: RLLoaderTaskPtr): Bool;

  @:native("rl_loader_finish_task")
  static function loaderFinishTask(task: RLLoaderTaskPtr): Int;

  @:native("rl_loader_free_task")
  static function loaderFreeTask(task: RLLoaderTaskPtr): Void;

  @:native("rl_loader_is_local")
  static function loaderIsLocal(filename: String): Bool;

  @:native("rl_loader_add_task")
  static function loaderAddTaskNative(task: RLLoaderTaskPtr, path: String,
    onSuccess: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    onFailure: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    userData: cpp.RawPointer<cpp.Void>): Int;

  @:native("rl_loader_clear_cache")
  static function loaderClearCache(): Int;

  // --- Music (rl_music.h) ---
  @:native("rl_music_create")
  static function musicCreate(filename: String): Int;

  @:native("rl_music_destroy")
  static function musicDestroy(music: Int): Void;

  @:native("rl_music_play")
  static function musicPlay(music: Int): Bool;

  @:native("rl_music_pause")
  static function musicPause(music: Int): Bool;

  @:native("rl_music_stop")
  static function musicStop(music: Int): Bool;

  @:native("rl_music_set_loop")
  static function musicSetLoop(music: Int, shouldLoop: Bool): Bool;

  @:native("rl_music_set_volume")
  static function musicSetVolume(music: Int, volume: Float): Bool;

  @:native("rl_music_is_playing")
  static function musicIsPlaying(music: Int): Bool;

  @:native("rl_music_update")
  static function musicUpdate(music: Int): Bool;

  @:native("rl_music_update_all")
  static function musicUpdateAll(): Void;

  // --- Lighting ---
  @:native("rl_enable_lighting")
  static function enableLighting(): Void;

  @:native("rl_disable_lighting")
  static function disableLighting(): Void;

  @:native("rl_is_lighting_enabled")
  static function isLightingEnabled(): Int;

  @:native("rl_set_light_direction")
  static function setLightDirection(x: Float, y: Float, z: Float): Void;

  @:native("rl_set_light_ambient")
  static function setLightAmbient(ambient: Float): Void;

  // --- Render ---
  @:native("rl_render_begin")
  static function renderBegin(): Void;

  @:native("rl_render_end")
  static function renderEnd(): Void;

  @:native("rl_render_clear_background")
  static function renderClearBackground(color: Int): Void;

  @:native("rl_render_begin_mode_2d")
  static function renderBeginMode2D(camera: Int): Void;

  @:native("rl_render_end_mode_2d")
  static function renderEndMode2D(): Void;

  @:native("rl_render_begin_mode_3d")
  static function renderBeginMode3D(): Void;

  @:native("rl_render_end_mode_3d")
  static function renderEndMode3D(): Void;

  // --- Window ---
  @:native("rl_window_open")
  static function windowOpen(width: Int, height: Int, title: String, flags: Int): Void;

  @:native("rl_window_set_title")
  static function windowSetTitle(title: String): Void;

  @:native("rl_window_set_size")
  static function windowSetSize(width: Int, height: Int): Void;

  @:native("rl_window_close")
  static function windowClose(): Void;

  @:native("rl_window_get_screen_size")
  static function windowGetScreenSize(): RLVec2;

  @:native("rl_window_get_monitor_count")
  static function windowGetMonitorCount(): Int;

  @:native("rl_window_get_current_monitor")
  static function windowGetCurrentMonitor(): Int;

  @:native("rl_window_set_monitor")
  static function windowSetMonitor(monitor: Int): Void;

  @:native("rl_window_get_monitor_width")
  static function windowGetMonitorWidth(monitor: Int): Int;

  @:native("rl_window_get_monitor_height")
  static function windowGetMonitorHeight(monitor: Int): Int;

  @:native("rl_window_get_monitor_position")
  static function windowGetMonitorPosition(monitor: Int): RLVec2;

  @:native("rl_window_get_position")
  static function windowGetPosition(): RLVec2;

  @:native("rl_window_set_position")
  static function windowSetPosition(x: Int, y: Int): Void;

  // --- 3D camera (rl_camera3d.h) ---
  @:native("rl_camera3d_create")
  static function camera3dCreate(
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): Int;

  @:native("rl_camera3d_set")
  static function camera3dSet(
    camera: Int,
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): Bool;

  @:native("rl_camera3d_set_active")
  static function camera3dSetActive(camera: Int): Bool;

  @:native("rl_camera3d_destroy")
  static function camera3dDestroy(camera: Int): Void;

  // --- Models (rl_model.h) ---
  @:native("rl_model_create")
  static function modelCreate(filename: String): Int;

  @:native("rl_model_set_transform")
  static function modelSetTransform(
    model: Int,
    positionX: Float, positionY: Float, positionZ: Float,
    rotationX: Float, rotationY: Float, rotationZ: Float,
    scaleX: Float, scaleY: Float, scaleZ: Float
  ): Bool;

  @:native("rl_model_draw")
  static function modelDraw(model: Int, tint: Int): Void;

  @:native("rl_model_set_animation")
  static function modelSetAnimation(model: Int, animationIndex: Int): Bool;

  @:native("rl_model_set_animation_speed")
  static function modelSetAnimationSpeed(model: Int, speed: Float): Bool;

  @:native("rl_model_set_animation_loop")
  static function modelSetAnimationLoop(model: Int, shouldLoop: Bool): Bool;

  @:native("rl_model_animate")
  static function modelAnimate(model: Int, deltaSeconds: Float): Bool;

  @:native("rl_model_destroy")
  static function modelDestroy(model: Int): Void;

  // --- Sprite3D (rl_sprite3d.h) ---
  @:native("rl_sprite3d_create")
  static function sprite3dCreate(filename: String): Int;

  @:native("rl_sprite3d_set_transform")
  static function sprite3dSetTransform(
    sprite: Int,
    positionX: Float, positionY: Float, positionZ: Float,
    size: Float
  ): Bool;

  @:native("rl_sprite3d_draw")
  static function sprite3dDraw(sprite: Int, tint: Int): Void;

  @:native("rl_sprite3d_destroy")
  static function sprite3dDestroy(sprite: Int): Void;

  // --- Input (rl_input.h) ---
  @:native("rl_input_get_mouse_state")
  static function inputGetMouseState(): RLMouseState;
}

#if cpp
@:include("rl_types.h")
@:native("vec2_t")
@:structAccess
extern class RLVec2 {
  var x: Float;
  var y: Float;
}

@:include("rl_types.h")
@:native("rl_mouse_state_t")
@:structAccess
extern class RLMouseState {
  public var x: Int;
  public var y: Int;
  public var wheel: Int;
  public var left: Int;
  public var right: Int;
  public var middle: Int;
}

@:include("rl_loader.h")
@:native("rl_loader_task_t")
extern class RLLoaderTask {}

@:forwardStatics
abstract RL(RLNative) from RLNative to RLNative {
  public static inline function run<T>(initFn: T->Void, tickFn: T->Void, shutdownFn: T->Void, ctx: T): Void {
    var initSpringboard: cpp.Callable<cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onInitSpringboard);
    var tickSpringboard: cpp.Callable<cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onTickSpringboard);
    var shutdownSpringboard: cpp.Callable<cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onShutdownSpringboard);
    RLBridge.initCallback = cast initFn;
    RLBridge.tickCallback = cast tickFn;
    RLBridge.shutdownCallback = cast shutdownFn;
    RLBridge.runContext = ctx;
    RLNative.runNative(
      initSpringboard,
      tickSpringboard,
      shutdownSpringboard,
      null
    );
  }

  public static inline function loaderAddTask<T>(task: RLLoaderTaskPtr, path: String,
    onSuccess: String->T->Void, onFailure: String->T->Void, ctx: T): Int {
    var successSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onLoaderSuccessSpringboard);
    var failureSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onLoaderFailureSpringboard);
    RLBridge.loaderCallbacks.set(path, {
      onSuccess: cast onSuccess,
      onFailure: cast onFailure,
      ctx: ctx
    });
    return RLNative.loaderAddTaskNative(
      task,
      path,
      successSpringboard,
      failureSpringboard,
      null
    );
  }

  public static inline function loggerMessage(level: Int, message: String): Void {
    RLLoggerBridge.message(level, message == null ? "" : message);
  }

  public static inline function loggerMessageSource(level: Int, sourceFile: String, sourceLine: Int, message: String): Void {
    RLLoggerBridge.messageSource(
      level,
      sourceFile == null ? "" : sourceFile,
      sourceLine,
      message == null ? "" : message
    );
  }

  public static inline function loggerSetLevel(level: Int): Void {
    RLLoggerBridge.setLevel(level);
  }

  public static inline function logTrace(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_TRACE, message);
  }

  public static inline function logDebug(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_DEBUG, message);
  }

  public static inline function logInfo(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_INFO, message);
  }

  public static inline function logWarn(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_WARN, message);
  }

  public static inline function logError(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_ERROR, message);
  }

  public static inline function logFatal(message: String): Void {
    loggerMessage(RLNative.LOGGER_LEVEL_FATAL, message);
  }
}

private typedef RLLoaderCallbacks = {
  var onSuccess: Null<String->Dynamic->Void>;
  var onFailure: Null<String->Dynamic->Void>;
  var ctx: Dynamic;
}

@:headerInclude("rl_logger.h")
private class RLLoggerBridge {
  @:functionCode('
    rl_logger_set_level((rl_log_level_t)level);
  ')
  public static function setLevel(level: Int): Void {}

  @:functionCode('
    rl_logger_message((rl_log_level_t)level, "%s", message.utf8_str());
  ')
  public static function message(level: Int, message: String): Void {}

  @:functionCode('
    rl_logger_message_source(
      (rl_log_level_t)level,
      sourceFile.utf8_str(),
      sourceLine,
      "%s",
      message.utf8_str()
    );
  ')
  public static function messageSource(level: Int, sourceFile: String, sourceLine: Int, message: String): Void {}
}

@:keep
private class RLBridge {
  public static var initCallback: Null<Dynamic->Void> = null;
  public static var tickCallback: Null<Dynamic->Void> = null;
  public static var shutdownCallback: Null<Dynamic->Void> = null;
  public static var runContext: Dynamic = null;
  public static var loaderCallbacks: StringMap<RLLoaderCallbacks> = new StringMap();

  @:keep public static function onInitSpringboard(userData: cpp.RawPointer<cpp.Void>): Void {
    if (initCallback != null) initCallback(runContext);
  }

  @:keep public static function onTickSpringboard(userData: cpp.RawPointer<cpp.Void>): Void {
    if (tickCallback != null) tickCallback(runContext);
  }

  @:keep public static function onShutdownSpringboard(userData: cpp.RawPointer<cpp.Void>): Void {
    if (shutdownCallback != null) shutdownCallback(runContext);
  }

  @:keep public static function onLoaderSuccessSpringboard(path: cpp.ConstCharStar, userData: cpp.RawPointer<cpp.Void>): Void {
    dispatchLoaderCallback(cast path, true);
  }

  @:keep public static function onLoaderFailureSpringboard(path: cpp.ConstCharStar, userData: cpp.RawPointer<cpp.Void>): Void {
    dispatchLoaderCallback(cast path, false);
  }

  static function dispatchLoaderCallback(path: String, success: Bool): Void {
    var callbacks = loaderCallbacks.get(path);
    if (callbacks == null) return;
    loaderCallbacks.remove(path);
    var fn = success ? callbacks.onSuccess : callbacks.onFailure;
    if (fn != null) fn(path, callbacks.ctx);
  }
}

typedef RLLoaderTaskPtr = cpp.RawPointer<RLLoaderTask>;
#else
typedef RLVec2 = {
  var x: Float;
  var y: Float;
}
#end
