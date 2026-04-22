package;

import InjectLibRL;

import rl.RL;
import cpp.cppia.Host;
import sys.io.File;
import haxe.io.Bytes;
import haxe.io.Path;

@:cppInclude("rl.h")
@:cppInclude("rl_loader.h")

  #if PLATFORM_WEB
    static final ASSET_HOST:String = "./";
  #else
    static final ASSET_HOST:String = "https://localhost:4444";
  #end

typedef AppContext = {
  var ?someValue: String;
}

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

  static function onCppiaReady(path: String, ctx: AppContext): Void {
    trace("cppia asset ready");
    cppiaReady = true;
  }

  static function onCppiaFailed(path: String, ctx: AppContext): Void {
    trace("cppia asset failed");
    cppiaFailed = true;
  }

  static function queueCppia(ctx: AppContext): Void {
    var path = cppiaPath;
    var task = RL.loaderImportAssetAsync(path);
    RL.loaderQueueTask(task, path, onCppiaReady, onCppiaFailed, ctx);
  }

  static function onInit(ctx: AppContext): Void {
    RL.loaderClearCache();
    
    RL.windowOpen(800, 600, "librl cppia host (Haxe)", RL.FLAG_MSAA_4X_HINT);
    RL.setTargetFps(60);
    lastTime = RL.getTime();

    queueCppia(ctx);

    if (CppiaBridge.onInit != null) {
      CppiaBridge.onInit();
    } else {
      trace("No onInit callback");
    }
  }

  static function onTick(ctx: AppContext): Void {
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

  static function onShutdown(ctx: AppContext): Void {
    if (CppiaBridge.onShutdown != null) {
      CppiaBridge.onShutdown();
    } else {
      trace("No onShutdown callback");
    }
    RL.deinit();
    RL.windowClose();
  }

  static function main(): Void {
    var ctx: AppContext = {};
    RL.init();
    RL.setAssetHost(ASSET_HOST);
    RL.run(onInit, onTick, onShutdown, ctx);
  }
}
