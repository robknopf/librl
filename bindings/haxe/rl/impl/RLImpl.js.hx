package rl.impl;

#if js
import haxe.io.Bytes;
import js.lib.Promise;
import rl.Types.RLHandle;
import rl.Types.RLBootConfig;
import rl.Types.RLInitConfig;
import rl.Types.RLGamepad;
import rl.Types.RLKeyboardState;
import rl.Types.RLMouseState;
import rl.Types.RLPickResult;
import rl.Types.RLScenePickResult;
import rl.Types.RLSprite3dFacing;
import rl.Types.RLSprite3dTransform;
import rl.Types.RLTouchpoint;
import rl.Types.RLVec2;
import rl.gen.RLVersion;
/**
 * Minimal JS-target backend for the target-neutral `rl.RL` facade.
 *
 * This backend boots through the standalone JS binding layer exported from
 * `bindings/js/rl.js`, then reuses the wrapper's scratch-backed helpers for APIs that
 * return structs to JS.
 */
class RLImpl {
	static var binding:Dynamic = null;
	static var bootPromise:Promise<Int> = null;

	public static inline var INIT_OK:Int = 0;
	public static inline var INIT_ERR_UNKNOWN:Int = -1;
	public static inline var INIT_ERR_ALREADY_INITIALIZED:Int = -2;
	public static inline var INIT_ERR_LOADER:Int = -3;
	public static inline var INIT_ERR_ASSET_HOST:Int = -4;
	public static inline var INIT_ERR_WINDOW:Int = -5;

	public static inline var BOOT_OK:Int = 0;
	public static inline var BOOT_ERR_UNKNOWN:Int = -10;
	public static inline var BOOT_ERR_LOADER:Int = -11;
	public static inline var BOOT_ERR_VERSION_MISMATCH:Int = -12;

	public static inline var TICK_RUNNING:Int = 0;
	public static inline var TICK_WAITING:Int = 1;
	public static inline var TICK_FAILED:Int = -1;

	public static inline var BUTTON_UP:Int = 0;
	public static inline var BUTTON_PRESSED:Int = 1;
	public static inline var BUTTON_DOWN:Int = 2;
	public static inline var BUTTON_RELEASED:Int = 3;

	public static inline var FLAG_WINDOW_RESIZABLE:Int = 0x00000004;
	public static inline var FLAG_MSAA_4X_HINT:Int = 0x00000020;
	public static inline var FLAG_VSYNC_HINT:Int = 0x00000040;

	public static inline var CAMERA_PERSPECTIVE:Int = 0;
	public static inline var CAMERA_ORTHOGRAPHIC:Int = 1;

	public static inline var ASSET_ADD_TASK_OK:Int = 0;
	public static inline var ASSET_ADD_TASK_ERR_INVALID:Int = -1;
	public static inline var ASSET_ADD_TASK_ERR_QUEUE_FULL:Int = -2;

	public static inline var LOGGER_LEVEL_TRACE:Int = 0;
	public static inline var LOGGER_LEVEL_DEBUG:Int = 1;
	public static inline var LOGGER_LEVEL_INFO:Int = 2;
	public static inline var LOGGER_LEVEL_WARN:Int = 3;
	public static inline var LOGGER_LEVEL_ERROR:Int = 4;
	public static inline var LOGGER_LEVEL_FATAL:Int = 5;
	public static inline var HANDLE_KIND_NONE:Int = 0;
	public static inline var HANDLE_KIND_COLOR:Int = 1;
	public static inline var HANDLE_KIND_CAMERA3D:Int = 2;
	public static inline var HANDLE_KIND_FONT:Int = 3;
	public static inline var HANDLE_KIND_TEXTURE:Int = 4;
	public static inline var HANDLE_KIND_SPRITE2D:Int = 5;
	public static inline var HANDLE_KIND_SPRITE3D:Int = 6;
	public static inline var HANDLE_KIND_MODEL:Int = 7;
	public static inline var HANDLE_KIND_MODEL_ASSET:Int = 8;
	public static inline var HANDLE_KIND_SOUND:Int = 9;
	public static inline var HANDLE_KIND_MUSIC:Int = 10;
	public static inline var HANDLE_KIND_TEXT2D:Int = 11;
	public static inline var HANDLE_KIND_SCENE:Int = 12;
	public static inline var HANDLE_KIND_SHAPE:Int = 13;
	public static inline var HANDLE_KIND_ASSET_TASK:Int = 32;

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

	private static function maybeCacheBustBindingsPath(path:String):String {
		#if debug
		var separator = path.indexOf("?") >= 0 ? "&" : "?";
		return path + separator + "t=" + Std.string(Date.now().getTime());
		#else
		return path;
		#end
	}

	/** Page-relative default so subpath deploys (e.g. `/testbed/librl/`) resolve correctly. */
	private static function defaultBindingsPath():String {
		return cast js.Syntax.code("new URL('js/rl.js', document.baseURI).href");
	}

	@async
	public static function boot(?config:RLBootConfig):Promise<Int> {
		if (binding != null) {
			return Promise.resolve(BOOT_OK);
		}
		if (bootPromise != null) {
			return bootPromise;
		}

		if (!hasJspiSupport()) {
			return Promise.resolve(BOOT_ERR_LOADER);
		}

		var bootOptions = buildBootOptions(config);
		trace(bootOptions);
		var bindingsPath = maybeCacheBustBindingsPath(optionString(bootOptions, "bindingsPath", defaultBindingsPath()));
		
		// ensure import() gets an absolute URL
		bindingsPath = cast js.Syntax.code("new URL({0}, document.baseURI).href", bindingsPath);

		trace('Bindings path: ${bindingsPath}');

		bootPromise = cast js.Syntax.code("(async () => {
        try {
          const lib = await import( /* @vite-ignore */ {0});
          const rl = lib.rl;
          if (!rl || typeof rl.boot !== 'function') throw new Error('{0} missing named rl export');
          {1} = rl;
          const rc = await rl.boot({2});
          return rc | 0;
        } catch (err) {
          console.error('RL.boot failed', err);
          {1} = null;
          {3} = null;
          return {4};
        }
      })()", bindingsPath, binding, bootOptions, bootPromise, BOOT_ERR_UNKNOWN);
		var rc:Int = cast @await bootPromise;//cast js.Syntax.code("await {0}", bootPromise);
		if (rc != BOOT_OK) {
			return Promise.resolve(rc);
		}
		
