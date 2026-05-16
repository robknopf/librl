package;

import rl.RL;
import rl.RLHandle;
import InjectWasmExports;
import rl.InjectLibRL;
import rl.Log;
import ws.WebSocket;
import Types.RTResult;
import Script;
import tools.PathUtil;
import haxe.io.Path;

/**
 * WASM/scriptable entry: performs {@link RL.init} once, connects script watcher WebSocket reload,
 * loads {@link #MAIN_CPPIA_FILE}, then forwards {@link IRuntime} to the cppia `MainScript` class.
 */



class ScriptableRuntime implements IRuntime {
	#if (emscripten || PLATFORM_WEB)
	final ASSET_HOST:String = "./";
	#else
	final ASSET_HOST:String = "https://192.168.1.100:4444";
	#end

	// final LOADER_CACHE_DIR:String = "/haxetest";

	/** Cppia module shipped under `public/`; server file watcher sends reload for this path. */
	static inline final MAIN_CPPIA_FILE:String = "assets/scripts/haxe/MainScript.cppia";

	var scriptOnInit:InitCallback = null;
	var scriptOnTick:TickCallback = null;
	var scriptOnShutdown:ShutdownCallback = null;
	var scriptOnUnload:UnloadCallback = null;
	var scriptOnLoad:LoadCallback = null;

	/**
	 * Script watcher helper: set to your reload/signaling server (e.g. `ws://127.0.0.1:9001/ws`).
	 * Leave empty to disable; {@link ws.WebSocket#poll} is required every frame while enabled (noop on wasm Emscripten).
	 */
	static inline final SCRIPT_WATCHER_URL:String = "ws://192.168.1.100:9001/ws";

	var scriptWatcher:Null<WebSocket> = null;

	/** Resolved cppia `Main` instance; receives {@link #onTick} / {@link #onShutdown}. */
	var scriptInstance:Script = null;

	public function new() {}

