/**
 * Core librl lifecycle and shared constants.
 *
 * Subsystem APIs live in sibling classes: `rl.Fs`, `rl.Asset`, `rl.Model`, …
 * All delegate through `rl.impl.RLImpl` by target (cpp / js).
 */

package rl;

import rl.Types.RLBootConfig;
import rl.Types.RLInitConfig;
import rl.Types.RLAsyncVoid;

@:keep
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

	public static var BOOT_OK(get, never):Int;

	static inline function get_BOOT_OK():Int
		return rl.impl.RLImpl.BOOT_OK;

	public static var BOOT_ERR_UNKNOWN(get, never):Int;

	static inline function get_BOOT_ERR_UNKNOWN():Int
		return rl.impl.RLImpl.BOOT_ERR_UNKNOWN;

	public static var BOOT_ERR_LOADER(get, never):Int;

	static inline function get_BOOT_ERR_LOADER():Int
		return rl.impl.RLImpl.BOOT_ERR_LOADER;

	public static var BOOT_ERR_VERSION_MISMATCH(get, never):Int;

	static inline function get_BOOT_ERR_VERSION_MISMATCH():Int
		return rl.impl.RLImpl.BOOT_ERR_VERSION_MISMATCH;

	public static var TICK_RUNNING(get, never):Int;

	static inline function get_TICK_RUNNING():Int
		return rl.impl.RLImpl.TICK_RUNNING;

	public static var TICK_WAITING(get, never):Int;

	static inline function get_TICK_WAITING():Int
		return rl.impl.RLImpl.TICK_WAITING;

	public static var TICK_FAILED(get, never):Int;

	static inline function get_TICK_FAILED():Int
		return rl.impl.RLImpl.TICK_FAILED;

	@:async
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

	@async
	public static function deinit():RLAsyncVoid {
		return cast rl.impl.RLImpl.deinit();
	}

	public static function isInitialized():Bool {
		return rl.impl.RLImpl.isInitialized();
	}

	public static function getPlatform():String {
		return rl.impl.RLImpl.getPlatform();
	}

	public static function handleKind(handle:Int):Int {
		return rl.impl.RLImpl.handleKind(handle);
	}

	public static var HANDLE_KIND_NONE(get, never):Int;

	static inline function get_HANDLE_KIND_NONE():Int
		return rl.impl.RLImpl.HANDLE_KIND_NONE;

	public static var HANDLE_KIND_COLOR(get, never):Int;

	static inline function get_HANDLE_KIND_COLOR():Int
		return rl.impl.RLImpl.HANDLE_KIND_COLOR;

	public static var HANDLE_KIND_CAMERA3D(get, never):Int;

	static inline function get_HANDLE_KIND_CAMERA3D():Int
		return rl.impl.RLImpl.HANDLE_KIND_CAMERA3D;

	public static var HANDLE_KIND_FONT(get, never):Int;

	static inline function get_HANDLE_KIND_FONT():Int
		return rl.impl.RLImpl.HANDLE_KIND_FONT;

	public static var HANDLE_KIND_TEXTURE(get, never):Int;

	static inline function get_HANDLE_KIND_TEXTURE():Int
		return rl.impl.RLImpl.HANDLE_KIND_TEXTURE;

	public static var HANDLE_KIND_SPRITE2D(get, never):Int;

	static inline function get_HANDLE_KIND_SPRITE2D():Int
		return rl.impl.RLImpl.HANDLE_KIND_SPRITE2D;

	public static var HANDLE_KIND_SPRITE3D(get, never):Int;

	static inline function get_HANDLE_KIND_SPRITE3D():Int
		return rl.impl.RLImpl.HANDLE_KIND_SPRITE3D;

	public static var HANDLE_KIND_MODEL(get, never):Int;

	static inline function get_HANDLE_KIND_MODEL():Int
		return rl.impl.RLImpl.HANDLE_KIND_MODEL;

	public static var HANDLE_KIND_MODEL_ASSET(get, never):Int;

	static inline function get_HANDLE_KIND_MODEL_ASSET():Int
		return rl.impl.RLImpl.HANDLE_KIND_MODEL_ASSET;

	public static var HANDLE_KIND_SOUND(get, never):Int;

	static inline function get_HANDLE_KIND_SOUND():Int
		return rl.impl.RLImpl.HANDLE_KIND_SOUND;

	public static var HANDLE_KIND_MUSIC(get, never):Int;

	static inline function get_HANDLE_KIND_MUSIC():Int
		return rl.impl.RLImpl.HANDLE_KIND_MUSIC;

	public static var HANDLE_KIND_TEXT2D(get, never):Int;

	static inline function get_HANDLE_KIND_TEXT2D():Int
		return rl.impl.RLImpl.HANDLE_KIND_TEXT2D;

	public static var HANDLE_KIND_SCENE(get, never):Int;

	static inline function get_HANDLE_KIND_SCENE():Int
		return rl.impl.RLImpl.HANDLE_KIND_SCENE;

	public static var HANDLE_KIND_ASSET_TASK(get, never):Int;

	static inline function get_HANDLE_KIND_ASSET_TASK():Int
		return rl.impl.RLImpl.HANDLE_KIND_ASSET_TASK;

	public static function versionMajor():Int {
		return rl.impl.RLImpl.versionMajor();
	}

	public static function versionMinor():Int {
		return rl.impl.RLImpl.versionMinor();
	}

	public static function versionPatch():Int {
		return rl.impl.RLImpl.versionPatch();
	}

	public static function versionLabel():String {
		return rl.impl.RLImpl.versionLabel();
	}

	public static function versionNumber():Int {
		return rl.impl.RLImpl.versionNumber();
	}

	public static function versionString():String {
		return rl.impl.RLImpl.versionString();
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
}
