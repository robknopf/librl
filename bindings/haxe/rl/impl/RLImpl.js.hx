package rl.impl;

#if js
import haxe.io.Bytes;
import js.lib.Promise;
import rl.RLHandle;
import rl.RLTaskGroup;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLKeyboardState;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLPickResult;
import rl.RLTypes.RLVec2;

/**
 * Minimal JS-target backend for the target-neutral `rl.RL` facade.
 *
 * This backend talks directly to the generated Emscripten module
 * (`librl.js` / `librl.wasm`). It intentionally does not use the standalone
 * hand-written JS wrapper or its scratch/SAB helper layer.
 */
@:build(hxasync.AsyncMacro.build())
class RLImpl {
	static var module:Dynamic = null;
	static var bootPromise:Promise<Int> = null;

	public static inline var INIT_OK:Int = 0;
	public static inline var INIT_ERR_UNKNOWN:Int = -1;
	public static inline var INIT_ERR_ALREADY_INITIALIZED:Int = -2;
	public static inline var INIT_ERR_LOADER:Int = -3;
	public static inline var INIT_ERR_ASSET_HOST:Int = -4;
	public static inline var INIT_ERR_WINDOW:Int = -5;

	public static inline var TICK_RUNNING:Int = 0;
	public static inline var TICK_WAITING:Int = 1;
	public static inline var TICK_FAILED:Int = -1;

	public static inline var FLAG_WINDOW_RESIZABLE:Int = 0x00000004;
	public static inline var FLAG_MSAA_4X_HINT:Int = 0x00000020;
	public static inline var FLAG_VSYNC_HINT:Int = 0x00000040;

	public static inline var CAMERA_PERSPECTIVE:Int = 0;
	public static inline var CAMERA_ORTHOGRAPHIC:Int = 1;

	public static inline var LOADER_QUEUE_TASK_OK:Int = 0;
	public static inline var LOADER_QUEUE_TASK_ERR_INVALID:Int = -1;
	public static inline var LOADER_QUEUE_TASK_ERR_QUEUE_FULL:Int = -2;

	public static inline var LOGGER_LEVEL_TRACE:Int = 0;
	public static inline var LOGGER_LEVEL_DEBUG:Int = 1;
	public static inline var LOGGER_LEVEL_INFO:Int = 2;
	public static inline var LOGGER_LEVEL_WARN:Int = 3;
	public static inline var LOGGER_LEVEL_ERROR:Int = 4;
	public static inline var LOGGER_LEVEL_FATAL:Int = 5;

	public static var COLOR_DEFAULT:RLHandle = 0;
	public static var COLOR_LIGHTGRAY:RLHandle = 0;
	public static var COLOR_GRAY:RLHandle = 0;
	public static var COLOR_YELLOW:RLHandle = 0;
	public static var COLOR_GOLD:RLHandle = 0;
	public static var COLOR_ORANGE:RLHandle = 0;
	public static var COLOR_PINK:RLHandle = 0;
	public static var COLOR_RED:RLHandle = 0;
	public static var COLOR_MAROON:RLHandle = 0;
	public static var COLOR_GREEN:RLHandle = 0;
	public static var COLOR_LIME:RLHandle = 0;
	public static var COLOR_DARKGREEN:RLHandle = 0;
	public static var COLOR_SKYBLUE:RLHandle = 0;
	public static var COLOR_BLUE:RLHandle = 0;
	public static var COLOR_DARKBLUE:RLHandle = 0;
	public static var COLOR_PURPLE:RLHandle = 0;
	public static var COLOR_VIOLET:RLHandle = 0;
	public static var COLOR_DARKPURPLE:RLHandle = 0;
	public static var COLOR_BEIGE:RLHandle = 0;
	public static var COLOR_BROWN:RLHandle = 0;
	public static var COLOR_DARKBROWN:RLHandle = 0;
	public static var COLOR_DARKGRAY:RLHandle = 0;
	public static var COLOR_WHITE:RLHandle = 0;
	public static var COLOR_BLANK:RLHandle = 0;
	public static var COLOR_MAGENTA:RLHandle = 0;
	public static var COLOR_RAYWHITE:RLHandle = 0;
	public static var COLOR_BLACK:RLHandle = 0;

