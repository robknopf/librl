/**
 * Haxe bindings for librl (Raylib wrapper).
 *
 * `rl.RL` is the public façade used by authored Haxe code.
 * It stays free of `cpp.*`, `@:native`, and `untyped __cpp__`.
 *
 * `RL.hx` delegates through `rl.impl.RLImpl`, which resolves by target:
 * - `RLImpl.cpp.hx` for hxcpp hosts
 * - `RLImpl.js.hx` for Haxe JS
 * - `RLImpl.hx` as the unsupported fallback
 */

package rl;

import haxe.io.Bytes;
import rl.RLTypes.RLBootConfig;
import rl.RLHandle;
import rl.RLTypes.RLInitConfig;
import rl.RLTypes.RLVec2;
import rl.RLTypes.RLPickResult;
import rl.RLTypes.RLMouseState;
import rl.RLTypes.RLKeyboardState;
import rl.RLTaskGroup;
import rl.RLTaskGroup.RLTaskGroupCallback;


	#if js
	//For js, we return promise<void>  instead of straight void
	typedef VoidResult = js.lib.Promise<Void>;
	#else
	typedef VoidResult = Void;
	#end

class RL {
	public static var INIT_OK(get, never):Int;

	static inline function get_INIT_OK():Int
		return rl.impl.RLImpl.INIT_OK;

	public static var INIT_ERR_UNKNOWN(get, never):Int;

	static inline function get_INIT_ERR_UNKNOWN():Int
		return rl.impl.RLImpl.INIT_ERR_UNKNOWN;

	public static var INIT_ERR_ALREADY_INITIALIZED(get, never):Int;

	static inline function get_INIT_ERR_ALREADY_INITIALIZED():Int
		return rl.impl.RLImpl.INIT_ERR_ALREADY_INITIALIZED;

	public static var INIT_ERR_LOADER(get, never):Int;

	static inline function get_INIT_ERR_LOADER():Int
		return rl.impl.RLImpl.INIT_ERR_LOADER;

	public static var INIT_ERR_ASSET_HOST(get, never):Int;

	static inline function get_INIT_ERR_ASSET_HOST():Int
		return rl.impl.RLImpl.INIT_ERR_ASSET_HOST;

	public static var INIT_ERR_WINDOW(get, never):Int;

	static inline function get_INIT_ERR_WINDOW():Int
		return rl.impl.RLImpl.INIT_ERR_WINDOW;

	public static var TICK_RUNNING(get, never):Int;

	static inline function get_TICK_RUNNING():Int
		return rl.impl.RLImpl.TICK_RUNNING;

	public static var TICK_WAITING(get, never):Int;

	static inline function get_TICK_WAITING():Int
		return rl.impl.RLImpl.TICK_WAITING;

	public static var TICK_FAILED(get, never):Int;

	static inline function get_TICK_FAILED():Int
		return rl.impl.RLImpl.TICK_FAILED;

	public static var FLAG_WINDOW_RESIZABLE(get, never):Int;

	static inline function get_FLAG_WINDOW_RESIZABLE():Int
		return rl.impl.RLImpl.FLAG_WINDOW_RESIZABLE;

	public static var FLAG_MSAA_4X_HINT(get, never):Int;

	static inline function get_FLAG_MSAA_4X_HINT():Int
		return rl.impl.RLImpl.FLAG_MSAA_4X_HINT;

	public static var FLAG_VSYNC_HINT(get, never):Int;

	static inline function get_FLAG_VSYNC_HINT():Int
		return rl.impl.RLImpl.FLAG_VSYNC_HINT;

	public static var CAMERA_PERSPECTIVE(get, never):Int;

	static inline function get_CAMERA_PERSPECTIVE():Int
		return rl.impl.RLImpl.CAMERA_PERSPECTIVE;

	public static var CAMERA_ORTHOGRAPHIC(get, never):Int;

	static inline function get_CAMERA_ORTHOGRAPHIC():Int
		return rl.impl.RLImpl.CAMERA_ORTHOGRAPHIC;

	public static var LOADER_QUEUE_TASK_OK(get, never):Int;

	static inline function get_LOADER_QUEUE_TASK_OK():Int
		return rl.impl.RLImpl.LOADER_QUEUE_TASK_OK;

