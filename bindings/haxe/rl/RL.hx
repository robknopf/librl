/**
 * Haxe extern bindings for librl (Raylib wrapper).
 * Target: hxcpp (native and emscripten).
 *
 * Build setup: add librl include path (-I path/to/librl/include) and link
 * against librl. See librl Makefile for building the library.
 */
package rl;

import haxe.ds.StringMap;

import rl.InjectLibRL;
import rl.RLHandle;
import rl.RLLoader.RLLoaderTaskPtr;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTaskGroup.RLTaskGroupTaskCallback;

/**
 * Optional `rl_init` settings (`rl_config.h`). Omitted / null fields are 0 or empty
 * on the C side so `rl_init_apply_defaults` can fill them.
 */
typedef RLInitConfig = {
	?windowWidth: Int,
	?windowHeight: Int,
	?windowTitle: String,
	?windowFlags: Int,
	?assetHost: String,
	?loaderCacheDir: String,
};

#if cpp
@:include("rl.h")
@:include("rl_config.h")
#end
private extern class RLNative {
  // --- Types (rl_handle_t = unsigned int) ---

  // --- Init result codes (rl.h) ---
  static inline var INIT_OK: Int = 0;
  static inline var INIT_ERR_UNKNOWN: Int = -1;
  static inline var INIT_ERR_ALREADY_INITIALIZED: Int = -2;
  static inline var INIT_ERR_LOADER: Int = -3;
  static inline var INIT_ERR_ASSET_HOST: Int = -4;
  static inline var INIT_ERR_WINDOW: Int = -5;

  // --- Window flags (rl_window.h) ---
  static inline var FLAG_WINDOW_RESIZABLE: Int = 0x00000004;
  static inline var FLAG_MSAA_4X_HINT: Int = 0x00000020;
  static inline var FLAG_VSYNC_HINT: Int = 0x00000040;

  // --- Camera projections (rl_camera3d.h) ---
  static inline var CAMERA_PERSPECTIVE: Int = 0;
  static inline var CAMERA_ORTHOGRAPHIC: Int = 1;

  // --- Loader queue_task result codes (rl_loader.h) ---
  static inline var LOADER_QUEUE_TASK_OK: Int = 0;
  static inline var LOADER_QUEUE_TASK_ERR_INVALID: Int = -1;
  static inline var LOADER_QUEUE_TASK_ERR_QUEUE_FULL: Int = -2;

  // --- Logger levels (rl_logger.h) ---
  static inline var LOGGER_LEVEL_TRACE: Int = 0;
  static inline var LOGGER_LEVEL_DEBUG: Int = 1;
  static inline var LOGGER_LEVEL_INFO: Int = 2;
  static inline var LOGGER_LEVEL_WARN: Int = 3;
  static inline var LOGGER_LEVEL_ERROR: Int = 4;
  static inline var LOGGER_LEVEL_FATAL: Int = 5;

  // --- Core lifecycle ---
  // NOTE: hxcpp may ignore `@:functionCode` bodies in some configurations; `untyped __cpp__` is reliable here.
  static inline function initOrNullConfigNative(): Int {
    return untyped __cpp__("::rl_init((const rl_init_config_t *)0)");
  }

  static inline function initConfigNative(
    width: Int,
    height: Int,
    title: String,
    flags: Int,
    asset: String,
    cache: String
  ): Int {
    return untyped __cpp__(
      "({int _hx_out = 0; rl_init_config_t cfg = {}; cfg.window_width = (int){0}; cfg.window_height = (int){1}; cfg.window_flags = (unsigned int){2}; cfg.window_title = (({3}).length > 0) ? ({3}).utf8_str() : (const char *)0; cfg.asset_host = (({4}).length > 0) ? ({4}).utf8_str() : (const char *)0; cfg.loader_cache_dir = (({5}).length > 0) ? ({5}).utf8_str() : (const char *)0; _hx_out = (int)::rl_init(&cfg); _hx_out;})",
      width,
      height,
      flags,
      title,
      asset,
      cache
    );
  }

  @:native("rl_deinit")
  static function deinit(): Void;

  @:native("rl_is_initialized")
  static function isInitializedNative(): Bool;

  static inline function getPlatformNative(): String {
    return untyped __cpp__("::String(::rl_get_platform())");
  }

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

  @:native("rl_start")
  static function start(
    initFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    tickFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    shutdownFn: cpp.Callable<cpp.RawPointer<cpp.Void>->Void>,
    userData: cpp.RawPointer<cpp.Void>
  ): Int;

  @:native("rl_tick")
  static function tick(): Int;

  @:native("rl_stop")
  static function stop(): Void;

  // --- Time ---
  @:native("rl_get_delta_time")
  static function getDeltaTime(): Float;

  @:native("rl_get_time")
  static function getTime(): Float;

  @:native("rl_set_target_fps")
  static function setTargetFps(fps: Int): Void;

  // --- Colors (rl_color.h) ---
  @:native("RL_COLOR_DEFAULT")
  static var COLOR_DEFAULT: RLHandle;

  @:native("RL_COLOR_LIGHTGRAY")
  static var COLOR_LIGHTGRAY: RLHandle;

  @:native("RL_COLOR_GRAY")
  static var COLOR_GRAY: RLHandle;

  @:native("RL_COLOR_DARKGRAY")
  static var COLOR_DARKGRAY: RLHandle;

  @:native("RL_COLOR_YELLOW")
  static var COLOR_YELLOW: RLHandle;

  @:native("RL_COLOR_GOLD")
  static var COLOR_GOLD: RLHandle;

  @:native("RL_COLOR_ORANGE")
  static var COLOR_ORANGE: RLHandle;

  @:native("RL_COLOR_PINK")
  static var COLOR_PINK: RLHandle;

  @:native("RL_COLOR_RED")
  static var COLOR_RED: RLHandle;

  @:native("RL_COLOR_MAROON")
  static var COLOR_MAROON: RLHandle;

  @:native("RL_COLOR_GREEN")
  static var COLOR_GREEN: RLHandle;

  @:native("RL_COLOR_LIME")
  static var COLOR_LIME: RLHandle;

  @:native("RL_COLOR_DARKGREEN")
  static var COLOR_DARKGREEN: RLHandle;

  @:native("RL_COLOR_SKYBLUE")
  static var COLOR_SKYBLUE: RLHandle;

  @:native("RL_COLOR_BLUE")
  static var COLOR_BLUE: RLHandle;

  @:native("RL_COLOR_DARKBLUE")
  static var COLOR_DARKBLUE: RLHandle;

  @:native("RL_COLOR_PURPLE")
  static var COLOR_PURPLE: RLHandle;

  @:native("RL_COLOR_VIOLET")
  static var COLOR_VIOLET: RLHandle;

  @:native("RL_COLOR_DARKPURPLE")
  static var COLOR_DARKPURPLE: RLHandle;

  @:native("RL_COLOR_BEIGE")
  static var COLOR_BEIGE: RLHandle;

  @:native("RL_COLOR_BROWN")
  static var COLOR_BROWN: RLHandle;

  @:native("RL_COLOR_DARKBROWN")
  static var COLOR_DARKBROWN: RLHandle;

  @:native("RL_COLOR_WHITE")
  static var COLOR_WHITE: RLHandle;

  @:native("RL_COLOR_BLACK")
  static var COLOR_BLACK: RLHandle;

  @:native("RL_COLOR_BLANK")
  static var COLOR_BLANK: RLHandle;

  @:native("RL_COLOR_MAGENTA")
  static var COLOR_MAGENTA: RLHandle;

  @:native("RL_COLOR_RAYWHITE")
  static var COLOR_RAYWHITE: RLHandle;

  @:native("rl_color_create")
  static function colorCreate(r: Int, g: Int, b: Int, a: Int): RLHandle;

  @:native("rl_color_destroy")
  static function colorDestroy(color: RLHandle): Void;

  // --- Fonts (rl_font.h, rl_text.h) ---
  @:native("rl_font_create")
  static function fontCreate(filename: String, fontSize: Int): RLHandle;

  @:native("rl_font_destroy")
  static function fontDestroy(font: RLHandle): Void;

  @:native("rl_text_draw")
  static function textDraw(text: String, x: Int, y: Int, fontSize: Int, color: RLHandle): Void;

  @:native("rl_text_measure")
  static function textMeasure(text: String, fontSize: Int): Int;

  @:native("rl_text_draw_fps")
  static function textDrawFps(x: Int, y: Int): Void;

  @:native("rl_text_draw_ex")
  static function textDrawEx(font: RLHandle, text: String, x: Int, y: Int, fontSize: Float, spacing: Float, color: RLHandle): Void;

  @:native("rl_text_measure_ex")
  static function textMeasureEx(font: RLHandle, text: String, fontSize: Float, spacing: Float): RLVec2;

  @:native("rl_text_draw_fps_ex")
  static function textDrawFpsEx(font: RLHandle, x: Int, y: Int, fontSize: Float, color: RLHandle): Void;

  // --- Asset host ---
  @:native("rl_set_asset_host")
  static function setAssetHost(assetHost: String): Int;

  @:native("rl_get_asset_host")
  static function getAssetHost(): String;


  // --- Music (rl_music.h) ---
  @:native("rl_music_create")
  static function musicCreate(filename: String): RLHandle;

  @:native("rl_music_destroy")
  static function musicDestroy(music: RLHandle): Void;

  @:native("rl_music_play")
  static function musicPlay(music: RLHandle): Bool;

  @:native("rl_music_pause")
  static function musicPause(music: RLHandle): Bool;

  @:native("rl_music_stop")
  static function musicStop(music: RLHandle): Bool;

  @:native("rl_music_set_loop")
  static function musicSetLoop(music: RLHandle, shouldLoop: Bool): Bool;

  @:native("rl_music_set_volume")
  static function musicSetVolume(music: RLHandle, volume: Float): Bool;

  @:native("rl_music_is_playing")
  static function musicIsPlaying(music: RLHandle): Bool;

  @:native("rl_music_update")
  static function musicUpdate(music: RLHandle): Bool;

  @:native("rl_music_update_all")
  static function musicUpdateAll(): Void;

  // --- Sound (rl_sound.h) ---
  @:native("rl_sound_create")
  static function soundCreate(filename: String): RLHandle;

  @:native("rl_sound_destroy")
  static function soundDestroy(sound: RLHandle): Void;

  @:native("rl_sound_play")
  static function soundPlay(sound: RLHandle): Bool;

  @:native("rl_sound_pause")
  static function soundPause(sound: RLHandle): Bool;

  @:native("rl_sound_resume")
  static function soundResume(sound: RLHandle): Bool;

  @:native("rl_sound_stop")
  static function soundStop(sound: RLHandle): Bool;

  @:native("rl_sound_set_volume")
  static function soundSetVolume(sound: RLHandle, volume: Float): Bool;

  @:native("rl_sound_set_pitch")
  static function soundSetPitch(sound: RLHandle, pitch: Float): Bool;

  @:native("rl_sound_set_pan")
  static function soundSetPan(sound: RLHandle, pan: Float): Bool;

  @:native("rl_sound_is_playing")
  static function soundIsPlaying(sound: RLHandle): Bool;

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
  static function renderClearBackground(color: RLHandle): Void;

  @:native("rl_render_begin_mode_2d")
  static function renderBeginMode2D(camera: RLHandle): Void;

  @:native("rl_render_end_mode_2d")
  static function renderEndMode2D(): Void;

  @:native("rl_render_begin_mode_3d")
  static function renderBeginMode3D(): Void;

  @:native("rl_render_end_mode_3d")
  static function renderEndMode3D(): Void;

  // --- Window ---
  @:native("rl_window_set_title")
  static function windowSetTitle(title: String): Void;

  @:native("rl_window_set_size")
  static function windowSetSize(width: Int, height: Int): Void;

  @:native("rl_window_close_requested")
  static function windowCloseRequested(): Bool;

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
  ): RLHandle;

  @:native("rl_camera3d_set")
  static function camera3dSet(
    camera: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    targetX: Float, targetY: Float, targetZ: Float,
    upX: Float, upY: Float, upZ: Float,
    fovy: Float, projection: Int
  ): Bool;

  @:native("rl_camera3d_set_active")
  static function camera3dSetActive(camera: RLHandle): Bool;

  @:native("rl_camera3d_destroy")
  static function camera3dDestroy(camera: RLHandle): Void;

  // --- Models (rl_model.h) ---
  @:native("rl_model_create")
  static function modelCreate(filename: String): RLHandle;

  @:native("rl_model_set_transform")
  static function modelSetTransform(
    model: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    rotationX: Float, rotationY: Float, rotationZ: Float,
    scaleX: Float, scaleY: Float, scaleZ: Float
  ): Bool;

  @:native("rl_model_draw")
  static function modelDraw(model: RLHandle, tint: RLHandle): Void;

  @:native("rl_model_set_animation")
  static function modelSetAnimation(model: RLHandle, animationIndex: Int): Bool;

  @:native("rl_model_set_animation_speed")
  static function modelSetAnimationSpeed(model: RLHandle, speed: Float): Bool;

  @:native("rl_model_set_animation_loop")
  static function modelSetAnimationLoop(model: RLHandle, shouldLoop: Bool): Bool;

  @:native("rl_model_animate")
  static function modelAnimate(model: RLHandle, deltaSeconds: Float): Bool;

  @:native("rl_model_destroy")
  static function modelDestroy(model: RLHandle): Void;

  // --- Sprite3D (rl_sprite3d.h) ---
  @:native("rl_sprite3d_create")
  static function sprite3dCreate(filename: String): RLHandle;

  @:native("rl_sprite3d_set_transform")
  static function sprite3dSetTransform(
    sprite: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    size: Float
  ): Bool;

  @:native("rl_sprite3d_draw")
  static function sprite3dDraw(sprite: RLHandle, tint: RLHandle): Void;

  @:native("rl_sprite3d_destroy")
  static function sprite3dDestroy(sprite: RLHandle): Void;

  // --- Sprite2D (rl_sprite2d.h) ---
  @:native("rl_sprite2d_create")
  static function sprite2dCreate(filename: String): RLHandle;

  @:native("rl_sprite2d_create_from_texture")
  static function sprite2dCreateFromTexture(texture: RLHandle): RLHandle;

  @:native("rl_sprite2d_set_transform")
  static function sprite2dSetTransform(
    sprite: RLHandle,
    x: Float, y: Float,
    scale: Float, rotation: Float
  ): Bool;

  @:native("rl_sprite2d_draw")
  static function sprite2dDraw(sprite: RLHandle, tint: RLHandle): Void;

  @:native("rl_sprite2d_destroy")
  static function sprite2dDestroy(sprite: RLHandle): Void;

  // --- Texture (rl_texture.h) ---
  @:native("rl_texture_create")
  static function textureCreate(filename: String): RLHandle;

  @:native("rl_texture_destroy")
  static function textureDestroy(texture: RLHandle): Void;

  @:native("rl_texture_draw_ex")
  static function textureDrawEx(texture: RLHandle, x: Float, y: Float, scale: Float, rotation: Float, tint: RLHandle): Void;

  @:native("rl_texture_draw_ground")
  static function textureDrawGround(texture: RLHandle,
    positionX: Float, positionY: Float, positionZ: Float,
    width: Float, length: Float, tint: RLHandle): Void;

  // --- Input (rl_input.h) ---
  @:native("rl_input_get_mouse_position")
  static function inputGetMousePosition(): RLVec2;

  @:native("rl_input_get_mouse_wheel")
  static function inputGetMouseWheel(): Int;

  @:native("rl_input_get_mouse_button")
  static function inputGetMouseButton(button: Int): Int;

  @:native("rl_input_get_mouse_state")
  static function inputGetMouseState(): RLMouseState;

  @:native("rl_input_get_keyboard_state")
  static function inputGetKeyboardStateNative(): RLKeyboardState;
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

