package;

import rl.RL;
import rl.*;
import rl.helpers.Log;
import rl.Types.RLAsyncVoid;
/*
import rl.Window;
import rl.Camera3d;
import rl.Color;
import rl.Render;
import rl.Asset;
import rl.Fs;
import rl.Logger;
import rl.Text2d;
import rl.Font;
import rl.Model;
import rl.Sprite3d;
import rl.Music;
import rl.Text;
import rl.Input;
import rl.Pick;
import rl.Types.RLHandle;
import rl.Types.RLAsyncVoid;
import rl.helpers.Log;
*/
import InjectWasmExports;	
import Types.RTResult;
import Script;
import utils.*;
import ScriptWatcherClient;

/**
 * Scriptable host: loads {@link #MAIN_CPPIA_FILE}, forwards {@link IRuntime} to the cppia
 * `${MAIN_SCRIPT_CLASS_NAME}` class. With {@code ENABLE_SCRIPT_WATCHER}, connects an internal
 * script_watcher WebSocket; reload work is deferred to {@link #onTick} so async asset loads
 * run under the {@code rt_tick} JSPI export (not from the browser WS callback).
 */
class ScriptableHost {
	#if (emscripten || PLATFORM_WEB || js)
	final ASSET_HOST:String = "./";
	#else

	/** script_watcher static host; adjust for your LAN. */
	final ASSET_HOST:String = "https://192.168.1.100:9001";
	#end

	// final LOADER_CACHE_DIR:String = "/haxetest";

	/** Cppia module shipped under `public/`; server file watcher sends reload for this path. */
	static inline final MAIN_CPPIA_FILE:String = "assets/scripts/cppia/MainScript.cppia";

	static inline final MAIN_SCRIPT_CLASS_NAME:String = "scripts.MainScript";

	var scriptOnInit:InitCallback = null;
	var scriptOnTick:TickCallback = null;
	var scriptOnShutdown:ShutdownCallback = null;
	var scriptOnUnload:UnloadCallback = null;
	var scriptOnLoad:LoadCallback = null;

	/**
	 * Desktop script watcher (Bun {@code script_watcher}). Leave empty to disable.
	 * {@link ws.WebSocket#poll} is required every frame while enabled.
	 */
	static inline final SCRIPT_WATCHER_URL:String = "wss://192.168.1.100:9001/ws";

	var scriptWatcherClient:Null<ScriptWatcherClient> = null;

	/** Set from script_watcher {@code file_changed}; handled on next {@link #onTick} (JSPI-safe). */
	var pendingScriptReload:Bool = false;

	/** Resolved cppia `Main` instance; receives {@link #onTick} / {@link #onShutdown}. */
	public var scriptInstance:Script = null;

	public function new() {}

	/**
	 * Load cppia bytes into a script instance.
	 * @param bytes The cppia bytes to load.
	 * @return true on success, false on failure.
	 */
	public function createMainScriptFromBytes(bytes:haxe.io.Bytes):Bool {
		Log.info('[script] loading cppia from bytes (${bytes.length} bytes)');
		try {
			if (bytes == null) {
				Log.error("[script] cppia bytes null");
				return false;
			}

			var cppiaModule = cpp.cppia.Module.fromData(bytes.getData());
			if (cppiaModule == null) {
				Log.error("[script] Module.fromData failed");
				return false;
			}

			cppiaModule.boot();

			var mainClass = cppiaModule.resolveClass(MAIN_SCRIPT_CLASS_NAME);
			if (mainClass == null) {
				Log.error('[script] cppia has no class ${MAIN_SCRIPT_CLASS_NAME}');
				return false;
			}

			// create the new script instance and wire up callbacks
			scriptInstance = Type.createInstance(mainClass, []);
			scriptOnInit = Reflect.field(scriptInstance, "onInit");
			scriptOnTick = Reflect.field(scriptInstance, "onTick");
			scriptOnShutdown = Reflect.field(scriptInstance, "onShutdown");
			scriptOnUnload = Reflect.field(scriptInstance, "onUnload");
			scriptOnLoad = Reflect.field(scriptInstance, "onLoad");
			return true;
		} catch (e:Dynamic) {
			Log.error('[script] loadMainCppia failed: $e');
			return false;
		}
	}

	function destroyMainScript():Void {
		scriptInstance = null;
		scriptOnInit = null;
		scriptOnTick = null;
		scriptOnShutdown = null;
		scriptOnUnload = null;
		scriptOnLoad = null;
	}