	public static var LOADER_QUEUE_TASK_ERR_INVALID(get, never):Int;

	static inline function get_LOADER_QUEUE_TASK_ERR_INVALID():Int
		return rl.impl.RLImpl.LOADER_QUEUE_TASK_ERR_INVALID;

	public static var LOADER_QUEUE_TASK_ERR_QUEUE_FULL(get, never):Int;

	static inline function get_LOADER_QUEUE_TASK_ERR_QUEUE_FULL():Int
		return rl.impl.RLImpl.LOADER_QUEUE_TASK_ERR_QUEUE_FULL;

	public static var LOGGER_LEVEL_TRACE(get, never):Int;

	static inline function get_LOGGER_LEVEL_TRACE():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_TRACE;

	public static var LOGGER_LEVEL_DEBUG(get, never):Int;

	static inline function get_LOGGER_LEVEL_DEBUG():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_DEBUG;

	public static var LOGGER_LEVEL_INFO(get, never):Int;

	static inline function get_LOGGER_LEVEL_INFO():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_INFO;

	public static var LOGGER_LEVEL_WARN(get, never):Int;

	static inline function get_LOGGER_LEVEL_WARN():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_WARN;

	public static var LOGGER_LEVEL_ERROR(get, never):Int;

	static inline function get_LOGGER_LEVEL_ERROR():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_ERROR;

	public static var LOGGER_LEVEL_FATAL(get, never):Int;

	static inline function get_LOGGER_LEVEL_FATAL():Int
		return rl.impl.RLImpl.LOGGER_LEVEL_FATAL;

	public static var COLOR_DEFAULT(get, never):RLHandle;

	static inline function get_COLOR_DEFAULT():RLHandle
		return rl.impl.RLImpl.COLOR_DEFAULT;

	public static var COLOR_LIGHTGRAY(get, never):RLHandle;

	static inline function get_COLOR_LIGHTGRAY():RLHandle
		return rl.impl.RLImpl.COLOR_LIGHTGRAY;

	public static var COLOR_GRAY(get, never):RLHandle;

	static inline function get_COLOR_GRAY():RLHandle
		return rl.impl.RLImpl.COLOR_GRAY;

	public static var COLOR_YELLOW(get, never):RLHandle;

	static inline function get_COLOR_YELLOW():RLHandle
		return rl.impl.RLImpl.COLOR_YELLOW;

	public static var COLOR_GOLD(get, never):RLHandle;

	static inline function get_COLOR_GOLD():RLHandle
		return rl.impl.RLImpl.COLOR_GOLD;

	public static var COLOR_ORANGE(get, never):RLHandle;

	static inline function get_COLOR_ORANGE():RLHandle
		return rl.impl.RLImpl.COLOR_ORANGE;

	public static var COLOR_PINK(get, never):RLHandle;

	static inline function get_COLOR_PINK():RLHandle
		return rl.impl.RLImpl.COLOR_PINK;

	public static var COLOR_RED(get, never):RLHandle;

	static inline function get_COLOR_RED():RLHandle
		return rl.impl.RLImpl.COLOR_RED;

	public static var COLOR_MAROON(get, never):RLHandle;

	static inline function get_COLOR_MAROON():RLHandle
		return rl.impl.RLImpl.COLOR_MAROON;

	public static var COLOR_GREEN(get, never):RLHandle;

	static inline function get_COLOR_GREEN():RLHandle
		return rl.impl.RLImpl.COLOR_GREEN;

	public static var COLOR_LIME(get, never):RLHandle;

	static inline function get_COLOR_LIME():RLHandle
		return rl.impl.RLImpl.COLOR_LIME;

	public static var COLOR_DARKGREEN(get, never):RLHandle;

	static inline function get_COLOR_DARKGREEN():RLHandle
		return rl.impl.RLImpl.COLOR_DARKGREEN;

	public static var COLOR_SKYBLUE(get, never):RLHandle;

	static inline function get_COLOR_SKYBLUE():RLHandle
		return rl.impl.RLImpl.COLOR_SKYBLUE;

	public static var COLOR_BLUE(get, never):RLHandle;

	static inline function get_COLOR_BLUE():RLHandle
		return rl.impl.RLImpl.COLOR_BLUE;

