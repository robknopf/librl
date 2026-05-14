import rl.RL;

#if (emscripten || PLATFORM_WEB || js)
final ASSET_HOST:String = "./";
#else
final ASSET_HOST:String = "https://localhost:4444";
#end

/*
	class Main {
	  static function main(): Void {
	#if js
	RL.boot().then(function(code) {
	  run(code);
	  if (code != RL.INIT_OK) {
		return null;
	  }
	  return RL.loaderInit().then(function(loaderCode) {
		trace("loader_init=" + loaderCode);
		trace("loader_initialized=" + RL.loaderIsInitialized());
		return RL.loaderDeinit();
	  });
	});
	#else
	run(RL.boot());
	#end
	  }

	  static function run(bootCode: Int): Void {
	trace("librl haxe-js backend");
	trace("boot=" + bootCode);
	trace("platform=" + RL.getPlatform());
	trace("tick_running=" + RL.TICK_RUNNING);
	trace("init_ok=" + RL.INIT_OK);
	  }
	}
 */
class SimpleRuntime implements IRuntime {
	final SCREEN_WIDTH:Int = 1024;
	final SCREEN_HEIGHT:Int = 1280;
	final SCREEN_TITLE:String = "nimrltest (Haxe runtime)";
	final SCREEN_FLAGS:Int = RL.FLAG_MSAA_4X_HINT;

	public function new() {
		trace("SimpleRuntime::new");
	}

	@async public function onBoot() {
		trace("onBoot");
		@await RL.boot({canvasId:"renderCanvas"});
		@await RL.loaderInit();
		return RT_SUCCESS;
	}

	@async public function onInit():Int {
		trace("onInit");
		var rc = @await RL.init({
			windowWidth: SCREEN_WIDTH,
			windowHeight: SCREEN_HEIGHT,
			windowTitle: SCREEN_TITLE,
			windowFlags: SCREEN_FLAGS,
		});
		trace("onInit: rc=" + rc);
		if (rc != 0) {
			return RT_FAILED;
		}

		RL.loaderClearCache();
		RL.setTargetFps(60);
		//setupScene();
		//createLoadingGroup();
		var bgColor = RL.colorCreate(245, 245, 245, 255);
		RL.renderBegin();
		RL.renderClearBackground(bgColor);
		RL.renderEnd();
		RL.colorDestroy(bgColor);

		return RT_SUCCESS;
	}

	public function onTick(deltaTime:Float):Int {
		//var bgColor = RL.colorCreate(245, 245, 245, 255);
		RL.renderBegin();
		RL.renderClearBackground(RL.COLOR_BLUE);
		RL.renderEnd();
		//RL.colorDestroy(bgColor);

		return RT_SUCCESS;
	}

	@async
	public function onShutdown():Void {
		@await RL.loaderDeinit();
		return;
	}
	/*
		  @async public function onInit():RTResult {
		var err = @await RL.init({
				windowWidth: SCREEN_WIDTH,
				windowHeight: SCREEN_HEIGHT,
				windowTitle: SCREEN_TITLE,
				windowFlags: SCREEN_FLAGS,
				//assetHost: ASSET_HOST,
				// loaderCacheDir: LOADER_CACHE_DIR
			});
			if (err != 0) {
				trace("Main: onInit failed with error: " + err);
				return RT_FAILED;
			}

			RL.loaderClearCache();

			// clear the screen
			RL.renderBegin();
			RL.renderClearBackground(RL.COLOR_RAYWHITE);
			RL.renderEnd();
		return RT_SUCCESS;
		  }

		  public function onTick(deltaTime:Float):RTResult {
		RL.renderBegin();
			RL.renderClearBackground(RL.COLOR_RAYWHITE);
			RL.renderEnd();
		return RT_SUCCESS;
		  }
		  
		  public function onShutdown():Void {
		RL.deinit();
		return;
		  }
	 */
}

///////////  Runtime ABI, called by host  ///////////

typedef Runtime = SimpleRuntime;
/*
	enum abstract RTResult(Int) from Int to Int {
	var RT_SUCCESS = 0;
	var RT_FAILED = -1;
	var RT_STOPPED = 1;
	}
 */
final RT_SUCCESS = 0;
final RT_FAILED = -1;
final RT_STOPPED = 1;

interface IRuntime {
	function onBoot():Int;
	function onInit():Int;
	function onTick(deltaTimeSec:Float):Int;
	function onShutdown():Void;
}

@:expose
@async
class Main {
	private static var _instance:IRuntime = null;

	@:expose("_rt_boot")
	@:exportc.entry
	@async static function rt_boot():Int {
		if (_instance == null) {
			_instance = new Runtime();
		}
		return @await _instance.onBoot();
	}

	@:expose("_rt_init")
	@:exportc
	@async static function rt_init(_hostData:Dynamic):Int {
		if (_instance != null) {
			return @await _instance.onInit();
		}
		return RT_FAILED;
	}

	@:expose("_rt_tick")
	@:exportc
	static function rt_tick(dt:Float):Int {
		try {
			var rc = RL.tick();
			if (rc == RL.TICK_FAILED) {
				trace("Main: RL.tick failed with error: " + rc);
				return RT_FAILED;
			}
			if (rc == RL.TICK_WAITING) {
				return RT_SUCCESS;
			}
			if (RL.windowCloseRequested()) {
				return RT_STOPPED;
			}
			if (_instance != null) {
				return _instance.onTick(dt);
			}
			return RT_SUCCESS;
		} catch (e:Dynamic) {
			trace("Main: rt_tick failed with error: " + e);
			return RT_FAILED;
		}
	}

	@:expose("_rt_shutdown")
	@:exportc.exit
	@async static function rt_shutdown():Void {
		if (_instance != null) {
			_instance.onShutdown();
			_instance = null;
		}

		return;
	}

	public static function main() {
		if (_instance == null) {
			_instance = new Runtime();
		}

		// fake a host
		// @await startLocalHost();
		return;
	}

	@async static function startLocalHost() {
		// fake a local host
		var rc = @await rt_boot();
		if (rc != RT_SUCCESS) {
			trace("Main: rt_boot failed with error: " + rc);
			return rc;
		}

		rc = @await rt_init(null);
		if (rc != RT_SUCCESS) {
			trace("Main: rt_init failed with error: " + rc);
			return rc;
		}

		final targetFrameRate = 60;
		final frameDelayMs = Std.int(1000 / targetFrameRate);
		var frameTimer = new haxe.Timer(frameDelayMs);
		var lastFrameTime = haxe.Timer.stamp();
		frameTimer.run = () -> {
			var now = haxe.Timer.stamp();
			var dt = now - lastFrameTime;
			lastFrameTime = now;
			var rc = rt_tick(dt);
			if (rc > RT_SUCCESS) {
				trace("Main: rt_tick returned RT_STOPPED");
				frameTimer.stop();
				rt_shutdown();
			}
			if (rc < RT_SUCCESS) {
				trace("Main: rt_tick failed with error: " + rc);
				frameTimer.stop();
				rt_shutdown();
			}
		}
		return RT_SUCCESS;
	}
}