	public function createMainScript():Void {
		var fsAlreadyInitialized = Fs.isInitialized();

		// if fs was not already initialized, initialize it
		if (!fsAlreadyInitialized) {
			var initRc = Fs.init();
			if (initRc != 0) {
				Log.error('[reload] loader init failed ($initRc), fs failed to initialize');
				return;
			}
		}

		// remove the old cppia file
		Fs.remove(MAIN_CPPIA_FILE);

		/*
		// begin async version
		Asset.addTask(Asset.ensureAsync(assetPath), (localPath, _) -> {
			var bytes = Fs.read(localPath);
			if (!fsAlreadyInitialized)
				Fs.deinit();
			if (bytes == null) {
				Log.error('[reload] failed to read $localPath');
				return;
			}
			loadMainCppia(bytes);
		}, (localPath, _) -> {
			if (!fsAlreadyInitialized)
				Fs.deinit();
			Log.error('[reload] failed to fetch $localPath');
		}, null);
		// end of async version
		*/

		// begin sync version
		// synchronously ensure the new cppia file
		var impRc = Asset.ensure(MAIN_CPPIA_FILE);
		if (impRc != 0) {
			Log.error('[reload] sync import failed for $MAIN_CPPIA_FILE (code $impRc)');
			if (!fsAlreadyInitialized)
				Fs.deinit();
			return;
		}
		// read the new cppia file
		var bytes = Fs.read(MAIN_CPPIA_FILE);
		// if we were the ones that initialized fs, deinit it
		if (!fsAlreadyInitialized)
			Fs.deinit();
		if (bytes == null) {
			Log.error('[reload] failed to read $MAIN_CPPIA_FILE');
			return;
		}

		createMainScriptFromBytes(bytes);

		// end of sync version
	}

	public function reloadMainScript():Void {
		var ctx = onUnload();
		createMainScript();
		onLoad(ctx);
	}

	public function onBoot():RTResult {
		// trace("ScriptableMain: onBoot (host)");
		trace("Using script: " + PathUtil.joinPath("./", MAIN_CPPIA_FILE));
		trace("Edit " + PathUtil.joinPath("./", PathUtil.withoutExtension(MAIN_CPPIA_FILE)) + ".hx to change the script");

		var rc = RL.boot();
		if (rc != RL.BOOT_OK) {
			Log.error('[script] RL.boot failed (code $rc)');
			return RT_FAILED;
		}

		// start the loader so we can cache the main script
		/*
		var fsAlreadyInitialized = Fs.isInitialized();
		if (!fsAlreadyInitialized) {
			var initRc = Fs.init();
			if (initRc != 0) {
				Log.error('[reload] loader init failed ($initRc), fs failed to initialize');
				return RT_FAILED;
			}
		}
		*/

		rc = Asset.setHost(ASSET_HOST);
		if (rc != RL.INIT_OK) {
			Log.error("[script] Loader set asset host failed (code $rc)");
			return RT_FAILED;
		}

		// Ping the asset host to see if it's reachable
		#if !(emscripten || PLATFORM_WEB)
		trace('ScriptableMain: onBoot: pinging asset host $ASSET_HOST');
		var rtt = Asset.pingHost(ASSET_HOST);
		if (rtt < 0) {
			Log.error("[script] Asset host not reachable");
			return RT_FAILED;
		}
		#end

		/*
		Fs.remove(MAIN_CPPIA_FILE);

		// synchronously ensure the main cppia file
		var impRc = Asset.ensure(MAIN_CPPIA_FILE);
		if (impRc != 0) {
			Log.error('[reload] sync import failed for $MAIN_CPPIA_FILE (code $impRc)');
			if (!fsAlreadyInitialized)
				Fs.deinit();
			return RT_FAILED;
		}

		// now that we have the main script, we can create our script main instance
		var cppiaBytes = Fs.read(MAIN_CPPIA_FILE);
		if (cppiaBytes == null) {
			Log.error("[script] Main.cppia bytes empty after sync import");
			if (!fsAlreadyInitialized)
				Fs.deinit();
			return RT_FAILED;
		}
		loadMainCppia(cppiaBytes);
		if (scriptInstance == null) {
			Log.error("[script] Main.cppia failed to load");
			if (!fsAlreadyInitialized)
				Fs.deinit();
			return RT_FAILED;
		}
		*/
		createMainScript();
		if (scriptInstance == null) {
			Log.error("[script] Main.cppia failed to load");
			return RT_FAILED;
		}
		/*
		// loader was only needed to bootstrap the cppia; Main.hx owns its own loader lifecycle
		if (!fsAlreadyInitialized)
			Fs.deinit();
		*/
		#if ENABLE_SCRIPT_WATCHER
		scriptWatcherClient = new ScriptWatcherClient();
		scriptWatcherClient.onFileChanged = (_assetPath: String) -> {
			pendingScriptReload = true;
		};
		scriptWatcherClient.connect(SCRIPT_WATCHER_URL);
		#end

		return RT_SUCCESS;
	}

	public function onInit():RTResult {
		trace("ScriptableMain: onInit (host)");
		if (scriptInstance != null && scriptOnInit != null) {
			var rc = scriptOnInit();
			if (rc != RT_SUCCESS) {
				Log.error("[script] Main.onInit returned non-success");
				return rc;
			}
		}

		return RT_SUCCESS;
	}

	public function onUnload():Dynamic {
		var stashedData:Dynamic = null;
		if (scriptInstance != null && scriptOnUnload != null) {
			stashedData = scriptOnUnload();
			destroyMainScript();
		}
		return stashedData;
	}