	public static var COLOR_DARKBLUE(get, never):RLHandle;

	static inline function get_COLOR_DARKBLUE():RLHandle
		return rl.impl.RLImpl.COLOR_DARKBLUE;

	public static var COLOR_PURPLE(get, never):RLHandle;

	static inline function get_COLOR_PURPLE():RLHandle
		return rl.impl.RLImpl.COLOR_PURPLE;

	public static var COLOR_VIOLET(get, never):RLHandle;

	static inline function get_COLOR_VIOLET():RLHandle
		return rl.impl.RLImpl.COLOR_VIOLET;

	public static var COLOR_DARKPURPLE(get, never):RLHandle;

	static inline function get_COLOR_DARKPURPLE():RLHandle
		return rl.impl.RLImpl.COLOR_DARKPURPLE;

	public static var COLOR_BEIGE(get, never):RLHandle;

	static inline function get_COLOR_BEIGE():RLHandle
		return rl.impl.RLImpl.COLOR_BEIGE;

	public static var COLOR_BROWN(get, never):RLHandle;

	static inline function get_COLOR_BROWN():RLHandle
		return rl.impl.RLImpl.COLOR_BROWN;

	public static var COLOR_DARKBROWN(get, never):RLHandle;

	static inline function get_COLOR_DARKBROWN():RLHandle
		return rl.impl.RLImpl.COLOR_DARKBROWN;

	public static var COLOR_DARKGRAY(get, never):RLHandle;

	static inline function get_COLOR_DARKGRAY():RLHandle
		return rl.impl.RLImpl.COLOR_DARKGRAY;

	public static var COLOR_WHITE(get, never):RLHandle;

	static inline function get_COLOR_WHITE():RLHandle
		return rl.impl.RLImpl.COLOR_WHITE;

	public static var COLOR_BLANK(get, never):RLHandle;

	static inline function get_COLOR_BLANK():RLHandle
		return rl.impl.RLImpl.COLOR_BLANK;

	public static var COLOR_MAGENTA(get, never):RLHandle;

	static inline function get_COLOR_MAGENTA():RLHandle
		return rl.impl.RLImpl.COLOR_MAGENTA;

	public static var COLOR_RAYWHITE(get, never):RLHandle;

	static inline function get_COLOR_RAYWHITE():RLHandle
		return rl.impl.RLImpl.COLOR_RAYWHITE;

	public static var COLOR_BLACK(get, never):RLHandle;

	static inline function get_COLOR_BLACK():RLHandle
		return rl.impl.RLImpl.COLOR_BLACK;

	public static function boot(?config:RLBootConfig):Int {
		return cast rl.impl.RLImpl.boot(config);
	}

	@async
	public static function init(?config:RLInitConfig):Int {
		return cast rl.impl.RLImpl.init(config);
	}

	public static function initAsync(?config:RLInitConfig):Int {
		return rl.impl.RLImpl.initAsync(config);
	}

	public static function initValuesInt(width:Int, height:Int, title:String, flags:Int = 0, assetHost:String = "", loaderCacheDir:String = ""):Int {
		return cast rl.impl.RLImpl.initValues(width, height, title, flags, assetHost, loaderCacheDir);
	}

	@async
	public static function deinit():VoidResult{
		return rl.impl.RLImpl.deinit();
	}

	public static function isInitialized():Bool {
		return rl.impl.RLImpl.isInitialized();
	}

	public static function getPlatform():String {
		return rl.impl.RLImpl.getPlatform();
	}

	public static function scratchRefresh():Void {
		rl.impl.RLImpl.scratchRefresh();
	}

	public static function tick():Int {
		return rl.impl.RLImpl.tick();
	}

	public static function getDeltaTime():Float {
		return rl.impl.RLImpl.getDeltaTime();
	}

	public static function getTime():Float {
		return rl.impl.RLImpl.getTime();
	}

	public static function setTargetFps(fps:Int):Void {
		rl.impl.RLImpl.setTargetFps(fps);
	}

	public static function colorCreate(r:Int, g:Int, b:Int, a:Int):RLHandle {
		return rl.impl.RLImpl.colorCreate(r, g, b, a);
	}

