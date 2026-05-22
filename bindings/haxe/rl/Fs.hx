/** Public façade: Fs subsystem. */
package rl;

import rl.Types.RLHandle;
import rl.Types.RLAsyncVoid;
import haxe.io.Bytes;

@:keep
class Fs {


	@async
	public static function init(?baseDir:String):Int {
		return cast rl.impl.RLImpl.fsInit(baseDir);
	}

	public static function initAsync(?baseDir:String):Int {
		return rl.impl.RLImpl.fsInitAsync(baseDir);
	}

	@async
	public static function deinit():RLAsyncVoid {
		return cast rl.impl.RLImpl.fsDeinit();
	}

	public static function deinitAsync():RLHandle {
		return rl.impl.RLImpl.fsDeinitAsync();
	}

	public static function isInitialized():Bool {
		return rl.impl.RLImpl.fsIsInitialized();
	}

	public static function isReady():Bool {
		return rl.impl.RLImpl.fsIsReady();
	}

	public static function flush():Int {
		return rl.impl.RLImpl.fsFlush();
	}

	public static function getRootDir():String {
		return rl.impl.RLImpl.fsGetRootDir();
	}

	public static function normalizePath(path:String):String {
		return rl.impl.RLImpl.fsNormalizePath(path);
	}

	public static function restoreAsync():RLHandle {
		return rl.impl.RLImpl.fsRestoreAsync();
	}

	public static function read(filename:String):Bytes {
		return rl.impl.RLImpl.fsRead(filename);
	}

	public static function write(path:String, bytes:Bytes):Int {
		return rl.impl.RLImpl.fsWrite(path, bytes);
	}

	public static function exists(filename:String):Bool {
		return rl.impl.RLImpl.fsExists(filename);
	}

	public static function remove(filename:String):Int {
		return rl.impl.RLImpl.fsRemove(filename);
	}

	public static function clear():Int {
		return rl.impl.RLImpl.fsClear();
	}

	public static function mkdir(path:String):Int {
		return rl.impl.RLImpl.fsMkdir(path);
	}

	public static function rmdir(path:String):Int {
		return rl.impl.RLImpl.fsRmdir(path);
	}
}