	public function onLoad(stashedData:Dynamic):RTResult {
		if (scriptOnLoad != null) {
			var rc = scriptOnLoad(stashedData);
			if (rc != RT_SUCCESS) {
				Log.error("[script] Main.onLoad returned non-success");
			}
			return rc;
		}
		return RT_SUCCESS;
	}

	public function onTick(deltaTimeSec:Float):RTResult {
		if (scriptWatcherClient != null) {
			scriptWatcherClient.tick();
		}

		// handle the deferred script reload
		if (pendingScriptReload) {
			pendingScriptReload = false;
			reloadMainScript();
			return RT_SUCCESS;
		}

		if (scriptInstance != null && scriptOnTick != null) {
			var rc = scriptOnTick(deltaTimeSec);
			if (rc != RT_SUCCESS) {
				Log.error("[script] Main.onTick returned non-success");
			}
			return rc;
		}
		return RT_SUCCESS;
	}

	public function onShutdown():Void {
		trace("ScriptableMain: onShutdown (host)");

		if (scriptInstance != null && scriptOnShutdown != null) {
			scriptOnShutdown();
		}
		
		destroyMainScript();

		if (scriptWatcherClient != null) {
			scriptWatcherClient.disconnect();
			scriptWatcherClient = null;
		}
	}
}

////////////////////////////////////////////////////////////
// Runtime ABI hooks / trampoline functions
//

class ScriptableMain {
	private static var _hostInstance:ScriptableHost = null;

	@:exportc.entry
	@async static function rt_boot():Int {
		trace("ScriptableMain: rt_boot (host)");
		if (_hostInstance == null) {
			_hostInstance = new ScriptableHost();
		}
		return @await _hostInstance.onBoot();
	}

	@:exportc
	@async static function rt_init(_hostData:cpp.RawPointer<cpp.Void>):Int {
		trace("ScriptableMain: rt_init (host)");
		if (_hostInstance != null) {
			return @await _hostInstance.onInit();
		}
		return RT_FAILED;
	}

	@:exportc
	static function rt_tick(dt:Float):Int {
		// trace("ScriptableMain: rt_tick (host)");
		var rc = RL.tick();
		if (rc == RL.TICK_FAILED)
			return RT_FAILED;
		if (rc == RL.TICK_WAITING)
			return RT_SUCCESS;
		if (Window.closeRequested())
			return RT_STOPPED;
		if (_hostInstance != null) {
			return _hostInstance.onTick(dt);
		}
		return RT_SUCCESS;
	}

	@:exportc.exit
	static function rt_shutdown():Void {
		trace("ScriptableMain: rt_shutdown (host)");
		if (_hostInstance != null) {
			_hostInstance.onShutdown();
			_hostInstance = null;
		}
	}

	@:exportc
	static function rt_load(stashedData:Dynamic):Int {
		try {
			if (_hostInstance == null) {
				_hostInstance = new ScriptableHost();
			}
			if (_hostInstance.scriptInstance == null) {
				_hostInstance.createMainScript();
			}
			return _hostInstance.onLoad(stashedData);
		} catch (e:Dynamic) {
			Log.error("ScriptableMain: rt_load failed with exception: " + e);
			return RT_FAILED;
		}
	}

	@:exportc
	static function rt_unload():Dynamic {
		trace("ScriptableMain: rt_unload (host)");
		if (_hostInstance != null) {
			return _hostInstance.onUnload();
		}
		return null;
	}

	@async
	static function main():RLAsyncVoid {
		trace("ScriptableMain: main (host)");
		if (_hostInstance == null) {
			_hostInstance = new ScriptableHost();
		}

		#if !(emscripten || PLATFORM_WEB || js)
		@await startLocalRuntimeHost();
		#end
	}

	@async static function startLocalRuntimeHost():RLAsyncVoid {
		var rc = @await rt_boot();
		if (rc != RT_SUCCESS) {
			trace("ScriptableMain: local runtime host: rt_boot failed with error: " + rc);
			return;
		}

		rc = @await rt_init(null);
		if (rc != RT_SUCCESS) {
			trace("ScriptableMain: local runtime host: rt_init failed with error: " + rc);
			return;
		}

		rc = rt_load(null);
		if (rc != RT_SUCCESS) {
			trace("ScriptableMain: local runtime host: rt_load failed with error: " + rc);
			return;
		}

		final targetFrameRate = 60;
		final frameDelayMs = Std.int(1000 / targetFrameRate);
		var frameTimer = new haxe.Timer(frameDelayMs);
		var lastFrameTime = haxe.Timer.stamp();
		frameTimer.run = () -> {
			var now = haxe.Timer.stamp();
			var dt = now - lastFrameTime;
			lastFrameTime = now;
			var tickRc = rt_tick(dt);
			if (tickRc != cast RT_SUCCESS) {
				if (tickRc > cast RT_SUCCESS)
					trace("ScriptableMain: startLocalHost: rt_tick returned RT_STOPPED");
				else
					trace("ScriptableMain: startLocalHost: rt_tick failed with error: " + tickRc);
				frameTimer.stop();
				rt_shutdown();
				Sys.exit(tickRc == RT_FAILED ? 1 : 0);
			}
		};
	}
}