	public static function colorDestroy(color:RLHandle):Void {
		rl.impl.RLImpl.colorDestroy(color);
	}

	public static function fontCreate(filename:String, fontSize:Int):RLHandle {
		return rl.impl.RLImpl.fontCreate(filename, fontSize);
	}

	public static function fontDestroy(font:RLHandle):Void {
		rl.impl.RLImpl.fontDestroy(font);
	}

	public static function textDraw(text:String, x:Int, y:Int, fontSize:Int, color:RLHandle):Void {
		rl.impl.RLImpl.textDraw(text, x, y, fontSize, color);
	}

	public static function textMeasure(text:String, fontSize:Int):Int {
		return rl.impl.RLImpl.textMeasure(text, fontSize);
	}

	public static function textDrawFps(x:Int, y:Int):Void {
		rl.impl.RLImpl.textDrawFps(x, y);
	}

	public static function textDrawEx(font:RLHandle, text:String, x:Int, y:Int, fontSize:Float, spacing:Float, color:RLHandle):Void {
		rl.impl.RLImpl.textDrawEx(font, text, x, y, fontSize, spacing, color);
	}

	public static function textMeasureEx(font:RLHandle, text:String, fontSize:Float, spacing:Float):RLVec2 {
		return rl.impl.RLImpl.textMeasureEx(font, text, fontSize, spacing);
	}

	public static function textDrawFpsEx(font:RLHandle, x:Int, y:Int, fontSize:Float, color:RLHandle):Void {
		rl.impl.RLImpl.textDrawFpsEx(font, x, y, fontSize, color);
	}

	public static function setAssetHost(assetHost:String):Int {
		return rl.impl.RLImpl.setAssetHost(assetHost);
	}

	public static function getAssetHost():String {
		return rl.impl.RLImpl.getAssetHost();
	}

