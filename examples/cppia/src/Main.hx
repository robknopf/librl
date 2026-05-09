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
	static inline final RESULT_OK:Int = 0;
	static inline final RESULT_ERROR:Int = -1;
	static inline final RESULT_QUIT:Int = 1;

	static var lastTime:Float = 0.0;
	static var cppiaPath = "assets/scripts/haxe/Test.cppia";
	static var ctx:AppContext = {};


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

	static function onInit(ctx:AppContext):Int {
		var initRc = RL.init({
			windowWidth: 800,
			windowHeight: 600,
			windowTitle: "librl cppia host (Haxe)",
			windowFlags: RL.FLAG_MSAA_4X_HINT,
			assetHost: ASSET_HOST,
		});
		if (initRc != 0) {
			trace("RL.init failed: " + initRc);
			return RESULT_ERROR;
		}

		//RL.loaderClearCache();

		RL.setTargetFps(60);
		lastTime = RL.getTime();

		var success = loadCppia(cppiaPath, ctx);
		if (!success) {
			return RESULT_ERROR;
		}

		if (CppiaBridge.onInit != null) {
			CppiaBridge.onInit();
		} else {
			trace("No onInit callback");
		}
		return RESULT_OK;
	}

	static function onTick(ctx:AppContext, hostDt:Float):Int {
		var currentTime = RL.getTime();
		var dt = hostDt > 0 ? hostDt : currentTime - lastTime;
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
		return RESULT_OK;
	}

	static function onShutdown(ctx:AppContext):Void {
		if (CppiaBridge.onShutdown != null) {
			CppiaBridge.onShutdown();
		} else {
			trace("No onShutdown callback");
		}
		RL.deinit();
	}

	public static function rt_boot():Int {
		ctx = {};
		return RESULT_OK;
	}

	public static function rt_init(_hostData:Dynamic):Int {
		return onInit(ctx);
	}

	public static function rt_tick(hostDt:Float):Int {
		var tickRc = RL.tick();
		if (tickRc == RL.TICK_FAILED) {
			return RESULT_ERROR;
		}
		if (tickRc == RL.TICK_WAITING) {
			return RESULT_OK;
		}
		if (RL.windowCloseRequested()) {
			return RESULT_QUIT;
		}
		return onTick(ctx, hostDt);
	}

	public static function rt_shutdown():Void {
		onShutdown(ctx);
		ctx = {};
	}

	static function main():Void {
		if (rt_boot() != RESULT_OK) {
			Sys.exit(RESULT_ERROR);
		}
		if (rt_init(null) != RESULT_OK) {
			rt_shutdown();
			Sys.exit(RESULT_ERROR);
		}

		var lastFrameTime = haxe.Timer.stamp();
		while (true) {
			var currentTime = haxe.Timer.stamp();
			var deltaTime = currentTime - lastFrameTime;
			lastFrameTime = currentTime;
			var rc = rt_tick(deltaTime);
			if (rc != RESULT_OK) {
				rt_shutdown();
				Sys.exit(rc);
			}
			Sys.sleep(0.001);
		}
	}
}
