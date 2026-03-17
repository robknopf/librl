package;

import InjectLibRL;

import rl.RL;
import cpp.cppia.Host;
import sys.io.File;
import haxe.io.Bytes;
import haxe.io.Path;

@:cppInclude("rl.h")
@:cppInclude("rl_loader.h")
class Main {
  static var lastTime: Float = 0.0;
  static inline var cppiaPath = "assets/scripts/haxe/Test.cppia";
  static var cppiaReady: Bool = false;
  static var cppiaFailed: Bool = false;
  static var cppiaStarted: Bool = false;

  static function loadCppia(): Void {
    try {
      var cachedPath = Path.join(["cache", cppiaPath]);
      var bytes: Bytes = File.getBytes(cachedPath);
      Host.run(bytes);
    } catch (e: Dynamic) {
      trace('Failed to load cppia script from $cppiaPath (cache path=${Path.join(["cache", cppiaPath])}): $e');
      cppiaFailed = true;
    }
  }

  @:keep static function onCppiaReady(path: Dynamic, userData: Dynamic): Void {
    trace("cppia asset ready");
    cppiaReady = true;
  }

  @:keep static function onCppiaFailed(path: Dynamic, userData: Dynamic): Void {
    trace("cppia asset failed");
    cppiaFailed = true;
  }

  @:functionCode("
    const char *path = \"assets/scripts/haxe/Test.cppia\";
    rl_loader_task_t *task = rl_loader_import_asset_async(path);
    rl_loader_add_task(task, path,
      (rl_loader_callback_fn)Main_obj::onCppiaReady,
      (rl_loader_callback_fn)Main_obj::onCppiaFailed,
      NULL);
  ")
  static function queueCppia(): Void {}

  @:keep static function onInit(userData: cpp.RawPointer<cpp.Void>): Void {
    RL.loaderClearCache();
    
    RL.windowOpen(800, 600, "librl cppia host (Haxe)", RL.FLAG_MSAA_4X_HINT);
    RL.setTargetFps(60);
    lastTime = RL.getTime();

    queueCppia();

    if (CppiaBridge.onInit != null) {
      CppiaBridge.onInit();
    } else {
      trace("No onInit callback");
    }
  }

  @:keep static function onTick(userData: cpp.RawPointer<cpp.Void>): Void {
    var currentTime = RL.getTime();
    var dt = currentTime - lastTime;
    lastTime = currentTime;

    if (!cppiaStarted && cppiaReady && !cppiaFailed) {
      cppiaStarted = true;
      loadCppia();
    }

    if (CppiaBridge.onTick != null) {
      CppiaBridge.onTick(dt);
    } else {
      trace("No onTick callback");
    }

    RL.renderBegin();
    var bg = RL.colorCreate(40, 40, 40, 255);
    RL.renderClearBackground(bg);
    RL.renderEnd();
    RL.colorDestroy(bg);
  }

  @:keep static function onShutdown(userData: cpp.RawPointer<cpp.Void>): Void {
    if (CppiaBridge.onShutdown != null) {
      CppiaBridge.onShutdown();
    } else {
      trace("No onShutdown callback");
    }
    RL.deinit();
    RL.windowClose();
  }

  @:functionCode("
    rl_init();
    rl_set_asset_host(\"https://localhost:4444\");
    rl_run(
      (rl_init_fn)Main_obj::onInit,
      (rl_tick_fn)Main_obj::onTick,
      (rl_shutdown_fn)Main_obj::onShutdown,
      NULL);
  ")
  static function main(): Void {}
}