  @async
	public static function boot(?options:Dynamic) : Promise<Int>{
		if (module != null) {
			return Promise.resolve(INIT_OK);
		}
		if (bootPromise != null) {
			return bootPromise;
		}

		if (!hasJspiSupport()) {
			return Promise.resolve(INIT_ERR_UNKNOWN);
		}

		var modulePath = optionString(options, "modulePath", "../../../lib/librl.js");
		var wasmPath = optionString(options, "wasmPath", null);
		var moduleOptions:Dynamic = optionObject(options, "moduleOptions");

		// if a path was provide for the wasm location, add a locateFile function that uses it
		if (wasmPath != null && Reflect.field(moduleOptions, "locateFile") == null) {
			Reflect.setField(moduleOptions, "locateFile", function(path:String, prefix:String):String {
				return path == "librl.wasm" ? wasmPath : prefix + path;
			});
		}

		// get the canvas element from the canvasId
		var canvasId = optionString(options, "canvasId", "renderCanvas");
		if (canvasId != null && Reflect.field(moduleOptions, "canvas") == null) {
			var canvas = js.Browser.document.getElementById(canvasId);
			Reflect.setField(moduleOptions, "canvas", canvas);
		}

		bootPromise = cast js.Syntax.code("(async () => {
        try {
          const lib = await import( /* @vite-ignore */ {0});
          const factory = lib.default;
          if (typeof factory !== 'function') throw new Error('librl.js default export is not a module factory');
          const mod = await factory({1});
          {2} = mod;
          return {3};
        } catch (err) {
          console.error('RL.boot failed', err);
          {2} = null;
          {4} = null;
          return {5};
        }
      })()", modulePath, moduleOptions, module, INIT_OK, bootPromise, INIT_ERR_UNKNOWN);
		var rc:Int = cast js.Syntax.code("await {0}", bootPromise);
		if (rc == INIT_OK) {
			setColorConstants();
		}
		return Promise.resolve(rc);
	}

	private static function setColorConstants():Void {
		if (module == null)
			return;
		var heap = cast js.Syntax.code("{0}.HEAPU32 || {0}.HEAP32", module);
		COLOR_DEFAULT = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DEFAULT'] >>> 2)] >>> 0", heap, module);
		COLOR_LIGHTGRAY = cast js.Syntax.code("{0}[({1}['_RL_COLOR_LIGHTGRAY'] >>> 2)] >>> 0", heap, module);
		COLOR_GRAY = cast js.Syntax.code("{0}[({1}['_RL_COLOR_GRAY'] >>> 2)] >>> 0", heap, module);
		COLOR_YELLOW = cast js.Syntax.code("{0}[({1}['_RL_COLOR_YELLOW'] >>> 2)] >>> 0", heap, module);
		COLOR_GOLD = cast js.Syntax.code("{0}[({1}['_RL_COLOR_GOLD'] >>> 2)] >>> 0", heap, module);
		COLOR_ORANGE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_ORANGE'] >>> 2)] >>> 0", heap, module);
		COLOR_PINK = cast js.Syntax.code("{0}[({1}['_RL_COLOR_PINK'] >>> 2)] >>> 0", heap, module);
		COLOR_RED = cast js.Syntax.code("{0}[({1}['_RL_COLOR_RED'] >>> 2)] >>> 0", heap, module);
		COLOR_MAROON = cast js.Syntax.code("{0}[({1}['_RL_COLOR_MAROON'] >>> 2)] >>> 0", heap, module);
		COLOR_GREEN = cast js.Syntax.code("{0}[({1}['_RL_COLOR_GREEN'] >>> 2)] >>> 0", heap, module);
		COLOR_LIME = cast js.Syntax.code("{0}[({1}['_RL_COLOR_LIME'] >>> 2)] >>> 0", heap, module);
		COLOR_DARKGREEN = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DARKGREEN'] >>> 2)] >>> 0", heap, module);
		COLOR_SKYBLUE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_SKYBLUE'] >>> 2)] >>> 0", heap, module);
		COLOR_BLUE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_BLUE'] >>> 2)] >>> 0", heap, module);
		COLOR_DARKBLUE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DARKBLUE'] >>> 2)] >>> 0", heap, module);
		COLOR_PURPLE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_PURPLE'] >>> 2)] >>> 0", heap, module);
		COLOR_VIOLET = cast js.Syntax.code("{0}[({1}['_RL_COLOR_VIOLET'] >>> 2)] >>> 0", heap, module);
		COLOR_DARKPURPLE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DARKPURPLE'] >>> 2)] >>> 0", heap, module);
		COLOR_BEIGE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_BEIGE'] >>> 2)] >>> 0", heap, module);
		COLOR_BROWN = cast js.Syntax.code("{0}[({1}['_RL_COLOR_BROWN'] >>> 2)] >>> 0", heap, module);
		COLOR_DARKBROWN = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DARKBROWN'] >>> 2)] >>> 0", heap, module);
		COLOR_DARKGRAY = cast js.Syntax.code("{0}[({1}['_RL_COLOR_DARKGRAY'] >>> 2)] >>> 0", heap, module);
		COLOR_WHITE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_WHITE'] >>> 2)] >>> 0", heap, module);
		COLOR_BLANK = cast js.Syntax.code("{0}[({1}['_RL_COLOR_BLANK'] >>> 2)] >>> 0", heap, module);
		COLOR_MAGENTA = cast js.Syntax.code("{0}[({1}['_RL_COLOR_MAGENTA'] >>> 2)] >>> 0", heap, module);
		COLOR_RAYWHITE = cast js.Syntax.code("{0}[({1}['_RL_COLOR_RAYWHITE'] >>> 2)] >>> 0", heap, module);
		COLOR_BLACK = cast js.Syntax.code("{0}[({1}['_RL_COLOR_BLACK'] >>> 2)] >>> 0", heap, module);
	}

	public static function init(?config:RLInitConfig):Promise<Int> {
		var values = normalizeInitConfig(config);
		return initValues(values.width, values.height, values.title, values.flags, values.assetHost, values.loaderCacheDir);
	}

	public static function initAsync(?config:RLInitConfig):Int {
		if (module == null) {
			return INIT_ERR_UNKNOWN;
		}
		var values = normalizeInitConfig(config);
		return initValuesAsync(values.width, values.height, values.title, values.flags, values.assetHost, values.loaderCacheDir);
	}

	public static function initValues(width:Int, height:Int, title:String, flags:Int = 0, assetHost:String = "", loaderCacheDir:String = ""):Promise<Int> {
		if (module == null) {
			return Promise.resolve(INIT_ERR_UNKNOWN);
		}
		return cast js.Syntax.code(
			"{0}.ccall('rl_init_values', 'number', ['number', 'number', 'string', 'number', 'string', 'string'], [{1}, {2}, {3}, {4}, {5}, {6}], { async: true })",
			module,
			width,
			height,
			title,
			flags,
			assetHost,
			loaderCacheDir
		);
	}

	public static function initValuesAsync(width:Int, height:Int, title:String, flags:Int = 0, assetHost:String = "", loaderCacheDir:String = ""):Int {
		if (module == null) {
			return INIT_ERR_UNKNOWN;
		}
		return cast js.Syntax.code(
			"{0}.ccall('rl_init_values_async', 'number', ['number', 'number', 'string', 'number', 'string', 'string'], [{1}, {2}, {3}, {4}, {5}, {6}])",
			module,
			width,
			height,
			title,
			flags,
			assetHost,
			loaderCacheDir
		);
	}

  @async
	public static function deinit():Promise<Void> {
		if (module == null) {
			return Promise.resolve(null);
		}
		return js.Syntax.code("{0}.ccall('rl_deinit', null, [], [], { async: true })", module);
	}

	public static function isInitialized():Bool {
		return module != null && cast js.Syntax.code("{0}.ccall('rl_is_initialized', 'number', [], []) !== 0", module);
	}

	public static function getPlatform():String {
		if (module == null) {
			return "js";
		}
		return cast js.Syntax.code("{0}.ccall('rl_get_platform', 'string', [], [])", module);
	}

	public static function update():Void {}

	public static function updateToScratch():Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_update_to_scratch', null, [], [])", module);
	}

	public static function tick():Int {
		return module == null ? TICK_FAILED : cast js.Syntax.code("{0}.ccall('rl_tick', 'number', [], [])", module);
	}

	public static function getDeltaTime():Float {
		return module == null ? 0 : cast js.Syntax.code("{0}.ccall('rl_get_delta_time', 'number', [], [])", module);
	}

	public static function getTime():Float {
		return module == null ? 0 : cast js.Syntax.code("{0}.ccall('rl_get_time', 'number', [], [])", module);
	}

	public static function setTargetFps(fps:Int):Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_set_target_fps', null, ['number'], [{1}])", module, fps);
	}

	public static function colorCreate(r:Int, g:Int, b:Int, a:Int):RLHandle {
		if (module == null)
			return 0;
		return js.Syntax.code("{0}.ccall('rl_color_create', 'number', ['number', 'number', 'number', 'number'], [{1}, {2}, {3}, {4}])", module, r,
			g, b, a);
	}

	public static function colorDestroy(color:RLHandle):Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_color_destroy', null, ['number'], [{1}])", module, color);
	}

	public static function fontCreate(filename:String, fontSize:Int):RLHandle
		return 0;

	public static function fontDestroy(font:RLHandle):Void {}

	public static function textDraw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void {}

	public static function textMeasure(text:String, fontSize:Int):Int
		return 0;

	public static function textDrawFps(x:Int, y:Int):Void {}

	public static function textDrawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void {}

	public static function textMeasureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2
		return vec2();

	public static function textDrawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void {}

	public static function setAssetHost(assetHost:String):Int {
		return module == null ? -1 : cast js.Syntax.code("{0}.ccall('rl_set_asset_host', 'number', ['string'], [{1}])", module, assetHost);
	}

	public static function getAssetHost():String {
		return module == null ? "" : cast js.Syntax.code("{0}.ccall('rl_get_asset_host', 'string', [], [])", module);
	}

	public static function musicCreate(filename:String):RLHandle
		return 0;

	public static function musicDestroy(music:RLHandle):Void {}

	public static function musicPlay(music:RLHandle):Bool
		return false;

	public static function musicPause(music:RLHandle):Bool
		return false;

	public static function musicStop(music:RLHandle):Bool
		return false;

	public static function musicSetLoop(music:RLHandle, shouldLoop:Bool):Bool
		return false;

	public static function musicSetVolume(music:RLHandle, volume:Float):Bool
		return false;

	public static function musicIsPlaying(music:RLHandle):Bool
		return false;

	public static function musicUpdate(music:RLHandle):Bool
		return false;

	public static function musicUpdateAll():Void {}

	public static function soundCreate(filename:String):RLHandle
		return 0;

	public static function soundDestroy(sound:RLHandle):Void {}

	public static function soundPlay(sound:RLHandle):Bool
		return false;

	public static function soundPause(sound:RLHandle):Bool
		return false;

	public static function soundResume(sound:RLHandle):Bool
		return false;

	public static function soundStop(sound:RLHandle):Bool
		return false;

	public static function soundSetVolume(sound:RLHandle, volume:Float):Bool
		return false;

	public static function soundSetPitch(sound:RLHandle, pitch:Float):Bool
		return false;

	public static function soundSetPan(sound:RLHandle, pan:Float):Bool
		return false;

	public static function soundIsPlaying(sound:RLHandle):Bool
		return false;

	public static function enableLighting():Void {}

	public static function disableLighting():Void {}

	public static function isLightingEnabled():Int
		return 0;

	public static function setLightDirection(x:Float, y:Float, z:Float):Void {}

	public static function setLightAmbient(ambient:Float):Void {}

	public static function renderBegin():Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_render_begin', null, [], [])", module);
	}

	public static function renderEnd():Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_render_end', null, [], [])", module);
	}

	public static function renderClearBackground(color:RLHandle):Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_render_clear_background', null, ['number'], [{1}])", module, color);
	}

	public static function renderBeginMode2D(camera:RLHandle):Void {}

	public static function renderEndMode2D():Void {}

	public static function renderBeginMode3D():Void {}

	public static function renderEndMode3D():Void {}

	public static function windowCloseRequested():Bool
		return false;

	public static function windowGetScreenSize():RLVec2
		return vec2();

	public static function windowGetMonitorCount():Int
		return 0;

	public static function windowSetTitle(title:String):Void {}

	public static function windowSetSize(width:Int, height:Int):Void {}

	public static function windowGetCurrentMonitor():Int
		return 0;

	public static function windowSetMonitor(monitor:Int):Void {}

	public static function windowGetMonitorWidth(monitor:Int):Int
		return 0;

	public static function windowGetMonitorHeight(monitor:Int):Int
		return 0;

	public static function windowGetMonitorPosition(monitor:Int):RLVec2
		return vec2();

	public static function windowGetPosition():RLVec2
		return vec2();

	public static function windowSetPosition(x:Int, y:Int):Void {}

	public static function camera3dCreate(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float,
			upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle
		return 0;

	public static function camera3dSet(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float,
			upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool
		return false;

	public static function camera3dSetActive(camera:RLHandle):Bool
		return false;

	public static function camera3dDestroy(camera:RLHandle):Void {}

	public static function modelCreate(filename:String):RLHandle
		return 0;

	public static function modelSetTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float,
			rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool
		return false;

	public static function modelDraw(model:RLHandle, tint:RLHandle):Void {}

	public static function modelSetAnimation(model:RLHandle, animationIndex:Int):Bool
		return false;

	public static function modelSetAnimationSpeed(model:RLHandle, speed:Float):Bool
		return false;

	public static function modelSetAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool
		return false;

	public static function modelAnimate(model:RLHandle, deltaSeconds:Float):Bool
		return false;

	public static function modelDestroy(model:RLHandle):Void {}

	public static function sprite3dCreate(filename:String):RLHandle
		return 0;

	public static function sprite3dSetTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, size:Float):Bool
		return false;

	public static function sprite3dDraw(sprite:RLHandle, tint:RLHandle):Void {}

	public static function sprite3dDestroy(sprite:RLHandle):Void {}

	public static function sprite2dCreate(filename:String):RLHandle
		return 0;

	public static function sprite2dCreateFromTexture(texture:RLHandle):RLHandle
		return 0;

	public static function sprite2dSetTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool
		return false;

	public static function sprite2dDraw(sprite:RLHandle, tint:RLHandle):Void {}

	public static function sprite2dDestroy(sprite:RLHandle):Void {}

	public static function textureCreate(filename:String):RLHandle
		return 0;

	public static function textureDestroy(texture:RLHandle):Void {}

	public static function textureDrawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void {}

	public static function textureDrawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float,
		tint:RLHandle):Void {}

	public static function inputPollEvents():Void {}

	public static function inputGetMousePosition():RLVec2
		return vec2();

	public static function inputGetMouseWheel():Int
		return 0;

	public static function inputGetMouseButton(button:Int):Int
		return 0;

	public static function inputGetMouseState():RLMouseState
		return {
			x: 0,
			y: 0,
			wheel: 0,
			left: 0,
			right: 0,
			middle: 0
		};

	public static function inputGetKeyboardState():RLKeyboardState
		return new RLKeyboardState();

	public static function pickModel(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return pickResult();

	public static function pickSprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return pickResult();

	public static function pickResetStats():Void {}

	public static function pickGetBroadphaseTests():Int
		return 0;

	public static function pickGetBroadphaseRejects():Int
		return 0;

	public static function pickGetNarrowphaseTests():Int
		return 0;

	public static function pickGetNarrowphaseHits():Int
		return 0;

  @async
	public static function loaderInit(?mountPoint:String):Promise<Int> {
		if (module == null) {
			return Promise.resolve(-1);
		}
		var path = mountPoint == null ? "" : mountPoint;
		return cast js.Syntax.code("{0}.ccall('rl_loader_init', 'number', ['string'], [{1}], { async: true })", module, path);
	}

	public static function loaderInitAsync(?mountPoint:String):Int {
		if (module == null) {
			return -1;
		}
		var path = mountPoint == null ? "" : mountPoint;
		return js.Syntax.code("{0}.ccall('rl_loader_init_async', 'number', ['string'], [{1}])", module, path);
	}

  @async
	public static function loaderDeinit():Promise<Void> {
		if (module == null) {
			return Promise.resolve(null);
		}
		return cast js.Syntax.code("{0}.ccall('rl_loader_deinit', null, [], [], { async: true })", module);
	}

	public static function loaderIsInitialized():Bool {
		return module != null && cast js.Syntax.code("{0}.ccall('rl_loader_is_initialized', 'number', [], []) !== 0", module);
	}

	public static function loaderRestoreFsAsync():RLHandle {
		return module == null ? 0 : cast js.Syntax.code("{0}.ccall('rl_loader_restore_fs_async', 'number', [], [])", module);
	}

	public static function loaderImportAssetAsync(filename:String):RLHandle {
		return module == null ? 0 : cast js.Syntax.code("{0}.ccall('rl_loader_create_import_task', 'number', ['string'], [{1}])", module, filename);
	}

	public static function loaderImportAsset(filename:String):Promise<Int> {
		if (module == null) {
			return Promise.resolve(-1);
		}
		return js.Syntax.code("{0}.ccall('rl_loader_import_asset', 'number', ['string'], [{1}], { async: true })", module, filename);
	}

	public static function loaderImportAssetsAsync(filenames:Array<String>):RLHandle
		return 0;

	public static function loaderPollTask(task:RLHandle):Bool {
		return module != null && cast js.Syntax.code("{0}.ccall('rl_loader_poll_task', 'number', ['number'], [{1}]) !== 0", module, task);
	}

	public static function loaderFinishTask(task:RLHandle):Int {
		return module == null ? -1 : cast js.Syntax.code("{0}.ccall('rl_loader_finish_task', 'number', ['number'], [{1}])", module, task);
	}

	public static function loaderGetTaskPath(task:RLHandle):String {
		return module == null ? "" : cast js.Syntax.code("{0}.ccall('rl_loader_get_task_path', 'string', ['number'], [{1}])", module, task);
	}

	public static function loaderReadLocal(filename:String):Bytes
		return Bytes.alloc(0);

	public static function loaderFreeTask(task:RLHandle):Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_loader_free_task', null, ['number'], [{1}])", module, task);
	}

	public static function loaderIsAssetCached(filename:String):Bool {
		return module != null
			&& cast js.Syntax.code("{0}.ccall('rl_loader_is_asset_cached', 'number', ['string'], [{1}]) !== 0", module, filename);
	}

	public static function loaderPingAssetHost(?assetHost:String):Float {
		var host = assetHost == null ? "" : assetHost;
		return module == null ? -1 : cast js.Syntax.code("{0}.ccall('rl_loader_ping_asset_host', 'number', ['string'], [{1}])", module, host);
	}

	public static function loaderGetCacheDir():String {
		return module == null ? "" : cast js.Syntax.code("{0}.ccall('rl_loader_get_cache_dir', 'string', [], [])", module);
	}

	public static function loaderCreateTaskGroup<T>(?onComplete:RLTaskGroupCallback<T>, ?onError:RLTaskGroupCallback<T>, ?ctx:T):RLTaskGroup
		return new RLTaskGroup(cast onComplete, cast onError, ctx);

	public static function loaderTaskInvalid():RLHandle
		return 0;

	public static function loaderTaskIsValid(task:RLHandle):Bool
		return task != 0;

	public static function loaderAddTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int
		return LOADER_QUEUE_TASK_ERR_INVALID;

	public static function loaderTick():Void {
		if (module != null)
			js.Syntax.code("{0}.ccall('rl_loader_tick', null, [], [])", module);
	}

	public static function loaderClearCache():Int {
		return module == null ? -1 : cast js.Syntax.code("{0}.ccall('rl_loader_clear_cache', 'number', [], [])", module);
	}

	public static function loaderUncacheAsset(filename:String):Int {
		return module == null ? -1 : cast js.Syntax.code("{0}.ccall('rl_loader_uncache_asset', 'number', ['string'], [{1}])", module, filename);
	}

	public static function loggerMessage(level:Int, message:String):Void {
		js.Syntax.code("console.log({0})", message);
	}

	public static function loggerSetLevel(level:Int):Void {}

	static inline function vec2():RLVec2 {
		return {x: 0.0, y: 0.0};
	}

	static function optionString(options:Dynamic, name:String, fallback:Null<String>):Null<String> {
		if (options == null) {
			return fallback;
		}
		var value = Reflect.field(options, name);
		if (value == null) {
			return fallback;
		}
		return Std.string(value);
	}

	static function hasJspiSupport():Bool {
		return cast js.Syntax.code("typeof WebAssembly !== 'undefined' &&
       typeof WebAssembly.Suspending === 'function' &&
       typeof WebAssembly.promising === 'function'");
	}

	static function optionObject(options:Dynamic, name:String):Dynamic {
		if (options == null) {
			return {};
		}
		var value = Reflect.field(options, name);
		if (value == null) {
			return {};
		}
		return value;
	}

	private static function normalizeInitConfig(?config:RLInitConfig):{
		var width:Int;
		var height:Int;
		var title:String;
		var flags:Int;
		var assetHost:String;
		var loaderCacheDir:String;
	} {
		return {
			width: config != null && config.windowWidth != null ? config.windowWidth : 0,
			height: config != null && config.windowHeight != null ? config.windowHeight : 0,
			title: config != null && config.windowTitle != null ? config.windowTitle : "",
			flags: config != null && config.windowFlags != null ? config.windowFlags : 0,
			assetHost: config != null && config.assetHost != null ? config.assetHost : "",
			loaderCacheDir: config != null && config.loaderCacheDir != null ? config.loaderCacheDir : ""
		};
	}

	static inline function pickResult():RLPickResult {
		return {
			hit: false,
			distance: 0.0,
			point: {x: 0.0, y: 0.0, z: 0.0},
			normal: {x: 0.0, y: 0.0, z: 0.0}
		};
	}
}
#end
