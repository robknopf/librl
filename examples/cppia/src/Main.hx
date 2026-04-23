package;

//import InjectLibRL;
import rl.RL;
import cpp.cppia.Host;
import sys.io.File;
import haxe.io.Bytes;
import haxe.io.Path;


#if PLATFORM_WEB
final ASSET_HOST:String = "./";
#else
final ASSET_HOST:String = "https://localhost:4444";
#end

typedef AppContext = {
	var ?someValue:String;
}

class Main {
	static var lastTime:Float = 0.0;
	static var cppiaPath = "assets/scripts/haxe/Test.cppia";


	/*
  static function loadCppia():Void {
		try {
			var cachedPath = Path.join(["cache", cppiaPath]);
			var bytes:Bytes = File.getBytes(cachedPath);
			Host.run(bytes);
		} catch (e:Dynamic) {
			trace('Failed to load cppia script from $cppiaPath (cache path=${Path.join(["cache", cppiaPath])}): $e');
			cppiaFailed = true;
		}
	}
    */

	static function loadCppia(cppiaPath:String, ctx:AppContext):Bool {
    
		var task = RL.loaderImportAssetAsync(cppiaPath);
		var result = -1;
		while (RL.loaderTaskIsValid(task) && !RL.loaderPollTask(task)) {
			RL.loaderTick();
		}
		if (RL.loaderTaskIsValid(task)) {
			result = RL.loaderFinishTask(task);
			RL.loaderFreeTask(task);
		}
		if (result == 0) {
			try {
				var cachedPath = Path.join(["cache", cppiaPath]);
				var bytes:Bytes = File.getBytes(cachedPath);
				Host.run(bytes);
				return true;
			} catch (e:Dynamic) {
				trace('Failed to load cppia script from $cppiaPath (cache path=${Path.join(["cache", cppiaPath])}): $e');
				return false;
			}
		}
      
		return false;
	}

	static function onInit(ctx:AppContext):Void {
		//RL.loaderClearCache();

		RL.setTargetFps(60);
		lastTime = RL.getTime();

		var success = loadCppia(cppiaPath, ctx);

		if (CppiaBridge.onInit != null) {
			CppiaBridge.onInit();
		} else {
			trace("No onInit callback");
		}
	}

	static function onTick(ctx:AppContext):Void {
		var currentTime = RL.getTime();
		var dt = currentTime - lastTime;
		lastTime = currentTime;

		if (CppiaBridge.onTick != null) {
			CppiaBridge.onTick(dt);
		} else {
			trace("No onTick callback");
		}

		RL.renderBegin();
		//var bg = RL.colorCreate(255, 40, 255, 255);
		RL.renderClearBackground(RL.COLOR_SKYBLUE);
		RL.renderEnd();
		//RL.colorDestroy(bg);
	}

	static function onShutdown(ctx:AppContext):Void {
		if (CppiaBridge.onShutdown != null) {
			CppiaBridge.onShutdown();
		} else {
			trace("No onShutdown callback");
		}
		RL.deinit();
	}

	static function main():Void {
		var ctx:AppContext = {};
		var initRc = RL.init({
			windowWidth: 800,
			windowHeight: 600,
			windowTitle: "librl cppia host (Haxe)",
			windowFlags: RL.FLAG_MSAA_4X_HINT,
			assetHost: ASSET_HOST,
		});
		if (initRc != 0) {
			trace("RL.init failed: " + initRc);
			return;
		}
		RL.run(onInit, onTick, onShutdown, ctx);
	}
}
