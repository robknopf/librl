package rl.impl;

#if js
import haxe.io.Bytes;
import js.lib.Promise;
import rl.RLHandle;
import rl.RLTaskGroup;
import rl.RLTaskGroup.RLTaskGroupCallback;
import rl.RLTypes.RLBootConfig;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLKeyboardState;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLPickResult;
import rl.RLTypes.RLVec2;
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
	public static inline var BOOT_ERR_UNKNOWN:Int = -1;
	public static inline var BOOT_ERR_VERSION_MISMATCH:Int = -2;

	public static inline var TICK_RUNNING:Int = 0;
	public static inline var TICK_WAITING:Int = 1;
	public static inline var TICK_FAILED:Int = -1;

	public static inline var FLAG_WINDOW_RESIZABLE:Int = 0x00000004;
	public static inline var FLAG_MSAA_4X_HINT:Int = 0x00000020;
	public static inline var FLAG_VSYNC_HINT:Int = 0x00000040;

	public static inline var CAMERA_PERSPECTIVE:Int = 0;
	public static inline var CAMERA_ORTHOGRAPHIC:Int = 1;

	public static inline var FILEIO_ADD_TASK_OK:Int = 0;
	public static inline var FILEIO_ADD_TASK_ERR_INVALID:Int = -1;
	public static inline var FILEIO_ADD_TASK_ERR_QUEUE_FULL:Int = -2;

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

	private static function maybeCacheBustBindingsPath(path:String):String {
		#if debug
		var separator = path.indexOf("?") >= 0 ? "&" : "?";
		return path + separator + "t=" + Std.string(Date.now().getTime());
		#else
		return path;
		#end
	}

	@async
	public static function boot(?config:RLBootConfig):Promise<Int> {
		if (binding != null) {
			return Promise.resolve(INIT_OK);
		}
		if (bootPromise != null) {
			return bootPromise;
		}

		if (!hasJspiSupport()) {
			return Promise.resolve(INIT_ERR_UNKNOWN);
		}

		var bootOptions = buildBootOptions(config);
		var bindingsPath = maybeCacheBustBindingsPath(optionString(bootOptions, "bindingsPath", "/bindings/js/rl.js"));

		bootPromise = cast js.Syntax.code("(async () => {
        try {
          const lib = await import( /* @vite-ignore */ {0});
          const rl = lib.rl;
          if (!rl || typeof rl.boot !== 'function') throw new Error('bindings/js/rl.js missing named rl export');
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
		var rc:Int = cast js.Syntax.code("await {0}", bootPromise);
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
		COLOR_DEFAULT = cast js.Syntax.code("{0}.COLOR_DEFAULT", binding);
		COLOR_LIGHTGRAY = cast js.Syntax.code("{0}.COLOR_LIGHTGRAY", binding);
		COLOR_GRAY = cast js.Syntax.code("{0}.COLOR_GRAY", binding);
		COLOR_YELLOW = cast js.Syntax.code("{0}.COLOR_YELLOW", binding);
		COLOR_GOLD = cast js.Syntax.code("{0}.COLOR_GOLD", binding);
		COLOR_ORANGE = cast js.Syntax.code("{0}.COLOR_ORANGE", binding);
		COLOR_PINK = cast js.Syntax.code("{0}.COLOR_PINK", binding);
		COLOR_RED = cast js.Syntax.code("{0}.COLOR_RED", binding);
		COLOR_MAROON = cast js.Syntax.code("{0}.COLOR_MAROON", binding);
		COLOR_GREEN = cast js.Syntax.code("{0}.COLOR_GREEN", binding);
		COLOR_LIME = cast js.Syntax.code("{0}.COLOR_LIME", binding);
		COLOR_DARKGREEN = cast js.Syntax.code("{0}.COLOR_DARKGREEN", binding);
		COLOR_SKYBLUE = cast js.Syntax.code("{0}.COLOR_SKYBLUE", binding);
		COLOR_BLUE = cast js.Syntax.code("{0}.COLOR_BLUE", binding);
		COLOR_DARKBLUE = cast js.Syntax.code("{0}.COLOR_DARKBLUE", binding);
		COLOR_PURPLE = cast js.Syntax.code("{0}.COLOR_PURPLE", binding);
		COLOR_VIOLET = cast js.Syntax.code("{0}.COLOR_VIOLET", binding);
		COLOR_DARKPURPLE = cast js.Syntax.code("{0}.COLOR_DARKPURPLE", binding);
		COLOR_BEIGE = cast js.Syntax.code("{0}.COLOR_BEIGE", binding);
		COLOR_BROWN = cast js.Syntax.code("{0}.COLOR_BROWN", binding);
		COLOR_DARKBROWN = cast js.Syntax.code("{0}.COLOR_DARKBROWN", binding);
		COLOR_DARKGRAY = cast js.Syntax.code("{0}.COLOR_DARKGRAY", binding);
		COLOR_WHITE = cast js.Syntax.code("{0}.COLOR_WHITE", binding);
		COLOR_BLANK = cast js.Syntax.code("{0}.COLOR_BLANK", binding);
		COLOR_MAGENTA = cast js.Syntax.code("{0}.COLOR_MAGENTA", binding);
		COLOR_RAYWHITE = cast js.Syntax.code("{0}.COLOR_RAYWHITE", binding);
		COLOR_BLACK = cast js.Syntax.code("{0}.COLOR_BLACK", binding);
	}

	public static function init(?config:RLInitConfig):Promise<Int> {
		var values = normalizeInitConfig(config);
		return initValues(values.width, values.height, values.title, values.flags, values.assetHost, values.fileioBaseDir);
	}

	public static function initAsync(?config:RLInitConfig):Int {
		if (binding == null) {
			return INIT_ERR_UNKNOWN;
		}
		var values = normalizeInitConfig(config);
		return initValuesAsync(values.width, values.height, values.title, values.flags, values.assetHost, values.fileioBaseDir);
	}

	public static function initValues(width:Int, height:Int, title:String, flags:Int = 0, assetHost:String = "", fileioBaseDir:String = ""):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(INIT_ERR_UNKNOWN);
		}
		return cast binding.initValues(width, height, title, flags, assetHost, fileioBaseDir);
	}

	public static function initValuesAsync(width:Int, height:Int, title:String, flags:Int = 0, assetHost:String = "", fileioBaseDir:String = ""):Int {
		if (binding == null) {
			return INIT_ERR_UNKNOWN;
		}
		return cast binding.initValuesAsync(width, height, title, flags, assetHost, fileioBaseDir);
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

	public static function versionMajor():Int {
		return binding == null ? 0 : cast binding.versionMajor();
	}

	public static function versionMinor():Int {
		return binding == null ? 0 : cast binding.versionMinor();
	}

	public static function versionPatch():Int {
		return binding == null ? 0 : cast binding.versionPatch();
	}

	public static function versionLabel():String {
		return binding == null ? "unknown" : cast binding.versionLabel();
	}

	public static function versionNumber():Int {
		return binding == null ? 0 : cast binding.versionNumber();
	}

	public static function versionString():String {
		return binding == null ? "0.0.0-unknown" : cast binding.versionString();
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

	public static function scratchRefresh():Void {
		if (binding != null)
			binding.refreshScratch();
	}

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
		return cast binding.createColor(r, g, b, a);
	}

	public static function colorDestroy(color:RLHandle):Void {
		if (binding != null)
			binding.destroyColor(color);
	}

	public static function fontCreate(filename:String, fontSize:Int):RLHandle
		return binding == null ? 0 : cast binding.createFont(filename, fontSize);

	public static function fontDestroy(font:RLHandle):Void {
		if (binding != null)
			binding.destroyFont(font);
	}

	public static function textDraw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void {
		if (binding != null)
			binding.drawText(text, x, y, fontSize, color);
	}

	public static function textMeasure(text:String, fontSize:Int):Int
		return binding == null ? 0 : cast binding.measureText(text, fontSize);

	public static function textDrawFps(x:Int, y:Int):Void {
		if (binding != null)
			binding.drawFPS(x, y);
	}

	public static function textDrawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void {
		if (binding != null)
			binding.drawTextEx(font, text, x, y, fontSize, spacing, color);
	}

	public static function textMeasureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2
		return binding == null ? vec2() : cast binding.measureTextEx(font, text, fontSize, spacing);

	public static function textDrawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void {
		if (binding != null)
			binding.drawFPSEx(font, x, y, fontSize, color);
	}

	public static function setAssetHost(assetHost:String):Int {
		return binding == null ? -1 : cast binding.setAssetHost(assetHost);
	}

	public static function getAssetHost():String {
		return binding == null ? "" : cast binding.getAssetHost();
	}

	public static function musicCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createMusic(filename);

	public static function musicDestroy(music:RLHandle):Void {
		if (binding != null)
			binding.destroyMusic(music);
	}

	public static function musicPlay(music:RLHandle):Bool
		return binding != null && cast binding.playMusic(music);

	public static function musicPause(music:RLHandle):Bool
		return binding != null && cast binding.pauseMusic(music);

	public static function musicStop(music:RLHandle):Bool
		return binding != null && cast binding.stopMusic(music);

	public static function musicSetLoop(music:RLHandle, shouldLoop:Bool):Bool
		return binding != null && cast binding.setMusicLoop(music, shouldLoop);

	public static function musicSetVolume(music:RLHandle, volume:Float):Bool
		return binding != null && cast binding.setMusicVolume(music, volume);

	public static function musicIsPlaying(music:RLHandle):Bool
		return binding != null && cast binding.isMusicPlaying(music);

	public static function musicUpdate(music:RLHandle):Bool
		return binding != null && cast binding.updateMusic(music);

	public static function musicUpdateAll():Void {
		if (binding != null)
			binding.updateAllMusic();
	}

	public static function soundCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createSound(filename);

	public static function soundDestroy(sound:RLHandle):Void {
		if (binding != null)
			binding.destroySound(sound);
	}

	public static function soundPlay(sound:RLHandle):Bool
		return binding != null && cast binding.playSound(sound);

	public static function soundPause(sound:RLHandle):Bool
		return binding != null && cast binding.pauseSound(sound);

	public static function soundResume(sound:RLHandle):Bool
		return binding != null && cast binding.resumeSound(sound);

	public static function soundStop(sound:RLHandle):Bool
		return binding != null && cast binding.stopSound(sound);

	public static function soundSetVolume(sound:RLHandle, volume:Float):Bool
		return binding != null && cast binding.setSoundVolume(sound, volume);

	public static function soundSetPitch(sound:RLHandle, pitch:Float):Bool
		return binding != null && cast binding.setSoundPitch(sound, pitch);

	public static function soundSetPan(sound:RLHandle, pan:Float):Bool
		return binding != null && cast binding.setSoundPan(sound, pan);

	public static function soundIsPlaying(sound:RLHandle):Bool
		return binding != null && cast binding.isSoundPlaying(sound);

	public static function enableLighting():Void {
		if (binding != null)
			binding.enableLighting();
	}

	public static function disableLighting():Void {
		if (binding != null)
			binding.disableLighting();
	}

	public static function isLightingEnabled():Int
		return binding == null ? 0 : (cast binding.isLightingEnabled() ? 1 : 0);

	public static function setLightDirection(x:Float, y:Float, z:Float):Void {
		if (binding != null)
			binding.setLightDirection(x, y, z);
	}

	public static function setLightAmbient(ambient:Float):Void {
		if (binding != null)
			binding.setLightAmbient(ambient);
	}

	public static function renderBegin():Void {
		if (binding != null)
			binding.beginDrawing();
	}

	public static function renderEnd():Void {
		if (binding != null)
			binding.endDrawing();
	}

	public static function renderClearBackground(color:RLHandle):Void {
		if (binding != null)
			binding.clearBackground(color);
	}

	public static function renderBeginMode2D(camera:RLHandle):Void {
		if (binding != null)
			binding.beginMode2D(camera);
	}

	public static function renderEndMode2D():Void {
		if (binding != null)
			binding.endMode2D();
	}

	public static function renderBeginMode3d():Void {
		if (binding != null)
			binding.beginMode3d();
	}

	public static function renderEndMode3d():Void {
		if (binding != null)
			binding.endMode3d();
	}

	public static function windowCloseRequested():Bool
		return binding != null && cast binding.isWindowCloseRequested();

	public static function windowGetScreenSize():RLVec2
		return binding == null ? vec2() : cast binding.getScreenSize();

	public static function windowGetMonitorCount():Int
		return binding == null ? 0 : cast binding.getMonitorCount();

	public static function windowSetTitle(title:String):Void {
		if (binding != null)
			binding.setWindowTitle(title);
	}

	public static function windowSetSize(width:Int, height:Int):Void {
		if (binding != null)
			binding.setWindowSize(width, height);
	}

	public static function windowGetCurrentMonitor():Int
		return binding == null ? 0 : cast binding.getCurrentMonitor();

	public static function windowSetMonitor(monitor:Int):Void {
		if (binding != null)
			binding.setWindowMonitor(monitor);
	}

	public static function windowGetMonitorWidth(monitor:Int):Int
		return binding == null ? 0 : cast binding.getMonitorWidth(monitor);

	public static function windowGetMonitorHeight(monitor:Int):Int
		return binding == null ? 0 : cast binding.getMonitorHeight(monitor);

	public static function windowGetMonitorPosition(monitor:Int):RLVec2
		return binding == null ? vec2() : cast binding.getMonitorPosition(monitor);

	public static function windowGetPosition():RLVec2
		return binding == null ? vec2() : cast binding.getWindowPosition();

	public static function windowSetPosition(x:Int, y:Int):Void {
		if (binding != null)
			binding.setWindowPosition(x, y);
	}

	public static function camera3dCreate(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float,
			upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle
		return binding == null ? 0 : cast binding.createCamera3d(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

	public static function camera3dSet(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float,
			upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool
		return binding != null
			&& cast binding.setCamera3d(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);

	public static function camera3dSetActive(camera:RLHandle):Bool
		return binding != null && cast binding.setActiveCamera3d(camera);

	public static function camera3dDestroy(camera:RLHandle):Void {
		if (binding != null)
			binding.destroyCamera3d(camera);
	}

	public static function modelGetDefaultAsset():RLHandle
		return binding == null ? 0 : cast binding.modelGetDefaultAsset();

	public static function modelLoadAsset(filename:String):RLHandle
		return binding == null ? 0 : cast binding.modelLoadAsset(filename);

	public static function modelDestroyAsset(asset:RLHandle):Void {
		if (binding != null)
			binding.modelDestroyAsset(asset);
	}

	public static function modelCreate(asset:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.createModel(asset);

	public static function modelCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createModelFromFile(filename);

	public static function modelSetAsset(model:RLHandle, asset:RLHandle):Bool
		return binding != null && cast binding.modelSetAsset(model, asset);

	public static function modelSetTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float,
			rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool
		return binding != null
			&& cast binding.modelSetTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);

	public static function modelDraw(model:RLHandle, tint:RLHandle):Void {
		if (binding != null)
			binding.drawModel(model, tint);
	}

	public static function modelSetAnimation(model:RLHandle, animationIndex:Int):Bool
		return binding != null && cast binding.modelSetAnimation(model, animationIndex);

	public static function modelSetAnimationSpeed(model:RLHandle, speed:Float):Bool
		return binding != null && cast binding.modelSetAnimationSpeed(model, speed);

	public static function modelSetAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool
		return binding != null && cast binding.modelSetAnimationLoop(model, shouldLoop);

	public static function modelAnimate(model:RLHandle, deltaSeconds:Float):Bool
		return binding != null && cast binding.modelAnimate(model, deltaSeconds);

	public static function modelDestroy(model:RLHandle):Void {
		if (binding != null)
			binding.destroyModel(model);
	}

	public static function sprite3dGetDefaultTexture():RLHandle
		return binding == null ? 0 : cast binding.sprite3dGetDefaultTexture();

	public static function sprite3dCreate(texture:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.createSprite3d(texture);

	public static function sprite3dCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createSprite3dFromFile(filename);

	public static function sprite3dSetTexture(sprite:RLHandle, texture:RLHandle):Bool
		return binding != null && cast binding.sprite3dSetTexture(sprite, texture);

	public static function sprite3dSetTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, size:Float):Bool
		return binding != null && cast binding.sprite3dSetTransform(sprite, positionX, positionY, positionZ, size);

	public static function sprite3dDraw(sprite:RLHandle, tint:RLHandle):Void {
		if (binding != null)
			binding.drawSprite3d(sprite, tint);
	}

	public static function sprite3dDestroy(sprite:RLHandle):Void {
		if (binding != null)
			binding.destroySprite3d(sprite);
	}

	public static function sprite2dGetDefaultTexture():RLHandle
		return binding == null ? 0 : cast binding.sprite2dGetDefaultTexture();

	public static function sprite2dCreate(texture:RLHandle):RLHandle
		return binding == null ? 0 : cast binding.createSprite2D(texture);

	public static function sprite2dCreateFromFile(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createSprite2DFromFile(filename);

	public static function sprite2dSetTexture(sprite:RLHandle, texture:RLHandle):Bool
		return binding != null && cast binding.sprite2DSetTexture(sprite, texture);

	public static function sprite2dSetTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool
		return binding != null && cast binding.sprite2DSetTransform(sprite, x, y, scale, rotation);

	public static function sprite2dDraw(sprite:RLHandle, tint:RLHandle):Void {
		if (binding != null)
			binding.drawSprite2D(sprite, tint);
	}

	public static function sprite2dDestroy(sprite:RLHandle):Void {
		if (binding != null)
			binding.destroySprite2D(sprite);
	}

	public static function text2dCreate(font:RLHandle, size:Float):RLHandle
		return binding == null ? 0 : cast binding.createText2D(font, size);

	public static function text2dSetFont(handle:RLHandle, font:RLHandle):Void {
		if (binding != null)
			binding.text2DSetFont(handle, font);
	}

	public static function text2dSetSize(handle:RLHandle, size:Float):Void {
		if (binding != null)
			binding.text2DSetSize(handle, size);
	}

	public static function text2dSetContent(handle:RLHandle, content:String):Void {
		if (binding != null)
			binding.text2DSetContent(handle, content);
	}

	public static function text2dSetPosition(handle:RLHandle, x:Float, y:Float):Void {
		if (binding != null)
			binding.text2DSetPosition(handle, x, y);
	}

	public static function text2dSetColor(handle:RLHandle, color:RLHandle):Void {
		if (binding != null)
			binding.text2DSetColor(handle, color);
	}

	public static function text2dDraw(handle:RLHandle):Void {
		if (binding != null)
			binding.drawText2D(handle);
	}

	public static function text2dDestroy(handle:RLHandle):Void {
		if (binding != null)
			binding.destroyText2D(handle);
	}

	public static function textureCreate(filename:String):RLHandle
		return binding == null ? 0 : cast binding.createTexture(filename);

	public static function textureDestroy(texture:RLHandle):Void {
		if (binding != null)
			binding.destroyTexture(texture);
	}

	public static function textureDrawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void {
		if (binding != null)
			binding.drawTextureEx(texture, x, y, scale, rotation, tint);
	}

	public static function textureDrawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float,
			tint:RLHandle):Void {
		if (binding != null)
			binding.drawTextureGround(texture, positionX, positionY, positionZ, width, length, tint);
	}

	public static function inputPollEvents():Void {
		if (binding != null)
			binding.pollInputEvents();
	}

	public static function inputGetMousePosition():RLVec2
		return binding == null ? vec2() : cast binding.getMousePosition();

	public static function inputGetMouseWheel():Int
		return binding == null ? 0 : cast binding.getMouseWheel();

	public static function inputGetMouseButton(button:Int):Int
		return binding == null ? 0 : cast binding.getMouseButton(button);

	public static function inputGetMouseState():RLMouseState
		return binding == null ? mouseState() : toMouseState(binding.getMouseState());

	public static function inputGetKeyboardState():RLKeyboardState
		return binding == null ? new RLKeyboardState() : toKeyboardState(binding.getKeyboardState());

	public static function pickModel(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return binding == null ? pickResult() : toPickResult(binding.pickModel(camera, model, mouseX, mouseY));

	public static function pickSprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult
		return binding == null ? pickResult() : toPickResult(binding.pickSprite3d(camera, sprite3d, mouseX, mouseY));

	public static function pickResetStats():Void {
		if (binding != null)
			binding.resetPickStats();
	}

	public static function pickGetBroadphaseTests():Int
		return binding == null ? 0 : cast binding.getPickStats().broadphaseTests;

	public static function pickGetBroadphaseRejects():Int
		return binding == null ? 0 : cast binding.getPickStats().broadphaseRejects;

	public static function pickGetNarrowphaseTests():Int
		return binding == null ? 0 : cast binding.getPickStats().narrowphaseTests;

	public static function pickGetNarrowphaseHits():Int
		return binding == null ? 0 : cast binding.getPickStats().narrowphaseHits;

	@async
	public static function fileioInit(?baseDir:String):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(-1);
		}
		var path = baseDir == null ? "" : baseDir;
		return cast binding.fileioInit(path);
	}

	public static function fileioInitAsync(?baseDir:String):Int {
		if (binding == null) {
			return -1;
		}
		var path = baseDir == null ? "" : baseDir;
		return cast binding.fileioInitAsync(path);
	}

	@async
	public static function fileioDeinit():Promise<Void> {
		if (binding == null) {
			return Promise.resolve(null);
		}
		binding.fileioDeinit();
		return Promise.resolve(null);
	}

	public static function fileioIsInitialized():Bool {
		return binding != null && cast binding.fileioIsInitialized();
	}

	public static function fileioRestoreAsync():RLHandle {
		return binding == null ? 0 : cast binding.fileioRestoreAsync();
	}

	public static function fileioEnsureAsync(localPath:String, ?src:String):RLHandle {
		return binding == null ? 0 : cast binding.fileioEnsureAsync(localPath, src);
	}

	public static function fileioEnsure(localPath:String, ?src:String):Promise<Int> {
		if (binding == null) {
			return Promise.resolve(-1);
		}
		return cast binding.ensure(localPath, src);
	}

	public static function fileioEnsureGroupAsync(filenames:Array<String>):RLHandle
		return binding == null ? 0 : cast binding.fileioEnsureGroupAsync(filenames);

	public static function fileioPollTask(task:RLHandle):Bool {
		return binding != null && cast binding.fileioPollTask(task);
	}

	public static function fileioFinishTask(task:RLHandle):Int {
		return binding == null ? -1 : cast binding.fileioFinishTask(task);
	}

	public static function fileioGetTaskPath(task:RLHandle):String {
		return binding == null ? "" : cast binding.fileioGetTaskPath(task);
	}

	public static function fileioRead(filename:String):Bytes {
		if (binding == null)
			return null;
		var d = binding.fileioRead(filename);
		return d == null ? null : Bytes.ofData(cast d);
	}

	public static function fileioFreeTask(task:RLHandle):Void {
		if (binding != null)
			binding.fileioFreeTask(task);
	}

	public static function fileioExists(filename:String):Bool {
		return binding != null && cast binding.fileioExists(filename);
	}

	public static function fileioPingAssetHost(?assetHost:String):Float {
		var host = assetHost == null ? "" : assetHost;
		return binding == null ? -1 : cast binding.fileioPingAssetHost(host);
	}

	public static function fileioGetBaseDir():String {
		return binding == null ? "" : cast binding.fileioGetBaseDir();
	}

	public static function fileioCreateTaskGroup<T>(?onComplete:RLTaskGroupCallback<T>, ?onError:RLTaskGroupCallback<T>, ?ctx:T):RLTaskGroup
		return new RLTaskGroup(cast onComplete, cast onError, ctx);

	public static function fileioTaskInvalid():RLHandle
		return 0;

	public static function fileioTaskIsValid(task:RLHandle):Bool
		return task != 0;

	public static function fileioAddTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int
		return binding == null ? FILEIO_ADD_TASK_ERR_INVALID : cast binding.fileioAddTask(task, onSuccess, onFailure, ctx);

	public static function fileioTick():Void {
		if (binding != null)
			binding.fileioTick();
	}

	public static function fileioClear():Int {
		return binding == null ? -1 : cast binding.fileioClear();
	}

	public static function fileioRemove(filename:String):Int {
		return binding == null ? -1 : cast binding.fileioRemove(filename);
	}

	public static function loggerMessage(level:Int, message:String):Void {
		if (binding != null)
			binding.loggerMessage(level, message);
		else
			js.Syntax.code("console.log({0})", message);
	}

	public static function loggerSetLevel(level:Int):Void {
		if (binding != null)
			binding.loggerSetLevel(level);
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
			middle: 0
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
		var fileioBaseDir:String;
	} {
		return {
			width: config != null && config.windowWidth != null ? config.windowWidth : 0,
			height: config != null && config.windowHeight != null ? config.windowHeight : 0,
			title: config != null && config.windowTitle != null ? config.windowTitle : "",
			flags: config != null && config.windowFlags != null ? config.windowFlags : 0,
			assetHost: config != null && config.assetHost != null ? config.assetHost : "",
			fileioBaseDir: config != null && config.fileioBaseDir != null ? config.fileioBaseDir : ""};
	}

	static inline function pickResult():RLPickResult {
		return {
			hit: false,
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
			middle: Std.int(value.middle)
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

	static function toPickResult(value:Dynamic):RLPickResult {
		if (value == null) {
			return pickResult();
		}
		return {
			hit: value.hit,
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