	/**
	 * Returns true if this is a reload (a previous script was live), false on first load.
	 */
	function loadMainCppia(bytes:haxe.io.Bytes):Bool {
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

			var mainClass = cppiaModule.resolveClass("MainScript");
			if (mainClass == null) {
				Log.error("[script] cppia has no class MainScript");
				return false;
			}

			var isReload = scriptInstance != null;

			// stash data from previous instance BEFORE overwriting the callbacks
			var stashedData:Dynamic = null;
			if (isReload && scriptOnUnload != null) {
				stashedData = scriptOnUnload();
			}

			// create the new script instance and wire up callbacks
			scriptInstance = Type.createInstance(mainClass, []);
			scriptOnInit = Reflect.field(scriptInstance, "onInit");
			scriptOnTick = Reflect.field(scriptInstance, "onTick");
			scriptOnShutdown = Reflect.field(scriptInstance, "onShutdown");
			scriptOnUnload = Reflect.field(scriptInstance, "onUnload");
			scriptOnLoad = Reflect.field(scriptInstance, "onLoad");

			if (isReload && scriptOnLoad != null) {
				var rc:RTResult = scriptOnLoad(stashedData);
				if (rc != RT_SUCCESS) {
					Log.warn('[script] Main.onLoad returned non-success: $rc');
				}
			}

			return isReload;
		} catch (e:Dynamic) {
			Log.error('[script] loadMainCppia failed: $e');
			return false;
		}
	}

	function fetchAndReload(assetPath:String):Void {
		var borrowed = !RL.loaderIsInitialized();
		if (borrowed) {
			var initRc = RL.loaderInit();
			if (initRc != 0) {
				Log.error('[reload] loader init failed ($initRc)');
				return;
			}
		}
		RL.loaderUncacheAsset(assetPath);
		RL.loaderAddTask(RL.loaderImportAssetAsync(assetPath), (localPath, _) -> {
			var bytes = RL.loaderReadLocal(localPath);
			if (borrowed)
				RL.loaderDeinit();
			if (bytes == null) {
				Log.error('[reload] failed to read $localPath');
				return;
			}
			loadMainCppia(bytes);
		}, (localPath, _) -> {
			if (borrowed)
				RL.loaderDeinit();
			Log.error('[reload] failed to fetch $localPath');
		}, null);
	}

	function handleScriptWatcherMessage(payload:haxe.io.Bytes, isText:Bool):Void {
		if (!isText)
			return;
		try {
			var s = payload.toString();
			var obj:Dynamic = haxe.Json.parse(s);
			if (Reflect.field(obj, "type") != "cppia_reload")
				return;
			var data = Reflect.field(obj, "data");
			if (data == null)
				return;
			var pathStr = Reflect.field(data, "path");
			if (pathStr == null)
				return;
			var assetPath = Std.string(pathStr);
			if (assetPath != MAIN_CPPIA_FILE) {
				Log.debug('[script_watcher] ignoring reload for $assetPath (springboard watches $MAIN_CPPIA_FILE)');
				return;
			}
			Log.info('[script_watcher] cppia_reload: $assetPath');
			fetchAndReload(assetPath);
		} catch (e:Dynamic) {
			Log.debug('[script_watcher] message ignored: $e');
		}
	}

	public function onBoot():RTResult {
		//trace("ScriptableMain: onBoot (host)");

		trace("Using script: " + PathUtil.joinPath("./", MAIN_CPPIA_FILE));
		trace("Edit " + PathUtil.joinPath("./", Path.withoutExtension(MAIN_CPPIA_FILE)) + ".hx to change the script");

		// start the loader so we can cache the main script
		var rc = RL.loaderInit();
		if (rc != 0) {
			Log.error("[script] Loader init failed");
			return RT_FAILED;
		}

		rc = RL.setAssetHost(ASSET_HOST);
		if (rc != 0) {
			Log.error("[script] Loader set asset host failed");
			return RT_FAILED;
		}

		// Ping the asset host to see if it's reachable
		#if !(emscripten || PLATFORM_WEB)
		trace('ScriptableMain: onBoot: pinging asset host $ASSET_HOST');
		var rtt = RL.loaderPingAssetHost(ASSET_HOST);
		if (rtt < 0) {
			Log.error("[script] Asset host not reachable");
			return RT_FAILED;
		}
		#end

		RL.loaderUncacheAsset(MAIN_CPPIA_FILE);

		// Synchronously fetch the main cppia into the loader cache. On wasm
		// this suspends through JSPI; on desktop it's a normal blocking fetch.
		var impRc = RL.loaderImportAsset(MAIN_CPPIA_FILE);
		if (impRc != 0) {
			Log.error('[script] sync import failed for $MAIN_CPPIA_FILE (code $impRc)');
			RL.loaderDeinit();
			return RT_FAILED;
		}

		// now that we have the main script, we can create our script main instance
		var cppiaBytes = RL.loaderReadLocal(MAIN_CPPIA_FILE);
		if (cppiaBytes == null) {
			Log.error("[script] Main.cppia bytes empty after sync import");
			RL.loaderDeinit();
			return RT_FAILED;
		}
		loadMainCppia(cppiaBytes);
		if (scriptInstance == null) {
			Log.error("[script] Main.cppia failed to load");
			return RT_FAILED;
		}
		// loader was only needed to bootstrap the cppia; Main.hx owns its own loader lifecycle
		RL.loaderDeinit();

		if (SCRIPT_WATCHER_URL.length > 0) {
			Log.info('[script_watcher] client constructing for ${SCRIPT_WATCHER_URL}');
			scriptWatcher = new WebSocket(SCRIPT_WATCHER_URL, {
				onOpen: function(ws) {
					Log.debug("[script_watcher] connected (handshake complete)");
					var watchMsg = haxe.Json.stringify({
						type: "watch",
						data: {
							watch: [
								{dir: "assets/scripts/haxe", ext: ".cppia", recursive: true}
							]
						}
					});
					ws.sendText(watchMsg);
				},
				onClose: function(_, code, reason) {
					Log.debug('[script_watcher] closed code=$code reason=$reason');
				},
				onError: function(_) {
					Log.error("[script_watcher] browser/emscripten WebSocket error (TLS/mixed-content/host/port — check DevTools→Network→WS)");
				},
				onMessage: function(_, payload, isText) {
					Log.info('[script_watcher] message bytes=${payload.length} isText=$isText');
					handleScriptWatcherMessage(payload, isText);
				},
			});
			Log.debug('[script_watcher] client constructed for ${SCRIPT_WATCHER_URL}; connection is opened asynchronously (poll is noop on wasm)');
		} else {
			Log.debug('[script_watcher] disabled (SCRIPT_WATCHER_URL is empty)');
		}

		return RT_SUCCESS;
	}

	public function onInit():RTResult {
		trace("ScriptableMain: onInit (host)");
		if (scriptInstance != null && scriptOnInit != null) {
			var rc = scriptOnInit();
			if (rc != RT_SUCCESS) {
				Log.error("[script] Main.onInit returned non-success");
			}
			return rc;
		}
		return RT_SUCCESS;
	}

	public function onTick(deltaTimeSec:Float):RTResult {
		if (scriptWatcher != null) {
			scriptWatcher.poll();
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
		scriptInstance = null;
		scriptOnInit = null;
		scriptOnTick = null;
		scriptOnShutdown = null;
		scriptOnUnload = null;
		scriptOnLoad = null;

		if (scriptWatcher != null) {
			scriptWatcher.destroy();
			scriptWatcher = null;
		}

	}
}

