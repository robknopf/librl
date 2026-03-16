/**
 * Haxe extern bindings for librl (Raylib wrapper).
 * Target: hxcpp (native and emscripten).
 *
 * Build setup: add librl include path (-I path/to/librl/include) and link
 * against librl. See librl Makefile for building the library.
 */
package rl;

#if cpp
@:include("rl.h")
#end
extern class RL {
  // --- Types (rl_handle_t = unsigned int) ---
  // RLHandle is passed as Int in Haxe; use Int for handle values

  // --- Window flags (rl_window.h) ---
  static inline var FLAG_WINDOW_RESIZABLE: Int = 0x00000004;
  static inline var FLAG_MSAA_4X_HINT: Int = 0x00000020;
  static inline var FLAG_VSYNC_HINT: Int = 0x00000040;

  // --- Core lifecycle ---
  @:native("rl_init")
  static function init(): Void;

  @:native("rl_deinit")
  static function deinit(): Void;

  @:native("rl_update")
  static function update(): Void;

  @:native("rl_update_to_scratch")
  static function updateToScratch(): Void;

  // --- Run loop (init_fn, tick_fn, shutdown_fn, user_data).
  //     Pass cpp.Pointer<cpp.Void>.fromRaw(0) for null callbacks/userData.
  //     Use cpp.Function.fromStaticFunction() to create callbacks from Haxe. ---
  @:native("rl_run")
  static function run(
    initFn: cpp.Pointer<cpp.Void>,
    tickFn: cpp.Pointer<cpp.Void>,
    shutdownFn: cpp.Pointer<cpp.Void>,
    userData: cpp.Pointer<cpp.Void>
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

  // --- Asset host ---
  @:native("rl_set_asset_host")
  static function setAssetHost(assetHost: String): Int;

  @:native("rl_get_asset_host")
  static function getAssetHost(): String;

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
}

#if cpp
@:include("rl_types.h")
@:native("vec2_t")
@:structAccess
extern class RLVec2 {
  var x: Float;
  var y: Float;
}
#else
typedef RLVec2 = {
  var x: Float;
  var y: Float;
}
#end