class RLKeyboardState {
  public var max_num_keys: Int = 0;
  public var keys: Array<Int> = [];
  public var pressed_key: Int = 0;
  public var pressed_char: Int = 0;
  public var num_pressed_keys: Int = 0;
  public var pressed_keys: Array<Int> = [];
  public var num_pressed_chars: Int = 0;
  public var pressed_chars: Array<Int> = [];

  public function new() {}
}

@:forwardStatics
#if cpp
@:include("rl.h")
@:include("rl_loader.h")
@:headerInclude("rl_loader.h")
@:headerInclude("alloca.h")
#end
abstract RL(RLNative) from RLNative to RLNative {
  public static inline function inputGetKeyboardState(): RLKeyboardState {
    return RLKeyboardBridge.getState();
  }

  public static inline function keyboardGetKeyState(state: RLKeyboardState, key: Int): Int {
    if (state.keys == null || key < 0 || key >= state.max_num_keys || key >= state.keys.length) {
      return 0;
    }
    return state.keys[key];
  }

  public static inline function keyboardIsKeyDown(state: RLKeyboardState, key: Int): Bool {
    return keyboardGetKeyState(state, key) != 0;
  }

  public static inline function keyboardGetPressedKey(state: RLKeyboardState, index: Int): Int {
    if (state.pressed_keys == null || index < 0 || index >= state.num_pressed_keys || index >= state.pressed_keys.length) {
      return 0;
    }
    return state.pressed_keys[index];
  }

  public static inline function keyboardGetPressedChar(state: RLKeyboardState, index: Int): Int {
    if (state.pressed_chars == null || index < 0 || index >= state.num_pressed_chars || index >= state.pressed_chars.length) {
      return 0;
    }
    return state.pressed_chars[index];
  }

  public static inline function keyboardGetPressedKeys(state: RLKeyboardState): Array<Int> {
    var result = new Array<Int>();
    for (i in 0...state.num_pressed_keys) {
      result.push(keyboardGetPressedKey(state, i));
    }
    return result;
  }

  public static inline function keyboardGetPressedChars(state: RLKeyboardState): Array<Int> {
    var result = new Array<Int>();
    for (i in 0...state.num_pressed_chars) {
      result.push(keyboardGetPressedChar(state, i));
    }
    return result;
  }

  public static inline function init(?config: RLInitConfig): Int {
    if (config == null) {
      return RLNative.initOrNullConfigNative();
    }
    var w: Int = config.windowWidth != null ? config.windowWidth : 0;
    var h: Int = config.windowHeight != null ? config.windowHeight : 0;
    var title: String = config.windowTitle != null ? config.windowTitle : "";
    var flags: Int = config.windowFlags != null ? config.windowFlags : 0;
    var asset: String = config.assetHost != null ? config.assetHost : "";
    var cache: String = config.loaderCacheDir != null ? config.loaderCacheDir : "";
    return RLNative.initConfigNative(w, h, title, flags, asset, cache);
  }

  public static inline function isInitialized(): Bool {
    return RLNative.isInitializedNative();
  }

  public static inline function getPlatform(): String {
    return RLNative.getPlatformNative();
  }

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

  public static function loaderRestoreFsAsync(): RLLoaderTaskPtr {
    return RLLoader.loaderRestoreFsAsync();
  }

  public static function loaderImportAssetAsync(filename: String): RLLoaderTaskPtr {
    return RLLoader.loaderImportAssetAsync(filename);
  }

  public static function loaderImportAssetsAsync(filenames: Array<String>): RLLoaderTaskPtr {
    return RLLoader.loaderImportAssetsAsync(filenames);
  }

  public static function loaderPollTask(task: RLLoaderTaskPtr): Bool {
    return RLLoader.loaderPollTask(task);
  }

  public static function loaderFinishTask(task: RLLoaderTaskPtr): Int {
    return RLLoader.loaderFinishTask(task);
  }

  public static inline function loaderCreateTaskGroup<T>(?onComplete:RLTaskGroupCallback<T>, ?onError:RLTaskGroupCallback<T>, ?ctx:T): RLTaskGroup {
    return new RLTaskGroup(cast onComplete, cast onError, ctx);
  }

  public static inline function loaderTaskInvalid(): RLLoaderTaskPtr {
    return RLLoaderTaskPtr.invalid();
  }

  public static inline function loaderTaskIsValid(task: RLLoaderTaskPtr): Bool {
    return task.isValid();
  }

  public static function loaderGetTaskPath(task: RLLoaderTaskPtr): String {
    return RLLoader.loaderGetTaskPath(task);
  }

  public static function loaderFreeTask(task: RLLoaderTaskPtr): Void {
    RLLoader.loaderFreeTask(task);
  }

  public static function loaderIsLocal(filename: String): Bool {
    return RLLoader.loaderIsLocal(filename);
  }

  public static function loaderPingAssetHost(?assetHost: String): Float {
    return RLLoader.loaderPingAssetHost(assetHost);
  }

  static function loaderAddTaskNative(task: RLLoaderTaskPtr, path: String,
    onSuccess: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    onFailure: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return RLLoader.loaderAddTask(task, path, onSuccess, onFailure, userData);
  }

  public static function loaderTick(): Void {
    RLLoader.loaderTick();
  }

  public static function loaderClearCache(): Int {
    return RLLoader.loaderClearCache();
  }

  public static function loaderUncacheFile(filename: String): Int {
    return RLLoader.loaderUncacheFile(filename);
  }

  public static inline function loaderAddTask<T>(task: RLLoaderTaskPtr,
    onSuccess: String->T->Void, onFailure: String->T->Void, ctx: T): Int {
    var successSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onLoaderSuccessSpringboard);
    var failureSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridge.onLoaderFailureSpringboard);
    var path = loaderGetTaskPath(task);
    var callbackKey = RLBridge.makeLoaderCallbackKey(path);
    var callbackInvoked = false;
    var callbackUserData = RLLoaderCallbackBridge.alloc(callbackKey);
    if (callbackUserData == null) {
      if (onFailure != null) {
        onFailure(path, ctx);
      }
      return RLNative.LOADER_QUEUE_TASK_ERR_INVALID;
    }
    RLBridge.loaderCallbacks.set(callbackKey, {
      onSuccess: cast function(callbackPath:String, callbackCtx:T):Void {
        callbackInvoked = true;
        if (onSuccess != null) {
          onSuccess(callbackPath, callbackCtx);
        }
      },
      onFailure: cast function(callbackPath:String, callbackCtx:T):Void {
        callbackInvoked = true;
        if (onFailure != null) {
          onFailure(callbackPath, callbackCtx);
        }
      },
      ctx: ctx
    });
    var rc = loaderAddTaskNative(
      task,
      path,
      successSpringboard,
      failureSpringboard,
      callbackUserData
    );
    if (rc != RLNative.LOADER_QUEUE_TASK_OK && !callbackInvoked) {
      RLBridge.loaderCallbacks.remove(callbackKey);
      RLLoaderCallbackBridge.free(callbackUserData);
    }
    return rc;
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
    ::rl_logger_set_level((::rl_log_level_t)level);
  ')
  public static function setLevel(level: Int): Void {}

  @:functionCode('
    ::rl_logger_message((::rl_log_level_t)level, "%s", message.utf8_str());
  ')
  public static function message(level: Int, message: String): Void {}

  @:functionCode('
    ::rl_logger_message_source(
      (::rl_log_level_t)level,
      sourceFile.utf8_str(),
      sourceLine,
      "%s",
      message.utf8_str()
    );
  ')
  public static function messageSource(level: Int, sourceFile: String, sourceLine: Int, message: String): Void {}
}

@:headerCode('
  #include <stdlib.h>
  #include <string.h>
')
private class RLLoaderCallbackBridge {
  @:functionCode('
    if (key == null()) {
      return nullptr;
    }
    const char *src = key.utf8_str();
    size_t len = strlen(src) + 1;
    char *copy = (char *)::malloc(len);
    if (copy == nullptr) {
      return nullptr;
    }
    ::memcpy(copy, src, len);
    return copy;
  ')
  public static function alloc(key: String): cpp.RawPointer<cpp.Void> {
    return null;
  }

  @:functionCode('
    if (userData == nullptr) {
      return ::String();
    }
    const char *src = (const char *)userData;
    ::String key = ::String(src);
    ::free(userData);
    return key;
  ')
  public static function consume(userData: cpp.RawPointer<cpp.Void>): String {
    return null;
  }

  @:functionCode('
    if (userData != nullptr) {
      ::free(userData);
    }
  ')
  public static function free(userData: cpp.RawPointer<cpp.Void>): Void {}
}

@:headerInclude("rl_input.h")
private class RLKeyboardBridge {
  @:functionCode('
    ::rl_keyboard_state_t nativeState = ::rl_input_get_keyboard_state();
    ::rl::RLKeyboardState result = ::rl::RLKeyboardState_obj::__new();
    result->max_num_keys = nativeState.max_num_keys;
    result->keys = Array_obj<int>::fromData(nativeState.keys, nativeState.max_num_keys);
    result->pressed_key = nativeState.pressed_key;
    result->pressed_char = nativeState.pressed_char;
    result->num_pressed_keys = nativeState.num_pressed_keys;
    result->pressed_keys = Array_obj<int>::fromData(nativeState.pressed_keys, nativeState.num_pressed_keys);
    result->num_pressed_chars = nativeState.num_pressed_chars;
    result->pressed_chars = Array_obj<int>::fromData(nativeState.pressed_chars, nativeState.num_pressed_chars);
    return result;
  ')
  public static function getState(): RLKeyboardState {
    return null;
  }
}

@:keep
private class RLBridge {
  public static var initCallback: Null<Dynamic->Void> = null;
  public static var tickCallback: Null<Dynamic->Void> = null;
  public static var shutdownCallback: Null<Dynamic->Void> = null;
  public static var runContext: Dynamic = null;
  public static var nextLoaderCallbackId: Int = 0;
  public static var loaderCallbacks: StringMap<RLLoaderCallbacks> = new StringMap();

  public static inline function makeLoaderCallbackKey(path: String): String {
    var key = (path == null ? "" : path) + "#" + nextLoaderCallbackId;
    nextLoaderCallbackId++;
    return key;
  }

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
    dispatchLoaderCallback(RLLoaderCallbackBridge.consume(userData), cast path, true);
  }

  @:keep public static function onLoaderFailureSpringboard(path: cpp.ConstCharStar, userData: cpp.RawPointer<cpp.Void>): Void {
    dispatchLoaderCallback(RLLoaderCallbackBridge.consume(userData), cast path, false);
  }

  static function dispatchLoaderCallback(callbackKey: String, path: String, success: Bool): Void {
    var callbacks = loaderCallbacks.get(callbackKey);
    if (callbacks == null) return;
    loaderCallbacks.remove(callbackKey);
    var fn = success ? callbacks.onSuccess : callbacks.onFailure;
    if (fn != null) fn(path, callbacks.ctx);
  }
}
#else
typedef RLVec2 = {
  var x: Float;
  var y: Float;
}
#end