////////////////////////////////////////////////////////////
// Runtime ABI hooks / trampoline functions
//

typedef Runtime = ScriptableRuntime;

/* defined in Types.hx so it can be shared with Script.hx
enum abstract RTResult(Int) from Int to Int {
	var RT_SUCCESS = 0;
	var RT_FAILED = -1;
	var RT_STOPPED = 1;
}
*/

interface IRuntime {
	function onBoot():RTResult;
	function onInit():RTResult;
	function onTick(deltaTimeSec:Float):RTResult;
	function onShutdown():Void;
}


class ScriptableMain {
	private static var _instance:IRuntime = null;

	@:exportc.entry
	static function rt_boot():Int {
		trace("ScriptableMain: rt_boot (host)");
		if (_instance == null) {
			_instance = new Runtime();
		}
		return _instance.onBoot();
	}

	@:exportc
	static function rt_init(_hostData:cpp.RawPointer<cpp.Void>):Int {
		trace("ScriptableMain: rt_init (host)");
		if (_instance != null) {
			return _instance.onInit();
		}
		return RT_FAILED;
	}

	@:exportc
	static function rt_tick(dt:Float):Int {
		//trace("ScriptableMain: rt_tick (host)");
		var rc = RL.tick();
		if (rc == RL.TICK_FAILED)
			return RT_FAILED;
		if (rc == RL.TICK_WAITING)
			return RT_SUCCESS;
		if (RL.windowCloseRequested())
			return RT_STOPPED;
		if (_instance != null) {
			return _instance.onTick(dt);
		}
		return RT_SUCCESS;
	}

	@:exportc.exit
	static function rt_shutdown():Void {
		trace("ScriptableMain: rt_shutdown (host)");
		if (_instance != null) {
			_instance.onShutdown();
			_instance = null;
		}
	}

	static function main():Void {
		trace("ScriptableMain: main (host)");
		if (_instance == null) {
			_instance = new Runtime();
		}

		#if !(emscripten || PLATFORM_WEB || js)
		startLocalHost();
		#end
	}

	// local host for when we are debugging without an actual host
	static function startLocalHost() {
		// fake a local host
		var rc = rt_boot();
		if (rc != RT_SUCCESS) {
			trace("ScriptableMain: startLocalHost: rt_boot failed with error: " + rc);
			return rc;
		}

		rc = rt_init(null);
		if (rc != RT_SUCCESS) {
			trace("ScriptableMain: startLocalHost: rt_init failed with error: " + rc);
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
			if (rc > cast RT_SUCCESS) {
				trace("ScriptableMain: startLocalHost: rt_tick returned RT_STOPPED");
				frameTimer.stop();
				rt_shutdown();
			}
			if (rc < cast RT_SUCCESS) {
				trace("ScriptableMain: startLocalHost: rt_tick failed with error: " + rc);
				frameTimer.stop();
				rt_shutdown();
			}
		}
		return RT_SUCCESS;
	}
}