		if ( compareVersion() < 0 ) {
			return Promise.resolve(BOOT_ERR_VERSION_MISMATCH);
		}
	
		setColorConstants();
	
		return Promise.resolve(BOOT_OK);
	}

	private static function buildBootOptions(?config:RLBootConfig):Dynamic {
		var options:Dynamic = {};
		var env:Dynamic = {};
		var hasEnv = false;

		if (config == null) {
			return options;
		}
		if (config.bindingsPath != null) {
			Reflect.setField(options, "bindingsPath", config.bindingsPath);
		}
		if (config.canvasId != null) {
			Reflect.setField(options, "canvasId", config.canvasId);
		}
		if (config.modulePath != null) {
			Reflect.setField(options, "modulePath", config.modulePath);
		}
		if (config.wasmPath != null) {
			Reflect.setField(options, "wasmPath", config.wasmPath);
		}
		if (config.idealWidth != null) {
			Reflect.setField(options, "idealWidth", config.idealWidth);
		}
		if (config.idealHeight != null) {
			Reflect.setField(options, "idealHeight", config.idealHeight);
		}
		if (config.print != null) {
			Reflect.setField(env, "print", config.print);
			hasEnv = true;
		}
		if (config.printErr != null) {
			Reflect.setField(env, "printErr", config.printErr);
			hasEnv = true;
		}
		if (config.locateFile != null) {
			Reflect.setField(env, "locateFile", config.locateFile);
			hasEnv = true;
		}
		if (hasEnv) {
			Reflect.setField(options, "env", env);
		}
		return options;
	}

	private static function setColorConstants():Void {
		if (binding == null)
			return;
		COLOR_DEFAULT = cast js.Syntax.code("{0}.color.DEFAULT", binding);
		COLOR_LIGHTGRAY = cast js.Syntax.code("{0}.color.LIGHTGRAY", binding);
		COLOR_GRAY = cast js.Syntax.code("{0}.color.GRAY", binding);
		COLOR_YELLOW = cast js.Syntax.code("{0}.color.YELLOW", binding);
		COLOR_GOLD = cast js.Syntax.code("{0}.color.GOLD", binding);
		COLOR_ORANGE = cast js.Syntax.code("{0}.color.ORANGE", binding);
		COLOR_PINK = cast js.Syntax.code("{0}.color.PINK", binding);
		COLOR_RED = cast js.Syntax.code("{0}.color.RED", binding);
		COLOR_MAROON = cast js.Syntax.code("{0}.color.MAROON", binding);
		COLOR_GREEN = cast js.Syntax.code("{0}.color.GREEN", binding);
		COLOR_LIME = cast js.Syntax.code("{0}.color.LIME", binding);
		COLOR_DARKGREEN = cast js.Syntax.code("{0}.color.DARKGREEN", binding);
		COLOR_SKYBLUE = cast js.Syntax.code("{0}.color.SKYBLUE", binding);
		COLOR_BLUE = cast js.Syntax.code("{0}.color.BLUE", binding);
		COLOR_DARKBLUE = cast js.Syntax.code("{0}.color.DARKBLUE", binding);
		COLOR_PURPLE = cast js.Syntax.code("{0}.color.PURPLE", binding);
		COLOR_VIOLET = cast js.Syntax.code("{0}.color.VIOLET", binding);
		COLOR_DARKPURPLE = cast js.Syntax.code("{0}.color.DARKPURPLE", binding);
		COLOR_BEIGE = cast js.Syntax.code("{0}.color.BEIGE", binding);
		COLOR_BROWN = cast js.Syntax.code("{0}.color.BROWN", binding);
		COLOR_DARKBROWN = cast js.Syntax.code("{0}.color.DARKBROWN", binding);
		COLOR_DARKGRAY = cast js.Syntax.code("{0}.color.DARKGRAY", binding);
		COLOR_WHITE = cast js.Syntax.code("{0}.color.WHITE", binding);
		COLOR_BLANK = cast js.Syntax.code("{0}.color.BLANK", binding);
		COLOR_MAGENTA = cast js.Syntax.code("{0}.color.MAGENTA", binding);
		COLOR_RAYWHITE = cast js.Syntax.code("{0}.color.RAYWHITE", binding);
		COLOR_BLACK = cast js.Syntax.code("{0}.color.BLACK", binding);
	}

	public static function init(?config:RLInitConfig):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(INIT_ERR_UNKNOWN);
		}
		return cast binding.init(normalizeInitOptions(config));
	}

	public static function initAsync(?config:RLInitConfig):Int {
		if (binding == null) {
			return INIT_ERR_UNKNOWN;
		}
		return cast binding.initAsync(normalizeInitOptions(config));
	}

	static function normalizeInitOptions(?config:RLInitConfig):Dynamic {
		var values = normalizeInitConfig(config);
		return {
			windowWidth: values.width,
			windowHeight: values.height,
			windowTitle: values.title,
			windowFlags: values.flags,
			assetHost: values.assetHost,
			fsRootDir: values.fsRootDir,
		};
	}

	@async
	public static function deinit():Promise<Void> {
		if (binding == null) {
			return Promise.resolve(null);
		}
		binding.deinit();
		binding = null;
		bootPromise = null;
		return Promise.resolve(null);
	}

	public static function isInitialized():Bool {
		return binding != null && cast binding.isInitialized();
	}

	public static function getPlatform():String {
		if (binding == null) {
			return "js";
		}
		return cast binding.getPlatform();
	}

	public static function handleKind(handle:Int):Int {
		return binding == null ? 0 : cast binding.handleKind(handle);
	}

	public static function versionMajor():Int {
		return binding == null ? 0 : cast binding.getVersionMajor();
	}

	public static function versionMinor():Int {
		return binding == null ? 0 : cast binding.getVersionMinor();
	}

	public static function versionPatch():Int {
		return binding == null ? 0 : cast binding.getVersionPatch();
	}

	public static function versionLabel():String {
		return binding == null ? "unknown" : cast binding.getVersionLabel();
	}

	public static function versionNumber():Int {
		return binding == null ? 0 : cast binding.getVersionNumber();
	}

	public static function versionString():String {
		return binding == null ? "0.0.0-unknown" : cast binding.getVersionString();
	}

	static function compareVersion():Int {
		final runtimeMajor = versionMajor();
		final runtimeMinor = versionMinor();
		final runtimePatch = versionPatch();
		final builtMajor = RLVersion.BUILT_MAJOR;
		final builtMinor = RLVersion.BUILT_MINOR;
		final builtPatch = RLVersion.BUILT_PATCH;

		trace('[librl] bindings version: ' + builtMajor + ', ' + builtMinor + ', ' + builtPatch);
		trace('[librl] librl version: ' + runtimeMajor + ', ' + runtimeMinor + ', ' + runtimePatch);

		if (runtimeMajor != builtMajor) {
			return -1;
		}
		if (runtimeMinor != builtMinor) {
			return -2;
		}
		if (runtimePatch != builtPatch) {
			// allow patch differences through
			return 1;
		}

		return 0;
	}

	// Intentionally not exposed on Haxe public API: scratch/SAB bridge is JS/wasm-only.
	// Haxe JS tick() forwards to bindings/js/rl.js, which calls refreshScratch() internally.
	// public static function scratchRefresh():Void {
	// 	if (binding != null)
	// 		binding.refreshScratch();
	// }

	public static function tick():Int {
		return binding == null ? TICK_FAILED : cast binding.tick();
	}

	public static function getDeltaTime():Float {
		return binding == null ? 0 : cast binding.getDeltaTime();
	}

	public static function getTime():Float {
		return binding == null ? 0 : cast binding.getTime();
	}

	public static function setTargetFps(fps:Int):Void {
		if (binding != null)
			binding.setTargetFPS(fps);
	}

	public static function colorCreate(r:Int, g:Int, b:Int, a:Int):RLHandle {
		if (binding == null)
			return 0;
		return cast binding.color.create(r, g, b, a);
	}

	public static function colorDestroy(color:RLHandle):Void {
		if (binding != null)
			binding.color.destroy(color);
	}

	public static function fontCreate(filename:String, fontSize:Int):RLHandle
		return binding == null ? 0 : cast binding.font.create(filename, fontSize);

	public static function fontDestroy(font:RLHandle):Void {
		if (binding != null)
			binding.font.destroy(font);
	}

	public static function textDraw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void {
		if (binding != null)
			binding.text.draw(text, x, y, fontSize, color);
	}

	public static function textMeasure(text:String, fontSize:Int):Int
		return binding == null ? 0 : cast binding.text.measure(text, fontSize);

	public static function textDrawFps(x:Int, y:Int):Void {
		if (binding != null)
			binding.text.drawFps(x, y);
	}

	public static function textDrawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void {
		if (binding != null)
			binding.text.drawEx(font, text, x, y, fontSize, spacing, color);
	}

	public static function textMeasureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2
		return binding == null ? vec2() : cast binding.text.measureEx(font, text, fontSize, spacing);

	public static function textDrawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void {
		if (binding != null)
			binding.text.drawFpsEx(font, x, y, fontSize, color);
	}

	public static function assetSetHost(assetHost:String):Int {
		return binding == null ? -1 : cast binding.asset.setHost(assetHost);
	}

	public static function assetGetHost():String {
		return binding == null ? "" : cast binding.asset.getHost();
	}

	public static function musicCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.music.create(filename);

	public static function musicDestroy(music:RLHandle):Void {
		if (binding != null)
			binding.music.destroy(music);
	}

	public static function musicPlay(music:RLHandle):Bool
		return binding != null && cast binding.music.play(music);

	public static function musicPause(music:RLHandle):Bool
		return binding != null && cast binding.music.pause(music);

	public static function musicStop(music:RLHandle):Bool
		return binding != null && cast binding.music.stop(music);

	public static function musicSetLoop(music:RLHandle, shouldLoop:Bool):Bool
		return binding != null && cast binding.music.setLoop(music, shouldLoop);

	public static function musicSetVolume(music:RLHandle, volume:Float):Bool
		return binding != null && cast binding.music.setVolume(music, volume);

	public static function musicIsPlaying(music:RLHandle):Bool
		return binding != null && cast binding.music.isPlaying(music);

	public static function musicUpdate(music:RLHandle):Bool
		return binding != null && cast binding.music.update(music);

	public static function musicUpdateAll():Void {
		if (binding != null)
			binding.music.updateAll();
	}

	public static function soundCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.sound.create(filename);

	public static function soundDestroy(sound:RLHandle):Void {
		if (binding != null)
			binding.sound.destroy(sound);
	}

	public static function soundPlay(sound:RLHandle):Bool
		return binding != null && cast binding.sound.play(sound);

	public static function soundPause(sound:RLHandle):Bool
		return binding != null && cast binding.sound.pause(sound);

	public static function soundResume(sound:RLHandle):Bool
		return binding != null && cast binding.sound.resume(sound);

	public static function soundStop(sound:RLHandle):Bool
		return binding != null && cast binding.sound.stop(sound);

	public static function soundSetVolume(sound:RLHandle, volume:Float):Bool
		return binding != null && cast binding.sound.setVolume(sound, volume);

	public static function soundSetPitch(sound:RLHandle, pitch:Float):Bool
		return binding != null && cast binding.sound.setPitch(sound, pitch);

	public static function soundSetPan(sound:RLHandle, pan:Float):Bool
		return binding != null && cast binding.sound.setPan(sound, pan);

	public static function soundIsPlaying(sound:RLHandle):Bool
		return binding != null && cast binding.sound.isPlaying(sound);

	public static function enableLighting():Void {
		if (binding != null)
			binding.render.enableLighting();
	}

	public static function disableLighting():Void {
		if (binding != null)
			binding.render.disableLighting();
	}

	public static function isLightingEnabled():Int
		return binding == null ? 0 : (cast binding.render.isLightingEnabled() ? 1 : 0);

	public static function setLightDirection(x:Float, y:Float, z:Float):Void {
		if (binding != null)
			binding.render.setLightDirection(x, y, z);
	}

	public static function setLightAmbient(ambient:Float):Void {
		if (binding != null)
			binding.render.setLightAmbient(ambient);
	}

	public static function renderBegin():Void {
		if (binding != null)
			binding.render.begin();
	}

	public static function renderEnd():Void {
		if (binding != null)
			binding.render.end();
	}

	public static function renderClearBackground(color:RLHandle):Void {
		if (binding != null)
			binding.render.clearBackground(color);
	}

	public static function renderBeginMode2D(camera:RLHandle):Void {
		if (binding != null)
			binding.render.beginMode2D(camera);
	}

	public static function renderEndMode2D():Void {
		if (binding != null)
			binding.render.endMode2D();
	}

	public static function renderBeginMode3d():Void {
		if (binding != null)
			binding.render.beginMode3D();
	}

	public static function renderEndMode3d():Void {
		if (binding != null)
			binding.render.endMode3D();
	}

	public static function windowCloseRequested():Bool
		return binding != null && cast binding.window.isCloseRequested();

	public static function windowGetScreenSize():RLVec2
		return binding == null ? vec2() : cast binding.window.getScreenSize();

	public static function windowGetMonitorCount():Int
		return binding == null ? 0 : cast binding.window.getMonitorCount();

	public static function windowSetTitle(title:String):Void {
		if (binding != null)
			binding.window.setTitle(title);
	}

	public static function windowSetSize(width:Int, height:Int):Void {
		if (binding != null)
			binding.window.setSize(width, height);
	}

	public static function windowGetCurrentMonitor():Int
		return binding == null ? 0 : cast binding.window.getCurrentMonitor();

	public static function windowSetMonitor(monitor:Int):Void {
		if (binding != null)
			binding.window.setMonitor(monitor);
	}

	public static function windowGetMonitorWidth(monitor:Int):Int
		return binding == null ? 0 : cast binding.window.getMonitorWidth(monitor);

	public static function windowGetMonitorHeight(monitor:Int):Int
		return binding == null ? 0 : cast binding.window.getMonitorHeight(monitor);

	public static function windowGetMonitorPosition(monitor:Int):RLVec2
		return binding == null ? vec2() : cast binding.window.getMonitorPosition(monitor);

	public static function windowGetPosition():RLVec2
		return binding == null ? vec2() : cast binding.window.getPosition();

	public static function windowSetPosition(x:Int, y:Int):Void {
		if (binding != null)
			binding.window.setPosition(x, y);
	}

	public static function camera3dCreate(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float,
			upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle
		return binding == null ? 0 : cast binding.camera3d.create(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

	public static function camera3dSet(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float,
			upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool
		return binding != null
			&& cast binding.camera3d.set(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

	public static function camera3dSetActive(camera:RLHandle):Bool
		return binding != null && cast binding.camera3d.setActive(camera);

	public static function camera3dDestroy(camera:RLHandle):Void {
		if (binding != null)
			binding.camera3d.destroy(camera);
	}

	public static function modelGetDefaultAsset():RLHandle
		return binding == null ? 0 : cast binding.model.getDefaultAsset();

	public static function modelLoadAsset(filename:String):RLHandle
		return binding == null ? 0 : cast binding.model.loadAsset(filename);

	public static function modelDestroyAsset(asset:RLHandle):Void {
		if (binding != null)
			binding.model.destroyAsset(asset);
	}

	public static function modelCreate(asset:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.model.create(asset);

	public static function modelCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.model.createFromFile(filename);

	public static function modelSetAsset(model:RLHandle, asset:RLHandle):Bool
		return binding != null && cast binding.model.setAsset(model, asset);

	public static function modelSetTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float,
			rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool
		return binding != null
			&& cast binding.model.setTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);

	public static function modelSetVisible(model:RLHandle, visible:Bool):Bool
		return binding != null && cast binding.model.setVisible(model, visible);

	public static function modelSetPickable(model:RLHandle, pickable:Bool):Bool
		return binding != null && cast binding.model.setPickable(model, pickable);

	public static function modelIsVisible(model:RLHandle):Bool
		return binding == null ? false : cast binding.model.isVisible(model);

	public static function modelIsPickable(model:RLHandle):Bool
		return binding == null ? false : cast binding.model.isPickable(model);

	public static function modelDraw(model:RLHandle):Void {
		if (binding != null)
			binding.model.draw(model);
	}

	public static function modelSetAnimation(model:RLHandle, animationIndex:Int):Bool
		return binding != null && cast binding.model.setAnimation(model, animationIndex);

	public static function modelSetAnimationSpeed(model:RLHandle, speed:Float):Bool
		return binding != null && cast binding.model.setAnimationSpeed(model, speed);

	public static function modelSetAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool
		return binding != null && cast binding.model.setAnimationLoop(model, shouldLoop);

	public static function modelSetTint(model:RLHandle, color:RLHandle):Bool
		return binding != null && cast binding.model.setTint(model, color);

	public static function modelAnimate(model:RLHandle, deltaSeconds:Float):Bool
		return binding != null && cast binding.model.animate(model, deltaSeconds);

	public static function modelDestroy(model:RLHandle):Void {
		if (binding != null)
			binding.model.destroy(model);
	}

	public static function modelIsValid(model:RLHandle):Bool
		return binding == null ? false : cast binding.model.isValid(model);

	public static function modelIsValidStrict(model:RLHandle):Bool
		return binding == null ? false : cast binding.model.isValidStrict(model);

	public static function modelGetAnimationCount(model:RLHandle):Int
		return binding == null ? 0 : cast binding.model.getAnimationCount(model);

	public static function modelGetAnimationFrameCount(model:RLHandle, animationIndex:Int):Int
		return binding == null ? 0 : cast binding.model.getAnimationFrameCount(model, animationIndex);

	public static function modelUpdateAnimation(model:RLHandle, animationIndex:Int, frame:Int):Void {
		if (binding != null)
			binding.model.updateAnimation(model, animationIndex, frame);
	}

	public static function camera3dGetDefault():RLHandle
		return binding == null ? 0 : cast binding.camera3d.getDefault();

	public static function camera3dGetActive():RLHandle
		return binding == null ? 0 : cast binding.camera3d.getActive();

	public static function fontGetDefault():RLHandle
		return binding == null ? 0 : cast binding.font.getDefault();

	public static function textureGetDefault():RLHandle
		return binding == null ? 0 : cast binding.texture.getDefault();

	public static function sprite3dGetDefaultTexture():RLHandle
		return binding == null ? 0 : cast binding.sprite3d.getDefaultTexture();

	public static function sprite3dGetTransform(sprite:RLHandle):RLSprite3dTransform
		return binding == null ? sprite3dTransformIdentity() : toSprite3dTransform(binding.sprite3d.getTransform(sprite));

	public static function shapeDrawRectangle(x:Int, y:Int, width:Int, height:Int, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawRectangle(x, y, width, height, color);
	}

	public static function shapeCreate():RLHandle
		return binding == null ? 0 : cast binding.shape.create();

	public static function shapeDestroy(shape:RLHandle):Void {
		if (binding != null)
			binding.shape.destroy(shape);
	}

	public static function shapeSetVisible(shape:RLHandle, visible:Bool):Bool
		return binding != null && cast binding.shape.setVisible(shape, visible);

	public static function shapeIsVisible(shape:RLHandle):Bool
		return binding != null && cast binding.shape.isVisible(shape);

	public static function shapeSetStrokeColor(shape:RLHandle, color:RLHandle):Bool
		return binding != null && cast binding.shape.setStrokeColor(shape, color);

	public static function shapeSetLine3d(shape:RLHandle, startX:Float, startY:Float, startZ:Float, endX:Float, endY:Float, endZ:Float):Bool
		return binding != null && cast binding.shape.setLine3d(shape, startX, startY, startZ, endX, endY, endZ);

	public static function shapeSetLineStrip3d(shape:RLHandle, points:Array<Float>):Bool
		return binding != null && cast binding.shape.setLineStrip3d(shape, points);

	public static function shapeSetRectangle3d(shape:RLHandle, centerX:Float, centerY:Float, centerZ:Float, width:Float, height:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float):Bool
		return binding != null && cast binding.shape.setRectangle3d(shape, centerX, centerY, centerZ, width, height, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle);

	public static function shapeDrawRectangle3d(centerX:Float, centerY:Float, centerZ:Float, width:Float, height:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawRectangle3d(centerX, centerY, centerZ, width, height, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color);
	}

	public static function shapeSetCube(shape:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, height:Float, length:Float):Bool
		return binding != null && cast binding.shape.setCube(shape, positionX, positionY, positionZ, width, height, length);

	public static function shapeSetCircle3d(shape:RLHandle, centerX:Float, centerY:Float, centerZ:Float, radius:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float):Bool
		return binding != null && cast binding.shape.setCircle3d(shape, centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle);

	public static function shapeSetSphere(shape:RLHandle, centerX:Float, centerY:Float, centerZ:Float, radius:Float):Bool
		return binding != null && cast binding.shape.setSphere(shape, centerX, centerY, centerZ, radius);

	public static function shapeDrawSphere(centerX:Float, centerY:Float, centerZ:Float, radius:Float, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawSphere(centerX, centerY, centerZ, radius, color);
	}

	public static function shapeSetTransform(shape:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool
		return binding != null && cast binding.shape.setTransform(shape, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);

	public static function shapeDraw(shape:RLHandle):Void {
		if (binding != null)
			binding.shape.draw(shape);
	}

	public static function shapeDrawCube(positionX:Float, positionY:Float, positionZ:Float, width:Float, height:Float, length:Float, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawCube(positionX, positionY, positionZ, width, height, length, color);
	}

	public static function shapeDrawCircle3d(centerX:Float, centerY:Float, centerZ:Float, radius:Float, rotationAxisX:Float, rotationAxisY:Float, rotationAxisZ:Float, rotationAngle:Float, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawCircle3d(centerX, centerY, centerZ, radius, rotationAxisX, rotationAxisY, rotationAxisZ, rotationAngle, color);
	}

	public static function shapeDrawLine3d(startX:Float, startY:Float, startZ:Float, endX:Float, endY:Float, endZ:Float, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawLine3d(startX, startY, startZ, endX, endY, endZ, color);
	}

	public static function shapeDrawLineStrip3d(points:Array<Float>, color:RLHandle):Void {
		if (binding != null)
			binding.shape.drawLineStrip3d(points, color);
	}

	public static function debugEnableFps(x:Int, y:Int, fontSize:Int, font:RLHandle):Void {
		if (binding != null)
			binding.debug.enableFps(x, y, fontSize, font);
	}

	public static function debugDisableFps():Void {
		if (binding != null)
			binding.debug.disableFps();
	}

	public static function eventOn(eventName:String, callback:Dynamic->Void):Int
		return binding == null ? -1 : cast binding.event.on(eventName, callback);

	public static function eventOnce(eventName:String, callback:Dynamic->Void):Int
		return binding == null ? -1 : cast binding.event.once(eventName, callback);

	public static function eventOff(eventName:String, callback:Dynamic->Void):Int
		return binding == null ? -1 : cast binding.event.off(eventName, callback);

	public static function eventOffAll(eventName:String):Int
		return binding == null ? -1 : cast binding.event.offAll(eventName);

	public static function eventEmit(eventName:String, ?payload:Int):Int
		return binding == null ? -1 : cast binding.event.emit(eventName, payload == null ? 0 : payload);

	public static function eventListenerCount(eventName:String):Int
		return binding == null ? 0 : cast binding.event.listenerCount(eventName);

	public static function sprite3dCreate(texture:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.sprite3d.create(texture);

	public static function sprite3dCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.sprite3d.createFromFile(filename);

	public static function sprite3dSetTexture(sprite:RLHandle, texture:RLHandle):Bool
		return binding != null && cast binding.sprite3d.setTexture(sprite, texture);

	public static function sprite3dSetTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float, rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool
		return binding != null && cast binding.sprite3d.setTransform(sprite, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);

	public static function sprite3dSetVisible(sprite:RLHandle, visible:Bool):Bool
		return binding != null && cast binding.sprite3d.setVisible(sprite, visible);

	public static function sprite3dSetPickable(sprite:RLHandle, pickable:Bool):Bool
		return binding != null && cast binding.sprite3d.setPickable(sprite, pickable);

	public static function sprite3dIsVisible(sprite:RLHandle):Bool
		return binding == null ? false : cast binding.sprite3d.isVisible(sprite);

	public static function sprite3dIsPickable(sprite:RLHandle):Bool
		return binding == null ? false : cast binding.sprite3d.isPickable(sprite);

	public static function sprite3dSetSize(sprite:RLHandle, size:Float):Bool
		return binding != null && cast binding.sprite3d.setSize(sprite, size);

	public static function sprite3dSetFacing(sprite:RLHandle, facing:RLSprite3dFacing):Bool
		return binding != null && cast binding.sprite3d.setFacing(sprite, facing);

	public static function sprite3dSetTint(sprite:RLHandle, color:RLHandle = 0):Bool
		return binding != null && cast binding.sprite3d.setTint(sprite, color);

	public static function sprite3dDraw(sprite:RLHandle):Void {
		if (binding != null)
			binding.sprite3d.draw(sprite);
	}

	public static function sprite3dDestroy(sprite:RLHandle):Void {
		if (binding != null)
			binding.sprite3d.destroy(sprite);
	}

	public static function sprite2dCreate(texture:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.sprite2d.create(texture);

	public static function sprite2dCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.sprite2d.createFromFile(filename);

	public static function sprite2dSetTexture(sprite:RLHandle, texture:RLHandle):Bool
		return binding != null && cast binding.sprite2d.setTexture(sprite, texture);

	public static function sprite2dSetTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool
		return binding != null && cast binding.sprite2d.setTransform(sprite, x, y, scale, rotation);

	public static function sprite2dSetVisible(sprite:RLHandle, visible:Bool):Bool
		return binding != null && cast binding.sprite2d.setVisible(sprite, visible);

	public static function sprite2dSetPickable(sprite:RLHandle, pickable:Bool):Bool
		return binding != null && cast binding.sprite2d.setPickable(sprite, pickable);

	public static function sprite2dIsVisible(sprite:RLHandle):Bool
		return binding == null ? false : cast binding.sprite2d.isVisible(sprite);

	public static function sprite2dIsPickable(sprite:RLHandle):Bool
		return binding == null ? false : cast binding.sprite2d.isPickable(sprite);

	public static function sprite2dSetTint(sprite:RLHandle, color:RLHandle = 0):Bool
		return binding != null && cast binding.sprite2d.setTint(sprite, color);

	public static function sprite2dDraw(sprite:RLHandle):Void {
		if (binding != null)
			binding.sprite2d.draw(sprite);
	}

	public static function sprite2dDestroy(sprite:RLHandle):Void {
		if (binding != null)
			binding.sprite2d.destroy(sprite);
	}

	public static function sprite2dGetDefaultTexture():RLHandle
		return binding == null ? 0 : cast binding.sprite2d.getDefaultTexture();

	public static function text2dCreate(font:RLHandle, size:Float):RLHandle
		return binding == null ? 0 : cast binding.text2d.create(font, size);

	public static function text2dSetFont(handle:RLHandle, font:RLHandle):Void {
		if (binding != null)
			binding.text2d.setFont(handle, font);
	}

	public static function text2dSetSize(handle:RLHandle, size:Float):Void {
		if (binding != null)
			binding.text2d.setSize(handle, size);
	}

	public static function text2dSetContent(handle:RLHandle, content:String):Void {
		if (binding != null)
			binding.text2d.setContent(handle, content);
	}

	public static function text2dSetPosition(handle:RLHandle, x:Float, y:Float):Void {
		if (binding != null)
			binding.text2d.setPosition(handle, x, y);
	}

	public static function text2dSetColor(handle:RLHandle, color:RLHandle):Void {
		if (binding != null)
			binding.text2d.setColor(handle, color);
	}

	public static function text2dSetVisible(handle:RLHandle, visible:Bool):Bool
		return binding != null && cast binding.text2d.setVisible(handle, visible);

	public static function text2dSetPickable(handle:RLHandle, pickable:Bool):Bool
		return binding != null && cast binding.text2d.setPickable(handle, pickable);

	public static function text2dIsVisible(handle:RLHandle):Bool
		return binding == null ? false : cast binding.text2d.isVisible(handle);

	public static function text2dIsPickable(handle:RLHandle):Bool
		return binding == null ? false : cast binding.text2d.isPickable(handle);

	public static function text2dDraw(handle:RLHandle):Void {
		if (binding != null)
			binding.text2d.draw(handle);
	}

	public static function text2dDestroy(handle:RLHandle):Void {
		if (binding != null)
			binding.text2d.destroy(handle);
	}

	public static function textureCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.texture.create(filename);

	public static function textureDestroy(texture:RLHandle):Void {
		if (binding != null)
			binding.texture.destroy(texture);
	}

	public static function textureDrawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void {
		if (binding != null)
			binding.texture.drawEx(texture, x, y, scale, rotation, tint);
	}

	public static function textureDrawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float,
			tint:RLHandle):Void {
		if (binding != null)
			binding.texture.drawGround(texture, positionX, positionY, positionZ, width, length, tint);
	}

	public static function inputPollEvents():Void {
		if (binding != null)
			binding.input.pollEvents();
	}

	public static function inputCaptureCursor():Void {
		if (binding != null)
			binding.input.captureCursor();
	}

	public static function inputReleaseCursor():Void {
		if (binding != null)
			binding.input.releaseCursor();
	}

	public static function inputGetMousePosition():RLVec2
		return binding == null ? vec2() : cast binding.input.getMousePosition();

	public static function inputGetMouseDelta():RLVec2
		return binding == null ? vec2() : cast binding.input.getMouseDelta();

	public static function inputGetMouseWheel():Int
		return binding == null ? 0 : cast binding.input.getMouseWheel();

	public static function inputGetMouseButton(button:Int):Int
		return binding == null ? 0 : cast binding.input.getMouseButton(button);

	public static function inputGetMouseState():RLMouseState
		return binding == null ? mouseState() : toMouseState(binding.input.getMouseState());

	public static function inputGetKeyboardState():RLKeyboardState
		return binding == null ? new RLKeyboardState() : toKeyboardState(binding.input.getKeyboardState());

	public static function inputGetGamepads():Array<RLGamepad> {
		if (binding == null)
			return [];
		return toGamepads(binding.input.getGamepads());
	}

	public static function inputGetGamepad(id:Int):Null<RLGamepad> {
		if (binding == null)
			return null;
		return toGamepad(binding.input.getGamepad(id));
	}

	public static function inputGetTouchpoints():Array<RLTouchpoint> {
		if (binding == null)
			return [];
		return toTouchpoints(binding.input.getTouchpoints());
	}

	public static function inputGetTouchpoint(id:Int):Null<RLTouchpoint> {
		if (binding == null)
			return null;
		return toTouchpoint(binding.input.getTouchpoint(id));
	}

	@async
	public static function helpersWaitForTask(task:RLHandle, ?pollMs:Int):Int {
		if (binding == null)
			return -1;
		return cast binding.helpers.waitForTask(task, pollMs == null ? 16 : pollMs);
	}

	@async
	public static function helpersWaitForFsReady(?timeoutMs:Int):Bool {
		if (binding == null)
			return false;
		return cast binding.helpers.waitForFsReady(timeoutMs == null ? 2000 : timeoutMs);
	}

	public static function pickModel(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return binding == null ? pickResult() : toPickResult(binding.pick.model(camera, model, mouseX, mouseY));

	public static function pickSprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return binding == null ? pickResult() : toPickResult(binding.pick.sprite3d(camera, sprite3d, mouseX, mouseY));

	public static function pickResetStats():Void {
		if (binding != null)
			binding.pick.resetStats();
	}

	public static function pickGetBroadphaseTests():Int
		return binding == null ? 0 : cast binding.helpers.getPickStats().broadphaseTests;

	public static function pickGetBroadphaseRejects():Int
		return binding == null ? 0 : cast binding.helpers.getPickStats().broadphaseRejects;

	public static function pickGetNarrowphaseTests():Int
		return binding == null ? 0 : cast binding.helpers.getPickStats().narrowphaseTests;

	public static function pickGetNarrowphaseHits():Int
		return binding == null ? 0 : cast binding.helpers.getPickStats().narrowphaseHits;

	public static function sceneCreate():RLHandle
		return binding == null ? 0 : cast binding.scene.create();

	public static function sceneDestroy(scene:RLHandle):Void {
		if (binding != null)
			binding.scene.destroy(scene);
	}

	public static function sceneAdd(scene:RLHandle, drawable:RLHandle, layer:Int):Bool
		return binding != null && cast binding.scene.add(scene, drawable, layer);

	public static function sceneSetLayer(scene:RLHandle, drawable:RLHandle, layer:Int):Bool
		return binding != null && cast binding.scene.setLayer(scene, drawable, layer);

	public static function sceneRemove(scene:RLHandle, drawable:RLHandle):Bool
		return binding != null && cast binding.scene.remove(scene, drawable);

	public static function sceneClear(scene:RLHandle):Void {
		if (binding != null)
			binding.scene.clear(scene);
	}

	public static function sceneSetActiveCamera(scene:RLHandle, camera:RLHandle):Void {
		if (binding != null)
			binding.scene.setActiveCamera(scene, camera);
	}

	public static function sceneDraw(scene:RLHandle):Void {
		if (binding != null)
			binding.scene.draw(scene);
	}

	public static function scenePick(scene:RLHandle, camera:RLHandle, mouseX:Float, mouseY:Float):RLScenePickResult {
		return binding == null ? pickResult() : toPickResult(binding.scene.pick(scene, camera, mouseX, mouseY));
	}

	@async
	public static function fsInit(?baseDir:String):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(-1);
		}
		var path = baseDir == null ? "" : baseDir;
		return cast binding.fs.init(path);
	}

	public static function fsInitAsync(?baseDir:String):Int {
		if (binding == null) {
			return -1;
		}
		var path = baseDir == null ? "" : baseDir;
		return cast binding.fs.initAsync(path);
	}

	@async
	public static function fsDeinit():Promise<Void> {
		if (binding == null) {
			return Promise.resolve(null);
		}
		binding.fs.deinit();
		return Promise.resolve(null);
	}

	public static function fsDeinitAsync():RLHandle {
		return binding == null ? 0 : cast binding.fs.deinitAsync();
	}

	public static function fsIsInitialized():Bool {
		return binding != null && cast binding.fs.isInitialized();
	}

	public static function fsIsReady():Bool {
		return binding != null && cast binding.fs.isReady();
	}

	public static function fsFlush():Int {
		return binding == null ? -1 : cast binding.fs.flush();
	}

	public static function fsRestoreAsync():RLHandle {
		return binding == null ? 0 : cast binding.fs.restoreAsync();
	}

	public static function assetEnsureAsync(localPath:String, ?src:String):RLHandle {
		return binding == null ? 0 : cast binding.asset.ensureAsync(localPath, src);
	}

	public static function assetEnsure(localPath:String, ?src:String):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(-1);
		}
		return cast binding.asset.ensure(localPath, src);
	}

	public static function assetEnsureGroupAsync(filenames:Array<String>):RLHandle
		return binding == null ? 0 : cast binding.asset.ensureGroupAsync(filenames);

	public static function assetPollTask(task:RLHandle):Bool {
		return binding != null && cast binding.asset.pollTask(task);
	}

	public static function assetFinishTask(task:RLHandle):Int {
		return binding == null ? -1 : cast binding.asset.finishTask(task);
	}

	public static function assetGetTaskPath(task:RLHandle):String {
		return binding == null ? "" : cast binding.asset.getTaskPath(task);
	}

	public static function fsRead(filename:String):Bytes {
		if (binding == null)
			return null;
		var d = binding.fs.read(filename);
		return d == null ? null : Bytes.ofData(cast d);
	}

	public static function fsWrite(path:String, bytes:Bytes):Int {
		if (binding == null)
			return -1;
		return cast binding.fs.write(path, bytes == null ? null : bytes.getData());
	}

	public static function fsMkdir(path:String):Int {
		return binding == null ? -1 : cast binding.fs.mkdir(path);
	}

	public static function fsRmdir(path:String):Int {
		return binding == null ? -1 : cast binding.fs.rmdir(path);
	}

	public static function assetFreeTask(task:RLHandle):Void {
		if (binding != null)
			binding.asset.freeTask(task);
	}

	public static function fsExists(filename:String):Bool {
		return binding != null && cast binding.fs.exists(filename);
	}

	public static function assetPingHost(?assetHost:String):Float {
		var host = assetHost == null ? "" : assetHost;
		return binding == null ? -1 : cast binding.asset.pingHost(host);
	}

	public static function fsGetRootDir():String {
		return binding == null ? "" : cast binding.fs.getRootDir();
	}

	public static function fsNormalizePath(path:String):String {
		return binding == null ? "" : cast binding.fs.normalizePath(path);
	}

	public static function assetTaskInvalid():RLHandle
		return 0;

	public static function assetTaskIsValid(task:RLHandle):Bool
		return task != 0;

	public static function assetAddTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int
		return binding == null ? ASSET_ADD_TASK_ERR_INVALID : cast binding.asset.addTask(task, onSuccess, onFailure, ctx);

	public static function assetTick():Void {
		if (binding != null)
			binding.asset.tick();
	}

	public static function fsClear():Int {
		return binding == null ? -1 : cast binding.fs.clear();
	}

	public static function fsRemove(filename:String):Int {
		return binding == null ? -1 : cast binding.fs.remove(filename);
	}

	public static function loggerMessage(level:Int, message:String):Void {
		if (binding != null)
			binding.logger.message(level, message);
		else
			js.Syntax.code("console.log({0})", message);
	}

	public static function loggerMessageSource(level:Int, sourceFile:String, sourceLine:Int, message:String):Void {
		if (binding != null)
			binding.logger.messageSource(level, sourceFile, sourceLine, message);
	}

	public static function loggerSetLevel(level:Int):Void {
		if (binding != null)
			binding.logger.setLevel(level);
	}

	static inline function vec2():RLVec2 {
		return {x: 0.0, y: 0.0};
	}

	static inline function mouseState():RLMouseState {
		return {
			x: 0,
			y: 0,
			wheel: 0,
			left: 0,
			right: 0,
			middle: 0,
			dx: 0,
			dy: 0
		};
	}

	static inline function unimplementedHaxeJsBackend<T>():T {
		throw "Unimplemented in Haxe JS backend, requires struct returns or scratch-bridge support from librl";
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

	private static function normalizeInitConfig(?config:RLInitConfig):{
		var width:Int;
		var height:Int;
		var title:String;
		var flags:Int;
		var assetHost:String;
		var fsRootDir:String;
	} {
		return {
			width: config != null && config.windowWidth != null ? config.windowWidth : 0,
			height: config != null && config.windowHeight != null ? config.windowHeight : 0,
			title: config != null && config.windowTitle != null ? config.windowTitle : "",
			flags: config != null && config.windowFlags != null ? config.windowFlags : 0,
			assetHost: config != null && config.assetHost != null ? config.assetHost : "",
			fsRootDir: config != null && config.fsRootDir != null ? config.fsRootDir : ""};
	}

	static inline function pickResult():RLPickResult {
		return {
			hit: false,
			handle: 0,
			distance: 0.0,
			point: {x: 0.0, y: 0.0, z: 0.0},
			normal: {x: 0.0, y: 0.0, z: 0.0}
		};
	}

	static function toMouseState(value:Dynamic):RLMouseState {
		if (value == null) {
			return mouseState();
		}
		return {
			x: Std.int(value.x),
			y: Std.int(value.y),
			wheel: Std.int(value.wheel),
			left: Std.int(value.left),
			right: Std.int(value.right),
			middle: Std.int(value.middle),
			dx: Std.int(value.dx),
			dy: Std.int(value.dy)
		};
	}

	static function toKeyboardState(value:Dynamic):RLKeyboardState {
		var out = new RLKeyboardState();
		if (value == null) {
			return out;
		}
		out.max_num_keys = value.max_num_keys;
		out.keys = cast value.keys;
		out.pressed_key = value.pressed_key;
		out.pressed_char = value.pressed_char;
		out.num_pressed_keys = value.num_pressed_keys;
		out.pressed_keys = cast value.pressed_keys;
		out.num_pressed_chars = value.num_pressed_chars;
		out.pressed_chars = cast value.pressed_chars;
		return out;
	}

	
	static inline function sprite3dTransformIdentity():RLSprite3dTransform {
		return {positionX: 0.0, positionY: 0.0, positionZ: 0.0, rotationX: 0.0, rotationY: 0.0, rotationZ: 0.0, scaleX: 0.0, scaleY: 0.0,scaleZ: 1.0 };
	}
	

	static function toSprite3dTransform(value:Dynamic):RLSprite3dTransform {
		if (value == null) {
			return sprite3dTransformIdentity();
		}
		return {
			positionX: value.positionX,
			positionY: value.positionY,
			positionZ: value.positionZ,
			rotationX: value.rotationX,
			rotationY: value.rotationY,
			rotationZ: value.rotationZ,			
			scaleX: value.scaleX,
			scaleY: value.scaleY,
			scaleZ: value.scaleZ,
		};
	}

	static function toGamepads(value:Dynamic):Array<RLGamepad> {
		if (value == null) {
			return [];
		}
		var out:Array<RLGamepad> = [];
		var len:Int = cast js.Syntax.code("{0}.length", value);
		for (i in 0...len) {
			out.push(toGamepad(js.Syntax.code("{0}[{1}]", value, i)));
		}
		return out;
	}

	static function toGamepad(value:Dynamic):Null<RLGamepad> {
		if (value == null) {
			return null;
		}
		return {
			id: value.id,
			axis: copyFloatArray(value.axis),
			buttons: copyIntArray(value.buttons)
		};
	}

	static function toTouchpoints(value:Dynamic):Array<RLTouchpoint> {
		if (value == null) {
			return [];
		}
		var out:Array<RLTouchpoint> = [];
		var len:Int = cast js.Syntax.code("{0}.length", value);
		for (i in 0...len) {
			out.push(toTouchpoint(js.Syntax.code("{0}[{1}]", value, i)));
		}
		return out;
	}

	static function toTouchpoint(value:Dynamic):Null<RLTouchpoint> {
		if (value == null) {
			return null;
		}
		return {
			id: value.id,
			x: value.x,
			y: value.y
		};
	}

	static function copyFloatArray(value:Dynamic):Array<Float> {
		if (value == null) {
			return [];
		}
		var out:Array<Float> = [];
		var len:Int = cast js.Syntax.code("{0}.length", value);
		for (i in 0...len) {
			out.push(cast js.Syntax.code("{0}[{1}]", value, i));
		}
		return out;
	}

	static function copyIntArray(value:Dynamic):Array<Int> {
		if (value == null) {
			return [];
		}
		var out:Array<Int> = [];
		var len:Int = cast js.Syntax.code("{0}.length", value);
		for (i in 0...len) {
			out.push(cast js.Syntax.code("{0}[{1}]", value, i));
		}
		return out;
	}

	static function toPickResult(value:Dynamic):RLPickResult {
		if (value == null) {
			return pickResult();
		}
		return {
			hit: value.hit,
			handle: value.handle != null ? value.handle : 0,
			distance: value.distance,
			point: {
				x: value.point != null ? value.point.x : 0.0,
				y: value.point != null ? value.point.y : 0.0,
				z: value.point != null ? value.point.z : 0.0
			},
			normal: {
				x: value.normal != null ? value.normal.x : 0.0,
				y: value.normal != null ? value.normal.y : 0.0,
				z: value.normal != null ? value.normal.z : 0.0
			}
		};
	}
}
#end
