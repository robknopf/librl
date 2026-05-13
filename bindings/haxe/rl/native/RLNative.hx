/**
 * hxcpp-only implementation of the RL binding.
 * Contains all cpp.*, @:native, untyped __cpp__, @:functionCode, and bridge
 * classes. Must NOT be imported by cppia scripts or Lua targets.
 *
 * Scripts should import rl.RL only — it resolves via export_classes.info at
 * cppia compile time, or via #if cpp delegation at hxcpp compile time.
 */
package rl.native;

#if cpp
import haxe.ds.StringMap;
import rl.InjectLibRL;
import rl.RLHandle;
import rl.native.RLLoaderNative.RLLoaderTaskPtrImpl;
import rl.native.RLLoaderNative.RLLoader;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLVec2;
import rl.RLTypes.RLVec3;
import rl.RLTypes.RLPickResult;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLKeyboardState;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTaskGroup.RLTaskGroupTaskCallback;

@:keep
@:include("rl.h")
@:include("rl_config.h")
private extern class RLNativeImpl {
  // --- Init result codes (rl.h) ---
  static inline var INIT_OK: Int = 0;
  static inline var INIT_ERR_UNKNOWN: Int = -1;
  static inline var INIT_ERR_ALREADY_INITIALIZED: Int = -2;
  static inline var INIT_ERR_LOADER: Int = -3;
  static inline var INIT_ERR_ASSET_HOST: Int = -4;
  static inline var INIT_ERR_WINDOW: Int = -5;

  // --- Tick result codes (rl.h) ---
  static inline var TICK_RUNNING: Int = 0;
  static inline var TICK_WAITING: Int = 1;
  static inline var TICK_FAILED: Int = -1;

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

  static inline function initOrNullConfigNative(): Int {
    return untyped __cpp__("::rl_init((const rl_init_config_t *)0)");
  }

  static inline function initAsyncOrNullConfigNative(): Int {
    return untyped __cpp__("::rl_init_async((const rl_init_config_t *)0)");
  }

  static inline function initConfigNative(
    width: Int, height: Int, title: String, flags: Int,
    asset: String, cache: String
  ): Int {
    return untyped __cpp__(
      "({int _hx_out = 0; rl_init_config_t cfg = {}; cfg.window_width = (int){0}; cfg.window_height = (int){1}; cfg.window_flags = (unsigned int){2}; cfg.window_title = (({3}).length > 0) ? ({3}).utf8_str() : (const char *)0; cfg.asset_host = (({4}).length > 0) ? ({4}).utf8_str() : (const char *)0; cfg.loader_cache_dir = (({5}).length > 0) ? ({5}).utf8_str() : (const char *)0; _hx_out = (int)::rl_init(&cfg); _hx_out;})",
      width, height, flags, title, asset, cache
    );
  }

  static inline function initAsyncConfigNative(
    width: Int, height: Int, title: String, flags: Int,
    asset: String, cache: String
  ): Int {
    return untyped __cpp__(
      "({int _hx_out = 0; rl_init_config_t cfg = {}; cfg.window_width = (int){0}; cfg.window_height = (int){1}; cfg.window_flags = (unsigned int){2}; cfg.window_title = (({3}).length > 0) ? ({3}).utf8_str() : (const char *)0; cfg.asset_host = (({4}).length > 0) ? ({4}).utf8_str() : (const char *)0; cfg.loader_cache_dir = (({5}).length > 0) ? ({5}).utf8_str() : (const char *)0; _hx_out = (int)::rl_init_async(&cfg); _hx_out;})",
      width, height, flags, title, asset, cache
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

  @:native("rl_tick")
  static function tick(): Int;

  @:native("rl_get_delta_time")
  static function getDeltaTime(): Float;

  @:native("rl_get_time")
  static function getTime(): Float;

  @:native("rl_set_target_fps")
  static function setTargetFps(fps: Int): Void;

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

  @:native("rl_set_asset_host")
  static function setAssetHost(assetHost: String): Int;

  @:native("rl_get_asset_host")
  static function getAssetHost(): String;

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

  @:native("rl_input_poll_events")
  static function inputPollEvents(): Void;

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

  @:native("rl_pick_model")
  static function pickModel(camera: RLHandle, model: RLHandle, mouseX: Float, mouseY: Float): RLPickResult;

  @:native("rl_pick_sprite3d")
  static function pickSprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: Float, mouseY: Float): RLPickResult;

  @:native("rl_pick_reset_stats")
  static function pickResetStats(): Void;

  @:native("rl_pick_get_broadphase_tests")
  static function pickGetBroadphaseTests(): Int;

  @:native("rl_pick_get_broadphase_rejects")
  static function pickGetBroadphaseRejects(): Int;

  @:native("rl_pick_get_narrowphase_tests")
  static function pickGetNarrowphaseTests(): Int;

  @:native("rl_pick_get_narrowphase_hits")
  static function pickGetNarrowphaseHits(): Int;
}

@:include("rl_types.h")
@:native("vec2_t")
@:structAccess
extern class RLVec2Native {
  var x: Float;
  var y: Float;
}

@:include("rl_types.h")
@:native("vec3_t")
@:structAccess
extern class RLVec3Native {
  var x: Float;
  var y: Float;
  var z: Float;
}

@:include("rl_pick.h")
@:native("rl_pick_result_t")
@:structAccess
extern class RLPickResultNative {
  var hit: Bool;
  var distance: Float;
  var point: RLVec3Native;
  var normal: RLVec3Native;
}

@:include("rl_types.h")
@:native("rl_mouse_state_t")
@:structAccess
extern class RLMouseStateNative {
  public var x: Int;
  public var y: Int;
  public var wheel: Int;
  public var left: Int;
  public var right: Int;
  public var middle: Int;
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

@:include("rl_input.h")
@:structAccess
@:native("rl_keyboard_state_t")
extern class RLNativeKeyboardState {
  var max_num_keys: Int;
  var keys: cpp.RawPointer<Int>;
  var pressed_key: Int;
  var pressed_char: Int;
  var num_pressed_keys: Int;
  var pressed_keys: cpp.RawPointer<Int>;
  var num_pressed_chars: Int;
  var pressed_chars: cpp.RawPointer<Int>;
}

private class RLKeyboardBridge {
  static function getNativeState(): RLNativeKeyboardState {
    return untyped __cpp__('::rl_input_get_keyboard_state()');
  }

  static function rawToArray(ptr: cpp.RawPointer<Int>, len: Int): Array<Int> {
    var arr = new Array<Int>();
    for (i in 0...len) {
      arr.push(untyped __cpp__('{0}[{1}]', ptr, i));
    }
    return arr;
  }

  public static function getState(): RLKeyboardState {
    var s = getNativeState();
    var result = new RLKeyboardState();
    result.max_num_keys = s.max_num_keys;
    result.keys = rawToArray(s.keys, s.max_num_keys);
    result.pressed_key = s.pressed_key;
    result.pressed_char = s.pressed_char;
    result.num_pressed_keys = s.num_pressed_keys;
    result.pressed_keys = rawToArray(s.pressed_keys, s.num_pressed_keys);
    result.num_pressed_chars = s.num_pressed_chars;
    result.pressed_chars = rawToArray(s.pressed_chars, s.num_pressed_chars);
    return result;
  }
}

private class RLBridgeImpl {
  public static var nextLoaderCallbackId: Int = 0;
  public static var loaderCallbacks: StringMap<RLLoaderCallbacks> = new StringMap();

  public static function makeLoaderCallbackKey(path: String): String {
    var key = (path == null ? "" : path) + "#" + nextLoaderCallbackId;
    nextLoaderCallbackId++;
    return key;
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

private typedef RLLoaderCallbacks = {
  var onSuccess: Null<String->Dynamic->Void>;
  var onFailure: Null<String->Dynamic->Void>;
  var ctx: Dynamic;
}

@:include("rl.h")
@:include("rl_loader.h")
@:headerInclude("rl_loader.h")
@:headerInclude("alloca.h")
abstract RLImpl(RLNativeImpl) from RLNativeImpl to RLNativeImpl {
  // --- Forwarded constants (inline so cppia bakes values at script compile time) ---
  public static inline var INIT_OK: Int = 0;
  public static inline var INIT_ERR_UNKNOWN: Int = -1;
  public static inline var INIT_ERR_ALREADY_INITIALIZED: Int = -2;
  public static inline var INIT_ERR_LOADER: Int = -3;
  public static inline var INIT_ERR_ASSET_HOST: Int = -4;
  public static inline var INIT_ERR_WINDOW: Int = -5;
  public static inline var TICK_RUNNING: Int = 0;
  public static inline var TICK_WAITING: Int = 1;
  public static inline var TICK_FAILED: Int = -1;
  public static inline var FLAG_WINDOW_RESIZABLE: Int = 0x00000004;
  public static inline var FLAG_MSAA_4X_HINT: Int = 0x00000020;
  public static inline var FLAG_VSYNC_HINT: Int = 0x00000040;
  public static inline var CAMERA_PERSPECTIVE: Int = 0;
  public static inline var CAMERA_ORTHOGRAPHIC: Int = 1;
  public static inline var LOADER_QUEUE_TASK_OK: Int = 0;
  public static inline var LOADER_QUEUE_TASK_ERR_INVALID: Int = -1;
  public static inline var LOADER_QUEUE_TASK_ERR_QUEUE_FULL: Int = -2;
  public static inline var LOGGER_LEVEL_TRACE: Int = 0;
  public static inline var LOGGER_LEVEL_DEBUG: Int = 1;
  public static inline var LOGGER_LEVEL_INFO: Int = 2;
  public static inline var LOGGER_LEVEL_WARN: Int = 3;
  public static inline var LOGGER_LEVEL_ERROR: Int = 4;
  public static inline var LOGGER_LEVEL_FATAL: Int = 5;
  public static var COLOR_DEFAULT(get, never): RLHandle; static function get_COLOR_DEFAULT() return RLNativeImpl.COLOR_DEFAULT;
  public static var COLOR_LIGHTGRAY(get, never): RLHandle; static function get_COLOR_LIGHTGRAY() return RLNativeImpl.COLOR_LIGHTGRAY;
  public static var COLOR_GRAY(get, never): RLHandle; static function get_COLOR_GRAY() return RLNativeImpl.COLOR_GRAY;
  public static var COLOR_DARKGRAY(get, never): RLHandle; static function get_COLOR_DARKGRAY() return RLNativeImpl.COLOR_DARKGRAY;
  public static var COLOR_YELLOW(get, never): RLHandle; static function get_COLOR_YELLOW() return RLNativeImpl.COLOR_YELLOW;
  public static var COLOR_GOLD(get, never): RLHandle; static function get_COLOR_GOLD() return RLNativeImpl.COLOR_GOLD;
  public static var COLOR_ORANGE(get, never): RLHandle; static function get_COLOR_ORANGE() return RLNativeImpl.COLOR_ORANGE;
  public static var COLOR_PINK(get, never): RLHandle; static function get_COLOR_PINK() return RLNativeImpl.COLOR_PINK;
  public static var COLOR_RED(get, never): RLHandle; static function get_COLOR_RED() return RLNativeImpl.COLOR_RED;
  public static var COLOR_MAROON(get, never): RLHandle; static function get_COLOR_MAROON() return RLNativeImpl.COLOR_MAROON;
  public static var COLOR_GREEN(get, never): RLHandle; static function get_COLOR_GREEN() return RLNativeImpl.COLOR_GREEN;
  public static var COLOR_LIME(get, never): RLHandle; static function get_COLOR_LIME() return RLNativeImpl.COLOR_LIME;
  public static var COLOR_DARKGREEN(get, never): RLHandle; static function get_COLOR_DARKGREEN() return RLNativeImpl.COLOR_DARKGREEN;
  public static var COLOR_SKYBLUE(get, never): RLHandle; static function get_COLOR_SKYBLUE() return RLNativeImpl.COLOR_SKYBLUE;
  public static var COLOR_BLUE(get, never): RLHandle; static function get_COLOR_BLUE() return RLNativeImpl.COLOR_BLUE;
  public static var COLOR_DARKBLUE(get, never): RLHandle; static function get_COLOR_DARKBLUE() return RLNativeImpl.COLOR_DARKBLUE;
  public static var COLOR_PURPLE(get, never): RLHandle; static function get_COLOR_PURPLE() return RLNativeImpl.COLOR_PURPLE;
  public static var COLOR_VIOLET(get, never): RLHandle; static function get_COLOR_VIOLET() return RLNativeImpl.COLOR_VIOLET;
  public static var COLOR_DARKPURPLE(get, never): RLHandle; static function get_COLOR_DARKPURPLE() return RLNativeImpl.COLOR_DARKPURPLE;
  public static var COLOR_BEIGE(get, never): RLHandle; static function get_COLOR_BEIGE() return RLNativeImpl.COLOR_BEIGE;
  public static var COLOR_BROWN(get, never): RLHandle; static function get_COLOR_BROWN() return RLNativeImpl.COLOR_BROWN;
  public static var COLOR_DARKBROWN(get, never): RLHandle; static function get_COLOR_DARKBROWN() return RLNativeImpl.COLOR_DARKBROWN;
  public static var COLOR_WHITE(get, never): RLHandle; static function get_COLOR_WHITE() return RLNativeImpl.COLOR_WHITE;
  public static var COLOR_BLACK(get, never): RLHandle; static function get_COLOR_BLACK() return RLNativeImpl.COLOR_BLACK;
  public static var COLOR_BLANK(get, never): RLHandle; static function get_COLOR_BLANK() return RLNativeImpl.COLOR_BLANK;
  public static var COLOR_MAGENTA(get, never): RLHandle; static function get_COLOR_MAGENTA() return RLNativeImpl.COLOR_MAGENTA;
  public static var COLOR_RAYWHITE(get, never): RLHandle; static function get_COLOR_RAYWHITE() return RLNativeImpl.COLOR_RAYWHITE;
  // --- Forwarded methods ---
  public static function deinit(): Void { RLNativeImpl.deinit(); }
  public static function update(): Void { RLNativeImpl.update(); }
  public static function updateToScratch(): Void { RLNativeImpl.updateToScratch(); }
  public static function tick(): Int { return RLNativeImpl.tick(); }
  public static function getDeltaTime(): Float { return RLNativeImpl.getDeltaTime(); }
  public static function getTime(): Float { return RLNativeImpl.getTime(); }
  public static function setTargetFps(fps: Int): Void { RLNativeImpl.setTargetFps(fps); }
  public static function colorCreate(r: Int, g: Int, b: Int, a: Int): RLHandle { return RLNativeImpl.colorCreate(r, g, b, a); }
  public static function colorDestroy(color: RLHandle): Void { RLNativeImpl.colorDestroy(color); }
  public static function fontCreate(filename: String, fontSize: Int): RLHandle { return RLNativeImpl.fontCreate(filename, fontSize); }
  public static function fontDestroy(font: RLHandle): Void { RLNativeImpl.fontDestroy(font); }
  public static function textDraw(text: String, x: Int, y: Int, fontSize: Int, color: RLHandle): Void { RLNativeImpl.textDraw(text, x, y, fontSize, color); }
  public static function textMeasure(text: String, fontSize: Int): Int { return RLNativeImpl.textMeasure(text, fontSize); }
  public static function textDrawFps(x: Int, y: Int): Void { RLNativeImpl.textDrawFps(x, y); }
  public static function textDrawEx(font: RLHandle, text: String, x: Int, y: Int, fontSize: Float, spacing: Float, color: RLHandle): Void { RLNativeImpl.textDrawEx(font, text, x, y, fontSize, spacing, color); }
  public static function textMeasureEx(font: RLHandle, text: String, fontSize: Float, spacing: Float): RLVec2 {
    var n: RLVec2Native = cast RLNativeImpl.textMeasureEx(font, text, fontSize, spacing);
    return {x: n.x, y: n.y};
  }
  public static function textDrawFpsEx(font: RLHandle, x: Int, y: Int, fontSize: Float, color: RLHandle): Void { RLNativeImpl.textDrawFpsEx(font, x, y, fontSize, color); }
  public static function setAssetHost(assetHost: String): Int { return RLNativeImpl.setAssetHost(assetHost); }
  public static function getAssetHost(): String { return RLNativeImpl.getAssetHost(); }
  public static function musicCreate(filename: String): RLHandle { return RLNativeImpl.musicCreate(filename); }
  public static function musicDestroy(music: RLHandle): Void { RLNativeImpl.musicDestroy(music); }
  public static function musicPlay(music: RLHandle): Bool { return RLNativeImpl.musicPlay(music); }
  public static function musicPause(music: RLHandle): Bool { return RLNativeImpl.musicPause(music); }
  public static function musicStop(music: RLHandle): Bool { return RLNativeImpl.musicStop(music); }
  public static function musicSetLoop(music: RLHandle, shouldLoop: Bool): Bool { return RLNativeImpl.musicSetLoop(music, shouldLoop); }
  public static function musicSetVolume(music: RLHandle, volume: Float): Bool { return RLNativeImpl.musicSetVolume(music, volume); }
  public static function musicIsPlaying(music: RLHandle): Bool { return RLNativeImpl.musicIsPlaying(music); }
  public static function musicUpdate(music: RLHandle): Bool { return RLNativeImpl.musicUpdate(music); }
  public static function musicUpdateAll(): Void { RLNativeImpl.musicUpdateAll(); }
  public static function soundCreate(filename: String): RLHandle { return RLNativeImpl.soundCreate(filename); }
  public static function soundDestroy(sound: RLHandle): Void { RLNativeImpl.soundDestroy(sound); }
  public static function soundPlay(sound: RLHandle): Bool { return RLNativeImpl.soundPlay(sound); }
  public static function soundPause(sound: RLHandle): Bool { return RLNativeImpl.soundPause(sound); }
  public static function soundResume(sound: RLHandle): Bool { return RLNativeImpl.soundResume(sound); }
  public static function soundStop(sound: RLHandle): Bool { return RLNativeImpl.soundStop(sound); }
  public static function soundSetVolume(sound: RLHandle, volume: Float): Bool { return RLNativeImpl.soundSetVolume(sound, volume); }
  public static function soundSetPitch(sound: RLHandle, pitch: Float): Bool { return RLNativeImpl.soundSetPitch(sound, pitch); }
  public static function soundSetPan(sound: RLHandle, pan: Float): Bool { return RLNativeImpl.soundSetPan(sound, pan); }
  public static function soundIsPlaying(sound: RLHandle): Bool { return RLNativeImpl.soundIsPlaying(sound); }
  public static function enableLighting(): Void { RLNativeImpl.enableLighting(); }
  public static function disableLighting(): Void { RLNativeImpl.disableLighting(); }
  public static function isLightingEnabled(): Int { return RLNativeImpl.isLightingEnabled(); }
  public static function setLightDirection(x: Float, y: Float, z: Float): Void { RLNativeImpl.setLightDirection(x, y, z); }
  public static function setLightAmbient(ambient: Float): Void { RLNativeImpl.setLightAmbient(ambient); }
  public static function renderBegin(): Void { RLNativeImpl.renderBegin(); }
  public static function renderEnd(): Void { RLNativeImpl.renderEnd(); }
  public static function renderClearBackground(color: RLHandle): Void { RLNativeImpl.renderClearBackground(color); }
  public static function renderBeginMode2D(camera: RLHandle): Void { RLNativeImpl.renderBeginMode2D(camera); }
  public static function renderEndMode2D(): Void { RLNativeImpl.renderEndMode2D(); }
  public static function renderBeginMode3D(): Void { RLNativeImpl.renderBeginMode3D(); }
  public static function renderEndMode3D(): Void { RLNativeImpl.renderEndMode3D(); }
  public static function windowSetTitle(title: String): Void { RLNativeImpl.windowSetTitle(title); }
  public static function windowSetSize(width: Int, height: Int): Void { RLNativeImpl.windowSetSize(width, height); }
  public static function windowCloseRequested(): Bool { return RLNativeImpl.windowCloseRequested(); }
  public static function windowGetScreenSize(): RLVec2 {
    var n: RLVec2Native = cast RLNativeImpl.windowGetScreenSize();
    return {x: n.x, y: n.y};
  }
  public static function windowGetMonitorCount(): Int { return RLNativeImpl.windowGetMonitorCount(); }
  public static function windowGetCurrentMonitor(): Int { return RLNativeImpl.windowGetCurrentMonitor(); }
  public static function windowSetMonitor(monitor: Int): Void { RLNativeImpl.windowSetMonitor(monitor); }
  public static function windowGetMonitorWidth(monitor: Int): Int { return RLNativeImpl.windowGetMonitorWidth(monitor); }
  public static function windowGetMonitorHeight(monitor: Int): Int { return RLNativeImpl.windowGetMonitorHeight(monitor); }
  public static function windowGetMonitorPosition(monitor: Int): RLVec2 {
    var n: RLVec2Native = cast RLNativeImpl.windowGetMonitorPosition(monitor);
    return {x: n.x, y: n.y};
  }
  public static function windowGetPosition(): RLVec2 {
    var n: RLVec2Native = cast RLNativeImpl.windowGetPosition();
    return {x: n.x, y: n.y};
  }
  public static function windowSetPosition(x: Int, y: Int): Void { RLNativeImpl.windowSetPosition(x, y); }
  public static function camera3dCreate(positionX: Float, positionY: Float, positionZ: Float, targetX: Float, targetY: Float, targetZ: Float, upX: Float, upY: Float, upZ: Float, fovy: Float, projection: Int): RLHandle { return RLNativeImpl.camera3dCreate(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection); }
  public static function camera3dSet(camera: RLHandle, positionX: Float, positionY: Float, positionZ: Float, targetX: Float, targetY: Float, targetZ: Float, upX: Float, upY: Float, upZ: Float, fovy: Float, projection: Int): Bool { return RLNativeImpl.camera3dSet(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection); }
  public static function camera3dSetActive(camera: RLHandle): Bool { return RLNativeImpl.camera3dSetActive(camera); }
  public static function camera3dDestroy(camera: RLHandle): Void { RLNativeImpl.camera3dDestroy(camera); }
  public static function modelCreate(filename: String): RLHandle { return RLNativeImpl.modelCreate(filename); }
  public static function modelSetTransform(model: RLHandle, positionX: Float, positionY: Float, positionZ: Float, rotationX: Float, rotationY: Float, rotationZ: Float, scaleX: Float, scaleY: Float, scaleZ: Float): Bool { return RLNativeImpl.modelSetTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ); }
  public static function modelDraw(model: RLHandle, tint: RLHandle): Void { RLNativeImpl.modelDraw(model, tint); }
  public static function modelSetAnimation(model: RLHandle, animationIndex: Int): Bool { return RLNativeImpl.modelSetAnimation(model, animationIndex); }
  public static function modelSetAnimationSpeed(model: RLHandle, speed: Float): Bool { return RLNativeImpl.modelSetAnimationSpeed(model, speed); }
  public static function modelSetAnimationLoop(model: RLHandle, shouldLoop: Bool): Bool { return RLNativeImpl.modelSetAnimationLoop(model, shouldLoop); }
  public static function modelAnimate(model: RLHandle, deltaSeconds: Float): Bool { return RLNativeImpl.modelAnimate(model, deltaSeconds); }
  public static function modelDestroy(model: RLHandle): Void { RLNativeImpl.modelDestroy(model); }
  public static function sprite3dCreate(filename: String): RLHandle { return RLNativeImpl.sprite3dCreate(filename); }
  public static function sprite3dSetTransform(sprite: RLHandle, positionX: Float, positionY: Float, positionZ: Float, size: Float): Bool { return RLNativeImpl.sprite3dSetTransform(sprite, positionX, positionY, positionZ, size); }
  public static function sprite3dDraw(sprite: RLHandle, tint: RLHandle): Void { RLNativeImpl.sprite3dDraw(sprite, tint); }
  public static function sprite3dDestroy(sprite: RLHandle): Void { RLNativeImpl.sprite3dDestroy(sprite); }
  public static function sprite2dCreate(filename: String): RLHandle { return RLNativeImpl.sprite2dCreate(filename); }
  public static function sprite2dCreateFromTexture(texture: RLHandle): RLHandle { return RLNativeImpl.sprite2dCreateFromTexture(texture); }
  public static function sprite2dSetTransform(sprite: RLHandle, x: Float, y: Float, scale: Float, rotation: Float): Bool { return RLNativeImpl.sprite2dSetTransform(sprite, x, y, scale, rotation); }
  public static function sprite2dDraw(sprite: RLHandle, tint: RLHandle): Void { RLNativeImpl.sprite2dDraw(sprite, tint); }
  public static function sprite2dDestroy(sprite: RLHandle): Void { RLNativeImpl.sprite2dDestroy(sprite); }
  public static function textureCreate(filename: String): RLHandle { return RLNativeImpl.textureCreate(filename); }
  public static function textureDestroy(texture: RLHandle): Void { RLNativeImpl.textureDestroy(texture); }
  public static function textureDrawEx(texture: RLHandle, x: Float, y: Float, scale: Float, rotation: Float, tint: RLHandle): Void { RLNativeImpl.textureDrawEx(texture, x, y, scale, rotation, tint); }
  public static function textureDrawGround(texture: RLHandle, positionX: Float, positionY: Float, positionZ: Float, width: Float, length: Float, tint: RLHandle): Void { RLNativeImpl.textureDrawGround(texture, positionX, positionY, positionZ, width, length, tint); }
  public static function inputPollEvents(): Void { RLNativeImpl.inputPollEvents(); }
  public static function inputGetMousePosition(): RLVec2 {
    var n: RLVec2Native = cast RLNativeImpl.inputGetMousePosition();
    return {x: n.x, y: n.y};
  }
  public static function inputGetMouseWheel(): Int { return RLNativeImpl.inputGetMouseWheel(); }
  public static function inputGetMouseButton(button: Int): Int { return RLNativeImpl.inputGetMouseButton(button); }
  public static function inputGetMouseState(): RLMouseState {
    var n: RLMouseStateNative = cast RLNativeImpl.inputGetMouseState();
    return {x: n.x, y: n.y, wheel: n.wheel, left: n.left, right: n.right, middle: n.middle};
  }
  public static function inputGetKeyboardState(): RLKeyboardState {
    return RLKeyboardBridge.getState();
  }

  public static function pickModel(camera: RLHandle, model: RLHandle, mouseX: Float, mouseY: Float): RLPickResult {
    var n: RLPickResultNative = cast RLNativeImpl.pickModel(camera, model, mouseX, mouseY);
    return {hit: n.hit, distance: n.distance, point: {x: n.point.x, y: n.point.y, z: n.point.z}, normal: {x: n.normal.x, y: n.normal.y, z: n.normal.z}};
  }

  public static function pickSprite3d(camera: RLHandle, sprite3d: RLHandle, mouseX: Float, mouseY: Float): RLPickResult {
    var n: RLPickResultNative = cast RLNativeImpl.pickSprite3d(camera, sprite3d, mouseX, mouseY);
    return {hit: n.hit, distance: n.distance, point: {x: n.point.x, y: n.point.y, z: n.point.z}, normal: {x: n.normal.x, y: n.normal.y, z: n.normal.z}};
  }

  public static function pickResetStats(): Void { RLNativeImpl.pickResetStats(); }
  public static function pickGetBroadphaseTests(): Int { return RLNativeImpl.pickGetBroadphaseTests(); }
  public static function pickGetBroadphaseRejects(): Int { return RLNativeImpl.pickGetBroadphaseRejects(); }
  public static function pickGetNarrowphaseTests(): Int { return RLNativeImpl.pickGetNarrowphaseTests(); }
  public static function pickGetNarrowphaseHits(): Int { return RLNativeImpl.pickGetNarrowphaseHits(); }

  public static function keyboardGetKeyState(state: RLKeyboardState, key: Int): Int {
    if (state.keys == null || key < 0 || key >= state.max_num_keys || key >= state.keys.length) {
      return 0;
    }
    return state.keys[key];
  }

  public static function keyboardIsKeyDown(state: RLKeyboardState, key: Int): Bool {
    return keyboardGetKeyState(state, key) != 0;
  }

  public static function keyboardGetPressedKey(state: RLKeyboardState, index: Int): Int {
    if (state.pressed_keys == null || index < 0 || index >= state.num_pressed_keys || index >= state.pressed_keys.length) {
      return 0;
    }
    return state.pressed_keys[index];
  }

  public static function keyboardGetPressedChar(state: RLKeyboardState, index: Int): Int {
    if (state.pressed_chars == null || index < 0 || index >= state.num_pressed_chars || index >= state.pressed_chars.length) {
      return 0;
    }
    return state.pressed_chars[index];
  }

  public static function keyboardGetPressedKeys(state: RLKeyboardState): Array<Int> {
    var result = new Array<Int>();
    for (i in 0...state.num_pressed_keys) {
      result.push(keyboardGetPressedKey(state, i));
    }
    return result;
  }

  public static function keyboardGetPressedChars(state: RLKeyboardState): Array<Int> {
    var result = new Array<Int>();
    for (i in 0...state.num_pressed_chars) {
      result.push(keyboardGetPressedChar(state, i));
    }
    return result;
  }

  public static function init(?config: RLInitConfig): Int {
    if (config == null) {
      return RLNativeImpl.initOrNullConfigNative();
    }
    var w: Int = config.windowWidth != null ? config.windowWidth : 0;
    var h: Int = config.windowHeight != null ? config.windowHeight : 0;
    var title: String = config.windowTitle != null ? config.windowTitle : "";
    var flags: Int = config.windowFlags != null ? config.windowFlags : 0;
    var asset: String = config.assetHost != null ? config.assetHost : "";
    var cache: String = config.loaderCacheDir != null ? config.loaderCacheDir : "";
    return RLNativeImpl.initConfigNative(w, h, title, flags, asset, cache);
  }

  public static function initAsync(?config: RLInitConfig): Int {
    if (config == null) {
      return RLNativeImpl.initAsyncOrNullConfigNative();
    }
    var w: Int = config.windowWidth != null ? config.windowWidth : 0;
    var h: Int = config.windowHeight != null ? config.windowHeight : 0;
    var title: String = config.windowTitle != null ? config.windowTitle : "";
    var flags: Int = config.windowFlags != null ? config.windowFlags : 0;
    var asset: String = config.assetHost != null ? config.assetHost : "";
    var cache: String = config.loaderCacheDir != null ? config.loaderCacheDir : "";
    return RLNativeImpl.initAsyncConfigNative(w, h, title, flags, asset, cache);
  }

  public static function initValues(
    width: Int, height: Int, title: String,
    flags: Int = 0, assetHost: String = "", loaderCacheDir: String = ""
  ): Int {
    return RLNativeImpl.initConfigNative(width, height, title, flags, assetHost, loaderCacheDir);
  }

  public static function isInitialized(): Bool {
    return RLNativeImpl.isInitializedNative();
  }

  public static function getPlatform(): String {
    return RLNativeImpl.getPlatformNative();
  }

  public static function loaderRestoreFsAsync(): RLLoaderTaskPtrImpl {
    return RLLoader.loaderRestoreFsAsync();
  }

  public static function loaderInit(?mountPoint: String): Int {
    return RLLoader.loaderInit(mountPoint);
  }

  public static function loaderInitAsync(?mountPoint: String): Int {
    return RLLoader.loaderInitAsync(mountPoint);
  }

  public static function loaderDeinit(): Void {
    RLLoader.loaderDeinit();
  }

  public static function loaderIsInitialized(): Bool {
    return RLLoader.loaderIsInitialized();
  }

  public static function loaderImportAssetAsync(filename: String): RLLoaderTaskPtrImpl {
    return RLLoader.loaderImportAssetAsync(filename);
  }

  public static function loaderImportAssetSync(filename: String): Int {
    return RLLoader.loaderImportAssetSync(filename);
  }

  public static function loaderImportAssetsAsync(filenames: Array<String>): RLLoaderTaskPtrImpl {
    return RLLoader.loaderImportAssetsAsync(filenames);
  }

  public static function loaderPollTask(task: RLLoaderTaskPtrImpl): Bool {
    return RLLoader.loaderPollTask(task);
  }

  public static function loaderFinishTask(task: RLLoaderTaskPtrImpl): Int {
    return RLLoader.loaderFinishTask(task);
  }

  public static function loaderCreateTaskGroup<T>(?onComplete:RLTaskGroupCallback<T>, ?onError:RLTaskGroupCallback<T>, ?ctx:T): RLTaskGroup {
    return new RLTaskGroup(cast onComplete, cast onError, ctx);
  }

  public static function loaderTaskInvalid(): RLLoaderTaskPtrImpl {
    return RLLoaderTaskPtrImpl.invalid();
  }

  public static function loaderTaskIsValid(task: RLLoaderTaskPtrImpl): Bool {
    return task.isValid();
  }

  public static function loaderGetTaskPath(task: RLLoaderTaskPtrImpl): String {
    return RLLoader.loaderGetTaskPath(task);
  }

  public static function loaderReadLocal(filename: String): haxe.io.Bytes {
    return RLLoader.loaderReadLocal(filename);
  }

  public static function loaderFreeTask(task: RLLoaderTaskPtrImpl): Void {
    RLLoader.loaderFreeTask(task);
  }

  public static function loaderIsAssetCached(filename: String): Bool {
    return RLLoader.loaderIsAssetCached(filename);
  }

  public static function loaderPingAssetHost(?assetHost: String): Float {
    return RLLoader.loaderPingAssetHost(assetHost);
  }

  public static function loaderGetCacheDir(): String {
    return RLLoader.loaderGetCacheDir();
  }

  static function loaderAddTaskNative(task: RLLoaderTaskPtrImpl,
    onSuccess: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    onFailure: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void>,
    userData: cpp.RawPointer<cpp.Void>): Int {
    return RLLoader.loaderAddTask(task, onSuccess, onFailure, userData);
  }

  public static function loaderTick(): Void {
    RLLoader.loaderTick();
  }

  public static function loaderClearCache(): Int {
    return RLLoader.loaderClearCache();
  }

  public static function loaderUncacheAsset(filename: String): Int {
    return RLLoader.loaderUncacheAsset(filename);
  }

  public static function loaderAddTask<T>(task: RLLoaderTaskPtrImpl,
    onSuccess: String->T->Void, onFailure: String->T->Void, ctx: T): Int {
    var successSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridgeImpl.onLoaderSuccessSpringboard);
    var failureSpringboard: cpp.Callable<cpp.ConstCharStar->cpp.RawPointer<cpp.Void>->Void> =
      cpp.Function.fromStaticFunction(RLBridgeImpl.onLoaderFailureSpringboard);
    var path = loaderGetTaskPath(task);
    var callbackKey = RLBridgeImpl.makeLoaderCallbackKey(path);
    var callbackInvoked = false;
    var callbackUserData = RLLoaderCallbackBridge.alloc(callbackKey);
    if (callbackUserData == null) {
      if (onFailure != null) {
        onFailure(path, ctx);
      }
      return RLNativeImpl.LOADER_QUEUE_TASK_ERR_INVALID;
    }
    RLBridgeImpl.loaderCallbacks.set(callbackKey, {
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
    var rc = loaderAddTaskNative(task, successSpringboard, failureSpringboard, callbackUserData);
    if (rc != RLNativeImpl.LOADER_QUEUE_TASK_OK && !callbackInvoked) {
      RLBridgeImpl.loaderCallbacks.remove(callbackKey);
      RLLoaderCallbackBridge.free(callbackUserData);
    }
    return rc;
  }

  public static function loggerMessage(level: Int, message: String): Void {
    RLLoggerBridge.message(level, message == null ? "" : message);
  }

  public static function loggerMessageSource(level: Int, sourceFile: String, sourceLine: Int, message: String): Void {
    RLLoggerBridge.messageSource(
      level,
      sourceFile == null ? "" : sourceFile,
      sourceLine,
      message == null ? "" : message
    );
  }

  public static function loggerSetLevel(level: Int): Void {
    RLLoggerBridge.setLevel(level);
  }

  public static function logTrace(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_TRACE, message);
  }

  public static function logDebug(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_DEBUG, message);
  }

  public static function logInfo(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_INFO, message);
  }

  public static function logWarn(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_WARN, message);
  }

  public static function logError(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_ERROR, message);
  }

  public static function logFatal(message: String): Void {
    loggerMessage(RLNativeImpl.LOGGER_LEVEL_FATAL, message);
  }
}
#end