	public static function musicCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.musicCreate(filename);
	}

	public static function musicDestroy(music:RLHandle):Void {
		rl.impl.RLImpl.musicDestroy(music);
	}

	public static function musicPlay(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicPlay(music);
	}

	public static function musicPause(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicPause(music);
	}

	public static function musicStop(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicStop(music);
	}

	public static function musicSetLoop(music:RLHandle, shouldLoop:Bool):Bool {
		return rl.impl.RLImpl.musicSetLoop(music, shouldLoop);
	}

	public static function musicSetVolume(music:RLHandle, volume:Float):Bool {
		return rl.impl.RLImpl.musicSetVolume(music, volume);
	}

	public static function musicIsPlaying(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicIsPlaying(music);
	}

	public static function musicUpdate(music:RLHandle):Bool {
		return rl.impl.RLImpl.musicUpdate(music);
	}

	public static function musicUpdateAll():Void {
		rl.impl.RLImpl.musicUpdateAll();
	}

	public static function soundCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.soundCreate(filename);
	}

	public static function soundDestroy(sound:RLHandle):Void {
		rl.impl.RLImpl.soundDestroy(sound);
	}

	public static function soundPlay(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundPlay(sound);
	}

	public static function soundPause(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundPause(sound);
	}

	public static function soundResume(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundResume(sound);
	}

	public static function soundStop(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundStop(sound);
	}

	public static function soundSetVolume(sound:RLHandle, volume:Float):Bool {
		return rl.impl.RLImpl.soundSetVolume(sound, volume);
	}

	public static function soundSetPitch(sound:RLHandle, pitch:Float):Bool {
		return rl.impl.RLImpl.soundSetPitch(sound, pitch);
	}

	public static function soundSetPan(sound:RLHandle, pan:Float):Bool {
		return rl.impl.RLImpl.soundSetPan(sound, pan);
	}

	public static function soundIsPlaying(sound:RLHandle):Bool {
		return rl.impl.RLImpl.soundIsPlaying(sound);
	}

	public static function enableLighting():Void {
		rl.impl.RLImpl.enableLighting();
	}

	public static function disableLighting():Void {
		rl.impl.RLImpl.disableLighting();
	}

	public static function isLightingEnabled():Int {
		return rl.impl.RLImpl.isLightingEnabled();
	}

	public static function setLightDirection(x:Float, y:Float, z:Float):Void {
		rl.impl.RLImpl.setLightDirection(x, y, z);
	}

	public static function setLightAmbient(ambient:Float):Void {
		rl.impl.RLImpl.setLightAmbient(ambient);
	}

	public static function renderBegin():Void {
		rl.impl.RLImpl.renderBegin();
	}

	public static function renderEnd():Void {
		rl.impl.RLImpl.renderEnd();
	}

	public static function renderClearBackground(color:RLHandle):Void {
		rl.impl.RLImpl.renderClearBackground(color);
	}

	public static function renderBeginMode2D(camera:RLHandle):Void {
		rl.impl.RLImpl.renderBeginMode2D(camera);
	}

	public static function renderEndMode2D():Void {
		rl.impl.RLImpl.renderEndMode2D();
	}

	public static function renderBeginMode3d():Void {
		rl.impl.RLImpl.renderBeginMode3d();
	}

	public static function renderEndMode3d():Void {
		rl.impl.RLImpl.renderEndMode3d();
	}

	public static function windowCloseRequested():Bool {
		return rl.impl.RLImpl.windowCloseRequested();
	}

	public static function windowGetScreenSize():RLVec2 {
		return rl.impl.RLImpl.windowGetScreenSize();
	}

	public static function windowGetMonitorCount():Int {
		return rl.impl.RLImpl.windowGetMonitorCount();
	}

	public static function windowSetTitle(title:String):Void {
		rl.impl.RLImpl.windowSetTitle(title);
	}

	public static function windowSetSize(width:Int, height:Int):Void {
		rl.impl.RLImpl.windowSetSize(width, height);
	}

	public static function windowGetCurrentMonitor():Int {
		return rl.impl.RLImpl.windowGetCurrentMonitor();
	}

	public static function windowSetMonitor(monitor:Int):Void {
		rl.impl.RLImpl.windowSetMonitor(monitor);
	}

	public static function windowGetMonitorWidth(monitor:Int):Int {
		return rl.impl.RLImpl.windowGetMonitorWidth(monitor);
	}

	public static function windowGetMonitorHeight(monitor:Int):Int {
		return rl.impl.RLImpl.windowGetMonitorHeight(monitor);
	}

	public static function windowGetMonitorPosition(monitor:Int):RLVec2 {
		return rl.impl.RLImpl.windowGetMonitorPosition(monitor);
	}

	public static function windowGetPosition():RLVec2 {
		return rl.impl.RLImpl.windowGetPosition();
	}

	public static function windowSetPosition(x:Int, y:Int):Void {
		rl.impl.RLImpl.windowSetPosition(x, y);
	}

	public static function camera3dCreate(positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float,
			upY:Float, upZ:Float, fovy:Float, projection:Int):RLHandle {
		return rl.impl.RLImpl.camera3dCreate(positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);
	}

	public static function camera3dSet(camera:RLHandle, positionX:Float, positionY:Float, positionZ:Float, targetX:Float, targetY:Float, targetZ:Float,
			upX:Float, upY:Float, upZ:Float, fovy:Float, projection:Int):Bool {
		return rl.impl.RLImpl.camera3dSet(camera, positionX, positionY, positionZ, targetX, targetY, targetZ, upX, upY, upZ, fovy, projection);
	}

	public static function camera3dSetActive(camera:RLHandle):Bool {
		return rl.impl.RLImpl.camera3dSetActive(camera);
	}

	public static function camera3dDestroy(camera:RLHandle):Void {
		rl.impl.RLImpl.camera3dDestroy(camera);
	}

	public static function modelCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.modelCreate(filename);
	}

	public static function modelSetTransform(model:RLHandle, positionX:Float, positionY:Float, positionZ:Float, rotationX:Float, rotationY:Float,
			rotationZ:Float, scaleX:Float, scaleY:Float, scaleZ:Float):Bool {
		return rl.impl.RLImpl.modelSetTransform(model, positionX, positionY, positionZ, rotationX, rotationY, rotationZ, scaleX, scaleY, scaleZ);
	}

	public static function modelDraw(model:RLHandle, tint:RLHandle):Void {
		rl.impl.RLImpl.modelDraw(model, tint);
	}

	public static function modelSetAnimation(model:RLHandle, animationIndex:Int):Bool {
		return rl.impl.RLImpl.modelSetAnimation(model, animationIndex);
	}

	public static function modelSetAnimationSpeed(model:RLHandle, speed:Float):Bool {
		return rl.impl.RLImpl.modelSetAnimationSpeed(model, speed);
	}

	public static function modelSetAnimationLoop(model:RLHandle, shouldLoop:Bool):Bool {
		return rl.impl.RLImpl.modelSetAnimationLoop(model, shouldLoop);
	}

	public static function modelAnimate(model:RLHandle, deltaSeconds:Float):Bool {
		return rl.impl.RLImpl.modelAnimate(model, deltaSeconds);
	}

	public static function modelDestroy(model:RLHandle):Void {
		rl.impl.RLImpl.modelDestroy(model);
	}

	public static function sprite3dCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.sprite3dCreate(filename);
	}

	public static function sprite3dSetTransform(sprite:RLHandle, positionX:Float, positionY:Float, positionZ:Float, size:Float):Bool {
		return rl.impl.RLImpl.sprite3dSetTransform(sprite, positionX, positionY, positionZ, size);
	}

	public static function sprite3dDraw(sprite:RLHandle, tint:RLHandle):Void {
		rl.impl.RLImpl.sprite3dDraw(sprite, tint);
	}

	public static function sprite3dDestroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite3dDestroy(sprite);
	}

	public static function sprite2dCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.sprite2dCreate(filename);
	}

	public static function sprite2dCreateFromTexture(texture:RLHandle):RLHandle {
		return rl.impl.RLImpl.sprite2dCreateFromTexture(texture);
	}

	public static function sprite2dSetTransform(sprite:RLHandle, x:Float, y:Float, scale:Float, rotation:Float):Bool {
		return rl.impl.RLImpl.sprite2dSetTransform(sprite, x, y, scale, rotation);
	}

	public static function sprite2dDraw(sprite:RLHandle, tint:RLHandle):Void {
		rl.impl.RLImpl.sprite2dDraw(sprite, tint);
	}

	public static function sprite2dDestroy(sprite:RLHandle):Void {
		rl.impl.RLImpl.sprite2dDestroy(sprite);
	}

	public static function textureCreate(filename:String):RLHandle {
		return rl.impl.RLImpl.textureCreate(filename);
	}

	public static function textureDestroy(texture:RLHandle):Void {
		rl.impl.RLImpl.textureDestroy(texture);
	}

	public static function textureDrawEx(texture:RLHandle, x:Float, y:Float, scale:Float, rotation:Float, tint:RLHandle):Void {
		rl.impl.RLImpl.textureDrawEx(texture, x, y, scale, rotation, tint);
	}

	public static function textureDrawGround(texture:RLHandle, positionX:Float, positionY:Float, positionZ:Float, width:Float, length:Float,
			tint:RLHandle):Void {
		rl.impl.RLImpl.textureDrawGround(texture, positionX, positionY, positionZ, width, length, tint);
	}

	public static function inputPollEvents():Void {
		rl.impl.RLImpl.inputPollEvents();
	}

	public static function inputGetMousePosition():RLVec2 {
		return rl.impl.RLImpl.inputGetMousePosition();
	}

	public static function inputGetMouseWheel():Int {
		return rl.impl.RLImpl.inputGetMouseWheel();
	}

	public static function inputGetMouseButton(button:Int):Int {
		return rl.impl.RLImpl.inputGetMouseButton(button);
	}

	public static function inputGetMouseState():RLMouseState {
		return rl.impl.RLImpl.inputGetMouseState();
	}

	public static function inputGetKeyboardState():RLKeyboardState {
		return rl.impl.RLImpl.inputGetKeyboardState();
	}

	public static function pickModel(camera:RLHandle, model:RLHandle, mouseX:Float, mouseY:Float):RLPickResult {
		return rl.impl.RLImpl.pickModel(camera, model, mouseX, mouseY);
	}

	public static function pickSprite3d(camera:RLHandle, sprite3d:RLHandle, mouseX:Float, mouseY:Float):RLPickResult {
		return rl.impl.RLImpl.pickSprite3d(camera, sprite3d, mouseX, mouseY);
	}

	public static function pickResetStats():Void {
		rl.impl.RLImpl.pickResetStats();
	}

	public static function pickGetBroadphaseTests():Int {
		return rl.impl.RLImpl.pickGetBroadphaseTests();
	}

	public static function pickGetBroadphaseRejects():Int {
		return rl.impl.RLImpl.pickGetBroadphaseRejects();
	}

	public static function pickGetNarrowphaseTests():Int {
		return rl.impl.RLImpl.pickGetNarrowphaseTests();
	}

	public static function pickGetNarrowphaseHits():Int {
		return rl.impl.RLImpl.pickGetNarrowphaseHits();
	}

	@async
	public static function loaderInit(?mountPoint:String):Int {
		return cast rl.impl.RLImpl.loaderInit(mountPoint);
	}

	public static function loaderInitAsync(?mountPoint:String):Int {
		return rl.impl.RLImpl.loaderInitAsync(mountPoint);
	}

	@async
	public static function loaderDeinit():VoidResult {
		return rl.impl.RLImpl.loaderDeinit();
	}

	public static function loaderIsInitialized():Bool {
		return rl.impl.RLImpl.loaderIsInitialized();
	}

	public static function loaderRestoreFsAsync():RLHandle {
		return rl.impl.RLImpl.loaderRestoreFsAsync();
	}

	public static function loaderImportAssetAsync(filename:String):RLHandle {
		return rl.impl.RLImpl.loaderImportAssetAsync(filename);
	}

	@async
	public static function loaderImportAsset(filename:String):RLHandle {
		return cast rl.impl.RLImpl.loaderImportAsset(filename);
	}

	public static function loaderImportAssetsAsync(filenames:Array<String>):RLHandle {
		return rl.impl.RLImpl.loaderImportAssetsAsync(filenames);
	}

	public static function loaderPollTask(task:RLHandle):Bool {
		return rl.impl.RLImpl.loaderPollTask(task);
	}

	public static function loaderFinishTask(task:RLHandle):Int {
		return rl.impl.RLImpl.loaderFinishTask(task);
	}

	public static function loaderGetTaskPath(task:RLHandle):String {
		return rl.impl.RLImpl.loaderGetTaskPath(task);
	}

	public static function loaderReadLocal(filename:String):Bytes {
		return rl.impl.RLImpl.loaderReadLocal(filename);
	}

	public static function loaderFreeTask(task:RLHandle):Void {
		rl.impl.RLImpl.loaderFreeTask(task);
	}

	public static function loaderIsAssetCached(filename:String):Bool {
		return rl.impl.RLImpl.loaderIsAssetCached(filename);
	}

	public static function loaderPingAssetHost(?assetHost:String):Float {
		return rl.impl.RLImpl.loaderPingAssetHost(assetHost);
	}

	public static function loaderGetCacheDir():String {
		return rl.impl.RLImpl.loaderGetCacheDir();
	}

	public static function loaderCreateTaskGroup<T>(?onComplete:RLTaskGroupCallback<T>, ?onError:RLTaskGroupCallback<T>, ?ctx:T):RLTaskGroup {
		return rl.impl.RLImpl.loaderCreateTaskGroup(onComplete, onError, ctx);
	}

	public static function loaderTaskInvalid():RLHandle {
		return rl.impl.RLImpl.loaderTaskInvalid();
	}

	public static function loaderTaskIsValid(task:RLHandle):Bool {
		return rl.impl.RLImpl.loaderTaskIsValid(task);
	}

	public static function loaderAddTask<T>(task:RLHandle, onSuccess:String->T->Void, onFailure:String->T->Void, ctx:T):Int {
		return rl.impl.RLImpl.loaderAddTask(task, onSuccess, onFailure, ctx);
	}

	public static function loaderTick():Void {
		rl.impl.RLImpl.loaderTick();
	}

	public static function loaderClearCache():Int {
		return rl.impl.RLImpl.loaderClearCache();
	}

	public static function loaderUncacheAsset(filename:String):Int {
		return rl.impl.RLImpl.loaderUncacheAsset(filename);
	}

	public static function loggerMessage(level:Int, message:String):Void {
		rl.impl.RLImpl.loggerMessage(level, message);
	}

	public static function loggerSetLevel(level:Int):Void {
		rl.impl.RLImpl.loggerSetLevel(level);
	}
}
